"""The generated leaves need a real-pack CI gate, independently of .imports."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("painting_ci_scope", ROOT / "tools/ci_scope.py")
CI = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = CI
spec.loader.exec_module(CI)


class ShippingGate(unittest.TestCase):
    def test_changed_runtime_and_export_inputs_select_actual_pack_guard(self):
        for path in ("presentation/stage/paged_painting_texture.gd", "export_presets.cfg",
                     "assets/art/scenes/opening-hearth.png", "tools/export_paintings.py"):
            with self.subTest(path=path):
                self.assertTrue(CI.classify_paths([path]).checks.get("run_painting_export", False),
                                "actual shipped page leaves must be audited for " + path)
        self.assertFalse(CI.classify_paths(["README.md"]).checks.get("run_painting_export", False))

    def test_selected_workflow_runs_real_positive_and_negative_pack_contract(self):
        text = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertIn("steps.scope.outputs.run_painting_export == 'true'", text)
        self.assertIn("python3 -B tests/check_painting_pack.py", text)
        self.assertIn("python3 -B tests/test_painting_pack_pipeline.py", text)


if __name__ == "__main__":
    unittest.main()
