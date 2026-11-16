#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${VERSION:?Pass the immutable candidate version}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || { echo 'Invalid version' >&2; exit 2; }
[[ ! -e build/maven && ! -e build/system-actions-maven.tar.gz ]] || { echo "Candidate outputs already exist" >&2; exit 2; }
bash gradlew --init-script "$PWD/scripts/ci-repositories.gradle" publishAllPublicationsToStagingRepository --no-daemon --max-workers=1 -Dorg.gradle.parallel=false "$@"
python3 scripts/jitpack-metadata.py build/maven
python3 release-pack.py build/maven build/system-actions-maven.tar.gz "$VERSION"
shasum -a 256 build/system-actions-maven.tar.gz > build/system-actions-maven.tar.gz.sha256
