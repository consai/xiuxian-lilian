extends RefCounted
class_name RewardTipPresenter

const TipIntentScript := preload("res://scripts/ui/tips/core/tip_intent.gd")
const RewardTipLineScene := preload("res://scenes/ui/components/reward_tip_line.tscn")
const ItemIconResolverScript := preload(
	"res://scripts/features/inventory/presentation/item_icon_resolver.gd"
)

const DEFAULT_TTL_MS := 1600

const _MAX_ROWS_BY_CHANNEL := {
	TipIntentScript.CHANNEL_REWARD_ITEM: 4,
	TipIntentScript.CHANNEL_REWARD_GROWTH: 5,
	TipIntentScript.CHANNEL_REWARD_RESOURCE: 3,
}

const _CHANNEL_TO_LANE := {
	TipIntentScript.CHANNEL_REWARD_ITEM: "ItemLane",
	TipIntentScript.CHANNEL_REWARD_GROWTH: "GrowthLane",
	TipIntentScript.CHANNEL_REWARD_RESOURCE: "ResourceLane",
}

const _TONE_COLORS := {
	EnumTipTone.LABEL_GAIN: Color(0.25, 0.48, 0.26, 1.0),
	EnumTipTone.LABEL_LOSS: Color(0.72, 0.22, 0.18, 1.0),
	EnumTipTone.LABEL_NEUTRAL: Color(0.33, 0.2, 0.18, 1.0),
}

var _root: Control


func setup(root: Control) -> void:
	_root = root
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func present_tip(intent: Dictionary) -> Dictionary:
	if _root == null:
		return {"ok": false, "reason_code": "reward_layer_missing"}
	var text := str(intent.get("text", "")).strip_edges()
	if text == "":
		return {"ok": false, "reason_code": "empty_text"}
	var lane := _lane_for(str(intent.get("channel", "")))
	if lane == null:
		return {"ok": false, "reason_code": "reward_lane_missing"}
	var channel := str(intent.get("channel", ""))
	_trim_lane(lane, int(_MAX_ROWS_BY_CHANNEL.get(channel, 4)))
	var row := RewardTipLineScene.instantiate() as Control
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.add_child(row)
	_apply_intent(row, intent, text)
	_play(row, intent)
	return {"ok": true}


func _lane_for(channel: String) -> VBoxContainer:
	var lane_name := str(_CHANNEL_TO_LANE.get(channel, ""))
	if lane_name == "":
		return null
	return _root.get_node_or_null("%" + lane_name) as VBoxContainer


func _trim_lane(lane: VBoxContainer, max_rows: int) -> void:
	while lane.get_child_count() >= max_rows:
		var child := lane.get_child(0)
		lane.remove_child(child)
		child.queue_free()


func _apply_intent(row: Control, intent: Dictionary, text: String) -> void:
	var label := row.get_node_or_null("%TextLabel") as Label
	if label != null:
		label.text = text
		var context := _context(intent)
		var color := _color_from_context(context)
		if color == Color.TRANSPARENT:
			color = _TONE_COLORS.get(
				str(intent.get("tone", EnumTipTone.LABEL_NEUTRAL)),
				_TONE_COLORS[EnumTipTone.LABEL_NEUTRAL]
			)
		label.add_theme_color_override("font_color", color)
	var icon := row.get_node_or_null("%Icon") as TextureRect
	if icon != null:
		var icon_path := str(_context(intent).get("icon_path", "")).strip_edges()
		icon.texture = ItemIconResolverScript.resolve(icon_path, icon.texture)
		icon.visible = icon.texture != null


func _play(row: Control, intent: Dictionary) -> void:
	row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	row.scale = Vector2(0.96, 0.96)
	# Defer pivot_offset to next frame to ensure the row has been laid out.
	row.set_deferred("pivot_offset", row.size * 0.5)
	var tree := row.get_tree()
	if tree == null:
		return
	var total_sec := clampf(float(int(intent.get("ttl_ms", DEFAULT_TTL_MS))) / 1000.0, 0.8, 4.0)
	var fade_in := clampf(total_sec * 0.12, 0.08, 0.16)
	var fade_out := clampf(total_sec * 0.18, 0.14, 0.28)
	var hold := maxf(0.0, total_sec - fade_in - fade_out)
	var tw := tree.create_tween()
	tw.set_parallel(true)
	tw.tween_property(row, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain()
	tw.set_parallel(false)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(row, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(row):
			row.queue_free()
	)


func _context(intent: Dictionary) -> Dictionary:
	var context_v: Variant = intent.get("context", {})
	return context_v as Dictionary if context_v is Dictionary else {}


func _color_from_context(context: Dictionary) -> Color:
	if context.has("color"):
		var color_v: Variant = context.get("color")
		if color_v is Color:
			return color_v as Color
	var quality := int(context.get("quality", 0))
	if quality > 0:
		return EnumQuality.get_color(quality)
	return Color.TRANSPARENT
