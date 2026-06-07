class_name CombatFloatLayer
extends CanvasLayer

const _FLOAT_LABEL_SCENE := preload("res://scenes/fight/float/float_label.tscn")

const _TONE_PRIORITY := {
	"buff_expire": 0,
	"mp_cost": 1,
	"skill": 2,
	"mp_gain": 3,
	"shield": 4,
	"heal": 5,
	"buff_add": 6,
	"damage": 7,
	"crit": 8,
}

var _styles_bundle: Dictionary = {}
var _frame_spawn_count: Dictionary = {} # unit_key -> count
var _last_frame: int = -1


func _ready() -> void:
	layer = 10
	follow_viewport_enabled = true
	_reload_styles()


func _reload_styles() -> void:
	_styles_bundle = JsonLoader.load_combat_float_styles()


func clear_all() -> void:
	for child in get_children():
		if child is Node:
			(child as Node).queue_free()
	_frame_spawn_count.clear()


func spawn(text: String, screen_pos: Vector2, tone: String, unit_key: String = "") -> void:
	var t := text.strip_edges()
	if t == "":
		return
	var styles_v: Variant = _styles_bundle.get("styles", {})
	if not styles_v is Dictionary:
		BattleDebugLog.write("飘字", "CombatFloatLayer.styles 为空", {})
		return
	var style: Dictionary = (styles_v as Dictionary).get(tone, {}) as Dictionary
	if style.is_empty():
		push_warning("CombatFloatLayer: unknown tone '%s'" % tone)
		BattleDebugLog.write("飘字", "CombatFloatLayer 未找到 tone 样式", {
			"tone": tone,
			"text": t,
		})
		return
	if not _consume_spawn_budget(unit_key, tone):
		BattleDebugLog.write("飘字", "CombatFloatLayer spawn 被节流", {
			"unit": unit_key,
			"tone": tone,
		})
		return
	var lane := _spawn_lane(unit_key)
	var inst := _FLOAT_LABEL_SCENE.instantiate() as FloatLabelAnim
	if inst == null:
		return
	var jitter := float(_styles_bundle.get("jitter_x", 18.0))
	var jitter_y := float(_styles_bundle.get("jitter_y", maxf(8.0, jitter * 0.45)))
	var lane_step_y := float(_styles_bundle.get("lane_step_y", 12.0))
	var rand_offset := Vector2(
		randf_range(-jitter, jitter),
		randf_range(-jitter_y, jitter_y)
	)
	# 同帧同单位的飘字按层错开，再叠加随机扰动，避免重叠成一团。
	var lane_offset := Vector2(0.0, -lane * lane_step_y)
	inst.position = screen_pos + lane_offset + rand_offset
	inst.apply_style(style)
	inst.apply_motion_config(_styles_bundle)
	inst.set_text(t)
	add_child(inst)
	BattleDebugLog.write("飘字", "CombatFloatLayer.spawn", {
		"unit": unit_key,
		"tone": tone,
		"text": t,
		"pos": screen_pos,
	})
	inst.call_deferred("play")


func _consume_spawn_budget(unit_key: String, tone: String) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _last_frame:
		_last_frame = frame
		_frame_spawn_count.clear()
	var key := unit_key if unit_key != "" else "_"
	var count := int(_frame_spawn_count.get(key, 0))
	var cap := int(_styles_bundle.get("max_per_unit_per_frame", 6))
	if count >= cap:
		# 已满时仍允许高优先级伤害类飘字
		if int(_TONE_PRIORITY.get(tone, 0)) < 7:
			return false
	_frame_spawn_count[key] = count + 1
	return true


func _spawn_lane(unit_key: String) -> int:
	var key := unit_key if unit_key != "" else "_"
	# _consume_spawn_budget 已经先 +1，这里取当前值 -1 作为 lane。
	return maxi(0, int(_frame_spawn_count.get(key, 1)) - 1)
