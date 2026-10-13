#!/usr/bin/env python3
"""模拟器准备、真实 PASS 门禁与资源所有权；不执行本机 Swift/simctl。"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'scripts/test-ios-module.sh'
DEVICE = '12345678-1234-1234-1234-123456789ABC'
MOCK = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
tool = Path(sys.argv[0]).name
with open(os.environ['MOCK_CALLS'], 'a') as f:
    f.write(json.dumps([tool, *args]) + '\n')
case = os.environ['MOCK_CASE']
if tool == 'codesign':
    sys.exit(17 if case == 'sign_failure' else 0)
if args[:2] == ['--sdk', 'iphonesimulator']:
    if args[2:] == ['--show-sdk-path']:
        print('/mock/sdk')
    else:
        assert args[2] == 'swiftc'
        if case == 'compile_failure':
            sys.exit(18)
        Path(args[args.index('-o') + 1]).write_text('mock app')
elif args[:3] == ['simctl', 'list', 'runtimes']:
    print(json.dumps({'runtimes': [{
        'isAvailable': case != 'no_runtime',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-18-5',
        'supportedDeviceTypes': [{'name': 'iPhone', 'identifier': 'mock-iPhone'}]
    }]}))
elif args[:2] == ['simctl', 'create']:
    print(os.environ['MOCK_DEVICE'])
elif args[:2] == ['simctl', 'launch']:
    if case != 'missing_pass':
        print('KUIKLY_MODULE_LIFECYCLE_PASS')
    if case == 'launch_failure':
        sys.exit(19)
elif args[0] == 'simctl' and args[1] in ['boot', 'bootstatus', 'install', 'shutdown', 'delete', 'uninstall']:
    assert args[2] == os.environ['MOCK_DEVICE']
    failures = {'boot_failure': 'boot', 'ready_failure': 'bootstatus', 'install_failure': 'install'}
    if failures.get(case) == args[1]:
        sys.exit(20)
else:
    raise AssertionError(args)
'''

with tempfile.TemporaryDirectory() as directory:
    temp = Path(directory)
    bin_dir = temp / 'bin'
    bin_dir.mkdir()
    for tool in ['xcrun', 'codesign']:
        p = bin_dir / tool
        p.write_text(MOCK)
        p.chmod(0o755)
    products = temp / 'Products'
    for name in ['GYCWindowPolicy', 'OpenKuiklyIOSRender']:
        (products / (name + '.framework')).mkdir(parents=True)
    calls = temp / 'calls.jsonl'
    output = temp / 'github-output'
    environment = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'],
                       TMPDIR=str(temp), MOCK_CALLS=str(calls), MOCK_DEVICE=DEVICE)

    def run(case, *args, output_path=output):
        calls.write_text('')
        output.write_text('')
        environment['MOCK_CASE'] = case
        environment['GITHUB_OUTPUT'] = str(output_path)
        result = subprocess.run(['bash', str(SCRIPT), *args], env=environment,
                                capture_output=True, text=True, timeout=15)
        commands = [json.loads(line) for line in calls.read_text().splitlines()]
        sim = [c[2] for c in commands if c[:2] == ['xcrun', 'simctl']]
        return result, sim

    result, sim = run('normal', '--prepare-simulator')
    assert result.returncode == 0 and sim == ['list', 'create', 'boot']
    assert output.read_text() == f'device={DEVICE}\n'
    for case in ['boot_failure', 'no_runtime', 'output_failure']:
        result, sim = run(case, '--prepare-simulator',
                          output_path=temp if case == 'output_failure' else output)
        assert result.returncode != 0 and output.read_text() == '', case
        assert sim[-2:] == ['shutdown', 'delete'] if case != 'no_runtime' else sim == ['list']

    result, sim = run('normal', str(products), DEVICE)
    assert result.returncode == 0 and sim == ['bootstatus', 'install', 'launch', 'uninstall']
    assert 'LIFECYCLE_PHASE launch.pass' in result.stdout
    assert all(f'LIFECYCLE_PHASE {phase}' in result.stdout for phase in [
        'compile.start', 'compile.end', 'sign.start', 'sign.end',
        'simulator.ready.start', 'simulator.ready.end', 'install.start', 'install.end'])
    for case in ['compile_failure', 'sign_failure', 'ready_failure', 'install_failure',
                 'missing_pass', 'launch_failure']:
        result, sim = run(case, str(products), DEVICE)
        assert result.returncode != 0 and 'LIFECYCLE_PHASE launch.pass' not in result.stdout, case
        assert not any(c in sim for c in ['create', 'boot', 'shutdown', 'delete']), case
        if case in ['compile_failure', 'sign_failure', 'ready_failure', 'install_failure']:
            assert 'launch' not in sim, case
        else:
            assert sim[-1] == 'uninstall', case
        result, sim = run('normal', '--cleanup-simulator', DEVICE)
        assert result.returncode == 0 and sim == ['shutdown', 'delete']

    for case in ['normal', 'ready_failure', 'missing_pass']:
        result, sim = run(case, str(products))
        assert (result.returncode == 0) == (case == 'normal')
        assert sim[:3] == ['list', 'create', 'boot'] and sim[-2:] == ['shutdown', 'delete']
    result, sim = run('normal', '--cleanup-simulator', 'booted')
    assert result.returncode != 0 and not sim

workflow = (ROOT / '.github/workflows/regression.yml').read_text()
native = workflow.split('\n  native:\n', 1)[1].split('\n  release-android:\n', 1)[0]
assert native.index('--prepare-simulator') < native.index('Restore complete Kotlin Native toolchains')
assert native.index('--prepare-simulator') < native.index('compileKotlinIosArm64')
assert 'if: always() && steps.module-simulator.outputs.device !=' in native
assert native.index('--cleanup-simulator') < native.index('Save public CI diagnostics')
assert 'MODULE_SIMULATOR: ${{ steps.module-simulator.outputs.device }}' in native
assert '${MODULE_SIMULATOR:?Simulator preparation did not produce a device}' in native
assert 'python3 verification/ci/test_ios_module_simulator.py' in workflow
print('Simulator contract: early boot, ready wait, real PASS and owned-device cleanup')
