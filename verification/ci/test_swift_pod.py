"""离线检查精确 Git Pod 的版本/来源与完整 Swift 源码身份边界，不运行原生工具。"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('swift_pod', Path(__file__).resolve().parents[2] / 'scripts/ci-verify-swift-pod.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SwiftPodIdentityTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.checkout = self.root / 'checkout'
        self.installed = self.root / 'Pods/GYCWindowPolicy'
        self.source = Path('ios/Sources/GYCWindowPolicy/Nested/Observation.swift')
        for root in (self.checkout, self.installed):
            (root / self.source).parent.mkdir(parents=True)
            (root / self.source).write_text('public class Observation {}\n')
        self.metadata = self.installed.parent / 'Local Podspecs/GYCWindowPolicy.podspec.json'
        self.metadata.parent.mkdir()
        self.data = {'version': '0.2.0-rc.8', 'source': {
            'git': 'https://github.com/gycrosskit/system-actions.git', 'tag': 'native-0.2.0-rc.8'}}
        self.metadata.write_text(json.dumps(self.data))

    def verify(self):
        return module.verify_sources(self.checkout, self.installed, '0.2.0-rc.8')

    def test_matching_remote_source_including_nested_files(self):
        self.assertEqual(list(self.verify()), ['Nested/Observation.swift'])

    def test_changed_missing_or_extra_source_rejected(self):
        path = self.installed / self.source
        path.write_text('changed')
        with self.assertRaises(AssertionError): self.verify()
        path.unlink()
        with self.assertRaises(AssertionError): self.verify()
        path.write_bytes((self.checkout / self.source).read_bytes())
        path.with_name('Extra.swift').write_text('extra')
        with self.assertRaises(AssertionError): self.verify()

    def test_wrong_version_or_source_tag_rejected(self):
        self.data['version'] = '0.2.0-rc.7'
        self.metadata.write_text(json.dumps(self.data))
        with self.assertRaises(AssertionError): self.verify()
        self.data['version'] = '0.2.0-rc.8'
        self.data['source']['tag'] = 'main'
        self.metadata.write_text(json.dumps(self.data))
        with self.assertRaises(AssertionError): self.verify()


if __name__ == '__main__':
    unittest.main()
