class_name StoryPlaybackPresenter
extends Control

const GuideMaskScript := preload("res://scripts/story/story_guide_mask.gd")
const EnumCharacterPortraitScript := preload("res://scripts/enum/enum_character_portrait.gd")
const TYPEWRITER_CHARS_PER_SEC := 32.0
const ADVANCE_DELAY_AFTER_COMPLETE := 0.3
const FOCUS_PROMPT_MARGIN := 12.0
const FOCUS_PROMPT_GAP := 10.0
const FOCUS_PROMPT_MIN_WIDTH := 200.0
const FOCUS_PROMPT_MAX_WIDTH := 520.0
const FOCUS_PROMPT_H_PADDING := 36.0

signal advance_requested
signal choice_requested(choice_id: String)
signal skip_requested

@onready var _background: ColorRect = %Background
@onready var _guide_mask: StoryGuideMask = %GuideMask
@onready var _advance_overlay: ColorRect = %AdvanceOverlay
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
@onready var _portrait: TextureRect = _dialogue.get_node("PortraitBack/Portrait")
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
	_advance_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_advance_overlay.gui_input.connect(_on_advance_input)
	_skip_button.pressed.connect(func() -> void: skip_requested.emit())
	_set_control_tree_mouse_filter(_focus_prompt, Control.MOUSE_FILTER_IGNORE)
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
	var speaker := str(frame.get("speaker", "")).strip_edges()
	# 无说话人时按旁白排版，隐藏立绘与名牌。
	var narration := bool(meta.get("narration", false)) or speaker == ""
	_portrait_back.visible = not narration
	_name_plate.visible = not narration
	_apply_portrait(frame, speaker, narration)
	var label := _dialogue_label
	label.set_anchors_preset(Control.PRESET_FULL_RECT, false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if narration:
		label.offset_left = 118.0
		label.offset_top = 58.0
		label.offset_right = -66.0
		label.offset_bottom = -44.0
	else:
		label.offset_left = 214.0
		label.offset_top = 88.0
		label.offset_right = -60.0
		label.offset_bottom = -48.0


func _apply_portrait(frame: Dictionary, speaker: String, narration: bool) -> void:
	if _portrait == null or narration:
		return
	var portrait_path := str(frame.get("portrait", "")).strip_edges()
	if portrait_path == "":
		portrait_path = EnumCharacterPortraitScript.portrait_for_speaker(speaker)
	var tex: Texture2D = EnumCharacterPortraitScript.texture(portrait_path)
	if tex != null:
		_portrait.texture = tex
		_portrait.modulate = Color.WHITE


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
	_refresh_focus_prompt_size()
	_update_focus()


func clear_guide() -> void:
	_focus_target = ""
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
	_background.visible = false
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
	var target := _find_target(SceneManager.get_active_scene(), _focus_target)
	if target == null:
		_focus_prompt.visible = false
		_guide_mask.set_active(false)
		_focus_prompt.position = Vector2(540, 96)
		return
	_guide_mask.set_active(true)
	_focus_prompt.visible = _focus_prompt_label.text.strip_edges() != ""
	var rect := target.get_global_rect()
	_guide_mask.set_hole(rect)
	_place_focus_prompt(rect)


func _set_control_tree_mouse_filter(root: Node, filter: Control.MouseFilter) -> void:
	if root == null:
		return
	if root is Control:
		(root as Control).mouse_filter = filter
	for child in root.get_children():
		_set_control_tree_mouse_filter(child, filter)


func _refresh_focus_prompt_size() -> void:
	if _focus_prompt == null or _focus_prompt_label == null:
		return
	_focus_prompt_label.custom_minimum_size = Vector2.ZERO
	_focus_prompt.custom_minimum_size.x = FOCUS_PROMPT_MIN_WIDTH
	_focus_prompt.reset_size()
	var viewport_size := _focus_viewport_size()
	var natural_width := _focus_prompt_label.get_minimum_size().x + FOCUS_PROMPT_H_PADDING
	var available_width := maxf(FOCUS_PROMPT_MIN_WIDTH, viewport_size.x - FOCUS_PROMPT_MARGIN * 2.0)
	var max_width := minf(FOCUS_PROMPT_MAX_WIDTH, available_width)
	var prompt_width := clampf(natural_width, FOCUS_PROMPT_MIN_WIDTH, max_width)
	_focus_prompt.custom_minimum_size.x = prompt_width
	_focus_prompt_label.custom_minimum_size.x = maxf(1.0, prompt_width - FOCUS_PROMPT_H_PADDING)
	_focus_prompt.reset_size()
	_focus_prompt.size = _focus_prompt.get_combined_minimum_size()


func _place_focus_prompt(target_rect: Rect2) -> void:
	if not _focus_prompt.visible:
		return
	_refresh_focus_prompt_size()
	var prompt_size := _focus_prompt_size()
	var viewport_size := _focus_viewport_size()
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var avoid_rect := target_rect.grow(
		maxf(GuideMaskScript.HOLE_PADDING.x, GuideMaskScript.HOLE_PADDING.y) + FOCUS_PROMPT_GAP
	)
	var center := target_rect.get_center()
	var candidates: Array[Vector2] = [
		Vector2(center.x - prompt_size.x * 0.5, target_rect.end.y + FOCUS_PROMPT_GAP),
		Vector2(center.x - prompt_size.x * 0.5, target_rect.position.y - prompt_size.y - FOCUS_PROMPT_GAP),
		Vector2(target_rect.end.x + FOCUS_PROMPT_GAP, center.y - prompt_size.y * 0.5),
		Vector2(target_rect.position.x - prompt_size.x - FOCUS_PROMPT_GAP, center.y - prompt_size.y * 0.5),
	]
	for candidate in candidates:
		var pos := _clamp_focus_prompt_position(candidate, prompt_size, viewport_size)
		var prompt_rect := Rect2(pos, prompt_size)
		if viewport_rect.encloses(prompt_rect) and not prompt_rect.intersects(avoid_rect):
			_focus_prompt.position = pos
			return
	_focus_prompt.position = _best_effort_focus_prompt_position(target_rect, prompt_size, viewport_size)


func _focus_prompt_size() -> Vector2:
	var prompt_size := _focus_prompt.size
	var minimum := _focus_prompt.get_combined_minimum_size()
	if prompt_size.x <= 1.0 or prompt_size.y <= 1.0:
		prompt_size = minimum
	else:
		prompt_size.x = maxf(prompt_size.x, minimum.x)
		prompt_size.y = maxf(prompt_size.y, minimum.y)
	if prompt_size.x <= 1.0 or prompt_size.y <= 1.0:
		prompt_size = Vector2(FOCUS_PROMPT_MIN_WIDTH, 52.0)
	return prompt_size


func _focus_viewport_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	return get_viewport_rect().size


func _clamp_focus_prompt_position(pos: Vector2, prompt_size: Vector2, viewport_size: Vector2) -> Vector2:
	var max_x := maxf(FOCUS_PROMPT_MARGIN, viewport_size.x - prompt_size.x - FOCUS_PROMPT_MARGIN)
	var max_y := maxf(FOCUS_PROMPT_MARGIN, viewport_size.y - prompt_size.y - FOCUS_PROMPT_MARGIN)
	return Vector2(
		clampf(pos.x, FOCUS_PROMPT_MARGIN, max_x),
		clampf(pos.y, FOCUS_PROMPT_MARGIN, max_y)
	)


func _best_effort_focus_prompt_position(
	target_rect: Rect2,
	prompt_size: Vector2,
	viewport_size: Vector2
) -> Vector2:
	var spaces := {
		"below": viewport_size.y - target_rect.end.y - FOCUS_PROMPT_MARGIN,
		"above": target_rect.position.y - FOCUS_PROMPT_MARGIN,
		"right": viewport_size.x - target_rect.end.x - FOCUS_PROMPT_MARGIN,
		"left": target_rect.position.x - FOCUS_PROMPT_MARGIN,
	}
	var best_side := "below"
	var best_space := -1.0
	for side in spaces.keys():
		var space := float(spaces[side])
		if space > best_space:
			best_side = str(side)
			best_space = space
	var center := target_rect.get_center()
	var pos := Vector2(center.x - prompt_size.x * 0.5, target_rect.end.y + FOCUS_PROMPT_GAP)
	match best_side:
		"above":
			pos = Vector2(center.x - prompt_size.x * 0.5, target_rect.position.y - prompt_size.y - FOCUS_PROMPT_GAP)
		"right":
			pos = Vector2(target_rect.end.x + FOCUS_PROMPT_GAP, center.y - prompt_size.y * 0.5)
		"left":
			pos = Vector2(target_rect.position.x - prompt_size.x - FOCUS_PROMPT_GAP, center.y - prompt_size.y * 0.5)
	return _clamp_focus_prompt_position(pos, prompt_size, viewport_size)


func _find_target(root: Node, target: String) -> Control:
	if target == "":
		return null
	var found := _find_target_recursive(root, target)
	if found != null:
		return found
	var tree := get_tree()
	if tree == null:
		return null
	var scene_manager := tree.root.get_node_or_null("SceneManager")
	if scene_manager != null and scene_manager.has_method("get_scene_root"):
		found = _find_target_recursive(scene_manager.call("get_scene_root"), target)
		if found != null:
			return found
	return null


func _find_target_recursive(root: Node, target: String) -> Control:
	if root == null:
		return null
	if root is CanvasItem and not (root as CanvasItem).is_visible_in_tree():
		return null
	if root.name == target and root is Control and _is_valid_focus_target(root as Control):
		return root as Control
	for i in range(root.get_child_count() - 1, -1, -1):
		var found := _find_target_recursive(root.get_child(i), target)
		if found != null:
			return found
	return null


func _is_valid_focus_target(control: Control) -> bool:
	if not control.is_visible_in_tree():
		return false
	var rect := control.get_global_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return false
	return Rect2(Vector2.ZERO, _focus_viewport_size()).intersects(rect)


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
