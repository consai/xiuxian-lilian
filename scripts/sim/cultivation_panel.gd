extends Control

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const ItemViewScript := preload("res://scenes/items/item.gd")

const MODE_IDS := EnumCultivationMode.MODE_IDS

@onready var _player_label: Label = %PlayerLabel
@onready var _day_label: Label = %DayLabel
@onready var _method_label: Label = %MethodLabel
@onready var _method_change_button: Button = %MethodChangeButton
@onready var _mastery_label: Label = %MasteryLabel
@onready var _mastery_bar: ProgressBar = %MasteryBar
@onready var _knowledge_label: Label = %KnowledgeLabel
@onready var _mode_description: Label = %ModeDescription
@onready var _preview_label: Label = %PreviewLabel
@onready var _formula_label: Label = %FormulaLabel
@onready var _preview_meta_label: Label = %PreviewMetaLabel
@onready var _result_label: Label = %ResultLabel
@onready var _start_button: Button = %StartButton
@onready var _mode_buttons: Array[Button] = [%CycleButton, %InsightButton, %BreathingButton, %PillButton]
@onready var _day_count_label: Label = %DayCountLabel
@onready var _day_slider: HSlider = %DaySlider
@onready var _day_max_button: Button = %DayMaxButton
@onready var _pill_select_row: Control = %PillSelectRow
@onready var _pill_slot: ItemView = %PillSlot
@onready var _pill_hint: Label = %PillHint
@onready var _pill_picker: LoadoutBagPopup = %PillPicker
@onready var _method_picker: LoadoutSelectionPopup = %MethodPicker

var _mode_id := EnumCultivationMode.LABEL_CYCLE
var _months := 0
var _selected_pill_id := ""


func _ready() -> void:
	%CloseButton.pressed.connect(_on_close_pressed)
	_method_change_button.pressed.connect(_on_method_change_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	for index in _mode_buttons.size():
		_mode_buttons[index].pressed.connect(_select_mode.bind(MODE_IDS[index]))
	_day_slider.value_changed.connect(_on_day_slider_changed)
	_day_max_button.pressed.connect(_on_day_max_pressed)
	_pill_slot.click_enabled = true
	_pill_slot.show_info_on_click = false
	_pill_slot.clicked.connect(_on_pill_slot_clicked)
	_pill_picker.entry_picked.connect(_on_pill_picked)
	_method_picker.selected.connect(_on_method_picked)
	_refresh()


func _refresh() -> void:
	if EnumCultivationMode.is_pill_mode(_mode_id):
		_selected_pill_id = GameState.resolve_cultivation_pill_id(_selected_pill_id)
	_sync_day_slider()
	var preview: Dictionary = _build_preview()
	_player_label.text = "%s · %s" % [GameState.player_name, GameState.realm_name]
	_day_label.text = GameState.time_date_label(GameState.day)
	_pill_select_row.visible = EnumCultivationMode.is_pill_mode(_mode_id)
	_refresh_pill_slot(preview)
	if not bool(preview.get("ok", false)):
		var method_preview: Dictionary = GameState.preview_cultivation_session(EnumCultivationMode.LABEL_CYCLE, _cultivation_days())
		if bool(method_preview.get("ok", false)):
			_bind_method_preview(method_preview)
		else:
			_method_label.text = "尚未装备主功法"
			_mastery_label.text = "功法熟练度 0%"
			_mastery_bar.value = 0.0
			_knowledge_label.text = "装备主功法后方可运功修炼。"
		_mode_description.text = _format_mode_description(
			EnumCultivationMode.config(_mode_id),
			preview
		)
		_preview_label.text = str(preview.get("error", "当前无法修炼"))
		_formula_label.text = ""
		_formula_label.visible = false
		_preview_meta_label.text = ""
		_preview_meta_label.visible = false
		_start_button.disabled = true
		_start_button.text = "暂不可闭关"
		_update_button_states()
		return
	var mode := preview.get("mode", {}) as Dictionary
	_bind_method_preview(preview)
	_mode_description.text = _format_mode_description(mode, preview)
	var formula_text := _format_cultivation_formula(preview)
	_preview_label.text = "闭关 %s\n预计修为 +%d" % [
		str(preview.get("duration_label", GameState.time_duration_label(_cultivation_days()))),
		int(preview.get("estimated_cultivation", 0)),
	]
	var meta_text := "%s → %s" % [
		str(preview.get("start_date_label", "")),
		str(preview.get("end_date_label", "")),
	]
	if int(preview.get("instability_gain", 0)) > 0:
		var pill_id := str(preview.get("pill_id", ""))
		var pill_name := ConfigManager.get_item_display_name(pill_id)
		meta_text += "\n消耗%s x%d · 灵力驳杂 +%d" % [
			pill_name,
			_months,
			int(preview.get("instability_gain", 0)),
		]
	meta_text += "\n\n世界时间将在闭关期间正常流逝。"
	_formula_label.text = formula_text
	_formula_label.visible = formula_text != ""
	_preview_meta_label.text = meta_text
	_preview_meta_label.visible = true
	_start_button.disabled = false
	_start_button.text = "开始闭关（%s）" % str(preview.get("duration_label", GameState.time_duration_label(_cultivation_days())))
	_result_label.text = ""
	_update_button_states()


func _sync_day_slider() -> void:
	var min_months := GameState.min_cultivation_months()
	var max_months := maxi(min_months, GameState.max_cultivation_months(_mode_id, _selected_pill_id))
	_day_slider.min_value = float(min_months)
	_day_slider.max_value = float(max_months)
	if _months < min_months:
		_months = max_months
	_months = clampi(_months, min_months, max_months)
	if int(round(_day_slider.value)) != _months:
		_day_slider.set_value_no_signal(float(_months))
	_day_max_button.disabled = max_months <= min_months
	_day_count_label.text = "闭关 %s" % GameState.time_duration_label(_cultivation_days())


func _cultivation_days() -> int:
	return _months * GameTimeService.days_per_month()


func _on_day_slider_changed(value: float) -> void:
	var new_months := int(round(value))
	if new_months == _months:
		return
	_months = new_months
	_day_count_label.text = "闭关 %s" % GameState.time_duration_label(_cultivation_days())
	_refresh()


func _on_day_max_pressed() -> void:
	_day_slider.value = _day_slider.max_value


func _bind_method_preview(preview: Dictionary) -> void:
	_method_label.text = str(preview.get("method_name", "主功法"))
	var mastery := float(preview.get("method_mastery", 0.0))
	_mastery_label.text = "功法熟练度 %d%%" % int(round(mastery * 100.0))
	_mastery_bar.value = mastery * 100.0
	_knowledge_label.text = _format_knowledge_routes(preview.get("knowledge_rows", []) as Array)


func _build_preview() -> Dictionary:
	if EnumCultivationMode.is_pill_mode(_mode_id):
		return GameState.preview_cultivation_session(_mode_id, _cultivation_days(), _selected_pill_id)
	return GameState.preview_cultivation_session(_mode_id, _cultivation_days())


func _format_mode_description(mode: Dictionary, preview: Dictionary) -> String:
	if not EnumCultivationMode.is_pill_mode(_mode_id):
		return str(mode.get("description", ""))
	var pill_id := str(preview.get("pill_id", ""))
	if pill_id == "":
		return "点击选择修炼丹药后打坐炼化，修为增长极快，但会使灵力驳杂。"
	var multiplier: float = GameState.cultivation_pill_multiplier(pill_id)
	var pill_name := ConfigManager.get_item_display_name(pill_id)
	return "炼化【%s】，修为增长约为普通周天的 %.0f 倍，但会使灵力驳杂。" % [
		pill_name,
		multiplier,
	]


func _refresh_pill_slot(preview: Dictionary) -> void:
	if not EnumCultivationMode.is_pill_mode(_mode_id):
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


func _format_cultivation_formula(preview: Dictionary) -> String:
	var formula := preview.get("cultivation_formula", {}) as Dictionary
	if formula.is_empty():
		return ""
	var speed_part := int(formula.get("speed_part", 0))
	var method_gain := int(formula.get("method_base_gain", 0))
	var monthly := int(formula.get("monthly_total", speed_part + method_gain))
	var months := int(formula.get("months", 1))
	var monthly_gains := formula.get("monthly_gains", []) as Array
	var injury_mult := float(formula.get("injury_multiplier", 1.0))
	if injury_mult < 1.0:
		return "每月 %d + 功法 %d = %d（受伤 ×%.1f）" % [
			speed_part, method_gain, monthly, injury_mult,
		]
	if months > 1:
		var uniform := true
		for gain_v in monthly_gains:
			if int(gain_v) != monthly:
				uniform = false
				break
		if uniform:
			return "每月 %d + 功法 %d = %d × %d月" % [
				speed_part, method_gain, monthly, months,
			]
		return "合计 +%d（各月受伤状态不同）" % int(preview.get("estimated_cultivation", 0))
	return "每月 %d + 功法 %d = %d" % [speed_part, method_gain, monthly]


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
		lines.append("· %s" % str(skill.get("name", skill_id)))
	if lines.size() == 1:
		lines.append("· 当前功法没有可通过修炼增长的知识")
	return "\n".join(lines)


func _select_mode(mode_id: String) -> void:
	_mode_id = mode_id
	if EnumCultivationMode.is_pill_mode(mode_id):
		_selected_pill_id = GameState.resolve_cultivation_pill_id(_selected_pill_id)
	_refresh()
	if EnumCultivationMode.is_pill_mode(mode_id):
		TutorialService.game_event("tutorial.pill_mode_selected")


func _on_pill_slot_clicked() -> void:
	if not EnumCultivationMode.is_pill_mode(_mode_id):
		return
	_pill_picker.open_for_cultivation_pill()


func _on_pill_picked(entry: Dictionary) -> void:
	_selected_pill_id = str(entry.get("id", ""))
	_refresh()


func _on_method_change_pressed() -> void:
	_method_picker.open_for("method", "main")


func _on_method_picked(entry_id: Variant) -> void:
	var result: Dictionary = GameState.equip_method("main", str(entry_id))
	if not bool(result.get("ok", false)):
		_result_label.text = str(result.get("error", "无法替换主修功法"))
		return
	_refresh()
	_result_label.text = "已替换当前主修功法。"


func _update_button_states() -> void:
	for index in _mode_buttons.size():
		_mode_buttons[index].modulate = Color(0.72, 0.9, 0.62) if MODE_IDS[index] == _mode_id else Color.WHITE


func _on_start_pressed() -> void:
	var preview: Dictionary = _build_preview()
	if not bool(preview.get("ok", false)):
		_result_label.text = str(preview.get("error", "修炼失败"))
		return
	var mode := preview.get("mode", {}) as Dictionary
	var session := {
		"mode_id": _mode_id,
		"days": _cultivation_days(),
		"method_name": str(preview.get("method_name", "主功法")),
		"mode_name": str(mode.get("name", "运转周天")),
		"start_day": int(preview.get("start_day", GameState.day)),
	}
	if EnumCultivationMode.is_pill_mode(_mode_id):
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
