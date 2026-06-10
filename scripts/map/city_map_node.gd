extends Control

signal city_selected(city_id: String)

@export var city_id := ""

@onready var _name_label: Label = %NameLabel
@onready var _event_badge: Label = %EventBadge


func setup(city_data: Dictionary) -> void:
	if city_id == "":
		city_id = str(city_data.get("id", ""))
	_name_label.text = str(city_data.get("name", city_id))


func set_map_state(state: String) -> void:
	match state:
		"current":
			modulate = Color(0.75, 0.95, 1.0, 1.0)
			_event_badge.visible = true
			_event_badge.text = "当前"
		"reachable":
			modulate = Color(0.85, 1.0, 0.85, 1.0)
			_event_badge.visible = false
		"discovered":
			modulate = Color.WHITE
			_event_badge.visible = false
		"vanished":
			modulate = Color(0.55, 0.55, 0.55, 0.45)
			_event_badge.visible = false
		_:
			modulate = Color(0.7, 0.7, 0.7, 0.35)
			_event_badge.visible = false


func _on_pressed() -> void:
	if city_id == "":
		return
	city_selected.emit(city_id)
