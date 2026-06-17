class_name ExpeditionLogPanelView
extends Control

signal closed

const ExpeditionLogServiceScript := preload("res://scripts/expedition/expedition_log_service.gd")

@onready var _backdrop: ColorRect = %Backdrop
@onready var _log_label: RichTextLabel = %LogBody
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide_panel)
	_backdrop.gui_input.connect(_on_backdrop_gui_input)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_panel()
		get_viewport().set_input_as_handled()


func show_log(entries: Array) -> void:
	var log_lines: PackedStringArray = []
	for entry_v in entries:
		if entry_v is Dictionary:
			log_lines.append(ExpeditionLogServiceScript.format_bbcode(entry_v as Dictionary))
	_log_label.text = "暂无历练记录。" if log_lines.is_empty() else "\n\n".join(log_lines)
	visible = true
	call_deferred("_scroll_to_bottom")


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _scroll_to_bottom() -> void:
	var scroll := _log_label.get_parent() as ScrollContainer
	if scroll == null:
		return
	if scroll.has_method("scroll_vertical_to_end"):
		await scroll.scroll_vertical_to_end()
		return
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()
