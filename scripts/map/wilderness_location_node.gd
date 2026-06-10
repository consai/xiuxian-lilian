extends Control

signal location_selected(location_id: String)

@export var location_id := ""

@onready var _name_label: Label = %NameLabel
@onready var _danger_badge: Label = %DangerBadge


func setup(location_data: Dictionary) -> void:
	if location_id == "":
		location_id = str(location_data.get("id", ""))
	_name_label.text = str(location_data.get("name", location_id))
	var danger := maxi(1, int(location_data.get("danger", 1)))
	_danger_badge.text = "危%d" % danger


func set_map_state(state: String) -> void:
	match state:
		"discovered":
			visible = true
			modulate = Color.WHITE
		"vanished":
			visible = true
			modulate = Color(0.55, 0.55, 0.55, 0.45)
		_:
			visible = false


func _on_pressed() -> void:
	if location_id == "":
		return
	location_selected.emit(location_id)
