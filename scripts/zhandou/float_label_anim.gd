class_name FloatLabelAnim
extends Control

@export var rise_px: float = 60.0
@export var duration: float = 1.2
@export var fade_in_frac: float = 0.15
@export var fade_out_frac: float = 0.3
@export var jelly_pop_frac: float = 0.38
@export var jelly_overshoot: float = 0.22
@export var arc_drift_ratio: float = 0.45
@export var arc_apex_min: float = 0.55
@export var arc_apex_max: float = 1.25

@onready var _label: Label = $Label

var _style_applied: bool = false
var _motion_cfg: Dictionary = {}


func set_text(t: String) -> void:
	if _label != null:
		_label.text = t
	elif has_node("Label"):
		($Label as Label).text = t


func apply_style(style: Dictionary) -> void:
	if _label == null:
		_label = get_node_or_null("Label") as Label
	if _label == null:
		return
	# 场景 Label 绑定了 label_settings，theme override 不会生效，须写入 LabelSettings。
	var ls: LabelSettings
	if _label.label_settings != null:
		ls = _label.label_settings.duplicate()
	else:
		ls = LabelSettings.new()
	var color_hex := str(style.get("color", "#FFFFFF")).strip_edges()
	if color_hex.begins_with("#") and color_hex.length() >= 7:
		ls.font_color = Color(color_hex)
	var font_size := int(style.get("font_size", 0))
	if font_size > 0:
		ls.font_size = font_size
	if bool(style.get("bold", false)):
		ls.outline_size = maxi(ls.outline_size, 12)
	_label.label_settings = ls
	rise_px = float(style.get("rise_px", rise_px))
	duration = maxf(0.2, float(style.get("duration", duration)))
	fade_in_frac = clampf(float(style.get("fade_in_frac", fade_in_frac)), 0.05, 0.5)
	fade_out_frac = clampf(float(style.get("fade_out_frac", fade_out_frac)), 0.1, 0.6)
	if style.has("arc_drift_ratio"):
		_motion_cfg["arc_drift_ratio"] = float(style.get("arc_drift_ratio"))
	if style.has("arc_apex_min"):
		_motion_cfg["arc_apex_min"] = float(style.get("arc_apex_min"))
	if style.has("arc_apex_max"):
		_motion_cfg["arc_apex_max"] = float(style.get("arc_apex_max"))
	var alpha := float(style.get("alpha", 1.0))
	modulate = Color(modulate.r, modulate.g, modulate.b, alpha)
	_style_applied = true


func apply_motion_config(bundle: Dictionary) -> void:
	for key in ["arc_drift_ratio", "arc_apex_min", "arc_apex_max"]:
		if bundle.has(key):
			_motion_cfg[key] = float(bundle[key])


func play() -> void:
	if _label == null:
		_label = get_node_or_null("Label") as Label
	_center_pivot_for_jelly()
	# 先缓存目标 alpha，避免在 modulate.a 被置零后又以它作为目标值
	#（否则 Tween 会把透明度缓慢“从 0 到 0”，导致一直不可见）。
	var target_alpha := modulate.a if _style_applied else 1.0
	modulate.a = 0.0
	scale = Vector2(0.12, 0.12)
	var start_pos := position
	var arc := _build_random_arc(start_pos)
	var fade_in := maxf(0.05, duration * fade_in_frac)
	var fade_out := maxf(0.08, duration * fade_out_frac)
	var hold := maxf(0.0, duration - fade_in - fade_out)
	var jelly_pop := clampf(duration * jelly_pop_frac, 0.18, fade_in + 0.28)
	var overshoot := 1.0 + jelly_overshoot
	ZhandouDebugLog.write("飘字", "FloatLabelAnim.play", {
		"text": (_label.text if _label != null else ""),
		"target_alpha": target_alpha,
		"arc_end": arc.get("end", Vector2.ZERO),
	})
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(self, "modulate:a", target_alpha, fade_in)
	_parabola_start = arc["start"] as Vector2
	_parabola_apex = arc["apex"] as Vector2
	_parabola_end = arc["end"] as Vector2
	tw.tween_method(_set_parabola_pos, 0.0, 1.0, duration)
	var scale_tw := create_tween()
	scale_tw.tween_property(self, "scale", Vector2(overshoot * 1.08, 1.0 / overshoot), jelly_pop * 0.26)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(self, "scale", Vector2(1.0 / overshoot, overshoot * 1.06), jelly_pop * 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	scale_tw.tween_property(self, "scale", Vector2(overshoot * 1.03, 1.0 / overshoot), jelly_pop * 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tw.tween_property(self, "scale", Vector2.ONE, jelly_pop * 0.34)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_subtween(scale_tw)
	tw.set_parallel(false)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(self, "modulate:a", 0.0, fade_out)
	tw.tween_callback(queue_free)


func _center_pivot_for_jelly() -> void:
	if _label == null:
		return
	_label.reset_size()
	var sz := _label.size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = _label.get_minimum_size()
	pivot_offset = _label.position + sz * 0.5


var _parabola_start := Vector2.ZERO
var _parabola_apex := Vector2.ZERO
var _parabola_end := Vector2.ZERO


func _motion_f(key: String, fallback: float) -> float:
	return float(_motion_cfg.get(key, fallback))


func _build_random_arc(start_pos: Vector2) -> Dictionary:
	var drift_ratio := _motion_f("arc_drift_ratio", arc_drift_ratio)
	var apex_min := _motion_f("arc_apex_min", arc_apex_min)
	var apex_max := _motion_f("arc_apex_max", arc_apex_max)
	var drift_x := randf_range(-rise_px * drift_ratio, rise_px * drift_ratio)
	var end_pos := Vector2(start_pos.x + drift_x, start_pos.y - rise_px)
	var apex_t := randf_range(0.28, 0.72)
	var apex_pos := Vector2(
		start_pos.x + drift_x * apex_t + randf_range(-rise_px * 0.12, rise_px * 0.12),
		start_pos.y - rise_px * randf_range(apex_min, apex_max)
	)
	return {
		"start": start_pos,
		"apex": apex_pos,
		"end": end_pos,
	}


func _set_parabola_pos(t: float) -> void:
	var u := 1.0 - t
	position = (
		u * u * _parabola_start
		+ 2.0 * u * t * _parabola_apex
		+ t * t * _parabola_end
	)
