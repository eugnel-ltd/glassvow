class_name CardTurn
extends RefCounted
## Turning a card over (issue #657): the pose maths both renderers share, the
## two pieces they add to a card, the back the table wears, and the pre-warm
## that pays for them while a fight loads. CardView.turn is the one API.
##
## TWO RENDERERS, ONE POSE. A turn is a pose, `yaw` about the card's vertical
## axis (0 face up, 180 face down) and `pitch` about its horizontal one, and
## `pose()` turns it into the one Basis both renderers wear:
##
##   live     the slab turns in the card's own 3D stage, a back plate on its
##            far side (`plate`) wearing the table's back and lit by the card's
##            own lamp, so the finish answers the angle. The stage renders once
##            per pose: about 0.5 ms a card on the iPad 8 while it turns. For a
##            slow, single-card reveal, where the eye has time for the light.
##   picture  the stage stays frozen and its resting picture is warped on the
##            canvas (card_turn.gdshader, `picture`), the back drawn from the
##            table's baked back: nothing renders, and the material is a
##            still. For fast, many-card flights.
##
## Both cast the same rays through the same slab at the same pose, so they
## agree on the silhouette, on which face shows and on where the rim shows
## (tools/check_card_turn.gd measures it; the turn sheet, `--turns`, is the
## regression still). At rest nothing here exists on a card, and a card turned
## back to rest is exactly the card it was built as.
##
## THE TABLE'S BACK is the player's chosen back (CardBacks.chosen), baked.
## `prewarm` records it; `back()` hands its bake to whoever turns a card.
##
## PRE-WARMING. A turn's first use would otherwise compile shaders and bake a
## back mid-fight: on the iPad 8 the first bake after an install held one
## frame for 3.7 s, a procedural back's shader 0.5 s, and the picture turn's
## shader is new to the session too. `prewarm` pays all of it in the frame
## that builds the fight (see there), so none of it reaches the fight's frames.

const PICTURE_SHADER: Shader = preload("res://presentation/cards/card_turn.gdshader")
## The narrowest the table shadow gets, edge-on, as a share of the card.
const MIN_FOOTPRINT: float = 0.03
## How far beyond the slab's back face the plate sits, so the two never fight
## over depth, in card px.
const PLATE_GAP: float = 0.05

## The back the last pre-warm baked: the one the table wears.
static var _wearing: String = ""
## One plate mesh serves every card: a face's outline, the slab's own fan.
static var _plate_mesh: ArrayMesh = null


## The Basis a card wears at this pose, in the stage's axes (x right, y up, z
## toward the lens): the slab's own Euler angles, pitch about x and yaw about
## y, the order Node3D.rotation_degrees composes them in.
static func pose(yaw: float, pitch: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))


## Whether a pose is rest: the card as it was built.
static func is_rest(p: Basis) -> bool:
	return p.is_equal_approx(Basis.IDENTITY)


## The table shadow's scale under a card at this pose: the card's width and
## height as the light above the table sees them, never quite nothing.
static func footprint(p: Basis) -> Vector2:
	return Vector2(maxf(absf(p.x.x), MIN_FOOTPRINT), maxf(absf(p.y.y), MIN_FOOTPRINT))


## The bake of the back the table wears, or null before any pre-warm.
static func back() -> CardBacks.Baked:
	return CardBacks.cached(_wearing) if _wearing != "" else null


## The id of the back the table wears ("" before any pre-warm).
static func wearing() -> String:
	return _wearing


## The picture turn's material for a card of this thickness and side colour,
## showing `back` on its far face (null shows none). The pose is set with
## `set_pose`.
static func picture(back_bake: CardBacks.Baked, thick: float, side: Color) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = PICTURE_SHADER
	m.set_shader_parameter("back_tex", back_bake.stage if back_bake != null else null)
	m.set_shader_parameter("lens", CardView.lens())
	m.set_shader_parameter("rect", Vector2(CardView.CARD_W, CardView.CARD_H)
		+ Vector2(CardView.PAD_3D, CardView.PAD_3D) * 2.0)
	m.set_shader_parameter("half_card", Vector2(CardView.CARD_W, CardView.CARD_H) * 0.5)
	m.set_shader_parameter("radius", float(CardView.RADIUS))
	m.set_shader_parameter("thick", thick)
	m.set_shader_parameter("side", side)
	set_pose(m, Basis.IDENTITY)
	return m


static func set_pose(m: ShaderMaterial, p: Basis) -> void:
	m.set_shader_parameter("pose", p)


## The live turn's back plate for a slab of this thickness: the face's
## outline turned to look out of the slab's far side, wearing the bake's own
## face material (the back card's plate, over its baked face). Null without a
## bake. The plate is the slab's child, so it turns with it; seen from behind,
## its picture reads the right way round.
static func plate(back_bake: CardBacks.Baked, thick: float) -> MeshInstance3D:
	if back_bake == null or back_bake.plate == null:
		return null
	if _plate_mesh == null:
		_plate_mesh = CardView.face_fan(0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _plate_mesh
	mi.material_override = back_bake.plate.duplicate() as ShaderMaterial
	mi.position = Vector3(0.0, 0.0, -thick * 0.5 - PLATE_GAP)
	mi.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	return mi


## Pay for a fight's turns while it loads: bake the back the table wears,
## `id`, and draw the picture turn's shader once. A coroutine.
##
## Main calls it in the frame that builds the fight. The bake builds its back
## card hidden in that frame, so the back's picture shader and the slab's
## compile in that frame's draw, and it reads back straight after it
## (CardBacks.BAKE_FRAMES), before the next frame starts the entrance. The
## warmer, one transparent pixel wearing the picture turn's material, is drawn
## in the same frame and dropped on the next. The live turn needs no warmer of
## its own: its plate wears the card surface the fight's own cards compile in
## that same draw, on the same mesh layout.
##
## A later fight whose back is already baked pays a cached lookup and one
## transparent pixel. `host` is the fight; whatever is still in flight when it
## leaves goes with it.
static func prewarm(host: Node, id: String) -> void:
	_wearing = id
	var warmer: TextureRect = _warmer()
	host.add_child(warmer)
	var baked_already: bool = CardBacks.cached(id) != null
	var made: CardBacks.Baked = await CardBacks.bake(host, id)
	if not is_instance_valid(warmer):
		return
	if baked_already or made == null:
		# No frame was drawn for a bake: the warmer still has its frame to draw.
		if warmer.is_inside_tree():
			await warmer.get_tree().process_frame
		if is_instance_valid(warmer):
			warmer.queue_free()
		return
	# Drawn in the bake's frame, the warmer goes straight after it, as the
	# bake's card does.
	warmer.free()


## One transparent pixel wearing the picture turn's material: a TextureRect,
## as the card's own picture is, so its draw takes the same pipeline.
static func _warmer() -> TextureRect:
	var clear: Image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var tex: ImageTexture = ImageTexture.create_from_image(clear)
	var warmer: TextureRect = TextureRect.new()
	warmer.name = "CardTurnWarmer"
	warmer.texture = tex
	warmer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	warmer.stretch_mode = TextureRect.STRETCH_SCALE
	warmer.size = Vector2.ONE
	warmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = PICTURE_SHADER
	m.set_shader_parameter("back_tex", tex)
	warmer.material = m
	return warmer
