extends PanelContainer

const COLOR_OK := Color(0.35, 0.48, 0.24, 1.0)
const COLOR_MISSING := Color(0.62, 0.32, 0.2, 1.0)

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _status_label: Label = %StatusLabel


func bind(row: Dictionary) -> void:
	var label := str(row.get("label", ""))
	var current := int(row.get("current_count", 0))
	var required := maxi(1, int(row.get("required_count", 1)))
	var satisfied := bool(row.get("satisfied", false))
	_name_label.text = label
	if str(row.get("kind", "")) == "lilian":
		_count_label.text = "%d/%d 步" % [current, required]
		if bool(row.get("require_not_defeated", false)):
			_count_label.text += " · %s" % ("未战败" if bool(row.get("not_defeated", true)) else "已战败")
	else:
		_count_label.text = "%d/%d" % [current, required]
	var icon_path := str(row.get("icon_path", "")).strip_edges()
	if icon_path != "":
		_icon.texture = ItemDef.resolve_icon_texture(icon_path, _icon.texture)
	set_satisfied(satisfied)


func set_satisfied(satisfied: bool) -> void:
	_status_label.text = "√" if satisfied else "缺"
	_status_label.modulate = COLOR_OK if satisfied else COLOR_MISSING
	_count_label.modulate = COLOR_OK if satisfied else COLOR_MISSING
