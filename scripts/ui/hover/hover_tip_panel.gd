extends Control
class_name HoverTipPanel

const _TITLE_COLOR_DEFAULT := Color(0.33333334, 0.19607843, 0.18431373, 1.0)
const _MIN_WIDTH := 168.0
const _MAX_WIDTH := 280.0
const _H_MARGIN := 20.0
const _ICON_ROW_EXTRA := 34.0

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _footer: Label = %Footer
@onready var _panel: PanelContainer = %Panel

var _present_generation := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


func apply_payload(payload: Dictionary) -> void:
	_reset_layout_sizes()

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


func show_at_anchor(anchor: Control, show_token: int, token_check: Callable) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	_present_generation += 1
	var generation := _present_generation
	visible = false
	modulate.a = 0.0

	_apply_panel_width(_MAX_WIDTH)
	await get_tree().process_frame
	if not _can_present(anchor, show_token, generation, token_check):
		return

	var panel_width := _compute_panel_width()
	_apply_panel_width(panel_width)
	await get_tree().process_frame
	if not _can_present(anchor, show_token, generation, token_check):
		return

	_finalize_layout()
	_place_near_pointer(anchor)
	visible = true
	modulate.a = 1.0


func hide_immediate() -> void:
	_present_generation += 1
	visible = false
	modulate.a = 0.0


func _can_present(
		anchor: Control,
		show_token: int,
		generation: int,
		token_check: Callable
) -> bool:
	if generation != _present_generation:
		return false
	if token_check.is_valid() and not bool(token_check.call(show_token)):
		return false
	return true


func _reset_layout_sizes() -> void:
	_panel.custom_minimum_size = Vector2.ZERO
	_body.custom_minimum_size = Vector2.ZERO
	_footer.custom_minimum_size = Vector2.ZERO
	size = Vector2.ZERO
	_panel.position = Vector2.ZERO


func _apply_panel_width(panel_width: float) -> void:
	var width := clampf(panel_width, _MIN_WIDTH, _MAX_WIDTH)
	var inner_width := maxf(1.0, width - _H_MARGIN)
	if _body.visible:
		_body.custom_minimum_size.x = inner_width
	if _footer.visible:
		_footer.custom_minimum_size.x = inner_width
	_panel.custom_minimum_size.x = width
	_panel.reset_size()


func _compute_panel_width() -> float:
	var width := _MIN_WIDTH

	if _title.visible:
		var header_width := _title.get_minimum_size().x
		if _icon.visible:
			header_width += _ICON_ROW_EXTRA
		width = maxf(width, header_width + _H_MARGIN)

	if _body.visible:
		width = maxf(width, minf(_body.get_minimum_size().x + _H_MARGIN, _MAX_WIDTH))
	if _footer.visible:
		width = maxf(width, minf(_footer.get_minimum_size().x + _H_MARGIN, _MAX_WIDTH))

	width = clampf(width, _MIN_WIDTH, _MAX_WIDTH)
	var inner_width := maxf(1.0, width - _H_MARGIN)

	if _body.visible:
		_body.custom_minimum_size.x = inner_width
	if _footer.visible:
		_footer.custom_minimum_size.x = inner_width

	return width


func _finalize_layout() -> void:
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = _panel.size
	size = panel_size
	_panel.position = Vector2.ZERO


func _resolve_panel_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size.x > 1.0 and panel_size.y > 1.0:
		return panel_size
	return _panel.size


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
