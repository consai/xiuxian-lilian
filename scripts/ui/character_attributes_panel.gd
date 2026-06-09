extends Control

const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")
const BTN_ACTIVE := preload("res://assets/art/ui_new/btn_lv.png")
const BTN_INACTIVE := preload("res://assets/art/ui_new/btn_mihuang.png")

enum Tab { ATTRIBUTES, EXPERIENCE, STATISTICS }

@onready var _close_button: TextureButton = %CloseButton
@onready var _portrait: TextureRect = %Portrait
@onready var _character_name: Label = %CharacterName
@onready var _realm: Label = %Realm
@onready var _cultivation_bar: ProgressBar = %CultivationBar
@onready var _cultivation_value: Label = %CultivationValue
@onready var _day_label: Label = %DayLabel
@onready var _injury_label: Label = %InjuryLabel
@onready var _stone_label: Label = %StoneLabel
@onready var _hp_bar: ProgressBar = %HpBar
@onready var _hp_value: Label = %HpValue
@onready var _mp_bar: ProgressBar = %MpBar
@onready var _mp_value: Label = %MpValue
@onready var _attack: Panel = %Attack
@onready var _defense: Panel = %Defense
@onready var _speed: Panel = %Speed
@onready var _crit: Panel = %Crit
@onready var _crit_damage: Panel = %CritDamage
@onready var _shield: Panel = %Shield
@onready var _attributes_card: Panel = %AttributesCard
@onready var _other_attr: Panel = %OtherAttr
@onready var _other_attr_heading: Label = %OtherAttrHeading
@onready var _biography: Label = %BiographyLabel
@onready var _attributes_tab: TextureButton = %AttributesTab
@onready var _experience_tab: TextureButton = %ExperienceTab
@onready var _statistics_tab: TextureButton = %StatisticsTab

var _active_tab: Tab = Tab.ATTRIBUTES


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_attributes_tab.pressed.connect(func() -> void: _select_tab(Tab.ATTRIBUTES))
	_experience_tab.pressed.connect(func() -> void: _select_tab(Tab.EXPERIENCE))
	_statistics_tab.pressed.connect(func() -> void: _select_tab(Tab.STATISTICS))
	_select_tab(Tab.ATTRIBUTES)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_bind_identity()
	_bind_vitals()
	_bind_combat_stats()
	_refresh_tab_content()


func _bind_identity() -> void:
	_character_name.text = GameState.player_name
	_realm.text = GameState.realm_name
	var breakthrough_at := maxi(1, GameState.breakthrough_at)
	_cultivation_bar.max_value = float(breakthrough_at)
	_cultivation_bar.value = float(GameState.cultivation)
	_cultivation_value.text = "%d / %d" % [GameState.cultivation, breakthrough_at]
	_day_label.text = "第 %d 日" % GameState.day
	if GameState.injury_days <= 0:
		_injury_label.text = "伤势：无"
	else:
		_injury_label.text = "伤势：%d 日" % GameState.injury_days
	_stone_label.text = "灵石 %d" % GameState.ling_stones
	_portrait.texture = BattleInitDataScript._resolve_icon_texture({"icon": GameState.player_icon})


func _bind_vitals() -> void:
	var hp_max := FightAttr.get_attr(GameState.attrs, FightAttr.HP_MAX, 100.0)
	var mp_max := FightAttr.get_attr(GameState.attrs, FightAttr.MP_MAX, 100.0)
	_hp_bar.max_value = hp_max
	_hp_bar.value = GameState.hp
	_hp_value.text = "%.0f/%.0f" % [GameState.hp, hp_max]
	_mp_bar.max_value = mp_max
	_mp_bar.value = GameState.mp
	_mp_value.text = "%.0f/%.0f" % [GameState.mp, mp_max]


func _bind_combat_stats() -> void:
	var attrs := GameState.attrs
	_set_stat_slot(_attack, "攻击", "%.0f" % FightAttr.get_attr(attrs, FightAttr.ATK, 0.0))
	_set_stat_slot(_defense, "防御", "%.0f" % FightAttr.get_attr(attrs, FightAttr.DEF, 0.0))
	_set_stat_slot(_speed, "速度", "%.0f" % FightAttr.get_attr(attrs, FightAttr.SPD, 0.0))
	_set_stat_slot(_crit, "暴击", "%.0f%%" % FightAttr.get_attr(attrs, FightAttr.CRIT, 0.0))
	_set_stat_slot(
		_crit_damage,
		"暴伤",
		"%.0f%%" % FightAttr.get_attr(attrs, FightAttr.CRIT_DAMAGE, 100.0)
	)
	_set_stat_slot(_shield, "护盾", "%.0f" % FightAttr.get_attr(attrs, FightAttr.SHIELD, 0.0))


func _set_stat_slot(panel: Panel, title: String, value_text: String) -> void:
	var label := panel.get_node("Label") as Label
	label.text = "%s\n%s" % [title, value_text]


func _biography_text() -> String:
	if not GameState.activity_log.is_empty():
		var lines: PackedStringArray = []
		var start := maxi(0, GameState.activity_log.size() - 3)
		for i in range(start, GameState.activity_log.size()):
			lines.append(str((GameState.activity_log[i] as Dictionary).get("text", "")))
		return "\n".join(lines)
	return "%s入道，初踏仙途。" % GameState.player_name


func _select_tab(tab: Tab) -> void:
	_active_tab = tab
	_attributes_tab.texture_normal = BTN_ACTIVE if tab == Tab.ATTRIBUTES else BTN_INACTIVE
	_experience_tab.texture_normal = BTN_ACTIVE if tab == Tab.EXPERIENCE else BTN_INACTIVE
	_statistics_tab.texture_normal = BTN_ACTIVE if tab == Tab.STATISTICS else BTN_INACTIVE
	_refresh_tab_content()


func _refresh_tab_content() -> void:
	match _active_tab:
		Tab.ATTRIBUTES:
			_other_attr.visible = true
			_other_attr_heading.text = "其他属性"
			_biography.text = _biography_text()
		Tab.EXPERIENCE:
			_other_attr.visible = true
			_other_attr_heading.text = "经历"
			_biography.text = _experience_text()
		Tab.STATISTICS:
			_other_attr.visible = true
			_other_attr_heading.text = "统计"
			_biography.text = _statistics_text()


func _experience_text() -> String:
	if GameState.activity_log.is_empty():
		return "暂无经历记录。"
	var lines: PackedStringArray = ["近期经历"]
	for entry_v in GameState.activity_log.slice(-8):
		if entry_v is Dictionary:
			lines.append(str((entry_v as Dictionary).get("text", "")))
	return "\n".join(lines)


func _statistics_text() -> String:
	var totals := GameState.totals
	return "\n".join([
		"历练统计",
		"战斗 %d 场，胜 %d，负 %d" % [
			int(totals.get("battles", 0)),
			int(totals.get("wins", 0)),
			int(totals.get("losses", 0)),
		],
		"历练 %d 次，最深 %d 层" % [
			int(totals.get("expeditions", 0)),
			int(totals.get("max_depth", 0)),
		],
		"获得物品 %d 件，击败首领 %d" % [
			int(totals.get("items_gained", 0)),
			int(totals.get("bosses_defeated", 0)),
		],
	])


func _on_close_pressed() -> void:
	SceneManager.go_back()
