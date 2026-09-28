class_name SceneScript
extends RefCounted
## Authored scene beat list. Copy lives in locale; this file is structure.
## Stage directions (cast, moods, styles, effects) are validated by
## `StageDirection`; a v1 script with none of them still plays unchanged.

const PATH: String = "res://content/scenes.json"
const MOTIONS: Dictionary = {"hold": true, "push-in": true, "linger": true}
## A drawn LineTable row's weather, by slot. Each closer closes its journey in
## its own light (07-scenes §9); every other slot keeps the quiet motes.
const POOL_LOOKS: Dictionary[String, Dictionary] = {
	"closer.ownShade": {
		"ambient": "ash", "grade": "cold", "style": "whisper", "fx": ["flash-cold"],
	},
	"closer.usurper": {"ambient": "embers", "grade": "dusk", "fx": ["crack"]},
	"closer.eighthOmen": {
		"ambient": "snow-glass", "grade": "inverted", "style": "title",
		"fx": ["flash-cold", "pulse"],
	},
	"closer.l3": {"ambient": "motes", "grade": "hearth", "style": "chorus", "fx": ["rays"]},
}
const POOL_AMBIENT: String = "motes"
## The Eighth Omen's broken words, as a tail line after a waystone's echo.
const OMEN_ECHO: Dictionary = {"style": "title", "fx": ["flash-cold"]}
## A LineTable row played as a run scene (the closers, the Queue at the door)
## has the scene id `line:<row id>`; its script is `pool_beat` in the row's look.
const LINE_PREFIX: String = "line:"
## The Unreadable Page's pages are quest copy (`content.quests`), not story
## leaves, so their scenes are built here, as the pool beats are, rather than
## authored in `content/scenes.json`: page N plays as `unreadable-page-N`.
const PAGE_PREFIX: String = "unreadable-page-"
const PAGE_COUNT: int = 5
const PAGE_KEY: String = "content.quests.unreadablePage.pages.%d"

var id: String = ""
var beats: Array[Dictionary] = []
var lines: Array[Dictionary] = []


static func load_all(path: String = PATH) -> Variant:
	if not FileAccess.file_exists(path):
		return _fail("scenes: missing %s" % path)
	return parse_bundle(JSON.parse_string(FileAccess.get_file_as_string(path)))


static func parse_bundle(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: root is not an object")
	var root: Dictionary = raw
	var scenes_v: Variant = root.get("scenes")
	if typeof(scenes_v) != TYPE_DICTIONARY:
		return _fail("scenes: missing scenes object")
	var scenes: Dictionary = scenes_v
	var out: Dictionary = {}
	for id_v: Variant in scenes:
		var scene_id: String = str(id_v)
		var parsed: Variant = parse_scene(scene_id, scenes[id_v])
		if typeof(parsed) == TYPE_STRING:
			return parsed
		out[scene_id] = parsed
	return out


static func parse_scene(scene_id: String, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: %s is not an object" % scene_id)
	var scene: Dictionary = raw
	var beats_v: Variant = scene.get("beats")
	if typeof(beats_v) != TYPE_ARRAY:
		return _fail("scenes: %s has no beats" % scene_id)
	var beats_raw: Array = beats_v
	if beats_raw.is_empty():
		return _fail("scenes: %s has no beats" % scene_id)
	var script: SceneScript = SceneScript.new()
	script.id = scene_id
	for beat_i: int in range(beats_raw.size()):
		var built: Variant = _beat(scene_id, beat_i, beats_raw[beat_i])
		if typeof(built) == TYPE_STRING:
			return built
		var beat: Dictionary = built
		script.beats.append(beat)
		var beat_lines: Array = beat["lines"]
		for line_v: Variant in beat_lines:
			var line: Dictionary = line_v
			var flat: Dictionary = line.duplicate()
			flat["beat"] = beat_i
			script.lines.append(flat)
	return script


func line_count() -> int:
	return lines.size()


## One-beat script for a LineTable row. Copy stays on the row; the dummy key
## is never resolved when ScenePlayer is given the pool row. `slot` picks the
## row's look (`POOL_LOOKS`); `tail` lines are locale keys, each with its own
## directions, that follow the row on the same beat.
static func pool_beat(art: String, slot: String = "",
		tail: Array[Dictionary] = []) -> SceneScript:
	var script: SceneScript = SceneScript.new()
	script.id = "pool"
	var look: Dictionary = {"ambient": POOL_AMBIENT}
	if POOL_LOOKS.has(slot):
		look.merge(POOL_LOOKS[slot], true)
	var beat: Dictionary = {"art": art, "motion": "hold", "skip_dwell": 0.0}
	var line: Dictionary = {"key": "pool.inline", "beat": 0}
	var where: String = "pool %s" % slot
	var error: String = StageDirection.parse_beat(look, beat, where)
	if error.is_empty():
		error = StageDirection.parse_line(look, line, where)
	if not error.is_empty():
		push_error(error)
		return pool_beat(art, "", tail)
	var beat_lines: Array[Dictionary] = [line]
	for i: int in range(tail.size()):
		var raw: Dictionary = tail[i]
		var extra: Dictionary = {"key": str(raw.get("key", "")), "beat": 0}
		error = StageDirection.parse_line(raw, extra, "%s tail %d" % [where, i])
		if not error.is_empty() or str(extra["key"]).is_empty():
			push_error(error if not error.is_empty() else "%s tail %d has no key" % [where, i])
			continue
		beat_lines.append(extra)
	beat["lines"] = beat_lines
	script.beats.append(beat)
	script.lines.append_array(beat_lines)
	return script


## Page N read by lamplight: one narrated line at dusk, the last with rays.
## Null for any id that is not a page.
static func quest_page(scene_id: String) -> SceneScript:
	var number: String = scene_id.trim_prefix(PAGE_PREFIX)
	if not scene_id.begins_with(PAGE_PREFIX) or not number.is_valid_int():
		return null
	var n: int = number.to_int()
	if n < 1 or n > PAGE_COUNT or str(n) != number:
		return null
	var line: Dictionary = {"key": PAGE_KEY % (n - 1), "style": "narration",
		"fx": ["rays" if n == PAGE_COUNT else "pulse"]}
	var built: Variant = parse_scene(scene_id, {"beats": [{
		"motion": "hold", "transition": "fade", "ambient": "motes", "grade": "dusk",
		"lines": [line],
	}]})
	return built if built is SceneScript else null


func beat_at(index: int) -> Dictionary:
	if index < 0 or index >= lines.size():
		return {}
	var beat_i: int = lines[index]["beat"]
	if beat_i < 0 or beat_i >= beats.size():
		return {}
	return beats[beat_i]


static func _beat(scene_id: String, beat_i: int, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: %s beat %d is not an object" % [scene_id, beat_i])
	var row: Dictionary = raw
	var motion: String = str(row.get("motion", ""))
	if not MOTIONS.has(motion):
		return _fail("scenes: %s beat %d has unknown motion '%s'" % [scene_id, beat_i, motion])
	var lines_v: Variant = row.get("lines")
	if typeof(lines_v) != TYPE_ARRAY:
		return _fail("scenes: %s beat %d has no lines" % [scene_id, beat_i])
	var lines_raw: Array = lines_v
	if lines_raw.is_empty():
		return _fail("scenes: %s beat %d has no lines" % [scene_id, beat_i])
	var cleaned_lines: Array[Dictionary] = []
	for line_i: int in range(lines_raw.size()):
		var built: Variant = _line(scene_id, beat_i, line_i, lines_raw[line_i])
		if typeof(built) == TYPE_STRING:
			return built
		var line: Dictionary = built
		cleaned_lines.append(line)
	var skip_dwell: float = float(str(row.get("skipDwell", 0.0)))
	if skip_dwell < 0.0:
		return _fail("scenes: %s beat %d has negative skipDwell" % [scene_id, beat_i])
	var beat: Dictionary = {
		"art": str(row.get("art", "")),
		"motion": motion,
		"lines": cleaned_lines,
		"skip_dwell": skip_dwell,
	}
	var staged: String = StageDirection.parse_beat(
		row, beat, "scenes: %s beat %d" % [scene_id, beat_i])
	if not staged.is_empty():
		return _fail(staged)
	return beat


static func _line(scene_id: String, beat_i: int, line_i: int, raw: Variant) -> Variant:
	if typeof(raw) != TYPE_DICTIONARY:
		return _fail("scenes: %s beat %d line %d is not an object" % [scene_id, beat_i, line_i])
	var row: Dictionary = raw
	var key: String = str(row.get("key", "")).strip_edges()
	if key.is_empty():
		return _fail("scenes: %s beat %d line %d has no key" % [scene_id, beat_i, line_i])
	var line: Dictionary = {"key": key}
	var speaker: String = str(row.get("speaker", "")).strip_edges()
	if not speaker.is_empty():
		line["speaker"] = speaker
	var staged: String = StageDirection.parse_line(
		row, line, "scenes: %s beat %d line %d" % [scene_id, beat_i, line_i])
	if not staged.is_empty():
		return _fail(staged)
	return line


static func _fail(message: String) -> String:
	push_error(message)
	return message
