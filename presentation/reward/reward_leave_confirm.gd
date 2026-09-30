class_name RewardLeaveConfirm
extends ColorRect
## "Leave rewards behind?" — asked when the player walks on with the offering
## still unanswered, because an offer walked past is gone for good.
##
## Built from `RewardScreen`'s own placard, heading and buttons, so the rows
## screen and the embers can never disagree about what that question looks
## like. Staying is the safe answer, so it is where the keyboard starts.

## `leave` true: walk on without the offering. False: back to the reward.
signal answered(leave: bool)

var _stay: Button = null


func _init(width: float) -> void:
	color = GlassStyle.scrim()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = GlassStyle.theme()
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.custom_minimum_size.x = width - RewardScreen.PANEL_PAD * 2.0
	body.add_child(RewardScreen._heading(Locale.active.t("ui.reward.leaveConfirmTitle")))
	body.add_child(RewardScreen._hairline())
	body.add_child(RewardScreen._spacer(6.0))
	var sub: Label = RewardScreen._sub_label(Locale.active.t("ui.reward.leaveConfirmBody"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	body.add_child(RewardScreen._spacer(20.0))
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	body.add_child(actions)
	var leave: Button = RewardScreen._button(
		Locale.active.t("ui.reward.leaveConfirmYes"), RewardScreen.GO_DANGER)
	leave.pressed.connect(answered.emit.bind(true))
	actions.add_child(leave)
	_stay = RewardScreen._button(
		Locale.active.t("ui.reward.leaveConfirmNo"), RewardScreen.GO_GHOST)
	_stay.pressed.connect(answered.emit.bind(false))
	actions.add_child(_stay)
	centre.add_child(RewardScreen._glass_panel(body))


func _ready() -> void:
	_stay.grab_focus()
