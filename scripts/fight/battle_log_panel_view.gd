class_name BattleLogPanelView
extends Control

const BattleRecordFormatterScript := preload("res://scripts/fight/battle_record_formatter.gd")

const _MAX_RENDER_LINES := 80

@onready var _scroll: ScrollContainer = %BattleLogScroll
@onready var _body: RichTextLabel = %BattleLogBody

var _lines: PackedStringArray = PackedStringArray()


func clear_log() -> void:
	_lines = PackedStringArray()
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
	if _scroll == null:
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
