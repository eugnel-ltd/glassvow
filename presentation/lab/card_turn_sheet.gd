class_name CardTurnSheet
extends Control
## The turn sheet (issue #657): one card laid at a row of poses by both of
## CardView.turn's renderers, for every back in the catalogue. Each back gets
## two rows, the live turn over the picture turn, so the two can be compared
## down a column and the whole sheet against an earlier still. It is the
## turn's regression still
## (docs/design/2026-10-03-cards-real-objects/stills/14-turn-sheet-live-over-picture.jpg).
##
##   godot --path . -- --turns[=bastion]
##   tools/shot.sh --turns --vp=2916x1640 --settle=1 --shot=/tmp/turns.png
##
## The sheet is laid out on the 1458 x 820 desktop stage; a window twice that
## size draws it at twice the pixels (the stage stretch re-rasterises), which
## is how the still is taken.
##
## Every back is baked first and worn as the table's back (CardTurn.prewarm),
## as a fight's load does, so each row turns exactly as a fight's card would.
## The numbers behind the sheet (the two renderers' agreement at each pose,
## rest restored exactly) are tools/check_card_turn.gd's.

const BACKDROP: Color = Color(0.043, 0.055, 0.102)
const DEFAULT_CARD: String = "bastion"
## Columns: (yaw, pitch) in degrees. Rest, four poses through the turn with
## the flight's pitch toward the viewer, and face down.
const POSES: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(35.0, -10.0), Vector2(70.0, -10.0),
	Vector2(100.0, -10.0), Vector2(140.0, -10.0), Vector2(180.0, 0.0),
]
const MARGIN: float = 24.0
const LABEL_W: float = 118.0
const HEADER_H: float = 26.0

var content: ContentDB
var _card_id: String = DEFAULT_CARD
var _uid: int = 1


func _init(content_ref: ContentDB, card_id: String = "") -> void:
	content = content_ref
	if card_id != "":
		_card_id = card_id
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	var field: ColorRect = ColorRect.new()
	field.color = BACKDROP
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)


func _ready() -> void:
	await get_tree().process_frame
	var data: Dictionary = CardLab.load_catalog(content).get(_card_id, {})
	if data.is_empty():
		push_warning("turn sheet: no such card id: %s" % _card_id)
		data = CardLab.load_catalog(content).get(DEFAULT_CARD, {})
		_card_id = DEFAULT_CARD
	var stage: Vector2 = get_viewport().get_visible_rect().size
	var backs: Array[String] = CardBacks.catalogue().ids()
	var rows: int = backs.size() * 2
	var cell: Vector2 = Vector2(
		(stage.x - MARGIN * 2.0 - LABEL_W) / float(POSES.size()),
		(stage.y - MARGIN * 2.0 - HEADER_H) / float(rows))
	var k: float = minf((cell.x - 14.0) / CardView.CARD_W, (cell.y - 12.0) / CardView.CARD_H)
	for c: int in range(POSES.size()):
		var pose: Vector2 = POSES[c]
		_label("yaw %d°  pitch %d°" % [roundi(pose.x), roundi(pose.y)],
			Vector2(MARGIN + LABEL_W + cell.x * float(c), MARGIN), cell.x)
	for b: int in range(backs.size()):
		await CardTurn.prewarm(self, backs[b])
		for r: int in range(2):
			var live: bool = r == 0
			var y: float = MARGIN + HEADER_H + cell.y * float(b * 2 + r)
			_label("%s · %s" % [backs[b].capitalize(), "live" if live else "picture"],
				Vector2(MARGIN, y + cell.y * 0.4), LABEL_W)
			for c: int in range(POSES.size()):
				var card: CardView = _card(data)
				card.scale = Vector2.ONE * k
				# Scaled about its centre (CardView's pivot), so centring the
				# unscaled rect centres the card.
				card.position = Vector2(MARGIN + LABEL_W + cell.x * float(c), y) \
					+ (cell - card.size) * 0.5
				add_child(card)
				var pose: Vector2 = POSES[c]
				card.turn(pose.x, pose.y, live)


func _card(data: Dictionary) -> CardView:
	var cost_v: Variant = data.get("cost")
	var cost: int = 0 if cost_v == null else int(float(str(cost_v)))
	var card: CardView = CardView.new(CardInst.new(_uid, StringName(_card_id)), data, cost)
	_uid += 1
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _label(text: String, at: Vector2, width: float) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, 18.0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", GlassStyle.TEXT_DIM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
