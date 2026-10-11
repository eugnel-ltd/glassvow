class_name GpuCopy
extends Texture2DRD
## A picture copied on the GPU from part of another texture, that owns its copy
## and frees it with itself (issue #657): a baked face kept from a card's stage
## (CardFaces), and a resting card's last frame kept when it lets its stage go
## (CardView). The copy is RenderingDevice.texture_copy, recorded after the
## frame that drew the source: nothing is read back, so nothing stalls.
##
## Draw it as any texture. When the last holder lets it go, the canvas's handle
## on the copy goes first, then the copy itself: a Texture2DRD never frees the
## texture it was handed.

var _gpu: RID = RID()


## A copy of `rect` of `source`, or null when no RenderingDevice can copy on
## this thread: the Compatibility renderer (the web build), a headless run. A
## caller that may stall a frame then reads the source back instead; one that
## may not (anything mid-play) does without.
static func of(source: Texture2D, rect: Rect2i) -> GpuCopy:
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd == null or not RenderingServer.is_on_render_thread():
		return null
	var from: RID = RenderingServer.texture_get_rd_texture(source.get_rid())
	if not rd.texture_is_valid(from):
		return null
	var into: RDTextureFormat = RDTextureFormat.new()
	into.width = rect.size.x
	into.height = rect.size.y
	into.format = rd.texture_get_format(from).format
	into.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var copy: GpuCopy = GpuCopy.new()
	copy._gpu = rd.texture_create(into, RDTextureView.new())
	rd.texture_copy(from, copy._gpu, Vector3(rect.position.x, rect.position.y, 0),
		Vector3.ZERO, Vector3(rect.size.x, rect.size.y, 1), 0, 0, 0, 0)
	copy.texture_rd_rid = copy._gpu
	return copy


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or not _gpu.is_valid():
		return
	texture_rd_rid = RID()
	var rd: RenderingDevice = RenderingServer.get_rendering_device()
	if rd != null and rd.texture_is_valid(_gpu):
		rd.free_rid(_gpu)
