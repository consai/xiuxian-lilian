extends Control

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const ItemViewScript := preload("res://scenes/items/item.gd")

const MODE_IDS := ["cycle", "insight", "breathing", "pill"]
const DAY_OPTIONS := [1, 3, 7]

@onready var _player_label: Label = %PlayerLabel
@onready var _day_label: Label = %DayLabel
@onready var _method_label: Label = %MethodLabel
@onready var _mastery_label: Label = %MasteryLabel
@onready var _mastery_bar: ProgressBar = %MasteryBar
@onready var _knowledge_label: Label = %KnowledgeLabel
@onready var _mode_description: Label = %ModeDescription
@onready var _preview_label: Label = %PreviewLabel
@onready var _result_label: Label = %ResultLabel
@onready var _start_button: Button = %StartButton
@onready var _mode_buttons: Array[Button] = [%CycleButton, %InsightButton, %BreathingButton, %PillButton]
@onready var _day_buttons: Array[Button] = [%OneDayButton, %ThreeDayButton, %SevenDayButton]
@onready var _pill_select_row: Control = %PillSelectRow
@onready var _pill_slot: ItemView = %PillSlot
@onready var _pill_hint: Label = %PillHint
@onready var _pill_picker: LoadoutBagPopup = %PillPicker

var _mode_id := "cycle"
var _days := 1
var _selected_pill_id := ""


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	for index in _mode_buttons.size():
		_mode_buttons[index].pressed.connect(_select_mode.bind(MODE_IDS[index]))
	for index in _day_buttons.size():
		_day_buttons[index].pressed.connect(_select_days.bind(DAY_OPTIONS[index]))
	_pill_slot.click_enabled = true
	_pill_slot.show_info_on_click = false
	_pill_slot.clicked.connect(_on_pill_slot_clicked)
	_pill_picker.entry_picked.connect(_on_pill_picked)
	_refresh()


func _refresh() -> void:
	if _mode_id == "pill":
		_selected_pill_id = GameState.resolve_cultivation_pill_id(_selected_pill_id)
	var preview: Dictionary = _build_preview()
	_player_label.text = "%s · %s" % [GameState.player_name, GameState.realm_name]
	_day_label.text = "第 %d 日" % GameState.day
	_pill_select_row.visible = _mode_id == "pill"
	_refresh_pill_slot(preview)
	if not bool(preview.get("ok", false)):
		var method_preview: Dictionary = GameState.preview_cultivation_session("cycle", _days)
		if bool(method_preview.get("ok", false)):
			_bind_method_preview(method_preview)
		else:
			_method_label.text = "尚未装备主功法"
			_mastery_label.text = "功法熟练度 0%"
			_mastery_bar.value = 0.0
			_knowledge_label.text = "装备主功法后方可运功修炼。"
		_mode_description.text = _format_mode_description(
			GameState.CULTIVATION_MODES.get(_mode_id, {}) as Dictionary,
			preview
		)
		_preview_label.text = str(preview.get("error", "当前无法修炼"))
		_start_button.disabled = true
		_start_button.text = "暂不可闭关"
		_update_button_states()
		return
	var mode := preview.get("mode", {}) as Dictionary
	_bind_method_preview(preview)
	_mode_description.text = _format_mode_description(mode, preview)
	var preview_text := (
		"闭关 %d 日\n预计修为 +%d\n第 %d 日 → 第 %d 日"
	) % [
		_days,
		int(preview.get("estimated_cultivation", 0)),
		int(preview.get("start_day", GameState.day)),
		int(preview.get("end_day", GameState.day + _days)),
	]
	if int(preview.get("instability_gain", 0)) > 0:
		var pill_id := str(preview.get("pill_id", ""))
		var pill_name := ConfigManager.get_item_display_name(pill_id)
		preview_text += "\n消耗%s x%d · 境界虚浮 +%d" % [
			pill_name,
			_days,
			int(preview.get("instability_gain", 0)),
		]
	preview_text += "\n\n世界时间将在闭关期间正常流逝。"
	_preview_label.text = preview_text
	_start_button.disabled = false
	_start_button.text = "开始闭关"
	_result_label.text = ""
	_update_button_states()


func _bind_method_preview(preview: Dictionary) -> void:
	_method_label.text = str(preview.get("method_name", "主功法"))
	var mastery := float(preview.get("method_mastery", 0.0))
	_mastery_label.text = "功法熟练度 %d%%" % int(round(mastery * 100.0))
	_mastery_bar.value = mastery * 100.0
	_knowledge_label.text = _format_knowledge_routes(preview.get("knowledge_rows", []) as Array)


func _build_preview() -> Dictionary:
	if _mode_id == "pill":
		return GameState.preview_cultivation_session(_mode_id, _days, _selected_pill_id)
	return GameState.preview_cultivation_session(_mode_id, _days)


func _format_mode_description(mode: Dictionary, preview: Dictionary) -> String:
	if _mode_id != "pill":
		return str(mode.get("description", ""))
	var pill_id := str(preview.get("pill_id", ""))
	if pill_id == "":
		return "点击选择修炼丹药后打坐炼化，修为增长极快，但会积累境界虚浮。"
	var multiplier: float = GameState.cultivation_pill_multiplier(pill_id)
	var pill_name := ConfigManager.get_item_display_name(pill_id)
	return "炼化【%s】，修为增长约为普通周天的 %.0f 倍，但会积累境界虚浮。" % [
		pill_name,
		multiplier,
	]


func _refresh_pill_slot(preview: Dictionary) -> void:
	if _mode_id != "pill":
		return
	var pill_id := str(preview.get("pill_id", ""))
	if pill_id == "":
		_pill_slot.apply_empty(null)
		_pill_hint.text = "点击选择修炼丹药"
		return
	var owned := int(GameState.inventory.get(pill_id, 0))
	ItemViewScript.apply_item_id(_pill_slot, pill_id, owned, {
		"show_name": true,
		"name_override": "%s %d" % [ConfigManager.get_item_display_name(pill_id), owned],
		"show_info_on_click": false,
		"click_enabled": true,
	})
	_pill_hint.text = "点击更换修炼丹药"


func _format_knowledge_routes(rows: Array) -> String:
	var lines: PackedStringArray = ["本功法可领悟"]
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if not bool(row.get("gainFromCultivation", true)):
			continue
		var skill_id := str(row.get("skillId", ""))
		var skill := DaoTreeServiceScript.skill_by_id(skill_id)
		lines.append("· %s  上限 %s 级" % [
			str(skill.get("name", skill_id)),
			str(row.get("capLevel", 5)),
		])
	if lines.size() == 1:
		lines.append("· 当前功法没有可通过修炼增长的知识")
	return "\n".join(lines)


func _select_mode(mode_id: String) -> void:
	_mode_id = mode_id
	if mode_id == "pill":
		_selected_pill_id = GameState.resolve_cultivation_pill_id(_selected_pill_id)
	_refresh()
	if mode_id == "pill":
		TutorialService.game_event("tutorial.pill_mode_selected")


func _select_days(days: int) -> void:
	_days = days
	_refresh()


func _on_pill_slot_clicked() -> void:
	if _mode_id != "pill":
		return
	_pill_picker.open_for_cultivation_pill()


func _on_pill_picked(entry: Dictionary) -> void:
	_selected_pill_id = str(entry.get("id", ""))
	_refresh()


func _update_button_states() -> void:
	for index in _mode_buttons.size():
		_mode_buttons[index].modulate = Color(0.72, 0.9, 0.62) if MODE_IDS[index] == _mode_id else Color.WHITE
	for index in _day_buttons.size():
		_day_buttons[index].modulate = Color(0.72, 0.9, 0.62) if DAY_OPTIONS[index] == _days else Color.WHITE


func _on_start_pressed() -> void:
	var preview: Dictionary = _build_preview()
	if not bool(preview.get("ok", false)):
		_result_label.text = str(preview.get("error", "修炼失败"))
		return
	var mode := preview.get("mode", {}) as Dictionary
	var session := {
		"mode_id": _mode_id,
		"days": _days,
		"method_name": str(preview.get("method_name", "主功法")),
		"mode_name": str(mode.get("name", "运转周天")),
		"start_day": int(preview.get("start_day", GameState.day)),
	}
	if _mode_id == "pill":
		session["pill_id"] = str(preview.get("pill_id", ""))
	var nav: Dictionary = SceneManager.go_cultivation_progress(session)
	if not bool(nav.get("ok", false)):
		_result_label.text = str(nav.get("error", "无法开始闭关"))
		return
	TutorialService.game_event("tutorial.cultivation_started")


func _on_close_pressed() -> void:
	var nav: Dictionary = SceneManager.go_hub()
	if not bool(nav.get("ok", false)):
		push_warning(str(nav.get("error", "无法返回洞府")))
