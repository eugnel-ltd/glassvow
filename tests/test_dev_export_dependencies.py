"""Developer exports must retain global classes used by hosted benchmarks."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "store_dev_exclusion", ROOT / "tools/check_store_dev_exclusion.py")
assert SPEC is not None and SPEC.loader is not None
CHECKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECKER)


class DeveloperExportDependencyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "tools").mkdir()
        (self.root / "presentation/dev").mkdir(parents=True)
        (self.root / "application").mkdir()
        (self.root / "presentation/dev/boot.gd").write_text("extends RefCounted\n")
        (self.root / "application/main.gd").write_text("extends Node\n")
        (self.root / "tools/bench_map_scene.gd").write_text(
            "extends Node\nvar _proxy: MapSceneProxy = null\n")
        (self.root / "tools/map_scene_proxy.gd").write_text(
            "class_name MapSceneProxy\nextends RefCounted\n")
        self.tracked = [
            "presentation/dev/boot.gd", "application/main.gd", "tests/run_all.gd",
            "tools/map_atelier/fixture.glb", "tools/map_atelier/fixture.glb.import",
            "tools/bench_map_scene.gd", "tools/map_scene_proxy.gd",
        ]

    def check(self, exclusion: str, tracked: list[str] | None = None) -> list[str]:
        presets = CHECKER.parse_presets((ROOT / "export_presets.cfg").read_text())
        text = []
        for index, preset in enumerate(presets):
            if preset["name"] in CHECKER.DEV_PRESETS:
                preset["exclude_filter"] = exclusion
            text.append('[preset.%d]\nname="%s"\ncustom_features="%s"\nexclude_filter="%s"'
                        % (index, preset["name"], preset["custom_features"],
                           preset["exclude_filter"]))
        path = self.root / "export_presets.cfg"
        path.write_text("\n".join(text))
        with mock.patch.object(CHECKER, "tracked_paths",
                               return_value=self.tracked if tracked is None else tracked):
            return CHECKER.check_presets(self.root, path)

    def test_authoring_exclusion_retains_benchmark_dependency(self) -> None:
        self.assertEqual([], self.check("port_fixtures/*,tools/map_atelier/*"))

    def test_broad_map_exclusion_drops_benchmark_global_class(self) -> None:
        errors = self.check("tools/map_*")
        for name in CHECKER.DEV_PRESETS:
            self.assertIn(name + " exclude_filter drops tools/map_scene_proxy.gd required by "
                          "tools/bench_map_scene.gd", errors)

    def test_missing_global_class_dependency_fails(self) -> None:
        tracked = [p for p in self.tracked if p != "tools/map_scene_proxy.gd"]
        errors = self.check("tools/map_atelier/*", tracked)
        for name in CHECKER.DEV_PRESETS:
            self.assertIn(name + " missing tools/map_scene_proxy.gd required by "
                          "tools/bench_map_scene.gd", errors)

    def test_fixture_without_benchmark_has_no_proxy_requirement(self) -> None:
        tracked = [p for p in self.tracked if p not in (
            "tools/bench_map_scene.gd", "tools/map_scene_proxy.gd")]
        self.assertEqual([], self.check("tools/map_*", tracked))

    def test_removed_source_reference_has_no_proxy_requirement(self) -> None:
        (self.root / "tools/bench_map_scene.gd").write_text(
            "extends Node\n# MapSceneProxy was once used here.\n")
        tracked = [p for p in self.tracked if p != "tools/map_scene_proxy.gd"]
        self.assertEqual([], self.check("tools/map_*", tracked))

    def test_tracked_benchmark_source_must_exist(self) -> None:
        (self.root / "tools/bench_map_scene.gd").unlink()
        errors = self.check("tools/map_atelier/*")
        for name in CHECKER.DEV_PRESETS:
            self.assertIn(name + " tracked developer script is missing: "
                          "tools/bench_map_scene.gd", errors)

    def test_real_presets_keep_the_real_map_benchmark_dependency(self) -> None:
        tracked = CHECKER.tracked_paths(ROOT)
        self.assertIn("tools/bench_map_scene.gd", tracked)
        self.assertIn("tools/map_scene_proxy.gd", tracked)
        self.assertEqual([], CHECKER.check_presets(ROOT, ROOT / "export_presets.cfg"))


if __name__ == "__main__":
    unittest.main()
