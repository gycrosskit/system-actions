#!/usr/bin/env python3
import subprocess
import re
from pathlib import Path

script = Path(__file__).with_name('ci-file-actions.sh')
for version in ('0.1.3', '0.2.0-rc.1', '0.2.0-rc.2', '0.2.0-rc.3', '0.2.0-rc.4'):
    assert subprocess.check_output(['bash', str(script), version], text=True).strip() == 'false'
for version in ('0.2.0-rc.5', '0.2.0-rc.6', '0.2.0-rc.7'):
    assert subprocess.check_output(['bash', str(script), version], text=True).strip() == 'true'
for version in ('1.0.0', 'native-0.2.0', 'bad/version'):
    result = subprocess.run(['bash', str(script), version], capture_output=True, text=True)
    assert result.returncode != 0 and not result.stdout, version
build = script.parent.parent / 'build.gradle.kts'
versions = re.findall(r'^\s*version = providers\.environmentVariable\("VERSION"\)\.orElse\("([^"\n]+)"\)\.get\(\)\s*$', build.read_text(), re.MULTILINE)
assert len(versions) == 1, 'Current source version declaration must match the explicit build format'
source_version = versions[0]
assert subprocess.check_output(['bash', str(script), source_version], text=True).strip() == 'true', source_version
print('File-actions release boundaries: 11 assertions passed')
print(f'Current source version {source_version}: mapped and file-actions probe enabled')
