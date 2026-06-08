class_name ItemView
extends Panel

## 道具展示块，场景 [code]item.tscn[/code]。
## [member click_enabled] 为 [code]false[/code] 时仅展示（如详情弹窗）；为 [code]true[/code] 时可点击并带缩放反馈（如背包）。
## [code]%GcItemHighlight[/code] 为品质边框，随 [member quality] / [method apply_display] 更新。

signal clicked
signal right_clicked

@export var click_enabled: bool = false:
	set(value):
		click_enabled = value
		if is_node_ready():
			_apply_click_enabled()

@export var show_name_label: bool = true:
	set(value):
		show_name_label = value
		if is_node_ready():
			_refresh_name_count_text()

@onready var _icon: TextureRect = %GcDetailIcon
@onready var _name_count: Label = %GcItemNameCount
@onready var _press: PressScale = %GcItemPress
@onready var _quality_border: Panel = %GcItemHighlight

var _display_name: String = ""
var _display_count: int = 0
var _quality: String = ""


func _ready() -> void:
	_apply_click_enabled()
	_apply_quality_border(_quality)
	_refresh_name_count_text()
	if click_enabled:
		_press.clicked.connect(_on_press_clicked)
	gui_input.connect(_on_gui_input)


func set_click_enabled(enabled: bool) -> void:
	click_enabled = enabled


func apply_empty(placeholder: Texture2D, icon_modulate: Color = Color(1, 1, 1, 0.28)) -> void:
	_display_name = ""
	_display_count = 0
	_quality = ""
	if placeholder != null:
		_icon.texture = placeholder
	_icon.self_modulate = icon_modulate
	_apply_quality_border("")
	_refresh_name_count_text()


func apply_display(
	icon: Texture2D,
	item_name: String = "",
	count: int = 0,
	icon_modulate: Color = Color.WHITE,
	quality: String = ""
) -> void:
	_display_name = item_name.strip_edges()
	_display_count = maxi(0, count)
	_quality = quality.strip_edges()
	if icon != null:
		_icon.texture = icon
	_icon.self_modulate = icon_modulate
	_apply_quality_border(_quality)
	_refresh_name_count_text()


func apply_row(row: Dictionary, fallback_icon: Texture2D = null) -> void:
	var path := str(row.get("wuPinTuBiao", row.get("icon", ""))).strip_edges()
	var tex: Texture2D = null
	if path != "":
		var loaded := load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		tex = fallback_icon
	var nm := str(row.get("wuPinMing", row.get("wuPinId", "")))
	var cnt := maxi(1, int(row.get("shuLiang", 1)))
	var pin := str(row.get("pinZhi", ""))
	apply_display(tex, nm, cnt, Color.WHITE, pin)


func _on_press_clicked() -> void:
	clicked.emit()


func _on_gui_input(event: InputEvent) -> void:
	if not click_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			right_clicked.emit()
			accept_event()


func _apply_click_enabled() -> void:
	if click_enabled:
		_press.process_mode = Node.PROCESS_MODE_INHERIT
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_press.process_mode = Node.PROCESS_MODE_DISABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		scale = Vector2.ONE


func _apply_quality_border(pin_zhi: String) -> void:
	match pin_zhi.strip_edges():
		"稀有":
			_quality_border.visible = true
			_quality_border.self_modulate = Color(0.45, 0.72, 1.0)
		"传说":
			_quality_border.visible = true
			_quality_border.self_modulate = Color(1.0, 0.82, 0.35)
		_:
			_quality_border.visible = false


func _refresh_name_count_text() -> void:
	if not show_name_label:
		if _display_count > 0:
			_name_count.text = str(_display_count)
			_name_count.visible = true
		else:
			_name_count.text = ""
			_name_count.visible = false
		return
	if _display_name == "" and _display_count <= 0:
		_name_count.text = ""
		_name_count.visible = false
		return
	if _display_count > 1:
		_name_count.text = "%sx%d" % [_display_name, _display_count]
	else:
		_name_count.text = _display_name
	_name_count.visible = _name_count.text != ""
