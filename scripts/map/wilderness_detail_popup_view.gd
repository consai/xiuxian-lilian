extends Control

signal enter_requested(region_id: String, options: Dictionary)
signal closed

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _enter_button: TextureButton = %EnterButton
@onready var _close_button: TextureButton = %CloseButton
@onready var _min_option: OptionButton = %MinDifficultyOption
@onready var _max_option: OptionButton = %MaxDifficultyOption

var _region_id := ""
var _location_bounds := {"min": 1, "max": 1}


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_enter_button.pressed.connect(_on_enter_pressed)
	%Dimmer.gui_input.connect(_on_dimmer_input)
	_min_option.item_selected.connect(_on_min_changed)
	_max_option.item_selected.connect(_on_max_changed)


func show_region(
	region_id: String,
	region_data: Dictionary,
	exploration: int,
	can_enter: bool,
	block_reason: String,
	location_bounds: Dictionary
) -> void:
	_region_id = region_id
	_location_bounds = location_bounds
	_title.text = str(region_data.get("name", region_id))
	var env_tags := ", ".join((region_data.get("environment_tags", []) as Array).map(func(v): return str(v)))
	var rewards := ", ".join((region_data.get("preview_rewards", []) as Array).map(func(v): return str(v)))
	_body.text = "危险：%s星\n推荐境界：%s\n环境：%s\n\n可能收获：%s\n探索度：%d%%\n\n野外区域没有固定路线，进入后可自由探索。" % [
		_star_label(maxi(1, int(region_data.get("danger", 1)))),
		str(region_data.get("recommended_realm", "未知")),
		env_tags,
		rewards,
		exploration,
	]
	_populate_difficulty_options(location_bounds)
	_enter_button.disabled = not can_enter
	if not can_enter and block_reason != "":
		_body.text += "\n\n%s" % block_reason
	visible = true


func hide_popup() -> void:
	visible = false
	_region_id = ""


func _populate_difficulty_options(bounds: Dictionary) -> void:
	var loc_min := maxi(1, int(bounds.get("min", 1)))
	var loc_max := maxi(loc_min, int(bounds.get("max", loc_min)))
	_min_option.clear()
	_max_option.clear()
	for value in range(loc_min, loc_max + 1):
		_min_option.add_item("难度 %d" % value, value)
		_max_option.add_item("难度 %d" % value, value)
	_min_option.select(0)
	_max_option.select(_max_option.item_count - 1)


func _on_min_changed(_index: int) -> void:
	var min_id := _min_option.get_selected_id()
	var max_id := _max_option.get_selected_id()
	if max_id < min_id:
		_max_option.select(_min_option.selected)


func _on_max_changed(_index: int) -> void:
	var min_id := _min_option.get_selected_id()
	var max_id := _max_option.get_selected_id()
	if max_id < min_id:
		_min_option.select(_max_option.selected)


func _on_enter_pressed() -> void:
	if _region_id == "":
		return
	enter_requested.emit(_region_id, {
		"min_difficulty": _min_option.get_selected_id(),
		"max_difficulty": _max_option.get_selected_id(),
	})


func _on_close_pressed() -> void:
	hide_popup()
	closed.emit()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_on_close_pressed()


func _star_label(danger: int) -> String:
	match danger:
		1: return "一"
		2: return "二"
		3: return "三"
		4: return "四"
		5: return "五"
		_: return str(danger)
