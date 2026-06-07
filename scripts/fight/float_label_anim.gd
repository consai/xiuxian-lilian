class_name FloatLabelAnim
extends Control

@export var rise_px: float = 60.0
@export var duration: float = 1.2
@export var fade_in_frac: float = 0.15
@export var fade_out_frac: float = 0.3

@onready var _label: Label = $Label

var _style_applied: bool = false


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
	var alpha := float(style.get("alpha", 1.0))
	modulate = Color(modulate.r, modulate.g, modulate.b, alpha)
	_style_applied = true


func play() -> void:
	if _label == null:
		_label = get_node_or_null("Label") as Label
	# 先缓存目标 alpha，避免在 modulate.a 被置零后又以它作为目标值
	#（否则 Tween 会把透明度缓慢“从 0 到 0”，导致一直不可见）。
	var target_alpha := modulate.a if _style_applied else 1.0
	modulate.a = 0.0
	var start_y := position.y
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var fade_in := maxf(0.05, duration * fade_in_frac)
	var fade_out := maxf(0.08, duration * fade_out_frac)
	var hold := maxf(0.0, duration - fade_in - fade_out)
	BattleDebugLog.write("飘字", "FloatLabelAnim.play", {"text": (_label.text if _label != null else ""), "target_alpha": target_alpha})
	tw.tween_property(self, "modulate:a", target_alpha, fade_in)
	tw.parallel().tween_property(self, "position:y", start_y - rise_px, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(self, "modulate:a", 0.0, fade_out)
	tw.tween_callback(queue_free)
