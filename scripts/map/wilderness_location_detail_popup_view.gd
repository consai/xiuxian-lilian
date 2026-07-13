extends Control

signal enter_requested(location_id: String, options: Dictionary)
signal closed

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _enter_button: TextureButton = %EnterButton
@onready var _close_button: TextureButton = %CloseButton

var _location_id := ""
var _close_blocked := false


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_enter_button.pressed.connect(_on_enter_pressed)
	%Dimmer.gui_input.connect(_on_dimmer_input)


func show_location(
	location_id: String,
	location_data: Dictionary,
	can_enter: bool,
	block_reason: String,
	exploration: int,
	close_blocked: bool
) -> void:
	_location_id = location_id
	_close_blocked = close_blocked
	_title.text = str(location_data.get("name", location_id))
	var env_tags := ", ".join((location_data.get("environment_tags", []) as Array).map(func(v): return str(v)))
	var rewards := ", ".join((location_data.get("preview_rewards", []) as Array).map(func(v): return str(v)))
	var services := ", ".join((location_data.get("services", []) as Array).map(func(v): return str(v)))
	_body.text = "类型：野外地点\n危险：%s星\n推荐境界：%s\n环境：%s\n\n可能收获：%s\n功能：%s\n探索状态：%s\n\n野外地点是区域中的独立地点，进入后可进行探索或触发事件。" % [
		_star_label(maxi(1, int(location_data.get("danger", 1)))),
		str(location_data.get("recommended_realm", "未知")),
		env_tags,
		rewards,
		services,
		"已发现" if exploration >= 0 else "未发现",
	]
	_enter_button.disabled = not can_enter
	if not can_enter and block_reason != "":
		_body.text += "\n\n%s" % block_reason
	visible = true


func hide_popup() -> void:
	visible = false
	_location_id = ""


func _on_enter_pressed() -> void:
	if _location_id == "":
		return
	enter_requested.emit(_location_id, {})


func _on_close_pressed() -> void:
	if _close_blocked:
		return
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
