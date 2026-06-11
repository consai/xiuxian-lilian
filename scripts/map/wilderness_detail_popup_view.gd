extends Control

signal enter_requested(region_id: String, options: Dictionary)
signal closed

const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")

const TIER_OUTER := 0
const TIER_DEEP := 1
const TIER_CORE := 2
const TIER_LABELS := ["外围探索", "深入探索", "进入核心"]

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _enter_button: TextureButton = %EnterButton
@onready var _close_button: TextureButton = %CloseButton
@onready var _difficulty_option: OptionButton = %DifficultyOption

var _region_id := ""
var _location_bounds := {"min": 1, "max": 1}


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_enter_button.pressed.connect(_on_enter_pressed)
	%Dimmer.gui_input.connect(_on_dimmer_input)


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
	_difficulty_option.clear()
	for tier in [TIER_OUTER, TIER_DEEP, TIER_CORE]:
		var tier_bounds := WorldMapServiceScript.difficulty_tier_bounds(loc_min, loc_max, tier)
		var label := "%s (难度 %d-%d)" % [
			TIER_LABELS[tier],
			int(tier_bounds.get("min", loc_min)),
			int(tier_bounds.get("max", loc_max)),
		]
		_difficulty_option.add_item(label, tier)
	_difficulty_option.select(TIER_DEEP)


func _selected_difficulty_bounds() -> Dictionary:
	var loc_min := maxi(1, int(_location_bounds.get("min", 1)))
	var loc_max := maxi(loc_min, int(_location_bounds.get("max", loc_min)))
	var tier := _difficulty_option.get_selected_id()
	return WorldMapServiceScript.difficulty_tier_bounds(loc_min, loc_max, tier)


func _on_enter_pressed() -> void:
	if _region_id == "":
		return
	var bounds := _selected_difficulty_bounds()
	enter_requested.emit(_region_id, {
		"min_difficulty": int(bounds.get("min", 1)),
		"max_difficulty": int(bounds.get("max", 1)),
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
