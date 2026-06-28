class_name LiandanPiliangTanchuang
extends Control

signal confirmed(batch_count: int)
signal cancelled

@onready var _summary_label: Label = %SummaryLabel
@onready var _count_label: Label = %CountLabel
@onready var _count_slider: HSlider = %CountSlider
@onready var _max_button: Button = %MaxButton
@onready var _cancel_button: TextureButton = %CancelButton
@onready var _confirm_button: TextureButton = %ConfirmButton

var _days_per_batch := 1
var _duration_per_batch := "1日"


func _ready() -> void:
	visible = false
	_count_slider.value_changed.connect(_on_slider_value_changed)
	_max_button.pressed.connect(_on_max_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func open(preview: Dictionary, max_batch: int) -> void:
	var recipe := preview.get("recipe", {}) as Dictionary
	var recipe_name := str(recipe.get("name", "丹方"))
	_days_per_batch = maxi(1, int(preview.get("days", 1)))
	_duration_per_batch = str(preview.get("duration_label", GameState.time_duration_label(_days_per_batch)))
	var safe_max := maxi(1, max_batch)
	_count_slider.min_value = 1.0
	_count_slider.max_value = float(safe_max)
	_count_slider.step = 1.0
	_count_slider.value = 1.0
	_max_button.disabled = safe_max <= 1
	_summary_label.text = (
		"%s\n每炉 %s · 最多可炼 %d 炉"
	) % [recipe_name, _duration_per_batch, safe_max]
	_update_count_display(1)
	visible = true


func close_popup() -> void:
	visible = false


func _update_count_display(count: int) -> void:
	var total_days := count * _days_per_batch
	_count_label.text = "%d 炉（共 %s）" % [count, GameState.time_duration_label(total_days)]


func _on_slider_value_changed(value: float) -> void:
	_update_count_display(int(round(value)))


func _on_max_pressed() -> void:
	_count_slider.value = _count_slider.max_value


func _on_cancel_pressed() -> void:
	close_popup()
	cancelled.emit()


func _on_confirm_pressed() -> void:
	var batch_count := int(round(_count_slider.value))
	close_popup()
	confirmed.emit(batch_count)
