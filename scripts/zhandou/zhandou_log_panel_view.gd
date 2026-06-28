class_name ZhandouLogPanelView
extends Control

const ZhandouRecordFormatterScript := preload("res://scripts/zhandou/zhandou_record_formatter.gd")

const _MAX_RENDER_LINES := 80

@onready var _scroll: ScrollContainer = %BattleLogScroll
@onready var _body: RichTextLabel = %BattleLogBody

var _lines: PackedStringArray = PackedStringArray()
var _auto_follow := true


func _ready() -> void:
	if _scroll != null and _scroll.has_signal("user_scrolled"):
		var handler := Callable(self, "_on_user_scrolled")
		if not _scroll.is_connected("user_scrolled", handler):
			_scroll.connect("user_scrolled", handler)


func clear_log() -> void:
	_lines = PackedStringArray()
	_auto_follow = true
	if _body != null:
		_body.text = ""


func append_plain_line(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	_lines.append(line)
	if _lines.size() > _MAX_RENDER_LINES:
		_lines = _lines.slice(_lines.size() - _MAX_RENDER_LINES, _lines.size())
	_render()


func append_entry(entry: Dictionary, formatter, names: Dictionary = {}) -> void:
	if formatter == null or entry.is_empty():
		return
	var line: String = str(formatter.format_entry(entry, names))
	if line == "":
		return
	_lines.append(line)
	if _lines.size() > _MAX_RENDER_LINES:
		_lines = _lines.slice(_lines.size() - _MAX_RENDER_LINES, _lines.size())
	_render()


func render_tail(entries: Array, formatter, names: Dictionary = {}) -> void:
	if formatter == null:
		return
	_lines = PackedStringArray()
	for ev_v in entries:
		if not ev_v is Dictionary:
			continue
		var line: String = str(formatter.format_entry(ev_v as Dictionary, names))
		if line == "":
			continue
		_lines.append(line)
	if _lines.size() > _MAX_RENDER_LINES:
		_lines = _lines.slice(_lines.size() - _MAX_RENDER_LINES, _lines.size())
	_render()


func _render() -> void:
	if _body == null:
		return
	_body.bbcode_enabled = true
	_body.text = "\n".join(_lines)
	scroll_to_end()


func scroll_to_end() -> void:
	if _scroll == null or not _auto_follow:
		return
	await get_tree().process_frame
	_set_scroll_vertical_quiet(int(_scroll.get_v_scroll_bar().max_value))


func _on_user_scrolled() -> void:
	_auto_follow = false


func _set_scroll_vertical_quiet(value: int) -> void:
	if _scroll == null:
		return
	if _scroll.has_method("scroll_vertical_quiet"):
		_scroll.scroll_vertical_quiet(value)
	else:
		_scroll.scroll_vertical = value
