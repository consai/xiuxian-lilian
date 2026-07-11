extends Button

signal chosen(id: String)

var choice_id := ""

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _desc_label: Label = %DescLabel
@onready var _bonus_label: Label = %BonusLabel


func _ready() -> void:
	pressed.connect(func(): chosen.emit(choice_id))


func set_choice(row: Dictionary, bonus_text: String = "") -> void:
	choice_id = str(row.get("id", "")).strip_edges()
	_name_label.text = str(row.get("name", choice_id))
	_desc_label.text = str(row.get("description", ""))
	_bonus_label.text = bonus_text
	var icon_path := str(row.get("iconPath", "")).strip_edges()
	_icon.texture = Tools.load_image(icon_path) if icon_path != "" else null


func set_selected(active: bool) -> void:
	self_modulate = Color(1.0, 0.92, 0.55) if active else Color.WHITE
