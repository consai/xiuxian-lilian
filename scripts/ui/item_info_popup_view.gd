class_name ItemInfoPopupView
extends Control

signal close_requested

const _TITLE_COLOR_DEFAULT := Color(0.33333334, 0.19607843, 0.18431373, 1.0)
const _BODY_COLOR := Color(0.4117647, 0.3019608, 0.27450982, 1.0)
const _FOOTER_COLOR := Color(0.5372549, 0.42745098, 0.3882353, 1.0)

@onready var _backdrop: ColorRect = %Backdrop
@onready var _item_preview: ItemView = %ItemPreview
@onready var _name_label: Label = %NameLabel
@onready var _meta_label: Label = %MetaLabel
@onready var _desc_label: Label = %DescLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _footer_label: Label = %FooterLabel
@onready var _close_button: TextureButton = %CloseButton


func _ready() -> void:
	visible = false
	_item_preview.show_name_label = false
	_item_preview.set_click_enabled(false)
	_item_preview.show_info_on_click = false
	_close_button.pressed.connect(_request_close)
	_backdrop.gui_input.connect(_on_backdrop_gui_input)


func apply_payload(payload: Dictionary) -> void:
	var title := str(payload.get("title", "")).strip_edges()
	var title_color_v: Variant = payload.get("title_color", null)
	var title_color := title_color_v as Color if title_color_v is Color else _TITLE_COLOR_DEFAULT
	_name_label.text = title
	_name_label.add_theme_color_override("font_color", title_color)

	var meta := str(payload.get("meta", "")).strip_edges()
	_meta_label.text = meta
	_meta_label.visible = meta != ""

	var desc := str(payload.get("desc", "")).strip_edges()
	_desc_label.text = desc
	_desc_label.visible = desc != ""

	var detail_lines: PackedStringArray = []
	var lines_v: Variant = payload.get("detail_lines", [])
	if lines_v is Array:
		for line_v in lines_v as Array:
			var line := str(line_v).strip_edges()
			if line != "":
				detail_lines.append(line)
	_detail_label.text = "\n".join(detail_lines)
	_detail_label.visible = not detail_lines.is_empty()

	var footer := str(payload.get("footer", "")).strip_edges()
	_footer_label.text = footer
	_footer_label.visible = footer != ""

	var icon_v: Variant = payload.get("icon", null)
	var icon := icon_v as Texture2D if icon_v is Texture2D else null
	var quality := str(payload.get("quality", "")).strip_edges()
	_item_preview.apply_display(icon, title, 0, Color.WHITE, quality)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_request_close()


func _request_close() -> void:
	close_requested.emit()
