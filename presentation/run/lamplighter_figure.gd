class_name LamplighterFigure
extends Control
## The Hollow Lamplighter at the head of the road, lit as stagecraft: his
## portrait (assets/art/portraits/lamplighter-<mood>.png), a warm rim where the
## hero's lantern catches his edge, a cool backlight from the door behind him
## and a little light on the road at his feet. The rim and the backlight
## breathe; under Reduce Motion they hold. Draw-only, input-blind. A new mood
## cross-fades in.

const PORTRAIT: String = "res://assets/art/portraits/lamplighter-%s.png"
const RIM: Color = Color(1.0, 0.64, 0.32)
## Where the hero's lantern stands relative to him: its light lands on this
## side of his silhouette (+1 right, -1 left).
var light_side: float = 1.0
var mood: StringName = &""
var _rim: TextureRect
var _figure: TextureRect
var _time: float = 0.0
var _swap: Tween


func _init(start_mood: StringName = &"recognising") -> void:
	name = "LamplighterFigure"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim = _layer()
	_rim.name = "Rim"
	_rim.modulate = Color(RIM, 0.62)
	_figure = _layer()
	_figure.name = "Figure"
	# Stage-lit: the figure a little under the light that catches his rim.
	_figure.modulate = Color(0.84, 0.84, 0.9, 1.0)
	set_mood(start_mood, true)


func _layer() -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(rect)
	return rect


## Show `next` (recognising, asking, urgent, wary): a quick cross-fade, or at
## once outside a tree, under Reduce Motion or when `instant`.
func set_mood(next: StringName, instant: bool = false) -> void:
	if next == mood:
		return
	mood = next
	var texture: Texture2D = load(PORTRAIT % String(next)) as Texture2D
	if instant or not is_inside_tree() or LeadlightMotion.reduced():
		_rim.texture = texture
		_figure.texture = texture
		return
	if _swap != null and _swap.is_valid():
		_swap.kill()
	_swap = create_tween()
	_swap.tween_property(_figure, "modulate:a", 0.0, LeadlightMotion.QUICK)
	_swap.parallel().tween_property(_rim, "modulate:a", 0.0, LeadlightMotion.QUICK)
	_swap.tween_callback(func() -> void:
		_rim.texture = texture
		_figure.texture = texture)
	_swap.tween_property(_figure, "modulate:a", 1.0, LeadlightMotion.SETTLE)
	_swap.parallel().tween_property(_rim, "modulate:a", 0.62, LeadlightMotion.SETTLE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_seat()


func _ready() -> void:
	_seat()


func _seat() -> void:
	_figure.position = Vector2.ZERO
	_figure.size = size
	_rim.size = size
	_place_rim()
	queue_redraw()


## The warm silhouette sits a few pixels toward the light, so only its edge
## shows past the figure: the rim the lantern lights.
func _place_rim() -> void:
	var reach: float = maxf(2.0, size.x * 0.007) * (1.0 + 0.35 * LeadlightMotion.breath(_time, 3.6))
	_rim.position = Vector2(reach * light_side, -reach * 0.35)


func _process(delta: float) -> void:
	if LeadlightMotion.reduced():
		return
	_time += delta
	_place_rim()
	queue_redraw()


func _draw() -> void:
	var disc: Texture2D = SkyField.disc()
	var breath: float = LeadlightMotion.breath(_time, 5.2)
	# The door behind him: a cool backlight round the head and shoulders.
	var back_r: float = size.x * 0.48 * (1.0 + 0.05 * breath)
	var head: Vector2 = Vector2(size.x * 0.5, size.y * 0.24)
	draw_texture_rect(disc, Rect2(head - Vector2(back_r, back_r), Vector2(back_r, back_r) * 2.0), false,
		Color(LeadlightTokens.GLASS, 0.13 * (1.0 + 0.2 * breath)))
	# The road at his feet, warm from the hero's lantern.
	var feet: Vector2 = Vector2(size.x * (0.5 + 0.08 * light_side), size.y * 0.95)
	var pool: Vector2 = Vector2(size.x * 0.46, size.y * 0.06)
	draw_texture_rect(disc, Rect2(feet - pool, pool * 2.0), false,
		Color(RIM, 0.22 * (1.0 + 0.15 * breath)))
