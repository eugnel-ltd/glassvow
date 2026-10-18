#include "rd_stub.h"
#include "actual_source.inc"

static constexpr uint64_t CAP = 4 * 1024 * 1024;
static std::string current_case;
static void require(bool value, const char *message) {
    if (!value) throw std::runtime_error(current_case + ": " + message);
}
static Vector<uint8_t> make_bytes(RenderingDevice &device) {
    auto &t = device.texture;
    Vector<uint8_t> result(RenderingDevice::get_image_format_required_size(
        t.format, t.width, t.height, t.depth, t.mipmaps));
    for (size_t i = 0; i < result.size(); i++)
        result.write[i] = uint8_t((i * 109 + (i / 97) * 43 + 17) % 251);
    return result;
}
static void check_bytes(RenderingDevice &device, const Vector<uint8_t> &source, bool boot) {
    auto &t = device.texture;
    uint32_t bpp = device.get_image_format_pixel_size(t.format);
    std::vector<uint8_t> gpu(source.size(), 0);
    std::vector<uint8_t> coverage(source.size(), 0);
    for (const auto &a : device.allocations) {
        require(a.required_align == device.alignment, "wrong staging offset alignment");
        require(a.offset % a.required_align == 0, "unaligned buffer offset");
        require(!a.can_segment, "actual upload unexpectedly permits allocator segmentation");
        if (boot) require(a.amount <= CAP, "boot staging request exceeds 4 MiB");
        const auto &bytes = device.buffers.at(a.buffer);
        for (size_t i = 0; i < a.offset; i++)
            require(bytes[i] == device.CANARY, "prefix staging canary overwritten");
        for (size_t i = size_t(a.offset) + a.size; i < bytes.size(); i++)
            require(bytes[i] == device.CANARY, "suffix staging canary overwritten");
    }
    uint32_t min_h = UINT32_MAX, max_h = 0;
    for (const auto &copy : device.draw_graph.copies) {
        const auto &r = copy.region;
        require(r.texture_subresource.layer == 0, "wrong array layer");
        require(r.row_pitch % device.driver->pitch_step == 0, "wrong driver row pitch");
        require(r.row_pitch >= r.texture_region_size.x * bpp, "short row pitch");
        if (boot) {
            require(r.texture_offset.x == 0, "boot is not a full-width row band");
            require(r.texture_region_size.x == t.width, "boot row band misses full width");
            min_h = MIN(min_h, r.texture_region_size.y);
            max_h = MAX(max_h, r.texture_region_size.y);
        }
        uint32_t width = t.width, height = t.height, depth = t.depth;
        size_t mip_offset = 0;
        for (uint32_t mm = 0; mm < r.texture_subresource.mipmap; mm++) {
            mip_offset += size_t(width) * height * depth * bpp;
            width = MAX(1u, width >> 1); height = MAX(1u, height >> 1);
            depth = MAX(1u, depth >> 1);
        }
        require(r.texture_offset.x + r.texture_region_size.x <= width, "x extent outside texture");
        require(r.texture_offset.y + r.texture_region_size.y <= height, "y extent outside texture");
        require(r.texture_offset.z < depth, "z extent outside texture");
        const auto &bytes = device.buffers.at(copy.from_buffer);
        for (uint32_t y = 0; y < r.texture_region_size.y; y++) {
            size_t dst = mip_offset + ((size_t(r.texture_offset.z) * height +
                r.texture_offset.y + y) * width + r.texture_offset.x) * bpp;
            size_t src = size_t(r.buffer_offset) + size_t(y) * r.row_pitch;
            size_t row_bytes = size_t(r.texture_region_size.x) * bpp;
            require(dst + row_bytes <= gpu.size() && src + r.row_pitch <= bytes.size(),
                "copy outside storage");
            require(std::all_of(coverage.begin() + dst, coverage.begin() + dst + row_bytes,
                [](uint8_t n) { return n == 0; }), "GPU byte written more than once");
            std::memcpy(gpu.data() + dst, bytes.data() + src, row_bytes);
            std::memset(coverage.data() + dst, 1, row_bytes);
            require(std::all_of(bytes.begin() + src + row_bytes, bytes.begin() + src + r.row_pitch,
                [](uint8_t n) { return n == RenderingDevice::CANARY; }), "row padding changed");
        }
    }
    require(std::all_of(coverage.begin(), coverage.end(), [](uint8_t n) { return n == 1; }),
        "GPU full texture has uncovered bytes");
    require(gpu == source.data, "reconstructed GPU texture differs from full source");
    if (boot) require(max_h - min_h <= 1, "boot row bands are not balanced");
    require(device.clear_checks == 1 && device.worker_checks == 1 && device.shared_updates == 1,
        "original texture lifecycle calls changed");
    require(device.actions.size() == device.allocations.size(), "missing staging required action");
    require(device.draw_graph.synchronizations == 1, "mutable synchronization lost or duplicated");
}
static std::string trace(const RenderingDevice &device) {
    std::string s = "{\"width\":" + std::to_string(device.texture.width) +
        ",\"height\":" + std::to_string(device.texture.height) +
        ",\"bpp\":" + std::to_string(device.get_image_format_pixel_size(device.texture.format)) +
        ",\"pitch_step\":" + std::to_string(device.driver->pitch_step) +
        ",\"allocations\":[";
    bool comma = false;
    for (const auto &a : device.allocations) {
        if (comma) s += ',';
        comma = true;
        s += '[' + std::to_string(a.amount) + ',' + std::to_string(a.required_align) + ',' +
            std::to_string(a.offset) + ',' + std::to_string(a.size) + ']';
    }
    s += "],\"copies\":["; comma = false;
    for (const auto &copy : device.draw_graph.copies) {
        if (comma) s += ',';
        comma = true;
        const auto &r = copy.region;
        s += '[' + std::to_string(r.buffer_offset) + ',' + std::to_string(r.row_pitch) + ',' +
            std::to_string(r.texture_subresource.mipmap) + ',' + std::to_string(r.texture_offset.x) + ',' +
            std::to_string(r.texture_offset.y) + ',' + std::to_string(r.texture_offset.z) + ',' +
            std::to_string(r.texture_region_size.x) + ',' + std::to_string(r.texture_region_size.y) + ']';
    }
    s += "],\"batch_sizes\":["; comma = false;
    for (size_t n : device.draw_graph.batch_sizes) {
        if (comma) s += ',';
        comma = true;
        s += std::to_string(n);
    }
    s += "],\"actions\":["; comma = false;
    for (int n : device.actions) {
        if (comma) s += ',';
        comma = true;
        s += std::to_string(n);
    }
    s += "],\"mutable_checks\":" + std::to_string(device.mutable_checks) + '}';
    return s;
}
static void configure(RenderingDevice &d, uint32_t w, uint32_t h, uint32_t bpp, uint32_t step) {
    d.texture.width = w; d.texture.height = h;
    d.texture.format = RenderingDevice::DataFormat(bpp);
    d.driver->pitch_step = step;
}
int main(int argc, char **argv) {
    try {
        require(argc == 2, "supply mode");
        std::string mode(argv[1]), normal = "[", boot = "[";
        size_t normal_count = 0, boot_count = 0, rejection_count = 0;
        if (mode == "normal" || mode == "all") {
            for (uint32_t bpp : {1u, 2u, 4u}) for (uint32_t step : {1u, 256u, 1024u}) {
                current_case = "normal bpp=" + std::to_string(bpp) + " pitch=" + std::to_string(step);
                RenderingDevice d; configure(d, 2361, 1641, bpp, step);
                d.texture.mipmaps = 3; d.texture.depth = 2;
                d.texture.type = RenderingDevice::TEXTURE_TYPE_3D;
                d.flush_every_second = true;
                auto bytes = make_bytes(d), frozen = bytes;
                require(d.texture_update(RID(1), 0, bytes) == OK, "ordinary upload returned error");
                require(bytes.data == frozen.data, "ordinary source bytes changed");
                check_bytes(d, bytes, false);
                if (normal_count++) normal += ',';
                normal += trace(d);
            }
        }
#if FIXTURE_HAS_BOOT
        if (mode == "boot" || mode == "all") {
            for (uint32_t bpp : {1u, 2u, 4u}) for (uint32_t step : {1u, 256u, 512u, 1024u, 16384u}) {
                current_case = "boot odd bpp=" + std::to_string(bpp) + " pitch=" + std::to_string(step);
                RenderingDevice d; configure(d, 2361, 1641, bpp, step);
                d.alignment = step == 1 ? 1 : step;
                d.flush_every_second = step >= 512;
                auto bytes = make_bytes(d), frozen = bytes;
                require(d.texture_update_boot_image(RID(1), 0, bytes) == OK, "boot upload returned error");
                require(bytes.data == frozen.data, "boot source bytes changed");
                check_bytes(d, bytes, true);
                if (boot_count++) boot += ',';
                boot += trace(d);
            }
            {
                current_case = "boot actual splash RGB validated to RGBA8";
                RenderingDevice d; configure(d, 2360, 1640, 4, 256);
                auto bytes = make_bytes(d);
                require(d.texture_update_boot_image(RID(1), 0, bytes) == OK, "actual splash boot failed");
                check_bytes(d, bytes, true);
                if (boot_count++) boot += ',';
                boot += trace(d);
            }
            for (uint32_t bpp : {1u, 2u, 4u}) {
                current_case = "boot small bpp=" + std::to_string(bpp);
                RenderingDevice d; configure(d, 3, 5, bpp, 256);
                auto bytes = make_bytes(d);
                require(d.texture_update_boot_image(RID(1), 0, bytes) == OK, "small odd boot failed");
                check_bytes(d, bytes, true);
                if (boot_count++) boot += ',';
                boot += trace(d);
            }
            for (uint32_t test = 0; test < 6; test++) {
                current_case = "boot rejection=" + std::to_string(test);
                RenderingDevice d; configure(d, 3, 5, 4, 1);
                if (test == 0) d.texture.width = uint32_t(CAP / 4) + 1;
                if (test == 1) d.driver->pitch_step = uint32_t(CAP) * 2;
                if (test == 2) d.texture.mipmaps = 2;
                if (test == 3) d.texture.depth = 2;
                if (test == 4) d.texture.type = RenderingDevice::TEXTURE_TYPE_3D;
                if (test == 5) d.texture.format = RenderingDevice::DATA_FORMAT_BC1_RGB_UNORM_BLOCK;
                auto bytes = make_bytes(d);
                require(d.texture_update_boot_image(RID(1), 0, bytes) != OK,
                    "unsupported boot shape or atomic row unexpectedly accepted");
                require(d.allocations.empty() && d.draw_graph.copies.empty(),
                    "rejected boot upload allocated or submitted a partial texture");
                rejection_count++;
            }
        }
#endif
        std::cout << "{\"status\":\"pass\",\"normal_cases\":" << normal_count <<
            ",\"boot_cases\":" << boot_count << ",\"rejections\":" << rejection_count <<
            ",\"normal_trace\":" << normal << "],\"boot_trace\":" << boot << "]}\n";
        return 0;
    } catch (const std::exception &e) {
        std::cerr << "RD RECORDING FIXTURE FAIL: " << e.what() << '\n';
        return 1;
    }
}
