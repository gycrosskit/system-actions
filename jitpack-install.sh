#!/usr/bin/env bash
set -euo pipefail

archive=system-actions-maven.tar.gz
curl -fL --retry 3 -o "$archive" "https://github.com/gycrosskit/system-actions/releases/download/${VERSION}/${archive}"
echo "848c4fd3dfd1d31c35d9393551db51cd22532c41bc6f42d11631b38915018267  $archive" | sha256sum -c -
mkdir -p "$HOME/.m2/repository" build/release-maven
tar -xzf "$archive" -C "$HOME/.m2/repository"
tar -xzf "$archive" -C build/release-maven
python3 - <<'PY'
import json
from pathlib import Path

# JitPack rewrites classified source/metadata JAR URLs to missing plain JARs.
changed = 0
for root in (Path.home() / '.m2/repository/com/github/gycrosskit/system-actions', Path('build/release-maven')):
    for file in root.rglob('*.module'):
        data = json.loads(file.read_text())
        variants = [v for v in data['variants'] if not v['name'].endswith(('SourcesElements-published', 'MetadataElements-published'))]
        if len(variants) != len(data['variants']):
            data['variants'] = variants
            file.write_text(json.dumps(data, indent=2))
            changed += 1
if not changed:
    raise SystemExit('No JitPack KMP metadata variants were fixed')
PY
