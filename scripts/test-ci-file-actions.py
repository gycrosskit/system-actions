#!/usr/bin/env python3
import subprocess
import json
import re
from pathlib import Path

script = Path(__file__).with_name('ci-file-actions.sh')
for version in ('0.1.3', '0.2.0-rc.1', '0.2.0-rc.2', '0.2.0-rc.3', '0.2.0-rc.4'):
    assert subprocess.check_output(['bash', str(script), version], text=True).strip() == 'false'
for version in ('0.2.0-rc.5', '0.2.0-rc.6', '0.2.0-rc.7', '1.0.0', '1.0.1', '1.1.0', '1.1.1'):
    assert subprocess.check_output(['bash', str(script), version], text=True).strip() == 'true'
for version in ('1.0.2', 'native-0.2.0', 'bad/version'):
    result = subprocess.run(['bash', str(script), version], capture_output=True, text=True)
    assert result.returncode != 0 and not result.stdout, version
build = script.parent.parent / 'build.gradle.kts'
versions = re.findall(r'^\s*version = providers\.environmentVariable\("VERSION"\)\.orElse\("([^"\n]+)"\)\.get\(\)\s*$', build.read_text(), re.MULTILINE)
assert len(versions) == 1, 'Current source version declaration must match the explicit build format'
source_version = versions[0]
assert subprocess.check_output(['bash', str(script), source_version], text=True).strip() == 'true', source_version
root = build.parent
har_version = json.loads((root / 'ohos/system-actions-native/oh-package.json5').read_text())['version']
for path, current in ((root / 'CHANGELOG.md', source_version),
                      (root / 'ohos/system-actions-native/CHANGELOG.md', har_version)):
    sections = re.findall(r'^##[ \t]+(.*?)\n(.*?)(?=^#{1,2}[ \t]|\Z)', path.read_text(), re.MULTILINE | re.DOTALL)
    current_sections = [(title, body) for title, body in sections
                        if re.match(re.escape(current) + r'($|[ \t（(])', title)]
    assert len(current_sections) == 1, f'{path}: current version must appear exactly once'
    title, body = current_sections[0]
    assert title == current, f'{path}: use ## <version>; put release status in the body'
    assert re.search(r'^-[ \t]+\S', body, re.MULTILINE), f'{path}: current version needs change entries'
print('File-actions release mappings and rejection checks passed')
print(f'Current source version {source_version}: mapped and file-actions probe enabled')
