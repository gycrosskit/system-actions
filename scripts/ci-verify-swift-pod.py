"""从不可变 native tag 安装真实 Git Pod，核对源码身份并编译独立 Swift API 消费者。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess


def verify_sources(checkout, installed, version):
    metadata = json.loads((installed.parent / 'Local Podspecs/GYCWindowPolicy.podspec.json').read_text())
    assert metadata['version'] == version, 'Installed Pod version mismatch'
    assert metadata['source'] == {
        'git': 'https://github.com/gycrosskit/system-actions.git', 'tag': f'native-{version}'
    }, 'Installed Pod source is not the exact native tag'
    relative = Path('ios/Sources/GYCWindowPolicy')
    expected = {str(p.relative_to(checkout / relative)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in (checkout / relative).rglob('*.swift')}
    actual = {str(p.relative_to(installed / relative)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in (installed / relative).rglob('*.swift')}
    assert expected and actual == expected, 'Remote Pod Swift sources differ from the checked-out release commit'
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--build-dir', required=True, type=Path)
    parser.add_argument('--proof', required=True, type=Path)
    args = parser.parse_args()
    assert re.fullmatch(r'native-\d+\.\d+\.\d+(?:-rc\.\d+)?', args.tag), 'Expected immutable native release tag'
    assert args.build_dir.is_absolute() and not args.build_dir.exists(), 'Use a fresh absolute consumer directory'
    checkout = Path.cwd()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    tag_commit = subprocess.check_output(['git', 'rev-parse', f'{args.tag}^{{commit}}'], text=True).strip()
    assert commit == tag_commit, 'Checkout is not the exact release tag'
    version = args.tag.removeprefix('native-')
    arch = platform.machine()
    assert arch in ('arm64', 'x86_64'), 'Unsupported Simulator architecture'
    args.build_dir.mkdir(parents=True)
    (args.build_dir / 'Podfile').write_text(f'''install! 'cocoapods', :integrate_targets => false
platform :ios, '14.0'
use_frameworks!
target 'KeyboardObservationConsumer' do
  pod 'GYCWindowPolicy/Core', :git => 'https://github.com/gycrosskit/system-actions.git', :tag => '{args.tag}'
end
''')
    subprocess.run(['pod', 'install'], cwd=args.build_dir,
                   env={**os.environ, 'CP_HOME_DIR': str(args.build_dir / 'cocoapods')}, check=True)
    sources = verify_sources(checkout, args.build_dir / 'Pods/GYCWindowPolicy', version)
    products = args.build_dir / 'Products'
    subprocess.run(['xcodebuild', '-project', str(args.build_dir / 'Pods/Pods.xcodeproj'),
                    '-scheme', 'GYCWindowPolicy', '-configuration', 'Debug', '-sdk', 'iphonesimulator',
                    '-derivedDataPath', str(args.build_dir / 'DerivedData'), '-arch', arch,
                    'ONLY_ACTIVE_ARCH=YES', f'CONFIGURATION_BUILD_DIR={products}',
                    'CODE_SIGNING_ALLOWED=NO', 'build'], check=True)
    sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
    subprocess.run(['xcrun', 'swiftc', '-typecheck', '-target', f'{arch}-apple-ios14.0-simulator',
                    '-sdk', sdk, '-F', str(products), str(checkout / 'verification/KeyboardObservation.swift')], check=True)
    proof = {'tag': args.tag, 'commit': commit, 'podVersion': version, 'sourcesSHA256': sources,
             'architecture': arch, 'podBuild': 'passed', 'consumerTypecheck': 'passed',
             'scope': 'Exact remote Git Pod Core and public legacy/completion Swift API; no device or host acceptance'}
    args.proof.parent.mkdir(parents=True, exist_ok=True)
    args.proof.write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(proof, ensure_ascii=False))


if __name__ == '__main__':
    main()
