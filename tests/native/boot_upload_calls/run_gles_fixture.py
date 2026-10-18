#!/usr/bin/env python3
"""Compile exact native GLES function excerpts with byte-recording GL stubs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

FILES = {
    "storage": "drivers/gles3/storage/texture_storage.cpp",
    "compositor": "drivers/gles3/rasterizer_gles3.cpp",
    "copy": "drivers/gles3/effects/copy_effects.cpp",
    "types": "servers/rendering/rendering_server_types.h",
    "shader": "drivers/gles3/shaders/effects/copy.glsl",
}

def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()

def function(text, signature, required=True):
    start = text.find(signature)
    if start < 0:
        if not required:
            return ""
        raise ValueError("missing native excerpt: " + signature)
    first = text.index("{", start)
    depth = 1
    end = first + 1
    while depth:
        if text[end] == "{":
            depth += 1
        elif text[end] == "}":
            depth -= 1
        end += 1
    return text[start:end] + "\n"

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source-root", type=Path, required=True)
    ap.add_argument("--patch", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--sanitize", action="store_true")
    args = ap.parse_args()
    home = Path(__file__).resolve().parent
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gles-boot-native-") as temp:
        tree = Path(temp)
        original = {}
        for name, relative in FILES.items():
            src = args.source_root / relative
            target = tree / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, target)
            original[name] = src.read_text()
        includes = ["--include=" + relative for relative in FILES.values()]
        for flags in (["--check"], []):
            subprocess.run(["git", "apply", *flags, *includes, str(args.patch.resolve())], cwd=tree, check=True, timeout=20)
        source = {name: (tree / relative).read_text() for name, relative in FILES.items()}
        types = source["types"].split("/* BACKGROUND */", 1)[1].split("/* RENDERING METHOD */", 1)[0]
        excerpts = {"rendering_types": "namespace RenderingServerTypes {\n" + types + "\n}\n"}
        for method in ("texture_2d_initialize", "texture_2d_initialize_boot_image", "_texture_2d_initialize", "texture_set_data", "_texture_set_data"):
            excerpts[method] = function(source["storage"], "void TextureStorage::" + method + "(", method not in ("texture_2d_initialize_boot_image", "_texture_2d_initialize"))
        excerpts["copy_to_rect"] = function(source["copy"], "void CopyEffects::copy_to_rect(")
        excerpts["copy_to_rect_from_rect"] = function(source["copy"], "void CopyEffects::copy_to_rect_from_rect(", False)
        excerpts["compositor"] = function(source["compositor"], "void RasterizerGLES3::set_boot_image_with_stretch(")
        (output / "extracted_native.inc").write_text("\n".join(excerpts.values()))
        for name in ("gles_types.h", "gles_recording.h", "gles_assertions.cpp"):
            shutil.copyfile(home / name, output / name)
        binding = {"source_root": str(args.source_root.resolve()), "patch_sha256": hashlib.sha256(args.patch.read_bytes()).hexdigest(),
                   "original_sha256": {k: sha(v) for k, v in original.items()},
                   "patched_sha256": {k: sha(v) for k, v in source.items()},
                   "excerpt_sha256": {k: sha(v) for k, v in excerpts.items()},
                   "fixture_sha256": {name: hashlib.sha256((home/name).read_bytes()).hexdigest() for name in ("gles_types.h", "gles_recording.h", "gles_assertions.cpp", "run_gles_fixture.py")},
                   "scope": "real native function bodies; GL/resource/platform/type stubs; no GPU/engine build"}
        (output / "source-bindings.json").write_text(json.dumps(binding, indent=2) + "\n")
        command = ["g++", "-std=c++17", "-O1", "-g", "-fno-omit-frame-pointer", "-Wall", "-Wextra", "-Werror", "-Wno-sign-compare"]
        if args.sanitize:
            command += ["-fsanitize=address,undefined"]
        command += [str(output / "gles_assertions.cpp"), "-o", str(output / "gles-native-fixture")]
        with (output / "compile.log").open("w") as log:
            compiled = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=60)
        if compiled.returncode:
            print((output / "compile.log").read_text())
            raise SystemExit(compiled.returncode)
        with (output / "run.log").open("w") as log:
            result = subprocess.run([str(output / "gles-native-fixture")], stdout=log, stderr=subprocess.STDOUT, timeout=30)
        print((output / "run.log").read_text(), end="")
        (output / "result.json").write_text(json.dumps({"compile_exit": compiled.returncode, "run_exit": result.returncode, "sanitize": args.sanitize}, indent=2) + "\n")
        raise SystemExit(result.returncode)

if __name__ == "__main__":
    main()
