extends Control

signal region_selected(region_id: String)

@export var region_id := ""

@onready var _name_label: Label = %NameLabel
@onready var _meta_label: Label = %MetaLabel


func setup(region_data: Dictionary, exploration: int = 0) -> void:
	if region_id == "":
		region_id = str(region_data.get("id", ""))
	_name_label.text = str(region_data.get("name", region_id))
	var danger := maxi(1, int(region_data.get("danger", 1)))
	_meta_label.text = "危险%s星 · 探索 %d%%" % [_star_label(danger), exploration]


func set_map_state(state: String) -> void:
	match state:
		"discovered":
			modulate = Color.WHITE
			visible = true
		"vanished":
			modulate = Color(0.55, 0.55, 0.55, 0.45)
			visible = true
		_:
			modulate = Color(0.75, 0.75, 0.75, 0.25)
			visible = true


func _star_label(danger: int) -> String:
	match danger:
		1: return "一"
		2: return "二"
		3: return "三"
		4: return "四"
		5: return "五"
		_: return str(danger)


func _on_pressed() -> void:
	if region_id == "":
		return
	region_selected.emit(region_id)
