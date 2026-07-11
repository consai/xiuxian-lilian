extends Control

const CONFIG_PATH := "character_creation.json"
const ORIGINS_PATH := "character_origins.json"
const ROOTS_PATH := "character_roots.json"
const TALENTS_PATH := "character_talents.json"

var _step := 0
var _settings: Dictionary = {}
var _selected: Dictionary = {"origin_id": "", "root_id": "", "talent_id": ""}
var _cards: Array = []

@onready var _name_input: LineEdit = %NameInput
@onready var _step_heading: Label = %StepHeading
@onready var _step_hint: Label = %StepHint
@onready var _message_label: Label = %MessageLabel
@onready var _next_button: Button = %NextButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_settings = JsonLoader._export_keyed_rows(JsonLoader.export_path(CONFIG_PATH)).get("default", {})
	_name_input.max_length = int(_settings.get("nameMaxLength", 12))
	for child in %ChoiceCards.get_children():
		_cards.append(child)
		child.connect("chosen", Callable(self, "_choose"))
	_next_button.pressed.connect(_next)
	_back_button.pressed.connect(_back)
	_show_step()


func _show_step() -> void:
	var meta: Dictionary = _meta()
	_step_heading.text = str(meta["title"])
	_step_hint.text = str(meta["hint"])
	_next_button.text = str(meta["next"])
	_message_label.text = ""
	for button in [%Step1, %Step2, %Step3]:
		button.theme_type_variation = &"TabIdle"
	%Step1.theme_type_variation = &"" if _step == 0 else &"TabIdle"
	%Step2.theme_type_variation = &"" if _step == 1 else &"TabIdle"
	%Step3.theme_type_variation = &"" if _step == 2 else &"TabIdle"
	var rows: Array = _rows(str(meta["path"]))
	for i in _cards.size():
		var card: Button = _cards[i]
		card.visible = i < rows.size()
		if i < rows.size():
			var row: Dictionary = rows[i]
			card.call("set_choice", row, _bonus(row))
			card.call("set_selected", str(card.get("choice_id")) == str(_selected[meta["selected"]]))


func _meta() -> Dictionary:
	return [
		{"title": "选择出身", "hint": "不同出身，将为你的修行带来不同助益", "next": "确认出身", "path": ORIGINS_PATH, "ids": "originIds", "selected": "origin_id"},
		{"title": "选择灵根", "hint": "灵根决定修行资质与功法契合", "next": "确认灵根", "path": ROOTS_PATH, "ids": "rootIds", "selected": "root_id"},
		{"title": "先天天赋 · 三选一", "hint": "选择一个伴随开局的天赋", "next": "踏入仙途", "path": TALENTS_PATH, "ids": "talentIds", "selected": "talent_id"},
	][_step]


func _choose(id: String) -> void:
	_selected[_meta()["selected"]] = id
	_show_step()


func _next() -> void:
	var key := str(_meta()["selected"])
	if str(_selected[key]) == "":
		_message_label.text = "请先%s。" % str(_meta()["title"])
		return
	if _step < 2:
		_step += 1
		_show_step()
		return
	_finish()


func _back() -> void:
	if _step > 0:
		_step -= 1
		_show_step()
		return
	SceneManager.go_to(SceneManager.MAIN_MENU, {}, {"reset_history": true})


func _finish() -> void:
	var name := _name_input.text.strip_edges()
	if name.length() < int(_settings.get("nameMinLength", 1)):
		_message_label.text = "请输入角色名称。"
		return
	GameState.new_game({
		"player_name": name,
		"origin_id": _selected["origin_id"],
		"root_id": _selected["root_id"],
		"talent_id": _selected["talent_id"],
	})
	var nav: Dictionary = SceneManager.go_hub({}, {"reset_history": true})
	if not bool(nav.get("ok", false)):
		_message_label.text = str(nav.get("error", "进入游戏失败"))


func _rows(file_name: String) -> Array:
	var rows: Dictionary = JsonLoader._export_keyed_rows(JsonLoader.export_path(file_name))
	var out: Array = []
	for row_v in rows.values():
		if not row_v is Dictionary:
			continue
		var row: Dictionary = (row_v as Dictionary).duplicate(true)
		if not row.is_empty() and bool(row.get("enabled", true)):
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("sortOrder", 0)) < int(b.get("sortOrder", 0)))
	return out


func _ids(value: Variant) -> Array:
	var out: Array = []
	var parts: Array = []
	if value is Array:
		parts = value as Array
	else:
		parts = [value]
	for part in parts:
		for id in str(part).split(",", false):
			var trimmed := id.strip_edges()
			if trimmed != "":
				out.append(trimmed)
	return out


func _bonus(row: Dictionary) -> String:
	if row.has("starterSkillId"):
		var names: Array[String] = []
		for skill_id in _ids(row.get("starterSkillId", [])):
			var skill := AbilityService.by_id(skill_id)
			if skill.is_empty():
				push_error("%s 的 starterSkillId 不存在: %s" % [str(row.get("id", "")), skill_id])
				continue
			names.append(str(skill.get("name", skill_id)))
		return "初始术法：%s" % "、".join(names)
	if row.has("passiveid"):
		return "特性：%s" % str(row.get("name", ""))
	if row.has("effectValue"):
		return "%s +%d%%" % [str(row.get("effectKey", "")), int(round(float(row.get("effectValue", 0.0)) * 100.0))]
	return ""
