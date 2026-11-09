"""Validate the release contract, including an installable ZIP and checksum assets."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    def test_release_assets_and_tag_guard(self):
        version = re.search(r'^## Version: (.+)$',
                            (ROOT / 'ItemFarmingTool/ItemFarmingTool.toc').read_text(), re.M)[1]
        result = subprocess.run([sys.executable, str(ROOT / 'tools/package.py'),
                                 '--tag', 'v' + version], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        versioned = ROOT / 'dist' / f'ItemFarmingTool-{version}.zip'
        stable = ROOT / 'dist/ItemFarmingTool.zip'
        self.assertEqual(stable.read_bytes(), versioned.read_bytes())
        with ZipFile(stable) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(set(archive.namelist()), {
                'ItemFarmingTool/ItemFarmingTool.toc', 'ItemFarmingTool/Core.lua',
                'ItemFarmingTool/UI.lua', 'ItemFarmingTool/README.md', 'ItemFarmingTool/LICENSE'})
        checksums = (ROOT / 'dist/SHA256SUMS.txt').read_text()
        for path in [versioned, stable]:
            self.assertIn(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}', checksums)
        bad = subprocess.run([sys.executable, str(ROOT / 'tools/package.py'), '--tag', 'v999.0.0'],
                             capture_output=True, text=True)
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn('must match TOC version', bad.stderr)


if __name__ == '__main__':
    unittest.main()
