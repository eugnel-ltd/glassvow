class_name PrivacyPolicy
extends RefCounted
## Where the public privacy policy lives, one address per language. These are
## the permanent URLs entered as the App Store Connect Privacy Policy URLs
## (docs/privacy/README.md, section 3); they are compiled into every build, so
## they change only together with that section and the site.

const URL_EN: String = "https://glassvow.eugnel.com/privacy/"
const URL_ZH_HANT: String = "https://glassvow.eugnel.com/privacy/zh-hant/"


## The policy in the language the player is reading: Traditional Chinese for
## `zh-Hant`, English for every other code.
static func url_for(language: StringName) -> String:
	return URL_ZH_HANT if language == Locale.CODE_ZH_HANT else URL_EN
