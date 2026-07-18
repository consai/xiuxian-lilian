extends Control

const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
var BTN_ACTIVE := Tools.load_image("res://assets/art/ui_new/btn_lv.png")
var BTN_INACTIVE := Tools.load_image("res://assets/art/ui_new/btn_mihuang.png")
var _tutorial_coordinator: Node
var _lilian_session_host: Node
var _game_session_host: Node


func bind_tutorial_coordinator(coordinator: Node) -> void:
	_tutorial_coordinator = coordinator


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host


func _game_session() -> Node:
	if _game_session_host == null:
		push_error("CharacterAttributesPanel: GameSessionHost 未注入")
		return null
	return _game_session_host.session()


func bind_lilian_session_host(host: Node) -> void:
	_lilian_session_host = host


func _lilian_session() -> Node:
	if _lilian_session_host == null:
		push_error("CharacterAttributesPanel: LilianSessionHost 未注入")
		return null
	return _lilian_session_host.session()


func _tutorial_event(event_id: String) -> void:
	if _tutorial_coordinator == null:
		push_error("CharacterAttributesPanel: TutorialCoordinator 未注入")
		return
	_tutorial_coordinator.game_event(event_id)

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
@onready var _magic_def: Panel = %MagicDef
@onready var _action_spd: Panel = %ActionSpd
@onready var _shield: Panel = %Shield
@onready var _attributes_heading: Label = %AttributesHeading
@onready var _attributes_card: Panel = %AttributesCard
@onready var _other_attr: Panel = %OtherAttr
@onready var _other_attr_heading: Label = %OtherAttrHeading
@onready var _biography: Label = %BiographyLabel
@onready var _attributes_tab: TextureButton = %AttributesTab
@onready var _experience_tab: TextureButton = %ExperienceTab
@onready var _statistics_tab: TextureButton = %StatisticsTab
@onready var _loadout_tab: TextureButton = %LoadoutTab
@onready var _mastered_arts_tab: TextureButton = %MasteredArtsTab

var _active_tab: Tab = Tab.ATTRIBUTES


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_attributes_tab.pressed.connect(func() -> void: _select_tab(Tab.ATTRIBUTES))
	_experience_tab.pressed.connect(func() -> void: _select_tab(Tab.EXPERIENCE))
	_statistics_tab.pressed.connect(func() -> void: _select_tab(Tab.STATISTICS))
	_loadout_tab.pressed.connect(func() -> void: SceneManager.go_zhandou_peizhi_mianban())
	_mastered_arts_tab.pressed.connect(func() -> void: SceneManager.go_mastered_arts_panel())
	_experience_tab.pressed.connect(func() -> void: SceneManager.go_dao_tree_panel())
	_select_tab(Tab.ATTRIBUTES)
	call_deferred("_initialize_after_session")


func _initialize_after_session() -> void:
	if _game_session() == null:
		return
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	_game_session().refresh_derived_attrs(true)
	_bind_identity()
	_bind_vitals()
	_bind_combat_stats()
	_refresh_tab_content()


func _bind_identity() -> void:
	var game_session := _game_session()
	_character_name.text = game_session.player_name
	_realm.text = game_session.realm_name
	var breakthrough_at := maxi(1, game_session.breakthrough_at)
	_cultivation_bar.max_value = float(breakthrough_at)
	_cultivation_bar.value = float(game_session.cultivation)
	_cultivation_value.text = "%d / %d" % [game_session.cultivation, breakthrough_at]
	_day_label.text = game_session.time_date_label(game_session.day)
	if game_session.injury_days <= 0:
		_injury_label.text = "伤势：无"
	else:
		_injury_label.text = "伤势：%s" % game_session.time_duration_label(game_session.injury_days)
	_stone_label.text = "灵石 %d" % game_session.ling_stones
	_portrait.texture = ZhandouInitDataScript._resolve_icon_texture({"icon": game_session.player_icon})


func _bind_vitals() -> void:
	var game_session := _game_session()
	var hp_max := ZhandouAttr.get_attr(game_session.attrs, EnumPlayerAttr.HP_MAX, 100.0)
	var mp_max := ZhandouAttr.get_attr(game_session.attrs, EnumPlayerAttr.MP_MAX, 100.0)
	_hp_bar.max_value = hp_max
	_hp_bar.value = game_session.hp
	_hp_value.text = "%.0f/%.0f" % [game_session.hp, hp_max]
	_mp_bar.max_value = mp_max
	_mp_bar.value = game_session.mp
	_mp_value.text = "%.0f/%.0f" % [game_session.mp, mp_max]


func _bind_combat_stats() -> void:
	var attrs: Dictionary = _game_session().attrs
	_attributes_heading.text = "战斗面板"
	_set_stat_slot(_attack, "物攻", "%.0f" % ZhandouAttr.get_attr(attrs, EnumPlayerAttr.PHYSICAL_ATK))
	_set_stat_slot(_defense, "法攻", "%.0f" % ZhandouAttr.get_attr(attrs, EnumPlayerAttr.MAGIC_ATK))
	_set_stat_slot(_speed, "物防", "%.0f" % ZhandouAttr.get_attr(attrs, EnumPlayerAttr.PHYSICAL_DEF))
	_set_stat_slot(_magic_def, "法防", "%.0f" % ZhandouAttr.get_attr(attrs, EnumPlayerAttr.MAGIC_DEF))
	_set_stat_slot(_action_spd, "出手", "%.0f" % ZhandouAttr.get_attr(attrs, EnumPlayerAttr.SPD))
	_shield.visible = false


func _set_stat_slot(panel: Panel, title: String, value_text: String) -> void:
	var label := panel.find_child("Label", false, false) as Label
	label.text = "%s\n%s" % [title, value_text]


func _biography_text() -> String:
	var game_session := _game_session()
	if not game_session.activity_log.is_empty():
		var lines: PackedStringArray = []
		var start := maxi(0, game_session.activity_log.size() - 3)
		for i in range(start, game_session.activity_log.size()):
			lines.append(str((game_session.activity_log[i] as Dictionary).get("text", "")))
		return "\n".join(lines)
	return "%s入道，初踏仙途。" % game_session.player_name


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
			_other_attr_heading.text = "根基与资质"
			_biography.text = _foundation_text()
		Tab.EXPERIENCE:
			_other_attr.visible = true
			_other_attr_heading.text = "经历"
			_biography.text = _experience_text()
		Tab.STATISTICS:
			_other_attr.visible = true
			_other_attr_heading.text = "统计"
			_biography.text = _statistics_text()


func _foundation_text() -> String:
	var game_session := _game_session()
	var base := CharacterStatsScript.normalize_foundations(game_session.foundations)
	var aptitude := CharacterStatsScript.normalize_aptitudes(game_session.aptitudes)
	var attrs: Dictionary = game_session.attrs
	return "\n".join([
		"根基",
		"肉身  %.0f    灵力  %.0f" % [float(base[EnumPlayerAttr.BODY]), float(base[EnumPlayerAttr.SPIRIT])],
		"神识  %.0f    身法  %.0f" % [float(base[EnumPlayerAttr.SENSE]), float(base[EnumPlayerAttr.AGILITY])],
		"",
		"资质",
		"灵根  %s" % CharacterStatsScript.root_label(aptitude),
		"悟性  %.0f    福缘  %.0f" % [
			float(aptitude[EnumPlayerAttr.COMPREHENSION]),
			float(aptitude[EnumPlayerAttr.FORTUNE]),
		],
		"",
		"辅助",
		"气血恢复 %.1f    法力恢复 %.1f" % [
			ZhandouAttr.get_attr(attrs, EnumPlayerAttr.HP_REGEN),
			ZhandouAttr.get_attr(attrs, EnumPlayerAttr.MP_REGEN),
		],
		"负重 %.0f" % ZhandouAttr.get_attr(attrs, EnumPlayerAttr.CARRY),
	])


func _experience_text() -> String:
	var game_session := _game_session()
	if game_session.activity_log.is_empty():
		return "暂无经历记录。"
	var lines: PackedStringArray = ["近期经历"]
	for entry_v in game_session.activity_log.slice(-8):
		if entry_v is Dictionary:
			lines.append(str((entry_v as Dictionary).get("text", "")))
	return "\n".join(lines)


func _statistics_text() -> String:
	var totals: Dictionary = _game_session().totals
	return "\n".join([
		"历练统计",
		"战斗 %d 场，胜 %d，负 %d" % [
			int(totals.get("battles", 0)),
			int(totals.get("wins", 0)),
			int(totals.get("losses", 0)),
		],
		"历练 %d 次，最高难度 %d" % [
			int(totals.get("lilian_count", 0)),
			maxi(int(totals.get("max_difficulty", 0)), int(totals.get("max_depth", 0))),
		],
		"获得物品 %d 件" % int(totals.get("items_gained", 0)),
	])


func _on_close_pressed() -> void:
	_tutorial_event("tutorial.attributes_closed")
	var lilian := _lilian_session()
	if lilian != null:
		LilianFlowService.go_back(lilian, SceneManager)
