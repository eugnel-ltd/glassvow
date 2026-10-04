class_name MusicBus
extends Node
## Two-player loop/crossfade layer matching the benchmark's Music Cue contract.

const DIR: String = "res://assets/audio/music/%s.mp3"
## Same-scene alternates: cue -> context -> the stems that may answer it. A cue
## or context absent from the file plays the `FILES` default.
const VARIANTS_PATH: String = "res://assets/audio/music/variants.json"
## Act IV is act index 3. It is the authored five-node Mirrored Road
## (`WorldMap.ACT4_TYPES`), not the fifteen-row map, so its boss is node 5.
const ACT4_INDEX: int = 3
## `VigilState.commit_run` records the best waystone as act * 15 + lit.
const WAYSTONES_PER_ACT: int = 15
const CROSSFADE: float = 0.8
## The cues of the road and the hall resume where they stopped when they come
## back in a session (docs/design/2026-10-03-title-rooms §7 item 14): the
## title's track no longer starts over after the Vigil. A fight's, a stinger's
## and the map's cues still start from their top.
const RESUMES: Array[StringName] = [&"title", &"vigil", &"roseWindow"]
const SILENT_DB: float = -60.0
const FILES: Dictionary[StringName, String] = {
	&"title": "title",
	&"embark": "embark",
	&"vigil": "vigil",
	&"roseWindow": "rose-window",
	&"map": "map",
	&"safeNodes": "safe-nodes",
	&"act1Combat": "act1-combat",
	&"act1Boss": "act1-boss",
	&"act2Combat": "act2-combat",
	&"act2Boss": "act2-boss",
	&"act3Combat": "act3-combat",
	&"act3Boss": "act3-boss",
	&"act4Combat": "act4-combat",
	&"act4Boss": "act4-boss",
	&"elite": "elite",
	&"paleOnes": "pale-ones",
	&"shadeDuel": "shade-duel",
	&"usurper": "usurper",
	&"eighthOmen": "eighth-omen",
	&"unreadablePage": "unreadable-page",
	&"hollowLamplighter": "hollow-lamplighter",
	&"sealedDoor": "sealed-door",
	&"victory": "victory",
	&"defeat": "defeat",
}

static var _variants: Dictionary = {}
static var _variants_loaded: bool = false

var current_cue: StringName = &""
## The file stem the last `play` actually started, for logs and tests.
var current_stem: String = ""

## Engine-side RNG owned by the bus, never the run's seeded RNG, so choosing a
## track cannot disturb replayable game truth (same rule as `SfxBus`).
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _context: StringName = &""

var _players: Array[AudioStreamPlayer] = []
## Where each resuming stem stopped this session, in seconds.
var _positions: Dictionary = {}
## The stem each player holds paused: a resuming cue that gives way keeps its
## player paused, so coming back is an unpause, never a seek. An MP3 seek scans
## the track from its top: on the iPad 8 the title's return cost its tap frame
## about 100 ms (#655 PR C's device rows). The position above is the fallback
## when the paused player has been taken by a third cue.
var _held: Array[String] = ["", ""]
var _active: int = 0
var _fade: Tween = null


func _init() -> void:
	name = "MusicBus"
	_rng.randomize()
	if DisplayServer.get_name() == "headless":
		return
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Player%d" % (index + 1)
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		_players.append(player)
		add_child(player)


## Which alternates may answer a combat cue. Act IV elites draw from the held
## combat takes; a return to the Act IV boss within the same Vigil hears the
## second take. `vigil` is read, never written.
static func combat_context(kind: String, act_index: int, vigil: VigilState) -> StringName:
	if act_index != ACT4_INDEX:
		return &""
	if kind == "elite":
		return &"elite"
	if kind == "boss" and boss_met_before(vigil):
		return &"return"
	return &""


## True once this Vigil has reached the Act IV boss in an earlier run: the
## best waystone ever lit covers the boss node (node 5 of the Mirrored Road),
## which a run lights on entering it, so a loss to the boss counts. A win does not: a run without six shards
## ends after Act III and never meets this boss. Existing Vigil data only.
static func boss_met_before(vigil: VigilState) -> bool:
	if vigil == null:
		return false
	var best: int = int(float(str(vigil.deeds.get("bestWaystone", 0))))
	return best >= ACT4_INDEX * WAYSTONES_PER_ACT + WorldMap.ACT4_TYPES.size()


## The file stem a play of `cue` in `context` would use: the default, or one
## allowed alternate drawn at random.
func resolve(cue: StringName, context: StringName = &"") -> String:
	var pool: Array[String] = _pool(cue, context)
	if pool.is_empty():
		return str(FILES.get(cue, ""))
	return pool[_rng.randi_range(0, pool.size() - 1)]


## Every stem that can answer `cue` in any context, the default first.
func variants_of(cue: StringName) -> Array[String]:
	var stems: Array[String] = []
	if FILES.has(cue):
		stems.append(FILES[cue])
	var contexts: Dictionary = _contexts_of(cue)
	for context_key: Variant in contexts:
		for stem: String in _pool(cue, StringName(str(context_key))):
			if not stems.has(stem):
				stems.append(stem)
	return stems


static func _variants_data() -> Dictionary:
	if _variants_loaded:
		return _variants
	_variants_loaded = true
	var file: FileAccess = FileAccess.open(VARIANTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("music: no variants file at %s" % VARIANTS_PATH)
		return _variants
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var root: Dictionary = parsed
		var cues: Variant = root.get("cues", {})
		if typeof(cues) == TYPE_DICTIONARY:
			_variants = cues
	return _variants


func _contexts_of(cue: StringName) -> Dictionary:
	var entry: Variant = _variants_data().get(str(cue), {})
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var entry_dict: Dictionary = entry
	var contexts: Variant = entry_dict.get("contexts", {})
	if typeof(contexts) != TYPE_DICTIONARY:
		return {}
	var contexts_dict: Dictionary = contexts
	return contexts_dict


func _pool(cue: StringName, context: StringName) -> Array[String]:
	var stems: Array[String] = []
	var raw: Variant = _contexts_of(cue).get(str(context), [])
	if typeof(raw) != TYPE_ARRAY:
		return stems
	for stem_v: Variant in raw:
		stems.append(str(stem_v))
	return stems


func play(cue: StringName, context: StringName = &"") -> void:
	if _players.is_empty():
		return
	if cue == current_cue and context == _context and _players[_active].playing:
		return
	if not FILES.has(cue):
		push_warning("music: unknown cue '%s'" % cue)
		return
	var stem: String = resolve(cue, context)
	var path: String = DIR % stem
	var outgoing: AudioStreamPlayer = _players[_active]
	var outgoing_index: int = _active
	var incoming_index: int = 1 - _active
	var incoming: AudioStreamPlayer = _players[incoming_index]
	var resumes: bool = RESUMES.has(cue) and _held[incoming_index] == stem and incoming.stream != null
	var stream: AudioStream = null
	if not resumes:
		if not ResourceLoader.exists(path):
			push_warning("music: no track for '%s'" % cue)
			return
		stream = looped(path)
		if stream == null:
			return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_remember(outgoing)
	_held[incoming_index] = ""
	if resumes:
		# Where it paused: no seek.
		incoming.volume_db = SILENT_DB
		incoming.stream_paused = false
	else:
		incoming.stop()
		incoming.stream_paused = false
		incoming.stream = stream
		incoming.volume_db = SILENT_DB
		incoming.play(resume_at(_positions, cue, stem, stream.get_length()))
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming, "volume_db", 0.0, CROSSFADE)
	if outgoing.playing and not outgoing.stream_paused:
		var keep: bool = RESUMES.has(current_cue) and not current_stem.is_empty()
		var kept_stem: String = current_stem
		_fade.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE)
		_fade.chain().tween_callback(func() -> void:
			if keep:
				outgoing.stream_paused = true
				_held[outgoing_index] = kept_stem
			else:
				outgoing.stop()
				outgoing.stream = null
		)
	_active = incoming_index
	current_cue = cue
	current_stem = stem
	_context = context
	if not OS.get_environment("GLASSVOW_MUSIC_LOG").is_empty():
		print("music: cue=%s context=%s stream=%s" % [cue, context, path])


## The track at `path`, looping: the loaded (cached) stream itself, looped in
## place. Only this bus plays these files and it loops every one, so nothing
## needs an unlooped copy, and a copy is costly: duplicating an MP3 re-reads
## the whole file (2 to 3 ms on the M1; about 10 ms of the Vigil's first tap
## frame on the iPad 8, #655 PR C), even when the warm has loaded it ahead.
static func looped(path: String) -> AudioStream:
	var stream: AudioStream = load(path) as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


## The files `cues` play by default, for a warm that loads them ahead.
static func paths(cues: Array[StringName]) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cue: StringName in cues:
		if FILES.has(cue):
			out.append(DIR % FILES[cue])
	return out


## Where a play of `stem` for `cue` starts: where it stopped this session if
## the cue resumes, else its top. Pure.
static func resume_at(positions: Dictionary, cue: StringName, stem: String, length: float) -> float:
	if not RESUMES.has(cue) or not positions.has(stem):
		return 0.0
	var at: float = positions[stem]
	return fposmod(at, length) if length > 0.0 else 0.0


## The stem `player` is playing, remembered where it is, when its cue resumes.
func _remember(player: AudioStreamPlayer) -> void:
	if player.playing and RESUMES.has(current_cue) and not current_stem.is_empty():
		_positions[current_stem] = player.get_playback_position()


func stop() -> void:
	if not _players.is_empty():
		_remember(_players[_active])
	current_cue = &""
	_context = &""
	if _players.is_empty():
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var outgoing: AudioStreamPlayer = _players[_active]
	if not outgoing.playing:
		return
	_fade = create_tween()
	_fade.tween_property(outgoing, "volume_db", SILENT_DB, CROSSFADE)
	_fade.tween_callback(func() -> void:
		outgoing.stop()
		outgoing.stream = null
	)
