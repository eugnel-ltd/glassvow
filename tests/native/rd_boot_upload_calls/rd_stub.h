#pragma once
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

#define _ALWAYS_INLINE_ inline
#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define STEPIFY(a, b) ((((a) + (b) - 1) / (b)) * (b))
#define ERR_RENDER_THREAD_GUARD_V(value) ((void)0)
#define ERR_FAIL_COND_V(cond, value) do { if (cond) return value; } while (0)
#define ERR_FAIL_COND_V_MSG(cond, value, message) ERR_FAIL_COND_V(cond, value)
#define ERR_FAIL_NULL_V(ptr, value) ERR_FAIL_COND_V((ptr) == nullptr, value)

enum Error { OK, ERR_UNAVAILABLE, ERR_INVALID_PARAMETER, ERR_BUG,
    ERR_CANT_ACQUIRE_RESOURCE, ERR_CANT_CREATE };
inline std::string itos(uint64_t n) { return std::to_string(n); }
struct RID {
    int id = 0;
    RID() = default;
    explicit RID(int n) : id(n) {}
    bool operator==(RID r) const { return id == r.id; }
    bool operator!=(RID r) const { return !(*this == r); }
};
struct Vector3i {
    uint32_t x = 0, y = 0, z = 0;
    Vector3i() = default;
    Vector3i(uint32_t a, uint32_t b, uint32_t c) : x(a), y(b), z(c) {}
};
template <typename T> struct Vector {
    std::vector<T> data;
    struct Write {
        Vector *owner;
        T &operator[](size_t i) { return owner->data.at(i); }
    } write{this};
    Vector() = default;
    explicit Vector(size_t n) : data(n) {}
    Vector(const Vector &other) : data(other.data) {}
    Vector &operator=(const Vector &other) { data = other.data; return *this; }
    size_t size() const { return data.size(); }
    bool is_empty() const { return data.empty(); }
    void clear() { data.clear(); }
    void push_back(const T &v) { data.push_back(v); }
    const T *ptr() const { return data.data(); }
    T *ptrw() { return data.data(); }
    const T &operator[](size_t i) const { return data.at(i); }
    T &operator[](size_t i) { return data.at(i); }
};
template <typename T> using LocalVector = Vector<T>;
namespace RDD {
enum { API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP, TEXTURE_ASPECT_DEPTH_BIT };
enum { TEXTURE_ASPECT_DEPTH, TEXTURE_ASPECT_COLOR };
using BufferID = uint32_t;
using TextureID = uint32_t;
struct TextureSubresource { uint32_t aspect = 0, mipmap = 0, layer = 0; };
struct BufferTextureCopyRegion {
    uint32_t buffer_offset = 0, row_pitch = 0;
    TextureSubresource texture_subresource;
    Vector3i texture_offset, texture_region_size;
};
}
namespace RDG {
struct RecordedBufferToTextureCopy {
    RDD::BufferID from_buffer = 0;
    RDD::BufferTextureCopyRegion region;
};
}
struct AspectFlags { bool has_flag(int) const { return false; } };
struct RecordingDriver {
    uint32_t pitch_step = 1;
    uint32_t api_trait_get(int trait) const {
        if (trait != RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)
            throw std::runtime_error("unexpected API trait");
        return pitch_step;
    }
};
struct RecordingGraph {
    std::vector<RDG::RecordedBufferToTextureCopy> copies;
    std::vector<size_t> batch_sizes;
    size_t synchronizations = 0;
    void add_synchronization() { synchronizations++; }
    void add_texture_update(uint32_t texture, void *,
            const LocalVector<RDG::RecordedBufferToTextureCopy> &items) {
        if (texture != 77) throw std::runtime_error("wrong destination texture");
        batch_sizes.push_back(items.size());
        copies.insert(copies.end(), items.data.begin(), items.data.end());
    }
};

class RenderingDevice {
public:
    enum TextureType { TEXTURE_TYPE_2D, TEXTURE_TYPE_3D, TEXTURE_TYPE_CUBE };
    enum DataFormat { DATA_FORMAT_R8_UNORM = 1, DATA_FORMAT_R8G8_UNORM = 2,
        DATA_FORMAT_R8G8B8_UNORM = 3, DATA_FORMAT_R8G8B8A8_UNORM = 4,
        DATA_FORMAT_BC1_RGB_UNORM_BLOCK = 100 };
    enum { TEXTURE_USAGE_CAN_UPDATE_BIT = 1 };
    struct Texture {
        RID owner;
        bool bound = false;
        uint32_t usage_flags = TEXTURE_USAGE_CAN_UPDATE_BIT;
        TextureType type = TEXTURE_TYPE_2D;
        DataFormat format = DATA_FORMAT_R8G8B8A8_UNORM;
        uint32_t width = 0, height = 0, depth = 1, mipmaps = 1, layers = 1;
        AspectFlags read_aspect_flags;
        uint32_t driver_id = 77;
        void *draw_tracker = nullptr;
    } texture;
    struct Owner {
        RenderingDevice *device;
        Texture *get_or_null(RID r) { return r.id == 1 ? &device->texture : nullptr; }
    } texture_owner{this};
    struct ActiveList { bool active = false; } draw_list, compute_list, raytracing_list;
    enum StagingRequiredAction { STAGING_REQUIRED_ACTION_NONE,
        STAGING_REQUIRED_ACTION_FLUSH_AND_STALL_ALL, STAGING_REQUIRED_ACTION_STALL_PREVIOUS };
    struct StagingBufferBlock {
        uint32_t driver_id = 0, fill_amount = 0;
        uint8_t *data_ptr = nullptr;
    };
    struct StagingBuffers { Vector<StagingBufferBlock> blocks; size_t current = 0; };
    struct Allocation {
        uint32_t amount, required_align, offset, size, buffer;
        bool can_segment;
    };
    static constexpr uint8_t CANARY = 0xD3;
    StagingBuffers upload_staging_buffers;
    RecordingDriver driver_storage;
    RecordingDriver *driver = &driver_storage;
    RecordingGraph draw_graph;
    std::map<uint32_t, std::vector<uint8_t>> buffers;
    std::vector<Allocation> allocations;
    std::vector<int> actions;
    uint32_t texture_upload_region_size_px = 1024;
    uint32_t alignment = 256;
    uint32_t clear_checks = 0, worker_checks = 0, shared_updates = 0, mutable_checks = 0;
    bool flush_every_second = false;
    bool mutable_first = true;

    Error texture_update(RID, uint32_t, const Vector<uint8_t> &);
    Error texture_update_boot_image(RID, uint32_t, const Vector<uint8_t> &);
    Error _texture_update(RID, uint32_t, const Vector<uint8_t> &, bool);
    uint32_t _texture_layer_count(Texture *t) const { return t->layers; }
    uint32_t _texture_alignment(Texture *) const { return alignment; }
    void _texture_check_pending_clear(RID, Texture *) { clear_checks++; }
    void _check_transfer_worker_texture(Texture *) { worker_checks++; }
    void _texture_update_shared_fallback(RID, Texture *, bool writing) {
        if (!writing) throw std::runtime_error("unexpected shared read");
        shared_updates++;
    }
    bool _texture_make_mutable(Texture *, RID) {
        mutable_checks++;
        return mutable_first && mutable_checks == 1;
    }
    Error _staging_buffer_allocate(StagingBuffers &staging, uint32_t amount,
            uint32_t required_align, uint32_t &offset, uint32_t &size,
            StagingRequiredAction &action, bool can_segment) {
        if (!required_align || !amount) throw std::runtime_error("zero allocation");
        offset = STEPIFY(19u, required_align);
        size = amount;
        uint32_t id = uint32_t(buffers.size()) + 1;
        auto &bytes = buffers[id];
        bytes.assign(size_t(offset) + size + 31, CANARY);
        staging.current = staging.blocks.size();
        staging.blocks.push_back({id, 0, bytes.data()});
        allocations.push_back({amount, required_align, offset, size, id, can_segment});
        action = flush_every_second && allocations.size() % 2 == 0 ?
            STAGING_REQUIRED_ACTION_FLUSH_AND_STALL_ALL : STAGING_REQUIRED_ACTION_NONE;
        return OK;
    }
    void _staging_buffer_execute_required_action(StagingBuffers &, StagingRequiredAction action) {
        actions.push_back(action);
    }
    static uint32_t get_image_format_pixel_size(DataFormat f) {
        return f == DATA_FORMAT_BC1_RGB_UNORM_BLOCK ? 1 : uint32_t(f);
    }
    static void get_compressed_image_format_block_dimensions(DataFormat f,
            uint32_t &w, uint32_t &h) {
        w = h = f == DATA_FORMAT_BC1_RGB_UNORM_BLOCK ? 4 : 1;
    }
    static uint32_t get_compressed_image_format_pixel_rshift(DataFormat f) {
        return f == DATA_FORMAT_BC1_RGB_UNORM_BLOCK ? 1 : 0;
    }
    static uint32_t get_compressed_image_format_block_byte_size(DataFormat f) {
        return f == DATA_FORMAT_BC1_RGB_UNORM_BLOCK ? 8 : uint32_t(f);
    }
    static uint32_t get_image_format_required_size(DataFormat f, uint32_t w,
            uint32_t h, uint32_t d, uint32_t mips, uint32_t *rw = nullptr,
            uint32_t *rh = nullptr, uint32_t *rd = nullptr) {
        uint32_t total = 0;
        for (uint32_t i = 0; i < mips; i++) {
            if (rw) *rw = w;
            if (rh) *rh = h;
            if (rd) *rd = d;
            total += w * h * d * get_image_format_pixel_size(f);
            w = MAX(1u, w >> 1); h = MAX(1u, h >> 1); d = MAX(1u, d >> 1);
        }
        return total;
    }
};
