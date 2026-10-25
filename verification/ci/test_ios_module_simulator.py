#!/usr/bin/env python3
"""模拟器准备、真实 PASS 门禁与资源所有权；不执行本机 Swift/simctl。"""
import json
import os
from pathlib import Path
import shutil
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
elif args[:1] == ['swift']:
    assert '-module-cache-path' in args and args[-1].endswith('main.swift')
    sys.exit(21 if case == 'native_services_failure' else 0)
elif args[:3] == ['simctl', 'list', 'runtimes']:
    print(json.dumps({'runtimes': [{
        'isAvailable': case != 'no_runtime',
        'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-18-5',
        'supportedDeviceTypes': [{'name': 'iPhone', 'identifier': 'mock-iPhone'}]
    }]}))
elif args[:2] == ['simctl', 'create']:
    print(os.environ['MOCK_DEVICE'])
elif args[:2] == ['simctl', 'get_app_container']:
    print(os.environ['MOCK_DATA'])
elif args[:2] == ['simctl', 'spawn']:
    print('fixture scoped lifecycle diagnostics')
elif args[:2] == ['simctl', 'launch']:
    run_id = os.environ.get('SIMCTL_CHILD_GYC_SYSTEM_ACTIONS_RUN_ID', os.environ['MOCK_DEVICE'])
    receipt = Path(os.environ['MOCK_DATA']) / 'Documents' / ('ModuleLifecycle-' + run_id + '.json')
    payload = json.dumps({'run_id': os.environ['MOCK_DEVICE'] if case == 'stale_receipt' else run_id,
                          'result': 'KUIKLY_MODULE_LIFECYCLE_PASS'})
    if case == 'delayed_receipt':
        import subprocess
        subprocess.Popen([sys.executable, '-c',
            'import sys,time;from pathlib import Path;time.sleep(0.2);p=Path(sys.argv[1]);t=p.with_suffix(".tmp");t.write_text(sys.argv[2]);t.replace(p)',
            str(receipt), payload], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif case != 'missing_pass':
        receipt.write_text('invalid json' if case == 'malformed_receipt' else payload)
    print('com.gycrosskit.systemactions.module.lifecycle: 4242')
    if case in ['missing_pass', 'launch_failure']:
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
    fixture = temp / 'component'
    fixture_script = fixture / 'scripts/test-ios-module.sh'
    fixture_script.parent.mkdir(parents=True)
    fixture_script.write_text(SCRIPT.read_text().replace('timeout=90', 'timeout=0.5')
        .replace('deadline = time.monotonic() + 90', 'deadline = time.monotonic() + 0.5')
        .replace('Path.home()', 'Path(' + repr(str(temp)) + ')'))
    for relative in ['verification/test-native-services.py',
                     'ios/Sources/GYCSystemActionsKuikly/GycSystemActionsNativeServices.swift',
                     'verification/KuiklyLifecycle.swift']:
        destination = fixture / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, destination)
    data = temp / 'Data/Documents'
    data.mkdir(parents=True)
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
                       TMPDIR=str(temp), MOCK_CALLS=str(calls), MOCK_DEVICE=DEVICE, MOCK_DATA=str(data.parent))

    def run(case, *args, output_path=output):
        calls.write_text('')
        output.write_text('')
        environment['MOCK_CASE'] = case
        environment['GITHUB_OUTPUT'] = str(output_path)
        result = subprocess.run(['bash', str(fixture_script), *args], env=environment,
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

    result, sim = run('native_services_failure', str(products), DEVICE)
    assert result.returncode != 0 and not sim
    assert 'LIFECYCLE_PHASE compile.start' not in result.stdout

    result, sim = run('normal', str(products), DEVICE)
    assert result.returncode == 0 and sim == ['bootstatus', 'install', 'get_app_container', 'launch', 'uninstall'], (result.stdout, result.stderr, sim)
    assert 'LIFECYCLE_PHASE launch.pass' in result.stdout
    assert 'Fresh lifecycle receipt:' in result.stdout
    assert all(f'LIFECYCLE_PHASE {phase}' in result.stdout for phase in [
        'compile.start', 'compile.end', 'sign.start', 'sign.end',
        'simulator.ready.start', 'simulator.ready.end', 'install.start', 'install.end'])
    for case in ['compile_failure', 'sign_failure', 'ready_failure', 'install_failure',
                 'missing_pass', 'launch_failure', 'stale_receipt', 'malformed_receipt']:
        result, sim = run(case, str(products), DEVICE)
        assert result.returncode != 0 and 'LIFECYCLE_PHASE launch.pass' not in result.stdout, case
        assert not any(c in sim for c in ['create', 'boot', 'shutdown', 'delete']), case
        if case in ['compile_failure', 'sign_failure', 'ready_failure', 'install_failure']:
            assert 'launch' not in sim, case
        else:
            assert sim[-1] == 'uninstall', case
        result, sim = run('normal', '--cleanup-simulator', DEVICE)
        assert result.returncode == 0 and sim == ['shutdown', 'delete']

    result, sim = run('delayed_receipt', str(products), DEVICE)
    assert result.returncode == 0 and 'Fresh lifecycle receipt:' in result.stdout

    for case in ['normal', 'ready_failure', 'missing_pass']:
        result, sim = run(case, str(products))
        assert (result.returncode == 0) == (case == 'normal')
        assert sim[:3] == ['list', 'create', 'boot'] and sim[-2:] == ['shutdown', 'delete']
    result, sim = run('normal', '--cleanup-simulator', 'booted')
    assert result.returncode != 0 and not sim

print('Simulator contract: ready wait, real PASS and owned-device cleanup')
