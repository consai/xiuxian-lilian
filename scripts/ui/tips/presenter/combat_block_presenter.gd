extends RefCounted
class_name CombatBlockPresenter

var _last_key: String = ""
var _last_ms: int = -10000
var _serial: int = 0
var _active_tweens: Dictionary = {}
var _base_positions: Dictionary = {}


func present_tip(intent: Dictionary) -> Dictionary:
	var text := str(intent.get("text", "")).strip_edges()
	if text == "":
		return {"ok": false, "reason_code": "empty_text"}
	var label := _resolve_block_label()
	if label == null:
		return {"ok": false, "reason_code": "block_label_missing"}
	var context: Dictionary = intent.get("context", {})
	var ctx := context as Dictionary if context is Dictionary else {}
	var slot_type := str(ctx.get("slot_type", ""))
	var index := int(ctx.get("index", -1))
	var reason_code := str(ctx.get("reason_code", ""))
	var key := "%s:%d:%s" % [slot_type, index, reason_code]
	var now := Time.get_ticks_msec()
	var min_gap_ms := int(intent.get("throttle_ms", 700))
	if key == _last_key and now - _last_ms < min_gap_ms:
		return {"ok": true}
	_last_key = key
	_last_ms = now
	_serial += 1
	var serial := _serial
	var lid := label.get_instance_id()
	var base_pos := _ensure_base_position(label)
	_kill_active_tween(lid)
	label.text = text
	label.visible = true
	label.position = base_pos + Vector2(0.0, 12.0)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var hide_after_ms := int(intent.get("ttl_ms", 900))
	var tree := label.get_tree()
	if tree == null:
		return {"ok": false, "reason_code": "scene_tree_missing"}
	var total_sec := maxf(0.25, float(hide_after_ms) / 1000.0)
	var fade_in := clampf(total_sec * 0.15, 0.06, 0.14)
	var fade_out := clampf(total_sec * 0.34, 0.12, 0.32)
	var hold := maxf(0.0, total_sec - fade_in - fade_out)
	var tw := tree.create_tween()
	_active_tweens[lid] = tw
	tw.set_parallel(true)
	tw.tween_property(label, "modulate:a", 1.0, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", base_pos.y - 18.0, total_sec).from(base_pos.y + 12.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain()
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(label, "modulate:a", 0.0, fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if serial != _serial or not is_instance_valid(label):
			return
		label.visible = false
		label.position = base_pos
		_active_tweens.erase(lid)
	)
	return {"ok": true}


func _resolve_block_label() -> Label:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var scene := SceneManager.get_active_scene()
	if scene == null:
		return null
	return scene.get_node_or_null("%block_reason_tip") as Label


func _ensure_base_position(label: Label) -> Vector2:
	var lid := label.get_instance_id()
	if _base_positions.has(lid):
		return _base_positions[lid]
	var p := label.position
	_base_positions[lid] = p
	return p


func _kill_active_tween(label_id: int) -> void:
	var tw: Tween = _active_tweens.get(label_id, null)
	if tw != null:
		tw.kill()
	_active_tweens.erase(label_id)
