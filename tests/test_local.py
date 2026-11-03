"""Check the recipe wrapper's local recorder selection."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class LocalTransportTest(unittest.TestCase):
    def test_wrapper_uses_pinned_recorder_in_local_mode(self):
        with tempfile.TemporaryDirectory() as home:
            revision = (ROOT / 'scripts/render-media-revision').read_text().strip()
            recorder = Path(home) / ('render-media-' + revision) / 'render.py'
            recorder.parent.mkdir()
            recorder.write_text('import json, sys\nprint(json.dumps(sys.argv[1:]))\n')
            env = dict(os.environ, DGX_MEDIA_HOME=home)
            result = subprocess.run([str(ROOT / 'scripts/media'), 'show', 'example'], env=env,
                                    text=True, capture_output=True, check=True)
            self.assertEqual(json.loads(result.stdout), ['--local', 'show', 'example'])

    def test_missing_recorder_gives_setup_instruction(self):
        with tempfile.TemporaryDirectory() as home:
            result = subprocess.run([str(ROOT / 'scripts/media'), 'doctor'],
                                    env=dict(os.environ, DGX_MEDIA_HOME=home), text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('scripts/install-recorder', result.stderr)


if __name__ == '__main__':
    unittest.main()
