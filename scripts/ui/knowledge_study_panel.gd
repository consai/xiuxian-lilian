extends Control

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")

@onready var _player_label: Label = %PlayerLabel
@onready var _day_label: Label = %DayLabel
@onready var _close_button: Button = %CloseButton
@onready var _skill_list: ItemList = %SkillList
@onready var _empty_label: Label = %EmptyLabel
@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _state_label: Label = %StateLabel
@onready var _progress: ProgressBar = %Progress
@onready var _preview_label: Label = %PreviewLabel
@onready var _day_slider: HSlider = %DaySlider
@onready var _day_count_label: Label = %DayCountLabel
@onready var _max_button: Button = %MaxButton
@onready var _start_button: Button = %StartButton
@onready var _result_label: Label = %ResultLabel

var _rows: Array = []
var _selected_skill_id := ""
var _days := 1


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_skill_list.item_selected.connect(_on_item_selected)
	_day_slider.value_changed.connect(_on_day_changed)
	_max_button.pressed.connect(_on_max_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_player_label.text = "%s · %s" % [GameState.player_name, GameState.realm_name]
	_day_label.text = GameState.time_date_label(GameState.day)
	_rows = GameState.studyable_knowledge()
	_bind_list()
	if _selected_skill_id == "" and not _rows.is_empty():
		_selected_skill_id = str((_rows.front() as Dictionary).get("id", ""))
		_skill_list.select(0)
	_bind_details()


func _bind_list() -> void:
	_skill_list.clear()
	_empty_label.visible = _rows.is_empty()
	for row_v in _rows:
		var row := row_v as Dictionary
		var skill_id := str(row.get("id", ""))
		var skill := DaoTreeServiceScript.skill_by_id(skill_id)
		var domain := DaoTreeServiceScript.domain_by_id(str(skill.get("domain", "")))
		var level := int(row.get("level", 0))
		var label := "%s  %s  · %s" % [
			str(row.get("name", skill_id)),
			_roman(level) if level > 0 else "未入门",
			str(domain.get("name", "")),
		]
		_skill_list.add_item(label)


func _bind_details() -> void:
	if _selected_skill_id == "":
		_name_label.text = "暂无可自主学习的知识"
		_description_label.text = "当前没有满足境界与前置条件、且未达到自主学习上限的知识。"
		_state_label.text = ""
		_progress.value = 0.0
		_preview_label.text = ""
		_day_count_label.text = "研读 1日"
		_start_button.disabled = true
		return
	var skill := DaoTreeServiceScript.skill_by_id(_selected_skill_id)
	var entry := KnowledgeServiceScript.get_entry(GameState.to_dict(), _selected_skill_id)
	var level := int(entry.get("level", 0))
	var max_days := maxi(1, GameState.max_knowledge_study_days(_selected_skill_id))
	_days = clampi(_days, 1, max_days)
	_day_slider.max_value = float(max_days)
	_day_slider.set_value_no_signal(float(_days))
	_max_button.disabled = max_days <= 1
	_name_label.text = "%s  %s" % [str(skill.get("name", "")), _roman(level) if level > 0 else "未入门"]
	_description_label.text = str(skill.get("description", ""))
	var preview := GameState.preview_knowledge_study(_selected_skill_id, _days)
	_progress.max_value = 100.0
	_progress.value = KnowledgeServiceScript.level_progress_percent(GameState.to_dict(), _selected_skill_id)
	var domain := DaoTreeServiceScript.domain_by_id(str(skill.get("domain", "")))
	_state_label.text = "%s · 自主学习上限 %s · 当前 %.0f%%" % [
		str(domain.get("name", "")),
		_roman(int(preview.get("max_self_study_level", 3))) if bool(preview.get("ok", false)) else "—",
		_progress.value,
	]
	_day_count_label.text = "研读 %s" % GameState.time_duration_label(_days)
	if not bool(preview.get("ok", false)):
		_preview_label.text = str(preview.get("error", "当前无法研读"))
		_start_button.disabled = true
		return
	var after_level := int(preview.get("level_after", level))
	var levels_gained := int(preview.get("levels_gained", 0))
	var level_text := _roman(level) if level > 0 else "未入门"
	var after_text := _roman(after_level) if after_level > 0 else "未入门"
	_preview_label.text = "预计训练点 +%.1f\n%s → %s%s\n%s 至 %s\n\n自主学习用于补课与冲门槛，无法替代功法带来的高阶领悟。" % [
		float(preview.get("xp", 0.0)),
		level_text,
		after_text,
		"（提升 %d 级）" % levels_gained if levels_gained > 0 else "",
		str(preview.get("start_date_label", "")),
		str(preview.get("end_date_label", "")),
	]
	_preview_label.text += "\n\n训练速度 %.1f 点/日 · 难度 rank %d\n距下一级还需 %.1f 点，约 %s" % [
		float(preview.get("training_speed", 0.0)),
		int(preview.get("rank", 1)),
		float(preview.get("points_to_next", 0.0)),
		GameState.time_duration_label(int(preview.get("estimated_days_to_next", 0))),
	]
	_start_button.disabled = false


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	_selected_skill_id = str((_rows[index] as Dictionary).get("id", ""))
	_days = 1
	_result_label.text = ""
	_bind_details()


func _on_day_changed(value: float) -> void:
	_days = int(round(value))
	_bind_details()


func _on_max_pressed() -> void:
	_days = int(round(_day_slider.max_value))
	_bind_details()


func _on_start_pressed() -> void:
	if _selected_skill_id == "":
		return
	var result := GameState.study_knowledge(_selected_skill_id, _days)
	if not bool(result.get("ok", false)):
		_result_label.text = str(result.get("error", "研读失败"))
		return
	var level_after := int(result.get("level_after", 0))
	_result_label.text = "研读完成：%s 训练点 +%.1f%s" % [
		str(result.get("skill_name", "")),
		float(result.get("xp", 0.0)),
		"，提升至%s" % _roman(level_after) if int(result.get("levels_gained", 0)) > 0 else "",
	]
	_selected_skill_id = ""
	_days = 1
	_refresh()


func _on_close_pressed() -> void:
	var nav: Dictionary = SceneManager.go_hub()
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回洞府")))


func _roman(level: int) -> String:
	match level:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		_:
			return "—"
