extends Control

const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")

signal confirmed
signal cancelled

@onready var _route_summary: Label = %RouteSummary
@onready var _confirm_button: TextureButton = %ConfirmButton
@onready var _cancel_button: TextureButton = %CancelButton


func _ready() -> void:
	_confirm_button.pressed.connect(func(): confirmed.emit())
	_cancel_button.pressed.connect(func(): cancelled.emit())
	%Dimmer.gui_input.connect(_on_dimmer_input)


func show_preview(preview: Dictionary, from_name: String, to_name: String, duration_label: String) -> void:
	var path_names: PackedStringArray = []
	for city_id_v in preview.get("path", []) as Array:
		var city_id := str(city_id_v)
		path_names.append(str(WorldMapServiceScript.city_by_id(city_id).get("name", city_id)))
	var route_text := " → ".join(path_names)
	if route_text == "":
		route_text = "%s → %s" % [from_name, to_name]
	_route_summary.text = "%s\n\n预计耗时：%s\n可能遭遇：商队、路匪、随机事件\n\n启程后将立即离开当前城市。" % [
		route_text,
		str(preview.get("duration_label", duration_label)),
	]
	visible = true


func hide_popup() -> void:
	visible = false


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		cancelled.emit()
