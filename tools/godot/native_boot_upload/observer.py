#!/usr/bin/env python3
"""Install the same CI-only native observer in baseline and candidate sources.

This file never changes a shipping patch/template. Hooks record the actual
validated Image immediately before native storage uploads, and hold only after
boot's actual final present so an external screenshot observes native boot.
"""
from __future__ import annotations
import argparse
from pathlib import Path

HEADER = r'''#pragma once
#include "core/io/image.h"
#include "core/io/json.h"
#include "core/os/os.h"

namespace GlassvowBootProbe {
struct State {
    bool active = false;
    int uploads = 0;
    int draws = 0;
    int clears = 0;
};
inline State &state() { static State value; return value; }
inline void emit(Dictionary p_event) {
    p_event["schema"] = 1;
    print_line("GV_BOOT_PROBE " + JSON::stringify(p_event));
}
inline void begin(const char *p_renderer, const Ref<Image> &p_image, const Size2i &p_window, bool p_filter, int p_stretch) {
    state() = State();
    state().active = OS::get_singleton()->get_environment("GLASSVOW_BOOT_UPLOAD_PROBE") == "1";
    if (!state().active) { return; }
    Dictionary event;
    event["event"] = "begin";
    event["renderer"] = p_renderer;
    event["source_width"] = p_image->get_width();
    event["source_height"] = p_image->get_height();
    event["source_format"] = Image::get_format_name(p_image->get_format());
    event["source_bytes"] = p_image->get_data_size();
    event["window_width"] = p_window.x;
    event["window_height"] = p_window.y;
    event["filter"] = p_filter;
    event["stretch"] = p_stretch;
    emit(event);
}
inline void upload(const Ref<Image> &p_validated_image) {
    if (!state().active) { return; }
    Dictionary event;
    event["event"] = "upload";
    event["index"] = state().uploads++;
    event["width"] = p_validated_image->get_width();
    event["height"] = p_validated_image->get_height();
    event["format"] = Image::get_format_name(p_validated_image->get_format());
    event["bytes"] = p_validated_image->get_data_size();
    emit(event);
}
inline void clear() { if (state().active) { state().clears++; } }
inline void draw() { if (state().active) { state().draws++; } }
inline void presented() {
    if (!state().active) { return; }
    Dictionary event;
    event["event"] = "present";
    event["uploads"] = state().uploads;
    event["draws"] = state().draws;
    event["clears"] = state().clears;
    event["presents"] = 1;
    emit(event);
    event.clear();
    event["event"] = "hold";
    emit(event);
    const int milliseconds = CLAMP(OS::get_singleton()->get_environment("GV_BOOT_PROBE_HOLD_MS").to_int(), 1, 30000);
    OS::get_singleton()->delay_usec(uint64_t(milliseconds) * 1000);
    state().active = false;
}
} // namespace GlassvowBootProbe
'''


def once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"observer expected one exact anchor: {old[:90]!r}")
    return text.replace(old, new)


def instrument(tree: Path) -> None:
    header = tree / "servers/rendering/glassvow_boot_probe.h"
    if header.exists():
        raise ValueError("observer already installed")
    paths = {
        "rd": "servers/rendering/renderer_rd/renderer_compositor_rd.cpp",
        "gles3": "drivers/gles3/rasterizer_gles3.cpp",
        "rd_storage": "servers/rendering/renderer_rd/storage_rd/texture_storage.cpp",
        "gles_storage": "drivers/gles3/storage/texture_storage.cpp",
    }
    changes: dict[Path, str] = {}
    for name, relative in paths.items():
        path = tree / relative
        source = path.read_text()
        source = once(source, '#include "core/config/engine.h"',
                      '#include "core/config/engine.h"\n#include "servers/rendering/glassvow_boot_probe.h"')
        if name in ("rd", "gles3"):
            signature = ("void RendererCompositorRD::set_boot_image_with_stretch" if name == "rd"
                         else "void RasterizerGLES3::set_boot_image_with_stretch")
            start = source.index(signature)
            end = source.index("\n}\n", start) + 3
            function = source[start:end]
            guard = "\tif (p_image.is_null() || p_image->is_empty()) {\n\t\treturn;\n\t}\n"
            begin = (f'\tGlassvowBootProbe::begin("{name}", p_image, '
                     'DisplayServer::get_singleton()->window_get_size(), p_use_filter, p_stretch_mode);\n')
            function = once(function, guard, guard + begin)
            if name == "rd":
                clear_line = "\tRD::DrawListID draw_list = RD::get_singleton()->draw_list_begin_for_screen(DisplayServerEnums::MAIN_WINDOW_ID, clear_color);"
                function = once(function, clear_line, clear_line + "\n\tGlassvowBootProbe::clear();")
                draw_line = "RD::get_singleton()->draw_list_draw(draw_list, true);"
                function = once(function, draw_line, "GlassvowBootProbe::draw();\n\t\t" + draw_line)
                present_line = "\tRD::get_singleton()->swap_buffers(true);"
            else:
                clear_line = "\tglClear(GL_COLOR_BUFFER_BIT);"
                function = once(function, clear_line, clear_line + "\n\tGlassvowBootProbe::clear();")
                draw_lines = [line for line in function.splitlines() if "copy_effects->copy_to_rect" in line]
                if len(draw_lines) not in (1, 2):
                    raise ValueError("expected baseline or split/small-image GLES draw callsites")
                for line in draw_lines:
                    function = once(function, line, line[:len(line)-len(line.lstrip())] + "GlassvowBootProbe::draw();\n" + line)
                present_line = "\tgl_end_frame(true);"
            function = once(function, present_line, present_line + "\n\tGlassvowBootProbe::presented();")
            source = source[:start] + function + source[end:]
        elif name == "rd_storage":
            anchor = "\tVector<uint8_t> data = image->get_data(); //use image data"
            start = source.index("void TextureStorage::texture_2d_initialize(")
            end = source.index("\n}\n", start) + 3
            function = once(source[start:end], anchor,
                            anchor + "\n\tGlassvowBootProbe::upload(image);")
            source = source[:start] + function + source[end:]
        else:
            anchor = "\tVector<uint8_t> read = img->get_data();"
            source = once(source, anchor, anchor + "\n\tGlassvowBootProbe::upload(img);")
        changes[path] = source
    # Validate every hook before writing any source.
    header.write_text(HEADER)
    for path, text in changes.items():
        path.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    args = parser.parse_args()
    instrument(args.source_dir.resolve())
    print("Installed CI-only native boot observer; no runtime/template activation")


if __name__ == "__main__":
    main()
