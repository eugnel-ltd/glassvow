#!/usr/bin/env python3
"""Capture actual native pre-script boot frames on X11; never run headless."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import numpy as np
from PIL import Image

from verify import BACKGROUND, digest, require, verify_pixels, verify_uploads
from processes import run_logged

SPLASH_SHA256 = "e4f310e8ea36872b523f03249f3beb14fede83c476a11f461ce21c0f36c13623"


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n")


def generate_fixture(path, alpha):
    width, height = 2360, 1640
    x, y = np.meshgrid(np.arange(width, dtype=np.uint32), np.arange(height, dtype=np.uint32))
    channels = [((x * 3 + y * 5) % 211 + 23).astype(np.uint8),
                ((x // 7 + y * 11) % 199 + 31).astype(np.uint8),
                ((x * 17 + y // 3) % 193 + 37).astype(np.uint8)]
    if alpha:
        channels.append(np.array([0, 64, 128, 255], dtype=np.uint8)[(x // 43 + y // 29) % 4])
    pixels = np.stack(channels, axis=2)
    # Asymmetric opposing borders expose lost wrap/clamp support and Y flips.
    pixels[0:3, :, :3] = (239, 19, 73)
    pixels[-3:, :, :3] = (29, 223, 181)
    pixels[:, 0:3, :3] = (197, 97, 17)
    pixels[:, -3:, :3] = (53, 41, 233)
    if alpha:
        pixels[0:3, :, 3] = pixels[-3:, :, 3] = 255
    Image.fromarray(pixels).save(path)


def make_project(directory, case):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "splash.png").write_bytes(Path(case["source"]).read_bytes())
    width, height = case["size"]
    bg = ",".join(str(channel / 255) for channel in BACKGROUND)
    (directory / "project.godot").write_text(f'''config_version=5
[application]
config/name="GV Native Boot Probe"
run/main_scene="res://main.tscn"
config/use_custom_user_dir=true
config/custom_user_dir_name="glassvow-native-boot-probe"
boot_splash/bg_color=Color({bg},1)
boot_splash/image="res://splash.png"
boot_splash/show_image=true
boot_splash/stretch_mode={case["stretch"]}
boot_splash/use_filter={str(case["filter"]).lower()}
[display]
window/size/viewport_width={width}
window/size/viewport_height={height}
window/size/window_width_override={width}
window/size/window_height_override={height}
window/size/borderless=true
window/dpi/allow_hidpi=false
''')
    (directory / "main.gd").write_text('''extends Node
func _ready() -> void:
    print("GV_BOOT_SCRIPT_STARTED")
    get_tree().quit(91)
''')
    (directory / "main.tscn").write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://main.gd" id="1"]
[node name="MustNotRunBeforeCapture" type="Node"]
script = ExtResource("1")
''')


def capture_worker(spec):
    """Called inside a fresh Xvfb with exactly the case's native window size."""
    output = Path(spec["output"])
    output.mkdir(parents=True, exist_ok=True)
    project = output / "project"
    make_project(project, spec["case"])
    width, height = spec["case"]["size"]
    renderer = spec["renderer"]
    command = [spec["binary"], "--path", str(project), "--display-driver", "x11",
               "--rendering-method", "gl_compatibility" if renderer == "gles3" else "mobile",
               "--rendering-driver", "opengl3" if renderer == "gles3" else "vulkan",
               "--audio-driver", "Dummy", "--resolution", f"{width},{height}",
               "--position", "0,0"]
    environment = dict(os.environ, GLASSVOW_BOOT_UPLOAD_PROBE="1", GV_BOOT_PROBE_HOLD_MS="30000",
                       LIBGL_ALWAYS_SOFTWARE="1", GALLIUM_DRIVER="llvmpipe")
    log_path = output / "native.log"
    capture_path = output / "boot.png"
    write_json(output / "command.json", {"argv": command, "renderer": renderer,
                                        "environment_names": ["DISPLAY", "LIBGL_ALWAYS_SOFTWARE",
                                         "GALLIUM_DRIVER", "VK_DRIVER_FILES",
                                         "GLASSVOW_BOOT_UPLOAD_PROBE", "GV_BOOT_PROBE_HOLD_MS"]})
    process = None
    try:
        with log_path.open("wb") as log:
            # Inherit the xvfb-run/worker process group. The outer owner's
            # timeout then reaches this engine even if Python finally cannot run.
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                       env=environment)
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline:
                contents = log_path.read_text(errors="replace")
                require("GV_BOOT_SCRIPT_STARTED" not in contents, "script ran before native hold")
                holds = [line for line in contents.splitlines() if line.startswith("GV_BOOT_PROBE ")
                         and json.loads(line[len("GV_BOOT_PROBE "):]).get("event") == "hold"]
                if holds:
                    break
                require(process.poll() is None, "engine exited before the native hold")
                time.sleep(0.05)
            else:
                raise AssertionError("native pre-script hold was not observed in 20 seconds")
            # Import's X11 read observes the actual presented framebuffer. Xvfb
            # has no WM, and this borderless window fills its exact-size screen.
            subprocess.run(["import", "-window", "root", str(capture_path)], check=True, timeout=10)
            require(process.poll() is None, "engine exited while capturing boot")
            require("GV_BOOT_SCRIPT_STARTED" not in log_path.read_text(errors="replace"),
                    "project script ran during native capture")
            write_json(output / "capture.json", {"captured_while_native_hold": True,
                       "native_pid": process.pid, "screenshot_sha256": digest(capture_path),
                       "log_sha256": digest(log_path), "source_sha256": digest(spec["case"]["source"])})
    finally:
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
            else:
                process.wait(timeout=3)


def capture(binary, case, renderer, output):
    output.mkdir(parents=True, exist_ok=True)
    spec = {"binary": str(binary.resolve()), "case": case,
            "renderer": renderer, "output": str(output.resolve())}
    spec_path = output / "spec.json"
    write_json(spec_path, spec)
    width, height = case["size"]
    command = ["xvfb-run", "--auto-servernum", "--server-args",
               f"-screen 0 {width}x{height}x24 -nolisten tcp -ac -nocursor",
               sys.executable, str(Path(__file__).resolve()), "--capture", str(spec_path)]
    run_logged(command, output / "capture-worker.log", 40)


def matrix(splash, directory):
    require(digest(splash) == SPLASH_SHA256, "real splash differs from the pinned product PNG")
    real = str(splash.resolve())
    rgb = directory / "asymmetric-rgb.png"
    alpha = directory / "asymmetric-rgba.png"
    generate_fixture(rgb, False)
    generate_fixture(alpha, True)
    cases = []
    for name, size in [("desktop", [1180, 820]), ("pad", [1024, 768]),
                       ("phone", [390, 844]), ("fractional", [901, 617])]:
        cases.append({"name": "real-" + name, "source": real, "size": size,
                      "filter": True, "stretch": 1})
    cases.append({"name": "real-source-anchor", "source": real, "size": [2360, 1640],
                  "filter": False, "stretch": 5})
    # Both filters, all six existing geometry modes; RGBA crosses every seam.
    for stretch in range(6):
        for filtering in (False, True):
            cases.append({"name": f"asymmetric-s{stretch}-f{int(filtering)}",
                          "source": str((alpha if stretch % 2 else rgb).resolve()),
                          "size": [901, 617], "filter": filtering, "stretch": stretch})
    return cases


def run_matrix(args):
    args.output.mkdir(parents=True, exist_ok=True)
    report = {"status": "running", "cases": [], "remaining_scope": [
              "Metal/iOS/template identity/A12/HDR/pre-rotation/device memory are not proved by Linux software renderers.",
              "Visual inspection of the captured running images remains required."]}
    report_path = args.output / "render-report.json"
    write_json(report_path, report)
    try:
        cases = matrix(args.splash, args.output)
        write_json(args.output / "cases.json", cases)
        for renderer in ("gles3", "rd"):
            for case in cases:
                item = {"renderer": renderer, "case": case["name"]}
                paths = {}
                for variant in ("baseline", "candidate"):
                    directory = args.output / renderer / case["name"] / variant
                    capture(getattr(args, variant), case, renderer, directory)
                    item[variant] = verify_uploads(directory / "native.log", case, renderer, variant)
                    paths[variant] = directory / "boot.png"
                item["pixels"] = verify_pixels(paths["baseline"], paths["candidate"], case, renderer)
                report["cases"].append(item)
                write_json(report_path, report)
        # Live wrong-source control: same dimensions/format and bounded native
        # calls, but changed pixels. Its image verifier must reject the frame.
        control_case = dict(cases[0], name="negative-corrupt-source")
        corrupt_path = args.output / "corrupt-splash.png"
        corrupt = Image.open(args.splash).convert("RGB")
        corrupt.paste((233, 47, 191), (500, 500, 1500, 1000))
        corrupt.save(corrupt_path)
        control_case["source"] = str(corrupt_path.resolve())
        control_dir = args.output / "negative-corrupt-source"
        capture(args.candidate, control_case, "gles3", control_dir)
        verify_uploads(control_dir / "native.log", control_case, "gles3", "candidate")
        baseline_path = args.output / "gles3" / cases[0]["name"] / "baseline" / "boot.png"
        try:
            verify_pixels(baseline_path, control_dir / "boot.png", cases[0], "gles3")
        except AssertionError as error:
            report["live_negative_control"] = {"expected_rejection": str(error)}
        else:
            raise AssertionError("live corrupt-source frame incorrectly passed the image oracle")
        report["status"] = "pass"
    except Exception as error:
        report["status"] = "failed_or_inconclusive"
        report["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        write_json(report_path, report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--splash", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.capture:
        capture_worker(json.loads(args.capture.read_text()))
    else:
        require(all([args.baseline, args.candidate, args.splash, args.output]), "missing matrix inputs")
        run_matrix(args)


if __name__ == "__main__":
    main()
