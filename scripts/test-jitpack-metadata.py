"""检查改写后的校验值、重复安装和空归档失败行为。"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().with_name("jitpack-metadata.py")
with tempfile.TemporaryDirectory() as directory:
    module = Path(directory) / "sample.module"
    module.write_text(json.dumps({"variants": [
        {"name": "commonSourcesElements-published"},
        {"name": "iosArm64MetadataElements-published"},
        {"name": "metadataSourcesElements"},
        {"name": "metadataApiElements"}, {"name": "androidRuntime"}
    ]}))
    checksum = module.with_suffix(".module.sha256")
    checksum.write_text("old")
    for _ in range(2):
        subprocess.run(["python3", str(script), directory], check=True)
        assert checksum.read_text() == hashlib.sha256(module.read_bytes()).hexdigest()
        assert json.loads(module.read_text())["variants"] == [
            {"name": "metadataApiElements"}, {"name": "androidRuntime"}
        ]
with tempfile.TemporaryDirectory() as empty:
    result = subprocess.run(["python3", str(script), empty], capture_output=True, text=True)
    assert result.returncode != 0 and "No Maven module metadata" in result.stderr
print("Metadata checksum and repeated-install checks passed")
