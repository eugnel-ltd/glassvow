#!/usr/bin/env python3
"""Verify observed native boot calls and independently sampled screen pixels."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

CAP = 4 * 1024 * 1024
PREFIX = "GV_BOOT_PROBE "
BACKGROUND = (5, 7, 14)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def events(log):
    text = Path(log).read_text(errors="replace")
    records = []
    for line in text.splitlines():
        if line.startswith(PREFIX):
            event = json.loads(line[len(PREFIX):])
            require(event.get("schema") == 1, "unsupported probe schema")
            records.append(event)
    require("GV_BOOT_SCRIPT_STARTED" not in text, "project script ran before capture")
    require(records, "native observer produced no records")
    return records


def verify_uploads(log, case, renderer, variant):
    records = events(log)
    kinds = [event.get("event") for event in records]
    require(kinds.count("begin") == kinds.count("present") == kinds.count("hold") == 1,
            "expected one native begin, present and pre-script hold")
    require(kinds[0] == "begin" and kinds[-2:] == ["present", "hold"],
            "native event order changed")
    require(all(kind == "upload" for kind in kinds[1:-2]), "unexpected native event")
    begin, present = records[0], records[-2]
    with Image.open(case["source"]) as source:
        image = source.copy()
    expected_channels = len(image.getbands())
    require(begin["renderer"] == renderer, "renderer fallback or wrong renderer")
    require((begin["source_width"], begin["source_height"]) == image.size,
            "native source dimensions differ from hashed fixture")
    require(begin["source_format"] == image.mode + "8", "native source format changed")
    require(begin["source_bytes"] == image.width * image.height * expected_channels,
            "native source byte count differs")
    require((begin["window_width"], begin["window_height"]) == tuple(case["size"]),
            "native window dimensions differ")
    require(begin["filter"] == case["filter"] and begin["stretch"] == case["stretch"],
            "native filter/stretch differs from fixture")
    uploads = records[1:-2]
    require(uploads, "no actual native upload was observed")
    for index, upload in enumerate(uploads):
        require(upload["index"] == index, "upload indices are not complete/in order")
        require(upload["width"] == image.width and upload["height"] > 0,
                "invalid native upload dimensions")
        # These are observed validated storage payloads, not planner estimates.
        channels = {"L8": 1, "LA8": 2, "RGB8": 3, "RGBA8": 4}.get(upload["format"])
        require(channels is not None, "unexpected native validated format")
        require(upload["bytes"] == upload["width"] * upload["height"] * channels,
                "observed payload is not the full non-mipmapped upload")
    require(present["uploads"] == len(uploads) and present["draws"] == len(uploads),
            "native upload/draw counters differ")
    require(present["clears"] == present["presents"] == 1,
            "native boot must clear once and present once")
    maximum = max(upload["bytes"] for upload in uploads)
    if variant == "baseline":
        require(len(uploads) == 1 and maximum > CAP,
                "baseline did not preserve the meaningful oversized upload control")
    else:
        require(maximum <= CAP, "candidate observed native upload exceeds 4 MiB")
        if image.size == (2360, 1640):
            require(len(uploads) == 4, "real splash/fixture must use four native leaves")
    return {"uploads": uploads, "maximum_bytes": maximum,
            "total_bytes": sum(upload["bytes"] for upload in uploads),
            "cap_result": "expected_baseline_failure" if variant == "baseline" else "pass"}


def screen_rect(image_size, window_size, stretch):
    iw, ih = image_size
    ww, wh = window_size
    if stretch == 0:
        return ((ww - iw) // 2, (wh - ih) // 2, iw, ih)
    if stretch == 1:
        scale = wh / ih if ww > wh else ww / iw
    elif stretch == 2:
        scale = ww / iw
    elif stretch == 3:
        scale = wh / ih
    elif stretch == 4:
        scale = max(ww / iw, wh / ih)
    elif stretch == 5:
        return (0, 0, ww, wh)
    else:
        raise AssertionError("unsupported native stretch mode")
    width, height = iw * scale, ih * scale
    return ((ww - width) / 2, (wh - height) / 2, width, height)


def source_reference(case, renderer):
    """Independent CPU source oracle; it does not implement the native tiler."""
    source = np.asarray(Image.open(case["source"]).convert("RGBA"), dtype=np.float64)
    ih, iw, _ = source.shape
    ww, wh = case["size"]
    left, top, width, height = screen_rect((iw, ih), (ww, wh), case["stretch"])
    xs = (np.arange(ww) + 0.5 - left) * iw / width - 0.5
    ys = (np.arange(wh) + 0.5 - top) * ih / height - 0.5
    inside = ((ys[:, None] >= -0.5) & (ys[:, None] < ih - 0.5) &
              (xs[None, :] >= -0.5) & (xs[None, :] < iw - 0.5))

    def indices(values, length):
        return values % length if renderer == "gles3" else np.clip(values, 0, length - 1)

    if case["filter"]:
        x0, y0 = np.floor(xs).astype(int), np.floor(ys).astype(int)
        xf, yf = xs - x0, ys - y0
        x1, y1 = indices(x0 + 1, iw), indices(y0 + 1, ih)
        x0, y0 = indices(x0, iw), indices(y0, ih)
        # Straight-alpha channels are filtered before the native blend.
        row0 = source[y0[:, None], x0[None, :]] * (1 - xf[None, :, None])
        row0 += source[y0[:, None], x1[None, :]] * xf[None, :, None]
        row1 = source[y1[:, None], x0[None, :]] * (1 - xf[None, :, None])
        row1 += source[y1[:, None], x1[None, :]] * xf[None, :, None]
        sampled = row0 * (1 - yf[:, None, None]) + row1 * yf[:, None, None]
    else:
        xi = indices(np.floor(xs + 0.5).astype(int), iw)
        yi = indices(np.floor(ys + 0.5).astype(int), ih)
        sampled = source[yi[:, None], xi[None, :]]
    alpha = sampled[:, :, 3:4] / 255
    rgb = sampled[:, :, :3] * alpha + np.asarray(BACKGROUND) * (1 - alpha)
    rgb[~inside] = BACKGROUND
    return np.clip(np.rint(rgb), 0, 255).astype(np.uint8)


def content_bbox(array):
    mask = np.max(np.abs(array.astype(int) - np.asarray(BACKGROUND)), axis=2) > 8
    ys, xs = np.nonzero(mask)
    require(len(xs) > 100, "blank or near-empty native boot screenshot")
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


def verify_pixels(baseline, candidate, case, renderer):
    before = np.asarray(Image.open(baseline).convert("RGB"))
    after = np.asarray(Image.open(candidate).convert("RGB"))
    require(before.shape == after.shape == (case["size"][1], case["size"][0], 3),
            "capture dimensions differ from native client dimensions")
    before_bbox, after_bbox = content_bbox(before), content_bbox(after)
    require(before_bbox == after_bbox, "candidate native content bounding box changed")
    difference = np.abs(before.astype(int) - after.astype(int))
    require(not difference.any(),
            f"native baseline/candidate pixels differ: maximum={difference.max()}, "
            f"changed_pixels={np.count_nonzero(np.any(difference, axis=2))}")
    reference = source_reference(case, renderer)
    reference_bbox = content_bbox(reference)
    require(before_bbox == reference_bbox, "native capture differs from source content bounding box")
    source_difference = np.abs(before.astype(int) - reference.astype(int))
    # The pair gate above is exact. This independent numeric oracle allows the
    # native sampler/blender's 8-bit rounding, never source/crop/color changes.
    require(source_difference.max() <= 2,
            f"native frame differs from independent source oracle: max={source_difference.max()}")
    return {"pair_exact": True, "bbox": after_bbox,
            "source_oracle_max_channel_error": int(source_difference.max()),
            "baseline_sha256": digest(baseline), "candidate_sha256": digest(candidate),
            "source_sha256": digest(case["source"])}
