#!/usr/bin/env bash
# Exercise the real SDK's dealloc/invalidate path using the already-built source Pod.
set -euo pipefail
products=${1:?Usage: test-ios-module.sh absolute-Products-directory [device] | --prepare-simulator | --cleanup-simulator device}
work_dir=
device=
own_device=false
installed=false
bundle_id=com.gycrosskit.systemactions.module.lifecycle
phase() {
  printf 'LIFECYCLE_PHASE %s elapsed_seconds=%s utc=%s\n' "$1" "$SECONDS" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
cleanup() {
  if [[ -n "$device" && "$own_device" == true ]]; then
    phase cleanup.start
    xcrun simctl shutdown "$device" || true
    xcrun simctl delete "$device" || true
    phase cleanup.end
  elif [[ "$installed" == true ]]; then
    phase uninstall.start
    xcrun simctl uninstall "$device" "$bundle_id" || true
    phase uninstall.end
  fi
  if [[ -n "$work_dir" ]]; then rm -rf "$work_dir"; fi
}
trap cleanup EXIT
prepare_simulator() {
  own_device=true
  phase simulator.create.start
  # Global device types can include iPhones unsupported by the selected runtime.
  read -r runtime device_type < <(xcrun simctl list runtimes -j | python3 -c '
import json, sys
for runtime in json.load(sys.stdin)["runtimes"]:
    if not runtime.get("isAvailable") or not runtime["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS"):
        continue
    for device_type in runtime.get("supportedDeviceTypes", []):
        if device_type["name"].startswith("iPhone"):
            print(runtime["identifier"], device_type["identifier"])
            sys.exit(0)
sys.exit("No available iOS runtime with a supported iPhone device type")
')
  device=$(xcrun simctl create GYCModuleLifecycle "$device_type" "$runtime")
  phase simulator.create.end
  phase simulator.boot.start
  xcrun simctl boot "$device"
  phase simulator.boot.end
}
case "$products" in
  --prepare-simulator)
    : "${GITHUB_OUTPUT:?Simulator preparation requires a GitHub step output file}"
    prepare_simulator
    printf 'device=%s\n' "$device" >> "$GITHUB_OUTPUT"
    # CI 的 always 清理步骤接管设备；此处不等待 ready，让启动与编译重叠。
    own_device=false
    exit 0
    ;;
  --cleanup-simulator)
    device=${2:?A prepared simulator UUID is required}
    [[ "$device" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]] || { device=; echo 'Invalid simulator UUID' >&2; exit 1; }
    own_device=true
    exit 0
    ;;
esac
[[ "$products" = /* ]] || { echo 'Products directory must be absolute' >&2; exit 1; }
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
python3 "$repo_dir/verification/test-native-services.py"
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/gyc-module-test.XXXXXX")
device=${2:-}
app="$work_dir/ModuleTest.app"
mkdir -p "$app/Frameworks"
for framework in OpenKuiklyIOSRender GYCWindowPolicy; do
  test -d "$products/$framework.framework"
  cp -R "$products/$framework.framework" "$app/Frameworks/"
done
phase compile.start
xcrun --sdk iphonesimulator swiftc -parse-as-library "$repo_dir/verification/KuiklyLifecycle.swift" \
  -target "$(uname -m)-apple-ios15.0-simulator" -sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -F "$products" -framework OpenKuiklyIOSRender -framework GYCWindowPolicy \
  -Xlinker -rpath -Xlinker '@executable_path/Frameworks' -o "$app/ModuleTest"
phase compile.end
cat > "$app/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.gycrosskit.systemactions.module.lifecycle</string>
<key>CFBundleExecutable</key><string>ModuleTest</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSRequiresIPhoneOS</key><true/>
<key>UIApplicationSceneManifest</key><dict>
<key>UIApplicationSupportsMultipleScenes</key><false/>
<key>UISceneConfigurations</key><dict>
<key>UIWindowSceneSessionRoleApplication</key><array><dict>
<key>UISceneConfigurationName</key><string>NativeCheck</string>
<key>UISceneDelegateClassName</key><string>GYCNativeCheckScene</string>
</dict></array></dict></dict>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>MinimumOSVersion</key><string>15.0</string>
</dict></plist>
PLIST
phase sign.start
codesign --force --sign - "$app/Frameworks/GYCWindowPolicy.framework" "$app/Frameworks/OpenKuiklyIOSRender.framework" "$app" >/dev/null
phase sign.end
if [[ -z "$device" ]]; then
  prepare_simulator
fi
phase simulator.ready.start
xcrun simctl bootstatus "$device" -b
phase simulator.ready.end
phase install.start
xcrun simctl install "$device" "$app"
installed=true
phase install.end
container=$(xcrun simctl get_app_container "$device" "$bundle_id" data)
run_id=$(python3 -c 'import uuid; print(uuid.uuid4())')
mkdir -p "$repo_dir/ci-diagnostics"
phase launch.start
python3 - "$device" "$bundle_id" "$container" "$run_id" "$repo_dir/ci-diagnostics" <<'RESULT'
import json, os, resource, subprocess, sys, time
from pathlib import Path

device, bundle, container, run_id, diagnostics = sys.argv[1:]
deadline = time.monotonic() + 90
receipt = Path(container, 'Documents', 'ModuleLifecycle-' + run_id + '.json')
console = Path(diagnostics, 'system-actions-module-' + run_id + '.log')
started = time.time_ns()
def fail(message):
    print(message, file=sys.stderr)
    with Path(diagnostics, 'system-actions-failure-' + run_id + '.log').open('wb') as output:
        try:
            subprocess.run(['xcrun', 'simctl', 'spawn', device, 'log', 'show', '--last', '2m', '--style', 'compact',
                '--predicate', 'process == "ModuleTest"'], stdout=output, stderr=subprocess.STDOUT, timeout=10,
                preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_FSIZE, (8388608, 8388608)))
        except subprocess.TimeoutExpired:
            print('Lifecycle diagnostic capture timed out', file=sys.stderr)
    folders = [Path.home() / 'Library/Logs/DiagnosticReports',
        Path.home() / 'Library/Developer/CoreSimulator/Devices' / device / 'data/Library/Logs/DiagnosticReports']
    reports = [p for folder in folders for p in folder.glob('ModuleTest*')
        if p.is_file() and p.stat().st_mtime_ns >= started]
    for index, report in enumerate(sorted(reports, key=lambda p: p.stat().st_mtime_ns, reverse=True)[:3]):
        with report.open('rb') as source:
            Path(diagnostics, 'system-actions-crash-' + str(index) + '-' + report.name + '.txt').write_bytes(source.read(262144))
    sys.exit(1)
try:
    with console.open('wb') as output:
        result = subprocess.run(['xcrun', 'simctl', 'launch', '--console', '--terminate-running-process', device, bundle],
            env={**os.environ, 'SIMCTL_CHILD_GYC_SYSTEM_ACTIONS_RUN_ID': run_id},
            stdout=output, stderr=subprocess.STDOUT, timeout=90,
            preexec_fn=lambda: resource.setrlimit(resource.RLIMIT_FSIZE, (8388608, 8388608)))
except subprocess.TimeoutExpired:
    fail('Lifecycle launch timed out; completion is not verified')
sys.stdout.buffer.write(console.read_bytes())
if result.returncode != 0:
    fail('Lifecycle launch failed: ' + str(result.returncode))
# simctl 可能先返回 PID；必须等待本次 App 完成全部原始断言，不能仅凭 console 放行。
while not receipt.is_file() and time.monotonic() < deadline:
    time.sleep(0.1)
try:
    value = json.loads(receipt.read_text())
except (OSError, ValueError) as error:
    fail('Lifecycle completion receipt unavailable: ' + str(error))
if value != {'run_id': run_id, 'result': 'KUIKLY_MODULE_LIFECYCLE_PASS'}:
    fail('Lifecycle completion receipt does not match this run')
Path(diagnostics, 'system-actions-module-' + run_id + '.json').write_text(json.dumps(value) + '\n')
print('Fresh lifecycle receipt: ' + run_id + ' KUIKLY_MODULE_LIFECYCLE_PASS')
RESULT
phase launch.pass
