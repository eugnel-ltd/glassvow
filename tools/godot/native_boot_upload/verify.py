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


# Schema 1 and every pixel function above remain frozen byte-for-byte. Schema 2
# describes a different causal mechanism: one full texture, bounded transfers.
_verify_uploads_schema1 = verify_uploads


def schema2_events(log):
    text = Path(log).read_text(errors="replace")
    require("GV_BOOT_SCRIPT_STARTED" not in text, "project script ran before capture")
    records = [json.loads(line[len(PREFIX):]) for line in text.splitlines() if line.startswith(PREFIX)]
    require(records and all(record.get("schema") == 2 for record in records),
            "missing or mixed schema2 native events")
    return records


def verify_uploads_schema2(log, case, renderer, variant):
    records = schema2_events(log)
    kinds = [record.get("event") for record in records]
    require(kinds[0] == "begin" and kinds[-2:] == ["present", "hold"], "schema2 event order changed")
    for kind in ("begin", "texture", "draw", "present", "hold"):
        require(kinds.count(kind) == 1, "schema2 requires exactly one " + kind)
    require(kinds[1] == "texture" and kinds[-3] == "draw", "texture/transfer/draw order changed")
    require(all(kind in ("staging", "transfer") for kind in kinds[2:-3]), "unexpected schema2 event")
    begin, texture, draw, present = records[0], records[1], records[-3], records[-2]
    with Image.open(case["source"]) as image:
        width, height, mode = image.width, image.height, image.mode
    channels = {"L": 1, "LA": 2, "RGB": 3, "RGBA": 4}.get(mode)
    require(channels is not None, "schema2 only qualifies native decoded PNG formats")
    native_channels = 4 if renderer == "rd" and mode == "RGB" else channels
    require(begin["renderer"] == renderer, "renderer fallback or wrong renderer")
    require((begin["source_width"], begin["source_height"], begin["source_format"], begin["source_bytes"])
            == (width, height, mode + "8", width * height * channels), "native source identity differs")
    require((begin["window_width"], begin["window_height"]) == tuple(case["size"]), "window dimensions differ")
    require(begin["filter"] == case["filter"] and begin["stretch"] == case["stretch"], "native settings differ")
    require(isinstance(texture["texture_id"], int) and texture["texture_id"] > 0, "invalid native texture identity")
    require((texture["width"], texture["height"], texture["depth"], texture["layers"], texture["mipmaps"])
            == (width, height, 1, 1, 1), "GPU allocation must preserve one full-size texture")
    require(texture["bytes_per_pixel"] == native_channels and
            texture["logical_bytes"] == width * height * native_channels, "native allocation format/bytes differ")
    # Exact pinned ed1 native enum values; no Vulkan-enum/Godot-enum conflation.
    codes = {"rd": {1: 8, 2: 15, 4: 36}, "gles3": {1: 33321, 2: 33323, 3: 32849, 4: 32856}}
    require(texture["format_code"] == codes[renderer][native_channels], "native GPU format code differs")
    require(texture["api"] == ("texture_create" if renderer == "rd" else "glTexImage2D"),
            "GPU allocation was not observed at its native call")
    direct_small_gles = renderer == "gles3" and width * height * 4 <= CAP
    expected_initial = width * height * native_channels if variant == "baseline" or direct_small_gles else 0
    require(texture["initial_data_bytes"] == expected_initial, "unexpected full initial-data upload")
    transfers = [record for record in records if record["event"] == "transfer"]
    staging = [record for record in records if record["event"] == "staging"]
    require(transfers, "no actual native row transfer")
    if renderer == "rd":
        require(kinds[2:-3] == [kind for _ in transfers for kind in ("staging", "transfer")],
                "each RD copy must follow its actual staging reservation")
    else:
        require(not staging, "GLES must not invent observed driver staging")
    effective_limit = CAP
    capacities = None
    if variant != "baseline" and renderer == "rd":
        capacities = {allocation["buffer_capacity"] for allocation in staging}
        effective_limit = min(CAP, min(capacities))
    expected_count = None
    if variant != "baseline":
        step = transfers[0]["row_pitch_step"]
        require(isinstance(step, int) and step > 0, "invalid observed native pitch step")
        require(all(transfer["row_pitch_step"] == step for transfer in transfers), "native pitch step changed")
        conservative_pitch = ((width * 4 + step - 1) // step) * step
        max_rows = effective_limit // conservative_pitch
        require(max_rows > 0, "one full native row exceeds the actual transfer budget")
        expected_count = (height + max_rows - 1) // max_rows
    next_row = 0
    largest = 0
    for index, transfer in enumerate(transfers):
        require(transfer["index"] == index and transfer["texture_id"] == texture["texture_id"],
                "transfer indices/texture identity differ")
        require((transfer["x"], transfer["y"], transfer["width"]) == (0, next_row, width),
                "native transfer rows have gaps/overlap/gutters or partial width")
        rows = transfer["height"]
        require(isinstance(rows, int) and rows > 0 and next_row + rows <= height, "invalid transfer height")
        require((transfer["z"], transfer["depth"], transfer["mipmap"], transfer["layer"]) == (0, 1, 0, 0),
                "native PNG transfer is not one base-mip 2D layer")
        source_bytes = width * rows * native_channels
        require(transfer["source_offset"] == next_row * width * native_channels and
                transfer["source_bytes"] == source_bytes, "native source pointer/byte extent differs")
        step = transfer["row_pitch_step"]
        require(isinstance(step, int) and step > 0, "invalid observed native pitch step")
        pitch = ((width * native_channels + step - 1) // step) * step
        require(transfer["row_pitch"] == pitch, "native row pitch differs from driver trait")
        request = source_bytes
        if renderer == "rd":
            allocation = staging[index]
            require(allocation["index"] == transfer["staging_index"] == index, "copy/staging identity differs")
            require(allocation["request_bytes"] == pitch * rows, "actual staging request differs from copied rows")
            require(allocation["allocated_bytes"] >= allocation["request_bytes"], "staging reservation is too small")
            require(allocation["alignment"] > 0 and allocation["offset"] % allocation["alignment"] == 0,
                    "native staging offset is misaligned")
            require(allocation["offset"] + allocation["allocated_bytes"] <= allocation["buffer_capacity"],
                    "staging reservation exceeds actual buffer capacity")
            require(transfer["buffer_offset"] == allocation["offset"], "copy uses a different staging offset")
            require(allocation["api"] == ("transfer_worker" if variant == "baseline" else "frame_staging"),
                    "unexpected native staging path")
            request = max(allocation["request_bytes"], allocation["allocated_bytes"])
        else:
            require(transfer["staging_index"] == -1 and transfer["buffer_offset"] == 0 and step == 1,
                    "GLES transfer has invented staging or changed unpack alignment")
        expected_api = ("rd_initialize_copy" if variant == "baseline" else "rd_update_copy") if renderer == "rd" else (
                        "glTexImage2D" if variant == "baseline" or direct_small_gles else "glTexSubImage2D")
        require(transfer["api"] == expected_api, "unexpected native transfer API")
        largest = max(largest, source_bytes, request)
        if variant != "baseline":
            conservative_pitch = ((width * 4 + step - 1) // step) * step
            require(max(source_bytes, request, conservative_pitch * rows) <= effective_limit,
                    "candidate native transfer/request exceeds 4 MiB or actual staging capacity")
            first = index * height // expected_count
            end = (index + 1) * height // expected_count
            require(len(transfers) == expected_count and next_row == first and rows == end - first,
                    "native transfer bands are not balanced from the actual conservative row budget")
        next_row += rows
    require(next_row == height, "native transfers do not cover the full texture")
    if capacities is not None:
        require(len(capacities) == 1, "frame staging capacity changed within one boot image")
    if variant == "baseline":
        require(len(transfers) == 1 and largest > CAP, "baseline must preserve the actual oversized transfer")
    require(draw["texture_id"] == texture["texture_id"] and draw["source_uv"] == [0, 0, 1, 1],
            "native boot must use the same full texture and original full UV quad")
    left, top, dw, dh = screen_rect((width, height), case["size"], case["stretch"])
    ww, wh = case["size"]
    expected_destination = [left / ww, top / wh, dw / ww, dh / wh]
    if renderer == "gles3":
        expected_destination[1] = 1 - expected_destination[1]
        expected_destination[3] *= -1
    require(np.allclose(draw["destination"], expected_destination, atol=1e-6, rtol=0),
            "original native full-image quad geometry changed")
    require((present["textures"], present["transfers"], present["draws"], present["clears"], present["presents"])
            == (1, len(transfers), 1, 1, 1), "schema2 requires one texture, one full quad and one present")
    return {"schema": 2, "texture": texture, "transfers": transfers, "staging": staging,
            "maximum_transfer_or_reservation_bytes": largest,
            "effective_transfer_limit_bytes": effective_limit,
            "total_source_transfer_bytes": sum(transfer["source_bytes"] for transfer in transfers),
            "cap_result": "expected_baseline_failure" if variant == "baseline" else "pass"}


def verify_uploads(log, case, renderer, variant):
    first = next((line for line in Path(log).read_text(errors="replace").splitlines() if line.startswith(PREFIX)), "")
    if first and json.loads(first[len(PREFIX):]).get("schema") == 2:
        return verify_uploads_schema2(log, case, renderer, variant)
    return _verify_uploads_schema1(log, case, renderer, variant)
