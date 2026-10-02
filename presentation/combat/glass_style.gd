class_name GlassStyle
extends RefCounted
## Shared procedural palette + stylebox factory for the combat screen. No art,
## no deps — every surface is a StyleBoxFlat / GradientTexture2D tuned to the
## stained-glass night-lantern key: deep indigo ground, pale glass-blue facets,
## ember lantern-fire. Pure factory (RefCounted, static) so the presentation
## layer stays a thin skin over the domain.

## Aliases of the Leadlight tokens (presentation/ui/leadlight_tokens.gd), the
## one home of these values since 2026-10-02. The names stay for every caller.
const NIGHT_TOP: Color = LeadlightTokens.NIGHT_TOP
const NIGHT_MID: Color = LeadlightTokens.NIGHT_MID
const NIGHT_BOT: Color = LeadlightTokens.NIGHT_BOT
const GLASS: Color = LeadlightTokens.GLASS      # #8fd0ff facet blue
const EMBER: Color = LeadlightTokens.EMBER      # #ff9a4d lantern fire
const GOLD: Color = LeadlightTokens.GOLD        # lantern gold (RunStyle.GOLD)
const INK: Color = LeadlightTokens.GLASS_INK    # panel body
const TEXT: Color = LeadlightTokens.GLASS_TEXT
const TEXT_DIM: Color = LeadlightTokens.GLASS_TEXT_DIM
const HP_RED: Color = LeadlightTokens.HP_RED


## The benchmark's two faces (roguecardv2@6e069118): Cinzel for display —
## names, cost numerals — and Alegreya for the reading text. Both stay the Latin
## primaries. Noto Serif TC is the complete zh-Hant chain: Regular for reading,
## SemiBold for names/headings, Black for the act plate, then a three-glyph Noto
## Sans Symbols2 subset for the two locale markers and the ticket spelling.
## The lightest weight the benchmark loads, and the one a rule that names no
## `font-weight` lands on: CSS matching for a desired 400 checks 500 before it
## checks anything heavier, and 400 is not in the set. `.enemy .name` is such a
## rule, so a foe's name is 500 on screen and was 700 in this port.
const CINZEL_500: String = "res://assets/fonts/Cinzel-500.woff2"
const CINZEL_700: String = "res://assets/fonts/Cinzel-700.woff2"
const CINZEL_800: String = "res://assets/fonts/Cinzel-800.woff2"
const ALEGREYA_400: String = "res://assets/fonts/Alegreya-400.woff2"
const ALEGREYA_700: String = "res://assets/fonts/Alegreya-700.woff2"
const NOTO_SERIF_TC_REGULAR: String = "res://assets/fonts/NotoSerifTC-Regular.woff2"
const NOTO_SERIF_TC_SEMIBOLD: String = "res://assets/fonts/NotoSerifTC-SemiBold.woff2"
const NOTO_SERIF_TC_BLACK: String = "res://assets/fonts/NotoSerifTC-Black.woff2"
const NOTO_SANS_SYMBOLS_2: String = "res://assets/fonts/NotoSansSymbols2-Glassvow.woff2"

static var _faces: Dictionary = {}


static func _is_serif_tc(path: String) -> bool:
	return path == NOTO_SERIF_TC_REGULAR or path == NOTO_SERIF_TC_SEMIBOLD \
		or path == NOTO_SERIF_TC_BLACK


static func _symbol_face() -> Font:
	var cache_key: String = "symbols"
	if _faces.has(cache_key):
		return _faces[cache_key]
	var symbols: Font = load(NOTO_SANS_SYMBOLS_2) as Font
	_faces[cache_key] = symbols
	return symbols


## Build the CJK/symbol leaf once. Every primary face points at this leaf, so
## its marker glyphs cannot fall through to an OS-specific system font.
static func _serif_tc_face(path: String) -> Font:
	var cache_key: String = "serif:" + path
	if _faces.has(cache_key):
		return _faces[cache_key]
	var serif: Font = load(path) as Font
	var symbols: Font = _symbol_face()
	if serif == null or symbols == null:
		_faces[cache_key] = serif if serif != null else symbols
		return _faces[cache_key]
	var chained: Font = serif.duplicate() as Font
	if chained == null:
		_faces[cache_key] = serif
		return serif
	var chain: Array[Font] = [symbols]
	chained.fallbacks = chain
	_faces[cache_key] = chained
	return chained


## Reading routes to Regular. Display paths (Cinzel plus bold Alegreya) route
## to SemiBold; transition_layer.gd explicitly requests Black for its act plate.
static func _cjk_fallback_for(path: String) -> String:
	if path == ALEGREYA_400 or path == NOTO_SERIF_TC_REGULAR:
		return NOTO_SERIF_TC_REGULAR
	if path == NOTO_SERIF_TC_BLACK:
		return NOTO_SERIF_TC_BLACK
	return NOTO_SERIF_TC_SEMIBOLD


## Load a Latin face with its deterministic serif/symbol fallback leaf. Cached
## by both primary and CJK paths because the same Latin weight has three CJK
## roles: reading, headings, and the act-plate display.
static func face(path: String, cjk_path: String = "") -> Font:
	var resolved_cjk_path: String = cjk_path if not cjk_path.is_empty() else _cjk_fallback_for(path)
	var cache_key: String = path + "|" + resolved_cjk_path
	if _faces.has(cache_key):
		return _faces[cache_key]
	if _is_serif_tc(path):
		var serif: Font = _serif_tc_face(path)
		_faces[cache_key] = serif
		return serif
	var primary: Font = load(path) as Font
	var serif_fallback: Font = _serif_tc_face(resolved_cjk_path)
	var symbols: Font = _symbol_face()
	if primary == null:
		_faces[cache_key] = serif_fallback
		return serif_fallback
	if serif_fallback == null:
		_faces[cache_key] = primary
		return primary
	var chained: Font = primary.duplicate() as Font
	if chained == null:
		_faces[cache_key] = primary
		return primary
	var chain: Array[Font] = [serif_fallback]
	if symbols != null:
		chain.append(symbols)
	chained.fallbacks = chain
	_faces[cache_key] = chained
	return chained


## Canonical modal veil — flat (no blur; backbuffer budget). Shared by Help,
## Settings, reward overlays, and ChoiceScreen overlay mode. RunMenu keeps a
## transparent hit-catcher; it is not a veil. The grain above is deliberately
## not frozen with the world beneath: a held screen must not read as a still.
static func scrim() -> Color:
	return Color(5.0 / 255.0, 7.0 / 255.0, 16.0 / 255.0, 0.72)


## Floating glass placard: translucent ink body, faint accent rim, soft glow.
static func pane(accent: Color, alpha: float = 0.80) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.14)
	sb.shadow_size = 10
	return sb


## `.stat-cell` (styles.css:1813): a flat white-tinted cell with NO
## shadow. The end screens' grids sat on gold panes whose 10px glows stacked
## in the 6px gutters — a lattice of bright seams the benchmark never draws.
static func stat_cell() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.045)
	sb.set_border_width_all(1)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


## Small rounded pill (intent / ward / status).
static func chip(fill: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, 0.18)
	sb.set_border_width_all(1)
	sb.border_color = Color(fill.r, fill.g, fill.b, 0.72)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## Bright circular gem for the card cost corner.
static func gem(fill: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, 0.95)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.35)
	sb.shadow_color = Color(fill.r, fill.g, fill.b, 0.45)
	sb.shadow_size = 6
	return sb


## The lantern ring — the one keyboard-focus treatment every glass surface
## shares. `draw_center = false` so it lays OVER whichever state box is
## showing without repainting it; the ring is the leading, the glow is the
## lantern behind it. Expanded 2px so it reads as an addition around the
## control, not a swap of its border. The glow outbids the hover box's own
## (0.35 @ 8px) so the persistent keyboard state is never out-glowed by
## the transient pointer state.
##
## ADOPTION PREREQUISITE: a surface that pushes its own "focus" stylebox
## shadows this ring entirely — an opaque focus box repainting the hover
## wash away is exactly the SettingsPanel focus≡hover defect. To adopt,
## DELETE "focus" from your state loop and let this overlay carry it.
static func focus_ring(accent: Color = GOLD, body_radius: int = 12) -> StyleBoxFlat:
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(2)
	ring.border_color = Color(accent, 0.85)
	# Concentric with the CONTROL it rings: the ring rides a rect expanded
	# 2px, so its radius is the adopter's own body radius plus that — a
	# fixed 14 sat ON the corner of every radius-6-8 adopter (DL, PR #43).
	ring.set_corner_radius_all(body_radius + 2)
	ring.set_expand_margin_all(2.0)
	ring.shadow_color = Color(accent, 0.45)
	ring.shadow_size = 8
	return ring


static func style_button(btn: Button, fill: Color) -> void:
	btn.add_theme_stylebox_override("focus", focus_ring(fill))
	var states: PackedStringArray = PackedStringArray(["normal", "hover", "pressed", "disabled"])
	for state: String in states:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		var a: float = 0.24
		if state == "hover":
			a = 0.38
		elif state == "pressed":
			a = 0.15
		elif state == "disabled":
			a = 0.07
		sb.bg_color = Color(fill.r, fill.g, fill.b, a)
		sb.set_border_width_all(1)
		var rim: float = 0.25 if state == "disabled" else 0.7
		sb.border_color = Color(fill.r, fill.g, fill.b, rim)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(10)
		if state == "hover":
			sb.shadow_color = Color(fill.r, fill.g, fill.b, 0.35)
			sb.shadow_size = 8
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)
	# Unset, these fall back to Godot's neutral defaults (0.95 grey and pure
	# white) — a focused or pressed button would shed the glass ink exactly
	# while it is selected.
	btn.add_theme_color_override("font_focus_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", TEXT)


static func style_bar(bar: ProgressBar, fill: Color) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	bg.set_corner_radius_all(5)
	bg.set_border_width_all(1)
	bg.border_color = Color(fill.r, fill.g, fill.b, 0.28)
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)


static func grad_tex(colors: PackedColorArray, offsets: PackedFloat32Array,
		radial: bool, from: Vector2, to: Vector2) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 256
	tex.height = 256
	return tex


## Lantern grabber shared by HSlider / VSlider. Settings used to paint this
## per-instance; the canonical Theme carries it so a raw slider is never gray.
static func disc(colour: Color, alpha: float = 1.0, size: int = 16) -> GradientTexture2D:
	var texture: GradientTexture2D = grad_tex(
		PackedColorArray([Color(colour, alpha), Color(colour, alpha * 0.45),
			Color(colour, 0.0)]),
		PackedFloat32Array([0.0, 0.52, 1.0]), true,
		Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	texture.width = size
	texture.height = size
	return texture


## Canonical Theme from RunStyle / GlassStyle tokens. Applied on Main; every
## routed Control inherits it. Per-instance helpers still override geometry
## (compact radius, primary CTA, card seats) — they do not fork the palette.
static func theme() -> Theme:
	return LeadlightTheme.build()
