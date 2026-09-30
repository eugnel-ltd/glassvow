extends RefCounted
## #415 in-app privacy link: Settings carries one enabled "Privacy policy"
## button in PRIVACY, and pressing it hands the system browser the policy for
## the language on screen. The panel is given a recorder instead of
## `OS.shell_open`, so no suite run opens a browser.

const README_PATH: String = "res://docs/privacy/README.md"

## Pinned literally: these are the App Store Connect values, and the app
## cannot change them after release.
const EXPECTED: Dictionary = {
	"en": "https://glassvow.eugnel.com/privacy/",
	"zh-Hant": "https://glassvow.eugnel.com/privacy/zh-hant/",
}

const COPY: Dictionary = {
	"ui.settings.privacyPolicy": ["Privacy Policy", "私隱政策"],
}


static func _check(fails: Array[String], ok: bool, what: String) -> void:
	if not ok:
		fails.append("privacy_policy_link: %s" % what)


static func run(fails: Array[String]) -> void:
	_resolver(fails)
	_addresses_match_the_hosting_note(fails)
	_row_opens_the_policy_for_each_language(fails)
	_focus_order(fails)
	_catalogue_copy(fails)


## Pure resolver: each language gets its own page, and anything that is not
## Traditional Chinese falls back to English.
static func _resolver(fails: Array[String]) -> void:
	for code: String in EXPECTED:
		_check(fails, PrivacyPolicy.url_for(StringName(code)) == str(EXPECTED[code]),
			"%s resolved to %s" % [code, PrivacyPolicy.url_for(StringName(code))])
	_check(fails, PrivacyPolicy.url_for(&"fr") == str(EXPECTED["en"]),
		"an unknown language did not fall back to English")
	_check(fails, PrivacyPolicy.url_for(&"") == str(EXPECTED["en"]),
		"an empty language did not fall back to English")


## The README section 3 table is where the store values are recorded; the
## compiled addresses and that table must not drift apart.
static func _addresses_match_the_hosting_note(fails: Array[String]) -> void:
	var note: String = FileAccess.get_file_as_string(README_PATH)
	_check(fails, not note.is_empty(), "could not read %s" % README_PATH)
	for code: String in EXPECTED:
		_check(fails, note.contains("`%s`" % EXPECTED[code]),
			"%s is not the address recorded in docs/privacy/README.md" % EXPECTED[code])


## Built through the production panel in both languages: the row exists, is
## enabled and visible, and its press opens exactly the language's address, once.
static func _row_opens_the_policy_for_each_language(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	var index: int = 0
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		Locale.active = Locale.new(code)
		var opened: Array[String] = []
		var panel: SettingsPanel = SettingsPanel.new(Preferences.new())
		panel.open_url = func(url: String) -> int:
			opened.append(url)
			return OK
		var link: Button = panel.find_child("PrivacyPolicyButton", true, false) as Button
		_check(fails, link != null, "%s: no privacy policy button in Settings" % code)
		if link != null:
			_check(fails, not link.disabled, "%s: the privacy policy button is disabled" % code)
			_check(fails, link.visible, "%s: the privacy policy button is hidden" % code)
			_check(fails, link.text == str(COPY["ui.settings.privacyPolicy"][index]).to_upper(),
				"%s: the button reads %s" % [code, link.text])
			link.pressed.emit()
			_check(fails, opened.size() == 1 and opened[0] == str(EXPECTED[str(code)]),
				"%s: pressing opened %s, wanted %s" % [code, opened, EXPECTED[str(code)]])
		panel.free()
		index += 1
	Locale.active = previous


## The keyboard and pad walk the panel in tree order: the diagnostics switch,
## then the policy, then ERASE, then CLOSE. The button must take focus and sit
## in the PRIVACY section, not be appended out of order.
static func _focus_order(fails: Array[String]) -> void:
	var previous: Locale = Locale.active
	Locale.active = Locale.new(Locale.CODE_EN)
	var panel: SettingsPanel = SettingsPanel.new(Preferences.new())
	var focusable: Array[Button] = []
	_collect_buttons(panel, focusable)
	var link: Button = panel.find_child("PrivacyPolicyButton", true, false) as Button
	var switch_row: Node = panel.find_child("DiagnosticsRow", true, false)
	var switch_button: Button = null
	if switch_row != null:
		for child: Node in switch_row.get_children():
			if child is Button:
				switch_button = child as Button
	var at: int = focusable.find(link)
	_check(fails, link != null and link.focus_mode == Control.FOCUS_ALL,
		"the privacy policy button cannot take focus")
	_check(fails, at > 0 and focusable[at - 1] == switch_button,
		"the diagnostics switch does not come immediately before the policy button")
	_check(fails, at >= 0 and at + 1 < focusable.size() - 1
			and focusable[at + 1].text == Locale.active.t("ui.settings.eraseAll").to_upper(),
		"ERASE does not follow the policy button")
	panel.free()
	Locale.active = previous


static func _collect_buttons(node: Node, into: Array[Button]) -> void:
	if node is Button:
		into.append(node as Button)
	for child: Node in node.get_children():
		_collect_buttons(child, into)


## Through the production lookup, so a zh key missing from its catalogue
## (which would fall back to English) fails here too.
static func _catalogue_copy(fails: Array[String]) -> void:
	var index: int = 0
	for code: StringName in [Locale.CODE_EN, Locale.CODE_ZH_HANT]:
		var catalogue: Locale = Locale.new(code)
		for key: String in COPY:
			_check(fails, catalogue.t(key) == str(COPY[key][index]),
				"%s drifted in %s" % [key, code])
		index += 1
