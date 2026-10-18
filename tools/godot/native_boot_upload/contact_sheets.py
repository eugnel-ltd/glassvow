#!/usr/bin/env python3
"""Transport bounded review copies of successful actual captures in job logs."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import sys

from PIL import Image, ImageDraw, ImageFont

MAX_JPEG_BYTES = 200 * 1024
MAX_BASE64_BYTES = 600 * 1024
CHUNK_SIZE = 4096
THUMBNAIL = (288, 200)
PADDING, LABEL_HEIGHT, HEADER_HEIGHT = 12, 36, 52
ROW_HEIGHT = THUMBNAIL[1] + LABEL_HEIGHT + PADDING
WIDTH = THUMBNAIL[0] * 2 + PADDING * 3
PREFIX = "GV_BOOT_CONTACT_"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def proof_bytes(root, relative, limit):
    path = root
    for part in Path(relative).parts:
        require(part not in ("..", "/"), "invalid proof path")
        path = path / part
        require(not path.is_symlink(), "symlink proof path refused")
    require(path.resolve().is_relative_to(root) and path.is_file(), "missing/outside proof file")
    require(path.stat().st_size <= limit, "proof file exceeds input bound")
    with path.open("rb") as stream:
        data = stream.read(limit + 1)
    require(len(data) <= limit, "proof file grew beyond input bound")
    return data


def proof_json(root, relative, limit=262144):
    return json.loads(proof_bytes(root, relative, limit))


def captured_image(root, directory, size, expected_sha=None):
    metadata = proof_json(root, directory / "capture.json", 8192)
    require(metadata.get("captured_while_native_hold") is True, "capture lacks native hold proof")
    data = proof_bytes(root, directory / "boot.png", 32 * 1024 * 1024)
    sha = hashlib.sha256(data).hexdigest()
    require(sha == metadata.get("screenshot_sha256"), "capture metadata SHA differs")
    require(expected_sha is None or sha == expected_sha, "render report screenshot SHA differs")
    with Image.open(io.BytesIO(data)) as source:
        require(source.format == "PNG" and source.size == tuple(size), "capture PNG/size differs")
        image = source.convert("RGB")
    return image, sha


def jpeg_bytes(image):
    for quality in (85, 70, 55, 40, 25, 15, 8):
        stream = io.BytesIO()
        image.save(stream, format="JPEG", quality=quality, optimize=True, progressive=False)
        data = stream.getvalue()
        if len(data) <= MAX_JPEG_BYTES:
            return data, quality
    raise ValueError("contact JPEG exceeds byte cap at every bounded quality")


def prepare(root):
    """Read only the successful report, cases and their exact capture proofs."""
    root = Path(root)
    require(not root.is_symlink(), "symlink evidence root refused")
    root = root.resolve()
    report = proof_json(root, "render-report.json")
    require(report.get("status") == "pass", "complete successful render report required")
    cases = proof_json(root, "cases.json", 65536)
    require(isinstance(cases, list) and 1 <= len(cases) <= 32, "case count outside bound")
    names = []
    for case in cases:
        name, size = case.get("name"), case.get("size")
        require(isinstance(name, str) and re.fullmatch(r"[a-z0-9-]{1,64}", name), "invalid case name")
        require(name != "negative-corrupt-source" and name not in names, "duplicate/reserved case")
        require(isinstance(size, list) and len(size) == 2 and
                all(type(value) is int and 0 < value <= 4096 for value in size) and
                size[0] * size[1] <= 8 * 1024 * 1024, "case dimensions outside bound")
        names.append(name)
    records = report.get("cases", [])
    require(isinstance(records, list) and len(records) == 2 * len(cases), "incomplete pair matrix")
    indexed = {(item["renderer"], item["case"]): item for item in records}
    require(set(indexed) == {(renderer, name) for renderer in ("gles3", "rd") for name in names},
            "missing/duplicate renderer case")
    require(isinstance(report.get("live_negative_control", {}).get("expected_rejection"), str) and
            report["live_negative_control"]["expected_rejection"], "live negative control missing")
    sheets = []
    font = ImageFont.load_default(size=14)
    for renderer in ("gles3", "rd"):
        count = len(cases) + int(renderer == "gles3")
        sheet = Image.new("RGB", (WIDTH, HEADER_HEIGHT + count * ROW_HEIGHT), (24, 26, 31))
        draw = ImageDraw.Draw(sheet)
        draw.text((PADDING, 8), f"{renderer.upper()} | actual native boot captures", font=font, fill="white")
        draw.text((PADDING, 28), "Downsampled JPEG review copy; full originals retained.", font=font, fill=(210, 210, 210))
        inputs = []

        def row(index, name, size, paths, expected):
            top = HEADER_HEIGHT + index * ROW_HEIGHT
            draw.text((PADDING, top), f"{index + 1:02d} {name} | {size[0]}x{size[1]}", font=font, fill="white")
            record = {"case": name, "size": size, "row": index, "images": []}
            for column, (directory, sha) in enumerate(zip(paths, expected)):
                image, actual_sha = captured_image(root, directory, size, sha)
                image.thumbnail(THUMBNAIL, Image.Resampling.LANCZOS)
                left = PADDING + column * (THUMBNAIL[0] + PADDING)
                label = "BASELINE" if column == 0 else "CANDIDATE"
                draw.text((left, top + 17), label, font=font, fill=(210, 210, 210))
                xy = (left + (THUMBNAIL[0] - image.width) // 2,
                      top + LABEL_HEIGHT + (THUMBNAIL[1] - image.height) // 2)
                sheet.paste(image, xy)
                record["images"].append({"variant": label.lower(), "path": str(directory / "boot.png"),
                                         "sha256": actual_sha})
            inputs.append(record)

        for index, case in enumerate(cases):
            pixels = indexed[(renderer, case["name"])]["pixels"]
            require(pixels.get("pair_exact") is True and
                    type(pixels.get("source_oracle_max_channel_error")) is int and
                    0 <= pixels["source_oracle_max_channel_error"] <= 2, "pair/oracle proof incomplete")
            require(all(isinstance(pixels.get(variant + "_sha256"), str) and
                        re.fullmatch(r"[0-9a-f]{64}", pixels[variant + "_sha256"])
                        for variant in ("baseline", "candidate")), "report screenshot SHA missing")
            row(index, case["name"], case["size"],
                [Path(renderer) / case["name"] / variant for variant in ("baseline", "candidate")],
                [pixels[variant + "_sha256"] for variant in ("baseline", "candidate")])
        if renderer == "gles3":
            first = cases[0]
            row(len(cases), "negative-corrupt-source (expected rejection)", first["size"],
                [Path(renderer) / first["name"] / "baseline", Path("negative-corrupt-source")],
                [indexed[(renderer, first["name"])]["pixels"]["baseline_sha256"], None])
        data, quality = jpeg_bytes(sheet)
        encoded = base64.b64encode(data).decode("ascii")
        sheets.append(({"schema": 1, "filename": f"boot-contact-{renderer}.jpg", "renderer": renderer,
                        "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                        "width": sheet.width, "height": sheet.height, "quality": quality,
                        "pairs": len(cases), "includes_live_negative": renderer == "gles3",
                        "chunks": (len(encoded) + CHUNK_SIZE - 1) // CHUNK_SIZE,
                        "inputs": inputs}, data, encoded))
    require(sum(len(encoded) for _, _, encoded in sheets) <= MAX_BASE64_BYTES, "total base64 exceeds cap")
    return root, sheets


def emit(root, stream=None):
    root, sheets = prepare(root)
    output = root / "contact-sheets"
    output.mkdir(exist_ok=False)
    for metadata, data, _ in sheets:
        (output / metadata["filename"]).write_bytes(data)
    (output / "manifest.json").write_text(json.dumps([item[0] for item in sheets], indent=2) + "\n")
    stream = stream or sys.stdout
    for metadata, _, encoded in sheets:
        header = {key: value for key, value in metadata.items() if key != "inputs"}
        header["case_names"] = [row["case"] for row in metadata["inputs"]]
        print(PREFIX + "BEGIN " + json.dumps(header, separators=(",", ":")), file=stream, flush=True)
        for number, start in enumerate(range(0, len(encoded), CHUNK_SIZE)):
            print(f"{PREFIX}DATA {metadata['filename']} {number:04d}/{metadata['chunks']:04d} " +
                  encoded[start:start + CHUNK_SIZE], file=stream, flush=True)
        print(f"{PREFIX}END {metadata['filename']} {metadata['sha256']}", file=stream, flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    emit(parser.parse_args().root)
