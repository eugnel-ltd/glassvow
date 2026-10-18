#!/usr/bin/env python3
"""CI-only schema2 observer for real full-texture boot allocation/row transfers."""
from pathlib import Path
import argparse

HEADER = r'''#pragma once
#include "core/io/image.h"
#include "core/io/json.h"
#include "core/os/os.h"
#include "core/variant/array.h"
#include "core/variant/dictionary.h"
namespace GlassvowBootProbe {
struct State { bool active = false; int textures = 0, transfers = 0, staging = 0, draws = 0, clears = 0; uint64_t texture_id = 0; };
inline State &state() { static State value; return value; }
inline void emit(Dictionary p_event) { p_event["schema"] = 2; print_line("GV_BOOT_PROBE " + JSON::stringify(p_event)); }
inline void begin(const char *p_renderer, const Ref<Image> &p_image, const Size2i &p_window, bool p_filter, int p_stretch) {
    state() = State(); state().active = OS::get_singleton()->get_environment("GLASSVOW_BOOT_UPLOAD_PROBE") == "1";
    if (!state().active) { return; }
    Dictionary e; e["event"] = "begin"; e["renderer"] = p_renderer;
    e["source_width"] = p_image->get_width(); e["source_height"] = p_image->get_height();
    e["source_format"] = Image::get_format_name(p_image->get_format()); e["source_bytes"] = p_image->get_data_size();
    e["window_width"] = p_window.x; e["window_height"] = p_window.y; e["filter"] = p_filter; e["stretch"] = p_stretch; emit(e);
}
inline void texture(uint64_t p_id, int p_width, int p_height, int p_depth, int p_layers, int p_mipmaps, int p_format, int p_bpp, uint64_t p_bytes, uint64_t p_initial, const char *p_api) {
    if (!state().active) { return; } state().textures++; state().texture_id = p_id;
    Dictionary e; e["event"] = "texture"; e["texture_id"] = int64_t(p_id);
    e["width"] = p_width; e["height"] = p_height; e["depth"] = p_depth; e["layers"] = p_layers; e["mipmaps"] = p_mipmaps;
    e["format_code"] = p_format; e["bytes_per_pixel"] = p_bpp; e["logical_bytes"] = int64_t(p_bytes); e["initial_data_bytes"] = int64_t(p_initial); e["api"] = p_api; emit(e);
}
inline void staging(uint64_t p_request, uint64_t p_allocated, uint64_t p_offset, uint64_t p_alignment, uint64_t p_capacity, const char *p_api) {
    if (!state().active) { return; }
    Dictionary e; e["event"] = "staging"; e["index"] = state().staging++;
    e["request_bytes"] = int64_t(p_request); e["allocated_bytes"] = int64_t(p_allocated); e["offset"] = int64_t(p_offset);
    e["alignment"] = int64_t(p_alignment); e["buffer_capacity"] = int64_t(p_capacity); e["api"] = p_api; emit(e);
}
inline void transfer(uint64_t p_id, int p_x, int p_y, int p_z, int p_width, int p_height, int p_depth, int p_mipmap, int p_layer, uint64_t p_source_offset, uint64_t p_source_bytes, uint64_t p_pitch, uint64_t p_pitch_step, uint64_t p_buffer_offset, const char *p_api, bool p_staging) {
    if (!state().active) { return; }
    Dictionary e; e["event"] = "transfer"; e["index"] = state().transfers++; e["texture_id"] = int64_t(p_id);
    e["x"] = p_x; e["y"] = p_y; e["z"] = p_z; e["width"] = p_width; e["height"] = p_height; e["depth"] = p_depth;
    e["mipmap"] = p_mipmap; e["layer"] = p_layer; e["source_offset"] = int64_t(p_source_offset); e["source_bytes"] = int64_t(p_source_bytes);
    e["row_pitch"] = int64_t(p_pitch); e["row_pitch_step"] = int64_t(p_pitch_step); e["buffer_offset"] = int64_t(p_buffer_offset);
    e["staging_index"] = p_staging ? state().staging - 1 : -1; e["api"] = p_api; emit(e);
}
inline void clear() { if (state().active) { state().clears++; } }
inline void draw(uint64_t p_texture, const Rect2 &p_source, const Rect2 &p_destination) {
    if (!state().active) { return; } state().draws++;
    Dictionary e; e["event"] = "draw"; e["texture_id"] = int64_t(p_texture);
    Array src; src.push_back(p_source.position.x); src.push_back(p_source.position.y); src.push_back(p_source.size.x); src.push_back(p_source.size.y);
    Array dst; dst.push_back(p_destination.position.x); dst.push_back(p_destination.position.y); dst.push_back(p_destination.size.x); dst.push_back(p_destination.size.y);
    e["source_uv"] = src; e["destination"] = dst; emit(e);
}
inline void presented() {
    if (!state().active) { return; }
    Dictionary e; e["event"] = "present"; e["textures"] = state().textures; e["transfers"] = state().transfers;
    e["draws"] = state().draws; e["clears"] = state().clears; e["presents"] = 1; emit(e);
    e.clear(); e["event"] = "hold"; emit(e);
    const int ms = CLAMP(OS::get_singleton()->get_environment("GV_BOOT_PROBE_HOLD_MS").to_int(), 1, 30000);
    OS::get_singleton()->delay_usec(uint64_t(ms) * 1000); state().active = false;
}
} // namespace GlassvowBootProbe
'''


def once(text, old, new):
    if text.count(old) != 1:
        raise ValueError("observer expected one exact anchor: " + repr(old[:100]))
    return text.replace(old, new)


def function(text, signature, transform):
    start = text.index(signature)
    end = text.index("\n}\n", start) + 3
    return text[:start] + transform(text[start:end]) + text[end:]


def compositor(source, renderer):
    signature = "void " + ("RendererCompositorRD" if renderer == "rd" else "RasterizerGLES3") + "::set_boot_image_with_stretch("
    def edit(body):
        guard = "\tif (p_image.is_null() || p_image->is_empty()) {\n\t\treturn;\n\t}\n"
        body = once(body, guard, guard + f'\tGlassvowBootProbe::begin("{renderer}", p_image, DisplayServer::get_singleton()->window_get_size(), p_use_filter, p_stretch_mode);\n')
        if renderer == "rd":
            clear = "\tRD::DrawListID draw_list = RD::get_singleton()->draw_list_begin_for_screen(DisplayServerEnums::MAIN_WINDOW_ID, clear_color);"
            draw = "\tRD::get_singleton()->draw_list_draw(draw_list, true);"
            record = "\tGlassvowBootProbe::draw(rd_texture.get_id(), Rect2(blit.push_constant.src_rect[0], blit.push_constant.src_rect[1], blit.push_constant.src_rect[2], blit.push_constant.src_rect[3]), Rect2(blit.push_constant.dst_rect[0], blit.push_constant.dst_rect[1], blit.push_constant.dst_rect[2], blit.push_constant.dst_rect[3]));\n"
            present = "\tRD::get_singleton()->swap_buffers(true);"
        else:
            clear = "\tglClear(GL_COLOR_BUFFER_BIT);"
            draw = "\tcopy_effects->copy_to_rect(screenrect);"
            record = "\tGlassvowBootProbe::draw(t->tex_id, Rect2(0, 0, 1, 1), screenrect);\n"
            present = "\tgl_end_frame(true);"
        body = once(body, clear, clear + "\n\tGlassvowBootProbe::clear();")
        body = once(body, draw, record + draw)
        return once(body, present, present + "\n\tGlassvowBootProbe::presented();")
    return function(source, signature, edit)


def gles_storage(source):
    def edit(body):
        full = "glTexImage2D(blit_target, i, internal_format, w, h, 0, format, type, &read[ofs]);"
        allocation = 'GlassvowBootProbe::texture(texture->tex_id, w, h, 1, 1, mipmaps, internal_format, int(size / (int64_t(w) * h)), size, size, "glTexImage2D");'
        transfer = 'GlassvowBootProbe::transfer(texture->tex_id, 0, 0, 0, w, h, 1, i, p_layer, ofs, size, size / h, 1, 0, "glTexImage2D", false);'
        body = once(body, full, full + "\n\t\t\t\t" + allocation + "\n\t\t\t\t" + transfer)
        empty = "glTexImage2D(blit_target, i, internal_format, w, h, 0, format, type, nullptr);"
        sub = "glTexSubImage2D(blit_target, i, 0, first, w, end - first, format, type, &read[ofs + first * row_bytes]);"
        if "texture->boot_image_upload" in body and not (empty in body and sub in body):
            raise ValueError("unknown native boot-image GLES transfer branch")
        if empty in body or sub in body:
            allocation = 'GlassvowBootProbe::texture(texture->tex_id, w, h, 1, 1, mipmaps, internal_format, int(row_bytes / w), size, 0, "glTexImage2D");'
            body = once(body, empty, empty + "\n\t\t\t\t" + allocation)
            transfer = 'GlassvowBootProbe::transfer(texture->tex_id, 0, first, 0, w, end - first, 1, i, p_layer, ofs + first * row_bytes, int64_t(end - first) * row_bytes, row_bytes, 1, 0, "glTexSubImage2D", false);'
            body = once(body, sub, sub + "\n\t\t\t\t\t" + transfer)
        return body
    return function(source, "void TextureStorage::_texture_set_data(", edit)


def rendering_device(source):
    def create(body):
        anchor = "\tRID id = texture_owner.make_rid(texture);"
        record = '''
\tuint64_t gv_initial_bytes = 0;
\tfor (const Vector<uint8_t> &gv_data : data) { gv_initial_bytes += gv_data.size(); }
\tGlassvowBootProbe::texture(id.get_id(), format.width, format.height, format.depth, format.array_layers, format.mipmaps, format.format, get_image_format_pixel_size(format.format), get_image_format_required_size(format.format, format.width, format.height, format.depth, format.mipmaps), gv_initial_bytes, "texture_create");'''
        return once(body, anchor, anchor + record)
    source = function(source, "RID RenderingDevice::texture_create(", create)
    def initialize(body):
        allocation = "\t\t\ttransfer_worker = _acquire_transfer_worker(staging_local_offset, required_align, staging_worker_offset);"
        stage = '\n\t\t\tGlassvowBootProbe::staging(staging_local_offset, staging_local_offset, staging_worker_offset, required_align, transfer_worker->staging_buffer_size_allocated, "transfer_worker");'
        body = once(body, allocation, allocation + stage)
        copy = "\t\t\t\t\tdriver->command_copy_buffer_to_texture(transfer_worker->command_buffer, transfer_worker->staging_buffer, texture->driver_id, p_dst_layout, copy_region);"
        record = '\n\t\t\t\t\tGlassvowBootProbe::transfer(p_texture.get_id(), copy_region.texture_offset.x, copy_region.texture_offset.y, copy_region.texture_offset.z, copy_region.texture_region_size.x, copy_region.texture_region_size.y, copy_region.texture_region_size.z, copy_region.texture_subresource.mipmap, copy_region.texture_subresource.layer, uint64_t(read_ptr_mipmap_layer - read_ptr), uint64_t(logic_width) * logic_height * pixel_size, copy_region.row_pitch, pitch_step, copy_region.buffer_offset, "rd_initialize_copy", true);'
        return once(body, copy, copy + record)
    source = function(source, "Error RenderingDevice::_texture_initialize(", initialize)
    # Candidate's dedicated entry point reuses this original frame-staging path.
    has_boot = "Error RenderingDevice::texture_update_boot_image(" in source
    has_update = "Error RenderingDevice::_texture_update(" in source
    if has_boot != has_update:
        raise ValueError("unknown native boot-image RD update entry point")
    if has_update:
        def update(body):
            allocation = "\t\t\t\t\tERR_FAIL_COND_V(err, ERR_CANT_CREATE);"
            stage = '\n\t\t\t\t\tGlassvowBootProbe::staging(to_allocate, alloc_size, alloc_offset, required_align, upload_staging_buffers.block_size, "frame_staging");'
            body = once(body, allocation, allocation + stage)
            copy = "\t\t\t\t\tcommand_buffer_to_texture_copies_vector.push_back(buffer_to_texture_copy);"
            record = '\n\t\t\t\t\tGlassvowBootProbe::transfer(p_texture.get_id(), copy_region.texture_offset.x, copy_region.texture_offset.y, copy_region.texture_offset.z, copy_region.texture_region_size.x, copy_region.texture_region_size.y, copy_region.texture_region_size.z, copy_region.texture_subresource.mipmap, copy_region.texture_subresource.layer, uint64_t(read_ptr_mipmap_layer - read_ptr) + (uint64_t(y) * width + x) * pixel_size, uint64_t(region_w) * region_h * pixel_size, copy_region.row_pitch, pitch_step, copy_region.buffer_offset, "rd_update_copy", true);'
            return once(body, copy, copy + record)
        source = function(source, "Error RenderingDevice::_texture_update(", update)
    return source


def instrument(tree):
    header = tree / "servers/rendering/glassvow_boot_probe.h"
    if header.exists():
        raise ValueError("observer already installed")
    transforms = {
        "servers/rendering/renderer_rd/renderer_compositor_rd.cpp": lambda text: compositor(text, "rd"),
        "drivers/gles3/rasterizer_gles3.cpp": lambda text: compositor(text, "gles3"),
        "drivers/gles3/storage/texture_storage.cpp": gles_storage,
        "servers/rendering/rendering_device.cpp": rendering_device,
    }
    changes = {}
    for relative, transform in transforms.items():
        path = tree / relative
        source = transform(path.read_text())
        # Both source pins and the drafted candidate contain this exact include.
        source = once(source, '#include "core/config/engine.h"',
                      '#include "core/config/engine.h"\n#include "servers/rendering/glassvow_boot_probe.h"')
        changes[path] = source
    # All anchors must validate before any source is written.
    header.write_text(HEADER)
    for path, source in changes.items():
        path.write_text(source)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True, type=Path)
    instrument(parser.parse_args().source_dir.resolve())
    print("Installed schema2 CI-only native boot allocation/transfer observer")
