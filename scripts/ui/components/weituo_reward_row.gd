extends PanelContainer

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel


func bind(row: Dictionary) -> void:
	var display_name := str(row.get("display_name", row.get("id", "")))
	var count := maxi(1, int(row.get("count", 1)))
	_name_label.text = display_name
	_count_label.text = str(count)
	var icon_path := str(row.get("icon_path", "")).strip_edges()
	if icon_path != "":
		_icon.texture = ItemDef.resolve_icon_texture(icon_path, _icon.texture)
