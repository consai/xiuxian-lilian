class_name StoryPlaybackPresenter
extends Control

const GuideMaskScript := preload("res://scripts/story/story_guide_mask.gd")
const TYPEWRITER_CHARS_PER_SEC := 32.0
const ADVANCE_DELAY_AFTER_COMPLETE := 0.3

signal advance_requested
signal choice_requested(choice_id: String)
signal skip_requested

@onready var _background: ColorRect = %Background
@onready var _guide_mask: Control = %GuideMask
@onready var _advance_overlay: ColorRect = %AdvanceOverlay
@onready var _focus_ring: Control = %FocusRing
@onready var _focus_prompt: Control = %FocusPrompt
@onready var _dialogue: Control = %DialoguePanel
@onready var _choice_panel: Control = %ChoicePanel
@onready var _history_panel: Control = %HistoryPanel
@onready var _skip_confirm: Control = %SkipConfirm
@onready var _chapter_card: Control = %ChapterCard
@onready var _end_card: Control = %EndCard
@onready var _skip_button: Button = %SkipButton
@onready var _auto_button: Button = %AutoButton
@onready var _history_button: Button = %HistoryButton
@onready var _dialogue_label: Label = _dialogue.get_node("DialogueLabel")
@onready var _continue_indicator: Control = _dialogue.get_node("ContinueIndicator")
@onready var _speaker_label: Label = _dialogue.get_node("NamePlate/SpeakerLabel")
@onready var _portrait_back: Control = _dialogue.get_node("PortraitBack")
@onready var _name_plate: Control = _dialogue.get_node("NamePlate")
@onready var _choices: VBoxContainer = _choice_panel.get_node("Choices")
@onready var _choice_template: Button = _choice_panel.get_node("Choices/ChoiceA")
@onready var _choice_template_b: Button = _choice_panel.get_node("Choices/ChoiceB")
@onready var _choice_prompt_label: Label = _choice_panel.get_node("PromptBack/PromptLabel")
@onready var _focus_prompt_label: Label = _focus_prompt.get_node("Label")

var _choice_buttons: Array[Button] = []
var _focus_target := ""
var _line_text := ""
var _typewriter_progress := 0.0
var _typewriter_done := true
var _advance_block_timer := 0.0


func _ready() -> void:
	_advance_overlay.gui_input.connect(_on_advance_input)
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	_auto_button.visible = false
	_history_button.visible = false
	_history_panel.visible = false
	_skip_confirm.visible = false
	_chapter_card.visible = false
	_end_card.visible = false
	_choice_template.visible = false
	_choice_template_b.visible = false
	_continue_indicator.visible = false
	hide_all()


func show_frame(frame: Dictionary) -> void:
	visible = true
	_focus_target = ""
	_focus_ring.visible = false
	_focus_prompt.visible = false
	_guide_mask.set_active(false)
	var is_line := str(frame.get("type", "")) == "line"
	_dialogue.visible = is_line
	_choice_panel.visible = str(frame.get("type", "")) == "choice"
	_advance_overlay.visible = is_line
	_background.visible = true
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _dialogue.visible:
		_apply_line_style(frame)
		_speaker_label.text = str(frame.get("speaker", ""))
		_start_typewriter(str(frame.get("text", "")))
	if _choice_panel.visible:
		_reset_typewriter()
		_choice_prompt_label.text = str(frame.get("prompt", "请选择"))
		_bind_choices(frame.get("choices", []) as Array)


func _apply_line_style(frame: Dictionary) -> void:
	var meta := frame.get("meta", {}) as Dictionary
	var narration := bool(meta.get("narration", false))
	_portrait_back.visible = not narration
	_name_plate.visible = not narration
	var label := _dialogue_label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if narration:
		label.offset_left = 118.0
		label.offset_top = 58.0
		label.offset_right = 1134.0
		label.offset_bottom = 188.0
	else:
		label.offset_left = 214.0
		label.offset_top = 88.0
		label.offset_right = 1140.0
		label.offset_bottom = 184.0


func show_guide(target: String, reason: String) -> void:
	visible = true
	_reset_typewriter()
	_advance_overlay.visible = false
	_dialogue.visible = false
	_choice_panel.visible = false
	_background.visible = false
	_guide_mask.set_active(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_target = target
	_focus_prompt_label.text = reason
	_focus_prompt.visible = reason.strip_edges() != ""
	_update_focus()


func clear_guide() -> void:
	_focus_target = ""
	_focus_ring.visible = false
	_focus_prompt.visible = false
	_guide_mask.set_active(false)
	_background.visible = false
	_advance_overlay.visible = false
	_dialogue.visible = false
	_choice_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hide_all() -> void:
	visible = false
	_reset_typewriter()
	_advance_overlay.visible = false
	_guide_mask.set_active(false)
	_background.visible = true
	_focus_target = ""
	_clear_choice_buttons()


func _process(delta: float) -> void:
	if visible and _focus_target != "":
		_update_focus()
	if _advance_block_timer > 0.0:
		_advance_block_timer = maxf(_advance_block_timer - delta, 0.0)
		if _advance_block_timer <= 0.0 and _typewriter_done and _dialogue.visible:
			_continue_indicator.visible = true
	if not _dialogue.visible or _typewriter_done:
		return
	_typewriter_progress += delta * TYPEWRITER_CHARS_PER_SEC
	var visible_count := mini(int(_typewriter_progress), _line_text.length())
	_dialogue_label.visible_characters = visible_count
	if visible_count >= _line_text.length():
		_finish_typewriter()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _dialogue.visible:
		return
	if event.is_action_pressed("ui_accept"):
		_handle_advance_click()
		get_viewport().set_input_as_handled()


func _start_typewriter(text: String) -> void:
	_line_text = text
	_dialogue_label.text = text
	_typewriter_progress = 0.0
	_advance_block_timer = 0.0
	_typewriter_done = text.is_empty()
	_dialogue_label.visible_characters = 0 if not _typewriter_done else -1
	_continue_indicator.visible = false
	if _typewriter_done:
		_finish_typewriter()


func _finish_typewriter() -> void:
	_typewriter_done = true
	_dialogue_label.visible_characters = -1
	_advance_block_timer = ADVANCE_DELAY_AFTER_COMPLETE
	_continue_indicator.visible = false


func _reset_typewriter() -> void:
	_line_text = ""
	_typewriter_progress = 0.0
	_typewriter_done = true
	_advance_block_timer = 0.0
	_dialogue_label.visible_characters = -1
	_continue_indicator.visible = false


func _bind_choices(rows: Array) -> void:
	_clear_choice_buttons()
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var button := _choice_template.duplicate() as Button
		button.visible = true
		button.text = str(row.get("label", "选择"))
		button.tooltip_text = str(row.get("hint", ""))
		button.pressed.connect(func() -> void: choice_requested.emit(str(row.get("id", ""))))
		_choices.add_child(button)
		_choice_buttons.append(button)


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()


func _update_focus() -> void:
	var target := _find_target(get_tree().current_scene, _focus_target)
	if target == null:
		_focus_ring.visible = false
		_focus_prompt.visible = false
		_guide_mask.set_active(false)
		_focus_prompt.position = Vector2(540, 96)
		return
	_guide_mask.set_active(true)
	_focus_prompt.visible = _focus_prompt_label.text.strip_edges() != ""
	var rect := target.get_global_rect()
	_guide_mask.set_hole(rect)
	_focus_ring.visible = true
	_focus_ring.position = rect.position - GuideMaskScript.HOLE_PADDING
	_focus_ring.size = rect.size + GuideMaskScript.HOLE_PADDING * 2.0
	_focus_prompt.position = Vector2(
		clampf(rect.get_center().x - _focus_prompt.size.x * 0.5, 12.0, size.x - _focus_prompt.size.x - 12.0),
		clampf(rect.end.y + 8.0, 12.0, size.y - _focus_prompt.size.y - 12.0)
	)


func _find_target(root: Node, target: String) -> Control:
	if target == "":
		return null
	var found := _find_target_recursive(root, target)
	if found != null:
		return found
	var tree := get_tree()
	if tree == null:
		return null
	for child in tree.root.get_children():
		if child == root:
			continue
		found = _find_target_recursive(child, target)
		if found != null:
			return found
	return null


func _find_target_recursive(root: Node, target: String) -> Control:
	if root == null:
		return null
	if root.name == target and root is Control:
		return root as Control
	for child in root.get_children():
		var found := _find_target_recursive(child, target)
		if found != null:
			return found
	return null


func _on_advance_input(event: InputEvent) -> void:
	if not _dialogue.visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_handle_advance_click()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_handle_advance_click()
		get_viewport().set_input_as_handled()


func _handle_advance_click() -> void:
	if not _typewriter_done:
		_finish_typewriter()
		return
	if _advance_block_timer > 0.0:
		return
	advance_requested.emit()
