extends Control

const ORIGIN_TYPE := "origin"
const ROOT_TYPE := "root"
const TALENT_TYPE := "talent"
const ChoiceCardScene := preload("res://scenes/ui/components/juese_choice_card.tscn")
const CharacterCreationApplicationScript := preload(
	"res://scripts/features/character/application/character_creation_application.gd"
)

var _step := 0
var _selected: Dictionary = {"origin_id": "", "root_id": "", "talent_id": ""}
var _cards: Array = []

@onready var _name_input: LineEdit = %NameInput
@onready var _step_heading: Label = %StepHeading
@onready var _step_hint: Label = %StepHint
@onready var _message_label: Label = %MessageLabel
@onready var _next_button: Button = %NextButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
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
	var query: Dictionary = CharacterCreationApplicationScript.query_choices(
		str(meta["choice_type"])
	)
	if not bool(query.get("ok", false)):
		for card_v in _cards:
			(card_v as Button).visible = false
		_message_label.text = str(query.get("message", "角色创建配置无效"))
		return
	var rows: Array = (query.get("value", []) as Array).duplicate(true)
	while _cards.size() < rows.size():
		var card := ChoiceCardScene.instantiate()
		%ChoiceCards.add_child(card)
		_cards.append(card)
		card.chosen.connect(_choose)
	for i in _cards.size():
		var card: Button = _cards[i]
		card.visible = i < rows.size()
		if i < rows.size():
			var row: Dictionary = rows[i]
			card.call("set_choice", row, _bonus(row))
			card.call("set_selected", str(card.get("choice_id")) == str(_selected[meta["selected"]]))


func _meta() -> Dictionary:
	return [
		{"title": "选择出身", "hint": "不同出身，将为你的修行带来不同助益", "next": "确认出身", "choice_type": ORIGIN_TYPE, "selected": "origin_id"},
		{"title": "选择灵根", "hint": "灵根决定修行资质与功法契合", "next": "确认灵根", "choice_type": ROOT_TYPE, "selected": "root_id"},
		{"title": "先天天赋 · 三选一", "hint": "选择一个伴随开局的天赋", "next": "踏入仙途", "choice_type": TALENT_TYPE, "selected": "talent_id"},
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
	if name.length() < 1 or name.length() > 12:
		_message_label.text = "角色名称须为 1–12 个字符。"
		return
	GameState.new_game({
		"player_name": name,
		"origin_id": _selected["origin_id"],
		"root_id": _selected["root_id"],
		"talent_id": _selected["talent_id"],
	})
	var nav: Dictionary = LilianFlowService.open_hub(
		LilianState,
		SceneManager,
		{},
		{"reset_history": true}
	)
	if not bool(nav.get("ok", false)):
		_message_label.text = str(nav.get("error", "进入游戏失败"))


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
