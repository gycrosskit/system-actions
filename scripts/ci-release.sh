#!/usr/bin/env bash
set -euo pipefail
: "${VERSION:?Provide an immutable release tag}"
[[ "$VERSION" =~ ^[0-9][0-9A-Za-z._-]*$ ]] || { echo 'Invalid release tag' >&2; exit 1; }
checksum="$(awk -v version="$VERSION" '$1 == version {print $2}' release-checksums.txt)"
[[ "$checksum" =~ ^[a-f0-9]{64}$ ]] || { echo "No verified checksum for $VERSION" >&2; exit 1; }
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
archive="$staging/system-actions-maven.tar.gz"
curl -fsSL --retry 3 --connect-timeout 30 --max-time 300 -o "$archive" "https://github.com/gycrosskit/system-actions/releases/download/$VERSION/system-actions-maven.tar.gz"
echo "$checksum  $archive" | shasum -a 256 -c -
python3 - "$archive" "$staging/maven" <<'EXTRACT'
import sys, tarfile
from pathlib import Path
archive, destination = sys.argv[1:]
root = Path(destination).resolve()
with tarfile.open(archive) as bundle:
    for item in bundle.getmembers():
        assert item.isfile() or item.isdir(), f"Unexpected archive member: {item.name}"
        assert (root / item.name).resolve().is_relative_to(root), item.name
    bundle.extractall(root)
EXTRACT
python3 scripts/check-maven.py "$staging/maven" com.github.gycrosskit.system-actions "$VERSION" system-actions-core,system-actions-kuikly ios_arm64,ios_x64,ios_simulator_arm64,ohos_arm64
# 标签必须解析为不可变发布提交；不把当前 PR 的 SHA 当成已发布版本。
commit="$(git ls-remote https://github.com/gycrosskit/system-actions.git "refs/tags/$VERSION" "refs/tags/$VERSION^{}" | awk '$2 ~ /\^\{\}$/ {peeled=$1} $2 !~ /\^\{\}$/ {direct=$1} END {print peeled ? peeled : direct}')"
case "$VERSION" in
  0.1.3|0.2.0-rc.1|0.2.0-rc.2|0.2.0-rc.3|0.2.0-rc.4|0.2.0-rc.5|0.2.0-rc.6) expected_publications="system-actions-core,system-actions-core-android,system-actions-core-iosarm64,system-actions-core-iosx64,system-actions-core-iossimulatorarm64,system-actions-core-ohosarm64,system-actions-core-jvm,system-actions-kuikly,system-actions-kuikly-ohosarm64" ;;
  *) expected_publications="system-actions-core,system-actions-core-android,system-actions-core-iosarm64,system-actions-core-iosx64,system-actions-core-iossimulatorarm64,system-actions-core-ohosarm64,system-actions-core-jvm,system-actions-kuikly,system-actions-kuikly-android,system-actions-kuikly-iosarm64,system-actions-kuikly-iosx64,system-actions-kuikly-iossimulatorarm64,system-actions-kuikly-ohosarm64" ;;
esac
python3 scripts/check-public-maven.py --repo system-actions --version "$VERSION" --commit "$commit" \
  --expected-publications "$expected_publications" --output-dir "${CI_DIAGNOSTICS_DIR:-ci-diagnostics}/public"
