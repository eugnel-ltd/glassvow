extends RefCounted
## Settings retain forward-compatible fields and the accepted privacy choice
## when a real write fails. The child alone receives the file-size limit.


static func run(fails: Array[String]) -> void:
	var path: String = "user://test_preferences_atomic_%d.cfg" % OS.get_process_id()
	var config: ConfigFile = ConfigFile.new()
	config.set_value("privacy", "diagnostics_enabled", false)
	config.set_value("motion", "screen_shake", true)
	config.set_value("audio", "future_bus", 0.75)
	config.set_value("future", "options", {"enabled": true, "levels": [1, 2, 3]})
	if config.save(path) != OK:
		fails.append("preferences atomic: could not seed accepted settings")
		return
	if not SaveService.store_vigil(VigilState.blank(), path + ".json"):
		fails.append("preferences atomic: could not seed accepted JSON")
		return
	if OS.get_name() in ["Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		var output: Array = []
		var status: int = OS.execute("/bin/sh", PackedStringArray([
			ProjectSettings.globalize_path("res://tests/support/preferences_write_failure.sh"),
			OS.get_executable_path(), "--headless", "--path",
			ProjectSettings.globalize_path("res://"), "-s",
			"res://tests/support/preferences_write_failure.gd", "--",
			ProjectSettings.globalize_path(path),
		]), output, true)
		var log: String = "\n".join(output)
		if status != 0 or not log.contains("preferences write failure: PASS"):
			fails.append("preferences atomic: child exited %d\n%s" % [status, log])
	else:
		print("preferences write failure: skipped (requires POSIX ulimit)")
	# The healthy setter check starts from its own accepted fixture.
	config.save(path)
	var preferences: Preferences = Preferences.read_from_disk(path, path + ".legacy")
	preferences.set_volume(Preferences.MUSIC, 0.42)
	preferences.set_screen_shake(false)
	preferences.set_language("zh-Hant")
	var loaded: ConfigFile = ConfigFile.new()
	if loaded.load(path) != OK:
		fails.append("preferences atomic: healthy settings did not load")
	else:
		if loaded.get_value("audio", "future_bus", 0.0) != 0.75 \
				or loaded.get_value("future", "options", {}) != config.get_value("future", "options"):
			fails.append("preferences atomic: setter discarded unknown ConfigFile keys")
		if loaded.get_value("audio", "music_volume") != 0.42 \
				or loaded.get_value("motion", "screen_shake") != false \
				or loaded.get_value("locale", "language") != "zh-Hant":
			fails.append("preferences atomic: healthy setters did not roundtrip")
	if Preferences.read_diagnostics_enabled(path):
		fails.append("preferences atomic: healthy setter changed diagnostics opt-out")
	for candidate: String in [path, path + ".tmp", path + ".probe",
			path + ".json", path + ".json.tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
