"""复用已安装 SDK 的 NAPI 声明，在 macOS 执行原生桥生命周期断言。"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

sdk = Path(os.environ.get('OHOS_NATIVE_SDK', '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native'))
root = Path(__file__).resolve().parents[2]
header = root / 'ohos/system-actions-native/src/main/resources/rawfile/native/gyc_clipboard_bridge.h'
subprocess.run([str(sdk / 'llvm/bin/clang++'), '--target=aarch64-linux-ohos',
                '--sysroot=' + str(sdk / 'sysroot'), '-std=c++17', '-fsyntax-only', '-x', 'c++', str(header)], check=True)
with tempfile.TemporaryDirectory(prefix='gyc-clipboard-') as temp:
    target = Path(temp)
    # 只复制 NAPI 声明，避免 OHOS libc 头覆盖宿主标准库。
    for name in ['napi/native_api.h', 'napi/common.h', 'node_api.h', 'node_api_types.h',
                 'js_native_api.h', 'js_native_api_types.h', 'info/application_target_sdk_version.h']:
        dest = target / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(sdk / 'sysroot/usr/include' / name, dest)
    subprocess.run(['clang++', '-std=c++17', '-pthread', '-I', temp,
                    str(root / 'ohos/tests/clipboard-bridge.test.cpp'), '-o', str(target / 'test')], check=True)
    subprocess.run([str(target / 'test')], check=True)
print('clipboard bridge: SDK syntax and 4 lifecycle checks passed')
