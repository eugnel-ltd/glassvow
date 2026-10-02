class_name LeadlightTokens
extends RefCounted
## Leadlight: the one interface kit (docs/design/2026-10-02-opening-start §8).
## Named for the leaded window — every surface in Glassvow is glass held in
## lead. This file is the single home of the design tokens. `RunStyle` and
## `GlassStyle` keep their constant names as aliases of these, so a screen that
## never heard of Leadlight renders exactly as it did.
##
## The values are the shipped ones, unchanged. Two families were authored
## apart and differ on purpose — the run screens' warm text and ink, and the
## combat glass's cool text and panel body — so both are kept, named for what
## they are rather than merged.
##
## The flame's colours are not copied here: `LanternFlame.COLOUR` owns them.

# --- night -----------------------------------------------------------------
const VOID: Color = Color("#05070e")
## The run screens' ink (RunStyle.INK).
const INK: Color = Color("#0b0e1a")
## The combat glass's panel body (GlassStyle.INK).
const GLASS_INK: Color = Color(0.10, 0.12, 0.19)
const FOG: Color = Color("#141a2e")
## The came between panes: darker than any ink, so a lead line reads on all.
const LEAD: Color = Color("#04050b")
const NIGHT_TOP: Color = Color(0.07, 0.08, 0.15)
const NIGHT_MID: Color = Color(0.035, 0.045, 0.095)
const NIGHT_BOT: Color = Color(0.015, 0.02, 0.045)

# --- light -----------------------------------------------------------------
const GOLD: Color = Color("#f2c14e")
const GOLD_DIM: Color = Color("#9c7c34")
const EMBER: Color = Color(1.0, 0.60, 0.30)
const GLASS: Color = Color(0.56, 0.82, 1.0)
const PARCHMENT: Color = Color("#e8dfc8")
## Run-screen text (RunStyle.TEXT / TEXT_DIM).
const TEXT: Color = Color("#d7dcea")
const TEXT_DIM: Color = Color("#8b93ad")
## Combat-glass text (GlassStyle.TEXT / TEXT_DIM): a cooler, brighter pair.
const GLASS_TEXT: Color = Color(0.86, 0.90, 1.0)
const GLASS_TEXT_DIM: Color = Color(0.58, 0.64, 0.80)
const DANGER: Color = Color("#ff8d8d")
const HP_RED: Color = Color(0.85, 0.33, 0.32)

# --- glass -----------------------------------------------------------------
const PANEL: Color = Color(0.055, 0.071, 0.133, 0.86)
const PANEL_LINE: Color = Color(GOLD, 0.28)
## Unlit glass: the indigo a pane holds when no light is behind it.
const GLASS_COLD_TOP: Color = Color(0.102, 0.129, 0.251, 0.92)
const GLASS_COLD_BOTTOM: Color = Color(0.051, 0.067, 0.141, 0.94)
## The gold-dim line inside every lead came.
const LEAD_LINE: Color = Color(GOLD_DIM, 0.55)

# --- spacing and radii -----------------------------------------------------
const SPACE: Array[int] = [4, 8, 12, 16, 24, 32, 48, 64]
const RADIUS_PANE: int = 14
const RADIUS_CONTROL: int = 12
const LEAD_W: float = 2.0

# --- type ------------------------------------------------------------------
## The roles. Each names its Latin face, the zh-Hant face its fallback chain
## carries, and its tracking in em for each script. Faces always come through
## `GlassStyle.face()`, so the CJK and symbol chain is never bypassed.
const ROLE_PRIMARY: StringName = &"primary"
const ROLE_LABEL: StringName = &"label"
const ROLE_CARVED: StringName = &"carved"
const ROLE_READ: StringName = &"read"
const ROLES: Dictionary = {
	ROLE_PRIMARY: {"latin": "res://assets/fonts/Cinzel-700.woff2",
		"cjk": "res://assets/fonts/NotoSerifTC-Black.woff2", "em": 0.16, "em_zh": 0.42},
	ROLE_LABEL: {"latin": "res://assets/fonts/Cinzel-500.woff2",
		"cjk": "res://assets/fonts/NotoSerifTC-SemiBold.woff2", "em": 0.14, "em_zh": 0.30},
	ROLE_CARVED: {"latin": "res://assets/fonts/Cinzel-700.woff2",
		"cjk": "res://assets/fonts/NotoSerifTC-SemiBold.woff2", "em": 0.32, "em_zh": 0.36},
	ROLE_READ: {"latin": "res://assets/fonts/Alegreya-400.woff2",
		"cjk": "res://assets/fonts/NotoSerifTC-Regular.woff2", "em": 0.0, "em_zh": 0.04},
}
## Sizes per shape class, pad first then phone. Nothing interactive drops
## below 11px on a phone; the floor for any text is 10px.
const SIZE_PLAQUE: Vector2i = Vector2i(24, 17)
const SIZE_PANE: Vector2i = Vector2i(15, 12)
const SIZE_WORD: Vector2i = Vector2i(15, 12)
const SIZE_CARVED: Vector2i = Vector2i(14, 11)
const SIZE_READ: Vector2i = Vector2i(16, 14)
const SIZE_CAPTION: Vector2i = Vector2i(12, 10)
const PHONE_FLOOR: int = 10

static var _fonts: Dictionary = {}


## Whether text on screen is set in zh-Hant, which tracks wider.
static func is_zh() -> bool:
	return Locale.active != null and Locale.active.code == Locale.CODE_ZH_HANT


## A role's face at a pixel size, tracked for the active script. Cached.
static func font(role: StringName, px: int) -> FontVariation:
	var zh: bool = is_zh()
	var key: String = "%s|%d|%s" % [role, px, zh]
	if _fonts.has(key):
		return _fonts[key]
	var spec: Dictionary = ROLES.get(role, ROLES[ROLE_READ])
	var variation: FontVariation = FontVariation.new()
	variation.base_font = GlassStyle.face(str(spec["latin"]), str(spec["cjk"]))
	variation.spacing_glyph = tracking(role, px, zh)
	_fonts[key] = variation
	return variation


## Tracking in whole pixels: em × size, rounded. Pure, so tests pin it.
static func tracking(role: StringName, px: int, zh: bool) -> int:
	var spec: Dictionary = ROLES.get(role, ROLES[ROLE_READ])
	var em: float = spec["em_zh" if zh else "em"]
	return roundi(float(px) * em)


## A size token for a shape: pad and desktop take the first, phone the second.
static func size_for(token: Vector2i, shape: StringName) -> int:
	return token.y if is_phone(shape) else token.x


static func is_phone(shape: StringName) -> bool:
	return shape == &"phone-landscape"


## The lead came as a stylebox border: dark lead with a gold-dim inner line is
## drawn by components; a StyleBoxFlat carries the outer lead only.
static func glass_box(lit: bool, radius: int = 0, margin: Vector2 = Vector2(18.0, 8.0)) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(GOLD, 0.16) if lit else GLASS_COLD_BOTTOM
	box.set_border_width_all(2)
	box.border_color = Color(GOLD, 0.70) if lit else LEAD_LINE
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin.x
	box.content_margin_right = margin.x
	box.content_margin_top = margin.y
	box.content_margin_bottom = margin.y
	return box
