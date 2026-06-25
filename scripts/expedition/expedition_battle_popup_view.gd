class_name ExpeditionBattlePopupView
extends Control

signal fight_requested
## 仅关闭战前弹窗，不触发撤退结算
signal close_requested

const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")

const _TITLE_COLOR := Color(0.33333334, 0.19607843, 0.18431373, 1.0)
const _BODY_COLOR := Color(0.4117647, 0.3019608, 0.27450982, 1.0)
const _META_COLOR := Color(0.5372549, 0.42745098, 0.3882353, 1.0)

@onready var _backdrop: ColorRect = %Backdrop
@onready var _enemy_preview: TextureRect = %EnemyPreview
@onready var _event_title: Label = %EventTitle
@onready var _enemy_name: Label = %EnemyName
@onready var _risk_label: Label = %RiskLabel
@onready var _desc_label: Label = %DescLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _fight_button: TextureButton = %FightButton
@onready var _retreat_button: TextureButton = %RetreatButton


func _ready() -> void:
	visible = false
	_fight_button.pressed.connect(func() -> void: fight_requested.emit())
	_retreat_button.pressed.connect(func() -> void: close_requested.emit())
	_backdrop.gui_input.connect(_on_backdrop_gui_input)


func apply_event(event: Dictionary, _depth: int = 0) -> void:
	var enemies := ExpeditionEventServiceScript.build_battle_enemies(event)
	var enemy := enemies[0] as Dictionary if not enemies.is_empty() else ExpeditionEventServiceScript.build_battle_enemy(event)
	var attrs := enemy.get("attrs", {}) as Dictionary
	var enemy_title := str(enemy.get("name", "")).strip_edges()
	if enemies.size() > 1:
		var base_name := str((event.get("enemy", {}) as Dictionary).get("name", enemy_title)).strip_edges()
		enemy_title = "%s x%d" % [base_name if base_name != "" else enemy_title, enemies.size()]
	var event_title := str(event.get("name", "")).strip_edges()
	_event_title.text = event_title if event_title != "" else "遭遇战"
	_event_title.add_theme_color_override("font_color", _TITLE_COLOR)

	_enemy_name.text = enemy_title if enemy_title != "" else "未知对手"
	_enemy_name.add_theme_color_override("font_color", _BODY_COLOR)

	var risk := str(event.get("risk_text", "")).strip_edges()
	_risk_label.text = risk
	_risk_label.visible = risk != ""

	var desc := str(event.get("desc", "")).strip_edges()
	_desc_label.text = desc
	_desc_label.visible = desc != ""

	var total_hp := 0.0
	for row_v in enemies:
		if row_v is Dictionary:
			var row := row_v as Dictionary
			var row_attrs := row.get("attrs", {}) as Dictionary
			total_hp += float(row.get("hp", row_attrs.get(FightAttr.HP_MAX, 0.0)))
	if total_hp <= 0.0:
		total_hp = float(enemy.get("hp", attrs.get(FightAttr.HP_MAX, 0.0)))
	var stat_lines: PackedStringArray = PackedStringArray([
		"气血  %.0f" % total_hp,
		"物攻  %.0f    法攻  %.0f" % [
			float(attrs.get(FightAttr.PHYSICAL_ATK, 0.0)),
			float(attrs.get(FightAttr.MAGIC_ATK, 0.0)),
		],
		"物防  %.0f    法防  %.0f" % [
			float(attrs.get(FightAttr.PHYSICAL_DEF, 0.0)),
			float(attrs.get(FightAttr.MAGIC_DEF, 0.0)),
		],
		"速度  %.0f" % float(attrs.get(FightAttr.SPD, 0.0)),
	])
	_stats_label.text = "\n".join(stat_lines)

	var icon := BattleInitDataScript._resolve_icon_texture(enemy)
	if icon != null:
		_enemy_preview.texture = icon
		_enemy_preview.self_modulate = Color.WHITE
	else:
		_enemy_preview.texture = null
		_enemy_preview.self_modulate = Color(1, 1, 1, 0.25)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
