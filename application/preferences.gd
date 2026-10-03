class_name Preferences
extends RefCounted
## Player-facing settings persisted at user://settings.cfg — audio (Master/
## Music/SFX), display (fullscreen, vsync), motion (screen shake, reduce
## motion), privacy (crash diagnostics) and cosmetics (the card back).
## Supersedes the audio-only user://audio.cfg: its values are imported once,
## the first time this file is created, and never re-read.
##
## `active` is the main-owned handle (SKILL §2: no autoloads). Main replaces
## it with the disk-backed instance at boot; the default is an in-memory
## instance holding the same defaults, so labs and tests that never boot main
## read sane values and can never write the player's real settings file.

const PATH: String = "user://settings.cfg"
const LEGACY_AUDIO_PATH: String = "user://audio.cfg"

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Music"
const SFX: StringName = &"SFX"

const DEFAULT_MASTER: float = 1.0
const DEFAULT_MUSIC: float = 0.35
const DEFAULT_SFX: float = 0.55

## Crash diagnostics are on unless the player switches them off (posture B,
## docs/privacy/README.md). The main loop reads the same key through
## `read_diagnostics_enabled`, so the two can never name different places.
const PRIVACY_SECTION: String = "privacy"
const DIAGNOSTICS_KEY: String = "diagnostics_enabled"
const DIAGNOSTICS_NOTICE_KEY: String = "diagnostics_notice_seen"
const DEFAULT_DIAGNOSTICS: bool = true

## The card back the player chose (CardBacks). Additive: an older build reading
## the file ignores the section.
const COSMETICS_SECTION: String = "cosmetics"
const CARD_BACK_KEY: String = "card_back"

static var active: Preferences = Preferences.new()

var master_volume: float = DEFAULT_MASTER
var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false

var fullscreen: bool = false
var vsync: bool = true
var screen_shake: bool = true
var reduce_motion: bool = false
## Empty = derive from OS (`zh*` → zh-Hant, else en). Explicit `en` / `zh-Hant`
## overrides. Persisted under [locale] language.
var language: String = ""
## Whether Sentry starts. The main loop reads it from settings.cfg before Main
## loads Preferences, so a change takes effect on the next launch.
var diagnostics_enabled: bool = DEFAULT_DIAGNOSTICS
## Whether the one-line diagnostics notice has been shown.
var diagnostics_notice_seen: bool = false
## The chosen card back's id, stored as given; empty = never chosen. Never
## validated here: CardBacks.chosen() owns the catalogue and the unlocks, and
## resolves an empty, unknown or locked id to the default back.
var card_back: String = ""

## Only the instance read from disk writes back to disk; the default `active`
## stand-in stays in memory whatever a lab does to it.
var _persistent: bool = false
var _path: String = PATH


static func read_from_disk(path: String = PATH,
		legacy_audio_path: String = LEGACY_AUDIO_PATH) -> Preferences:
	var preferences: Preferences = Preferences.new()
	preferences._path = path
	preferences._persistent = true
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) == OK:
		preferences._read(config)
	else:
		# First boot on the new file: carry the old audio.cfg choices over,
		# then store immediately so the import happens exactly once —
		# settings.cfg owns every key from here on.
		preferences._import_legacy(legacy_audio_path)
		preferences._store()
	preferences.apply_audio()
	return preferences


## The main loop's read. Sentry starts before Main loads Preferences, so this
## reads the one key straight from the file and has no other effect: it never
## creates the file, imports audio.cfg or touches the audio buses.
static func read_diagnostics_enabled(path: String = PATH) -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return DEFAULT_DIAGNOSTICS
	return _diagnostics_value(config)


func volume(bus: StringName) -> float:
	match bus:
		MASTER: return master_volume
		MUSIC: return music_volume
		SFX: return sfx_volume
	return 1.0


func is_muted(bus: StringName) -> bool:
	match bus:
		MASTER: return master_muted
		MUSIC: return music_muted
		SFX: return sfx_muted
	return false


func set_volume(bus: StringName, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	match bus:
		MASTER: master_volume = clamped
		MUSIC: music_volume = clamped
		SFX: sfx_volume = clamped
		_:
			push_warning("preferences: unknown bus '%s'" % bus)
			return
	_apply_bus(bus)
	_store()


func set_muted(bus: StringName, value: bool) -> void:
	match bus:
		MASTER: master_muted = value
		MUSIC: music_muted = value
		SFX: sfx_muted = value
		_:
			push_warning("preferences: unknown bus '%s'" % bus)
			return
	_apply_bus(bus)
	_store()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_display()
	_store()


func set_vsync(on: bool) -> void:
	vsync = on
	apply_display()
	_store()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_store()


func set_reduce_motion(on: bool) -> void:
	reduce_motion = on
	_store()


func set_language(code: String) -> void:
	language = code
	_store()


func set_diagnostics_enabled(on: bool) -> void:
	diagnostics_enabled = on
	_store()


func set_card_back(id: String) -> void:
	card_back = id
	_store()


func mark_diagnostics_notice_seen() -> void:
	if diagnostics_notice_seen:
		return
	diagnostics_notice_seen = true
	_store()


## Resolves the catalogue code Preferences wants Locale to load.
func effective_language() -> StringName:
	return resolve_language(language, OS.get_locale_language())


## Pure resolver: an explicit player choice wins; otherwise the OS language
## selects Traditional Chinese for any zh locale and English for everything else.
static func resolve_language(saved: String, os_language: String) -> StringName:
	if saved == "en" or saved == "zh-Hant":
		return StringName(saved)
	if os_language.begins_with("zh"):
		return Locale.CODE_ZH_HANT
	return Locale.CODE_EN


func apply_audio() -> void:
	_apply_bus(MASTER)
	_apply_bus(MUSIC)
	_apply_bus(SFX)


## Window mode is applied only where main decides the window is the player's
## (a plain boot) — capture rigs and labs own their windows and never call
## this, so a saved fullscreen choice cannot hijack a screenshot run.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _read(config: ConfigFile) -> void:
	master_volume = _volume_value(
		config.get_value("audio", "master_volume", DEFAULT_MASTER), DEFAULT_MASTER)
	music_volume = _volume_value(
		config.get_value("audio", "music_volume", DEFAULT_MUSIC), DEFAULT_MUSIC)
	sfx_volume = _volume_value(
		config.get_value("audio", "sfx_volume", DEFAULT_SFX), DEFAULT_SFX)
	master_muted = _bool_value(config.get_value("audio", "master_muted", false), false)
	music_muted = _bool_value(config.get_value("audio", "music_muted", false), false)
	sfx_muted = _bool_value(config.get_value("audio", "sfx_muted", false), false)
	fullscreen = _bool_value(config.get_value("display", "fullscreen", false), false)
	vsync = _bool_value(config.get_value("display", "vsync", true), true)
	screen_shake = _bool_value(config.get_value("motion", "screen_shake", true), true)
	reduce_motion = _bool_value(
		config.get_value("motion", "reduce_motion", false), false)
	language = str(config.get_value("locale", "language", ""))
	diagnostics_enabled = _diagnostics_value(config)
	diagnostics_notice_seen = _bool_value(
		config.get_value(PRIVACY_SECTION, DIAGNOSTICS_NOTICE_KEY, false), false)
	var back: Variant = config.get_value(COSMETICS_SECTION, CARD_BACK_KEY, "")
	card_back = back if back is String else ""


func _import_legacy(legacy_audio_path: String) -> void:
	var legacy: ConfigFile = ConfigFile.new()
	if legacy.load(legacy_audio_path) != OK:
		return
	music_volume = _volume_value(
		legacy.get_value("music", "volume", DEFAULT_MUSIC), DEFAULT_MUSIC)
	sfx_volume = _volume_value(
		legacy.get_value("sfx", "volume", DEFAULT_SFX), DEFAULT_SFX)
	music_muted = _bool_value(legacy.get_value("music", "muted", false), false)
	sfx_muted = _bool_value(legacy.get_value("sfx", "muted", false), false)


static func _volume_value(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		return clampf(str(value).to_float(), 0.0, 1.0)
	return fallback


static func _bool_value(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	return fallback


static func _diagnostics_value(config: ConfigFile) -> bool:
	return _bool_value(config.get_value(PRIVACY_SECTION, DIAGNOSTICS_KEY, DEFAULT_DIAGNOSTICS),
		DEFAULT_DIAGNOSTICS)


func _apply_bus(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("preferences: missing bus '%s'" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume(bus), 0.0001)))
	AudioServer.set_bus_mute(index, is_muted(bus))


func _store() -> void:
	if not _persistent:
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "master_muted", master_muted)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("motion", "screen_shake", screen_shake)
	config.set_value("motion", "reduce_motion", reduce_motion)
	config.set_value("locale", "language", language)
	config.set_value(PRIVACY_SECTION, DIAGNOSTICS_KEY, diagnostics_enabled)
	config.set_value(PRIVACY_SECTION, DIAGNOSTICS_NOTICE_KEY, diagnostics_notice_seen)
	config.set_value(COSMETICS_SECTION, CARD_BACK_KEY, card_back)
	var error: Error = config.save(_path)
	if error != OK:
		push_warning("preferences: could not save (%s)" % error_string(error))
