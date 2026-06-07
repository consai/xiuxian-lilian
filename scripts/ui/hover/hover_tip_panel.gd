extends Control
class_name HoverTipPanel

const _TITLE_COLOR_DEFAULT := Color(0.33333334, 0.19607843, 0.18431373, 1.0)
const _BODY_COLOR := Color(0.4117647, 0.3019608, 0.27450982, 1.0)
const _FOOTER_COLOR := Color(0.5372549, 0.42745098, 0.3882353, 1.0)
const _MIN_WIDTH := 168.0
const _MAX_WIDTH := 280.0

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _footer: Label = %Footer
@onready var _panel: PanelContainer = %Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


func apply_payload(payload: Dictionary) -> void:
	var title := str(payload.get("title", "")).strip_edges()
	var title_color_v: Variant = payload.get("title_color", null)
	var title_color := title_color_v as Color if title_color_v is Color else _TITLE_COLOR_DEFAULT
	_title.text = title
	_title.visible = title != ""
	_title.add_theme_color_override("font_color", title_color)

	var icon_v: Variant = payload.get("icon", null)
	if icon_v is Texture2D:
		_icon.texture = icon_v
		_icon.visible = true
	else:
		_icon.texture = null
		_icon.visible = false

	var body_lines: PackedStringArray = []
	var lines_v: Variant = payload.get("lines", [])
	if lines_v is Array:
		for line_v in lines_v as Array:
			var line := str(line_v).strip_edges()
			if line != "":
				body_lines.append(line)
	_body.text = "\n".join(body_lines)
	_body.visible = not body_lines.is_empty()

	var footer := str(payload.get("footer", "")).strip_edges()
	_footer.text = footer
	_footer.visible = footer != ""

	_panel.custom_minimum_size.x = clampf(
		maxf(_MIN_WIDTH, _measure_content_width()),
		_MIN_WIDTH,
		_MAX_WIDTH
	)
	_panel.reset_size()
	size = _panel.size


func show_at_anchor(anchor: Control) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	visible = true
	await get_tree().process_frame
	_place_near_pointer(anchor)
	modulate.a = 1.0


func hide_immediate() -> void:
	visible = false
	modulate.a = 0.0


func _resolve_panel_size() -> Vector2:
	var panel_size := size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = _panel.size
	return panel_size


func _place_near_pointer(anchor: Control) -> void:
	var viewport_rect := get_viewport().get_visible_rect()
	var panel_size := _resolve_panel_size()
	var mouse := anchor.get_global_mouse_position()
	var anchor_rect := anchor.get_global_rect()

	const CURSOR_GAP := 14.0
	const MARGIN := 8.0

	var pos := Vector2(
		mouse.x - panel_size.x * 0.5,
		mouse.y - CURSOR_GAP - panel_size.y
	)

	var above_fits := pos.y >= viewport_rect.position.y + MARGIN
	if not above_fits:
		pos.y = mouse.y + CURSOR_GAP

	pos = _avoid_anchor_overlap(
		pos,
		panel_size,
		anchor_rect,
		viewport_rect,
		above_fits,
		CURSOR_GAP,
		MARGIN
	)

	pos.x = clampf(
		pos.x,
		viewport_rect.position.x + MARGIN,
		viewport_rect.position.x + viewport_rect.size.x - panel_size.x - MARGIN
	)
	pos.y = clampf(
		pos.y,
		viewport_rect.position.y + MARGIN,
		viewport_rect.position.y + viewport_rect.size.y - panel_size.y - MARGIN
	)
	global_position = pos


func _avoid_anchor_overlap(
	pos: Vector2,
	panel_size: Vector2,
	anchor_rect: Rect2,
	viewport_rect: Rect2,
	prefer_above_screen: bool,
	gap: float,
	margin: float
) -> Vector2:
	var tip_rect := Rect2(pos, panel_size)
	if not tip_rect.intersects(anchor_rect):
		return pos

	var above_anchor_y := anchor_rect.position.y - panel_size.y - gap
	var below_anchor_y := anchor_rect.end.y + gap
	var above_anchor_fits := above_anchor_y >= viewport_rect.position.y + margin
	var below_anchor_fits := below_anchor_y + panel_size.y <= viewport_rect.end.y - margin

	if prefer_above_screen and above_anchor_fits:
		pos.y = above_anchor_y
	elif below_anchor_fits:
		pos.y = below_anchor_y
	elif above_anchor_fits:
		pos.y = above_anchor_y
	else:
		pos.y = below_anchor_y

	return pos


func _measure_content_width() -> float:
	var width := _MIN_WIDTH
	if _title.visible:
		width = maxf(width, _title.get_minimum_size().x + 16.0)
	if _body.visible:
		width = maxf(width, _body.get_minimum_size().x + 16.0)
	if _footer.visible:
		width = maxf(width, _footer.get_minimum_size().x + 16.0)
	if _icon.visible:
		width += _icon.custom_minimum_size.x + 8.0
	return width
