class_name GlassvowMainLoop
extends SceneTree
## Inits Sentry before the main scene, unless the player has switched crash
## diagnostics off in Settings. Auto Init is off so `before_send` can attach;
## `_initialize()` is still earlier than any game script.


## Numeric iOS CFBundleVersion. Must match both iOS export presets'
## `application/version` and `sentry/options/dist`. Not the marketing
## version (`application/config/version` / `application/short_version`).
const IOS_BUILD_NUMBER: String = "17"

var _privacy: SentryPrivacy = SentryPrivacy.new()


func _initialize() -> void:
	if OS.has_feature("editor"):
		return
	start_if_enabled(func() -> void: SentrySDK.init(_configure))


## Runs `start` unless the player has switched crash diagnostics off, and says
## whether it ran. Sentry starts before Main loads Preferences, so the choice
## is read from the settings file itself and a change waits for the next
## launch. Tests pass their own `start` and file, so no suite run can start
## the real SDK.
static func start_if_enabled(start: Callable,
		settings_path: String = Preferences.PATH) -> bool:
	if not Preferences.read_diagnostics_enabled(settings_path):
		return false
	start.call()
	return true


func _configure(options: SentryOptions) -> void:
	options.release = "io.fol2.glassvow@{app_version}"
	options.dist = IOS_BUILD_NUMBER
	options.before_send = _before_send


func _before_send(event: SentryEvent) -> SentryEvent:
	if event.get_environment().contains("editor"):
		return null
	var i: int = 0
	var n: int = event.get_exception_count()
	while i < n:
		event.set_exception_value(i, SentryPrivacy.redact(event.get_exception_value(i)))
		i += 1
	event.set_message(SentryPrivacy.redact(event.get_message()))
	if not event.is_crash():
		var key: String = event.get_exception_value(0) + "\n" + event.get_message()
		if SentryPrivacy.is_known_noise(key) or not _privacy.allow_nonfatal(key):
			return null
	return event
