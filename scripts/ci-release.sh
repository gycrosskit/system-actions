#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Provide an immutable release tag}"
[[ "$VERSION" =~ ^[0-9][0-9A-Za-z._-]*$ ]] || { echo 'Invalid release tag' >&2; exit 1; }
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
# 从不可变版本 Tag 取得提交和 tree，沿用 JitPack 的回执与归档校验。
repo_root="$PWD"
git init -q "$staging/tag"
git -C "$staging/tag" fetch -q --no-tags --depth=1 https://github.com/gycrosskit/system-actions.git "refs/tags/$VERSION"
git -C "$staging/tag" checkout -q --detach FETCH_HEAD
commit="$(git -C "$staging/tag" rev-parse --verify HEAD)"
(cd "$staging/tag" && bash "$repo_root/jitpack-install.sh" system-actions "$staging/maven")
python3 scripts/check-maven.py "$staging/maven" com.github.gycrosskit.system-actions "$VERSION" system-actions-core,system-actions-kuikly ios_arm64,ios_x64,ios_simulator_arm64,ohos_arm64
# 标签必须解析为不可变发布提交；不把当前 PR 的 SHA 当成已发布版本。
case "$VERSION" in
  0.1.3|0.2.0-rc.1|0.2.0-rc.2|0.2.0-rc.3|0.2.0-rc.4|0.2.0-rc.5|0.2.0-rc.6) expected_publications="system-actions-core,system-actions-core-android,system-actions-core-iosarm64,system-actions-core-iosx64,system-actions-core-iossimulatorarm64,system-actions-core-ohosarm64,system-actions-core-jvm,system-actions-kuikly,system-actions-kuikly-ohosarm64" ;;
  *) expected_publications="system-actions-core,system-actions-core-android,system-actions-core-iosarm64,system-actions-core-iosx64,system-actions-core-iossimulatorarm64,system-actions-core-ohosarm64,system-actions-core-jvm,system-actions-kuikly,system-actions-kuikly-android,system-actions-kuikly-iosarm64,system-actions-kuikly-iosx64,system-actions-kuikly-iossimulatorarm64,system-actions-kuikly-ohosarm64" ;;
esac
python3 scripts/check-public-maven.py --repo system-actions --version "$VERSION" --commit "$commit" \
  --expected-publications "$expected_publications" --output-dir "${CI_DIAGNOSTICS_DIR:-ci-diagnostics}/public"
