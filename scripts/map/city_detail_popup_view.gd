extends Control

signal travel_requested(city_id: String)
signal closed

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _travel_button: TextureButton = %TravelButton
@onready var _close_button: TextureButton = %CloseButton

var _city_id := ""


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_travel_button.pressed.connect(_on_travel_pressed)
	%Dimmer.gui_input.connect(_on_dimmer_input)


func show_city(city_id: String, city_data: Dictionary, preview: Dictionary, duration_label: String) -> void:
	_city_id = city_id
	_title.text = str(city_data.get("name", city_id))
	var type_label := "坊市" if str(city_data.get("type", "")) == "market" else "修真城市"
	var services := ", ".join((city_data.get("services", []) as Array).map(func(v): return str(v)))
	var lines: PackedStringArray = [
		"类型：%s" % type_label,
		"",
		str(city_data.get("desc", "")),
		"",
		"城市功能：%s" % services,
	]
	if bool(preview.get("ok", false)):
		lines.append("路程：预计 %s" % str(preview.get("duration_label", duration_label)))
		lines.append("路线状态：可前往")
	elif str(preview.get("error", "")) != "":
		lines.append("路程：%s" % str(preview.get("error", "")))
	else:
		lines.append("路程：已在当前城市")
	_body.text = "\n".join(lines)
	var can_travel := bool(preview.get("ok", false)) and int(preview.get("total_days", 0)) >= 0
	_travel_button.disabled = not can_travel
	visible = true


func hide_popup() -> void:
	visible = false
	_city_id = ""


func _on_travel_pressed() -> void:
	if _city_id == "":
		return
	travel_requested.emit(_city_id)


func _on_close_pressed() -> void:
	hide_popup()
	closed.emit()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_on_close_pressed()
