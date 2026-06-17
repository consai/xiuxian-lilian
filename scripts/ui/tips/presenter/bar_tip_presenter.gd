extends RefCounted
class_name BarTipPresenter

const TipIntentScript := preload("res://scripts/ui/tips/core/tip_intent.gd")

const BAR_TTL_MS := 2000
const DISMISS_AFTER_MS := 200

const _TONE_COLORS := {
	TipIntentScript.TONE_GAIN: Color(0.22, 0.52, 0.28, 1.0),
	TipIntentScript.TONE_LOSS: Color(0.72, 0.22, 0.18, 1.0),
	TipIntentScript.TONE_NEUTRAL: Color(0.33, 0.2, 0.18, 1.0),
}

var _root: Control
var _label: Label
var _active_tween: Tween
var _serial: int = 0
var _click_dismiss_enabled: bool = false
var _dismiss_handler: Callable


func setup(bar_root: Control) -> void:
	_root = bar_root
	_label = bar_root.get_node_or_null("%TipLabel") as Label
	_dismiss_handler = Callable(self, "_on_tip_gui_input")
	if _root != null:
		_root.visible = false
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not _root.gui_input.is_connected(_dismiss_handler):
			_root.gui_input.connect(_dismiss_handler)


func present_tip(intent: Dictionary) -> Dictionary:
	if _root == null or _label == null:
		return {"ok": false, "reason_code": "bar_missing"}
	var text := str(intent.get("text", "")).strip_edges()
	if text == "":
		return {"ok": false, "reason_code": "empty_text"}
	var tone := str(intent.get("tone", TipIntentScript.TONE_NEUTRAL))
	_label.text = text
	_label.add_theme_color_override(
		"font_color",
		_TONE_COLORS.get(tone, _TONE_COLORS[TipIntentScript.TONE_NEUTRAL])
	)
	_serial += 1
	var serial := _serial
	_click_dismiss_enabled = false
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tree := _root.get_tree()
	if tree == null:
		return {"ok": false, "reason_code": "scene_tree_missing"}
	var ttl_ms := int(intent.get("ttl_ms", BAR_TTL_MS))
	var total_sec := clampf(float(ttl_ms) / 1000.0, 1.0, 8.0)
	var fade_in := clampf(total_sec * 0.1, 0.08, 0.16)
	var fade_out := clampf(total_sec * 0.12, 0.1, 0.2)
	var hold := maxf(0.0, total_sec - fade_in - fade_out)
	var tw := tree.create_tween()
	_active_tween = tw
	tw.tween_property(_root, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain()
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(_root, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if serial != _serial or not is_instance_valid(_root):
			return
		_finish_tip()
	)
	tree.create_timer(float(DISMISS_AFTER_MS) / 1000.0).timeout.connect(func() -> void:
		if serial != _serial or not is_instance_valid(_root) or not _root.visible:
			return
		_click_dismiss_enabled = true
	, CONNECT_ONE_SHOT)
	return {"ok": true}


func _on_tip_gui_input(event: InputEvent) -> void:
	if not _click_dismiss_enabled or _root == null or not _root.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_dismiss_current_tip()


func _dismiss_current_tip() -> void:
	_serial += 1
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
	_finish_tip()


func _finish_tip() -> void:
	_click_dismiss_enabled = false
	if not is_instance_valid(_root):
		return
	_root.visible = false
	_root.modulate = Color.WHITE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_tween = null
