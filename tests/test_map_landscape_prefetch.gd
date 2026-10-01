extends RefCounted
## An act's landscape warmed on a worker thread (`MapLandscapeAssets.prefetch`)
## is the landscape a cold decode makes. Taking it before the worker is done
## decodes each picture once, and a warm-up of another act is never waited for.
## Only one act's artwork is held at a time.

## Act I's textures as the texture importer's lossless import drew them
## (recorded at 3466a885, before the pictures moved to Image imports): the
## terrain, then each painted card cropped and mipmapped.
const ACT_I_PIXELS: PackedStringArray = [
	"1254x1254 4 true 3e5cfb345a7e126aa9f4d73215a6488cdc67d0c4fc4cb4f1a980f350fa127d92",
	"1254x1254 4 true 52682f4a3e1b8d412b7c92501f059bdf90374468d3716a24663350a559001a7e",
	"1533x1020 5 true 1bc441c069759a8f9e9c93b7b5b7272e55e2549588b5baea7732d27dcc379145",
	"1298x1199 5 true 8fd3d1edf0a2418515aadee60942cefd0406d928d2104c37e8b12e44200f4e9f",
	"1426x990 5 true e3b49d9db76dafe14be459a57c1052c1edc01eb3d338f9d8b2ea0bc4460fa282",
	"988x1495 5 true 7de9e85617df9d82393a7630dafdebf87976156acc1d65a65f83f90e8b17568d",
	"1472x1024 5 true b7282a934448fb2928b72a62c21adf9ff502ba62b1dde3dfad8c477ae8fa84e7",
]


static func run(fails: Array[String]) -> void:
	_warm_matches_cold(fails)
	_early_take_decodes_each_picture_once(fails)
	_stale_warm_up_is_never_waited_for(fails)
	_one_act_held(fails)
	MapLandscapeAssets.release()


static func _warm_matches_cold(fails: Array[String]) -> void:
	MapLandscapeAssets.release()
	var cold: MapLandscapeAssets = MapLandscapeAssets.new(0)
	_check(fails, _pixels(cold) == ACT_I_PIXELS,
		"Act I draws the pixels its texture import drew, edge bleed included")
	MapLandscapeAssets.prefetch(0)
	var warm: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
	_check(fails, warm != null and warm.act == 0 and warm.task >= 0,
		"a prefetch starts a worker for the act")
	if warm == null:
		return
	_settle(warm)
	_check(fails, warm.decoded == warm.files, "the worker decodes every picture of the act")
	var assets: MapLandscapeAssets = MapLandscapeAssets.for_act(0)
	_check(fails, MapLandscapeAssets.warming() == null, "the map takes the warm-up")
	_check(fails, assets.failure.is_empty() and assets.digest == cold.digest
			and assets.profiles == cold.profiles and assets.paths == cold.paths,
		"a warmed catalogue has the cold catalogue's geometry and paths")
	_check(fails, _pixels(assets) == ACT_I_PIXELS,
		"a warmed catalogue draws the cold catalogue's pixels")
	_check(fails, assets.ground == warm.texture("forest-floor.png")
			and assets.resources.has(warm.texture("vigil-painted.png")),
		"the map draws the worker's textures rather than decoding again")
	_check(fails, warm.decoded.size() == warm.files.size(), "taking a finished warm-up decodes nothing")


## The worker has decoded one picture when the map opens: the rest are decoded
## then, and no picture is decoded twice. The same holds for a real worker
## caught at whatever point it has reached.
static func _early_take_decodes_each_picture_once(fails: Array[String]) -> void:
	MapLandscapeAssets.release()
	var cold: MapLandscapeAssets = MapLandscapeAssets.new(1)
	var partial: MapLandscapeAssets.Pictures = MapLandscapeAssets.Pictures.new(1)
	partial.step()
	var finished: MapLandscapeAssets = MapLandscapeAssets.new(1, partial)
	_check(fails, partial.decoded[0] == partial.files[0] and _once(partial),
		"a part-decoded warm-up is finished, each picture once")
	_check(fails, finished.digest == cold.digest and _pixels(finished) == _pixels(cold),
		"a part-decoded warm-up finishes into the cold catalogue")
	MapLandscapeAssets.prefetch(1)
	var racing: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
	var taken: MapLandscapeAssets = MapLandscapeAssets.for_act(1)
	_check(fails, _once(racing) and racing.is_done(),
		"a warm-up taken at once is finished, each picture decoded once")
	_check(fails, taken.digest == cold.digest and _pixels(taken) == _pixels(cold),
		"a warm-up taken at once is the cold catalogue")


## Every picture of the act was decoded, and none twice.
static func _once(pictures: MapLandscapeAssets.Pictures) -> bool:
	var decoded: PackedStringArray = pictures.decoded.duplicate()
	decoded.sort()
	var files: PackedStringArray = pictures.files.duplicate()
	files.sort()
	return decoded == files


## A warm-up of Act IV that cannot finish is in the slot when Act I's map opens:
## the map opens without waiting for it, and the worker is reaped once it ends.
static func _stale_warm_up_is_never_waited_for(fails: Array[String]) -> void:
	MapLandscapeAssets.release()
	var gate: Semaphore = Semaphore.new()
	var stale: MapLandscapeAssets.Pictures = MapLandscapeAssets.Pictures.new(3)
	stale.task = WorkerThreadPool.add_task(gate.wait)
	MapLandscapeAssets._warming = stale
	var assets: MapLandscapeAssets = MapLandscapeAssets.for_act(0)
	_check(fails, not WorkerThreadPool.is_task_completed(stale.task),
		"the map opened while the stale warm-up was still running")
	_check(fails, assets.act == 0 and assets.failure.is_empty(), "the asked-for act is whole")
	_check(fails, stale.decoded.is_empty() and not stale.step(),
		"a stale warm-up is stopped before it claims another picture")
	_check(fails, MapLandscapeAssets.warming() == null and MapLandscapeAssets._retired.has(stale),
		"a stale warm-up is held until its worker ends")
	gate.post()
	_settle(stale)
	MapLandscapeAssets.release()
	_check(fails, MapLandscapeAssets._retired.is_empty(), "an ended stale warm-up is reaped")


static func _one_act_held(fails: Array[String]) -> void:
	MapLandscapeAssets.release()
	var first: MapLandscapeAssets = MapLandscapeAssets.for_act(0)
	MapLandscapeAssets.prefetch(0)
	_check(fails, MapLandscapeAssets.warming() == null, "a kept act is not warmed again")
	var released: WeakRef = weakref(first)
	first = null
	MapLandscapeAssets.prefetch(1)
	var warm: MapLandscapeAssets.Pictures = MapLandscapeAssets.warming()
	_check(fails, released.get_ref() == null,
		"warming the next act releases the kept act's artwork")
	MapLandscapeAssets.prefetch(1)
	_check(fails, MapLandscapeAssets.warming() == warm, "an act already warming is not started again")
	_check(fails, MapLandscapeAssets.for_act(1).act == 1, "the warmed act is the one kept")


## Every texture a catalogue holds, as its size, format, mipmaps and the
## SHA-256 of its pixels.
static func _pixels(assets: MapLandscapeAssets) -> PackedStringArray:
	var out: PackedStringArray = []
	for resource: Resource in assets.resources:
		var texture: Texture2D = resource as Texture2D
		if texture == null:
			continue
		var image: Image = texture.get_image()
		var hashing: HashingContext = HashingContext.new()
		hashing.start(HashingContext.HASH_SHA256)
		hashing.update(image.get_data())
		out.append("%dx%d %d %s %s" % [image.get_width(), image.get_height(),
			image.get_format(), image.has_mipmaps(), hashing.finish().hex_encode()])
	return out


## Waits for a worker this test started; the headless renderer never asks the
## main thread to serve it, so a busy wait cannot deadlock.
static func _settle(pictures: MapLandscapeAssets.Pictures) -> void:
	while not pictures.is_done():
		OS.delay_msec(1)


static func _check(fails: Array[String], ok: bool, label: String) -> void:
	if not ok:
		fails.append("map landscape prefetch: " + label)
