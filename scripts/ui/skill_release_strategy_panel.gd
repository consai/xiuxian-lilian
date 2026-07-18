extends Control

var _lilian_session_host: Node
var _game_session_host: Node


func bind_lilian_session_host(host: Node) -> void:
	_lilian_session_host = host


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host


func _game_session() -> Node:
	if _game_session_host == null:
		push_error("SkillReleaseStrategyPanel: GameSessionHost 未注入")
		return null
	return _game_session_host.session()


func _lilian_session() -> Node:
	if _lilian_session_host == null:
		push_error("SkillReleaseStrategyPanel: LilianSessionHost 未注入")
		return null
	return _lilian_session_host.session()

const PlayerAutoBattleServiceScript := preload("res://scripts/sim/player_auto_battle_service.gd")
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)
const InventoryEquipQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_equip_query_application.gd"
)
const ItemIconResolverScript := preload(
	"res://scripts/features/inventory/presentation/item_icon_resolver.gd"
)
const AbilityQueryApplicationScript := preload(
	"res://scripts/features/ability/application/ability_query_application.gd"
)
const ROW_SCENE := preload("res://scenes/ui/components/strategy_skill_row.tscn")

const MODE_ROWS := [
	{"node": "Balanced", "preset": "balanced"},
	{"node": "Aggressive", "preset": "aggressive"},
	{"node": "Conservative", "preset": "conservative"},
]

const SETTING_ROWS := [
	{"node": "Cooldown", "key": "global_cooldown_sec"},
	{"node": "SameSkill", "key": "duplicate_skill_policy"},
	{"node": "Range", "key": "cast_range"},
	{"node": "AutoPill", "key": "auto_pill"},
	{"node": "AutoBuff", "key": "opening_buff"},
]

@onready var _close_button: TextureButton = %CloseButton
@onready var _add_button: TextureButton = %AddButton
@onready var _confirm_button: TextureButton = %ConfirmButton
@onready var _cancel_button: TextureButton = %CancelButton
@onready var _rows: VBoxContainer = %Rows
@onready var _modes: HBoxContainer = %Modes
@onready var _mode_description: Label = $Panel/ModeCard/Description
@onready var _settings: VBoxContainer = %Settings
@onready var _hint: Label = %Hint

var _draft_preset := "balanced"
var _draft_strategies: Array = []
var _draft_settings: Dictionary = {}
var _wired := false


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_cancel_button.pressed.connect(_go_back)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_add_button.pressed.connect(_on_add_pressed)
	_wire_static_interactions()
	call_deferred("_initialize_after_session")


func _initialize_after_session() -> void:
	if _game_session() == null:
		return
	_load_draft()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _load_draft() -> void:
	var game_session := _game_session()
	_draft_preset = game_session.auto_battle_preset
	var rules: Dictionary = game_session.resolved_auto_battle_rules()
	_draft_strategies = (rules.get("strategies", []) as Array).duplicate(true)
	_draft_settings = PlayerAutoBattleServiceScript.normalize_settings(rules.get("settings", {}))


func _wire_static_interactions() -> void:
	if _wired:
		return
	_wired = true
	for spec in MODE_ROWS:
		var button := _modes.get_node(str(spec["node"])) as Button
		button.pressed.connect(_select_preset.bind(str(spec["preset"])))
	for spec in SETTING_ROWS:
		var row := _settings.get_node(str(spec["node"])) as Control
		_make_clickable(row, _cycle_setting.bind(str(spec["key"])))


func _make_clickable(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				action.call()
	)


func _refresh(message: String = "") -> void:
	_bind_modes()
	_bind_settings()
	_mode_description.text = PlayerAutoBattleServiceScript.preset_description(_draft_preset)
	if message != "":
		_hint.text = message
	elif _draft_strategies.is_empty():
		_hint.text = "提示：当前列表为空，将按技能槽默认顺位施法；点击「添加技能」创建自定义策略。"
	else:
		_hint.text = "提示：从上到下依次检查条件，满足条件时释放对应技能。"
	call_deferred("_sync_strategy_rows")


func _sync_strategy_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i in _draft_strategies.size():
		var strategy := _draft_strategies[i] as Dictionary
		var row := ROW_SCENE.instantiate() as Control
		_rows.add_child(row)
		_bind_strategy_row(row, strategy, i)
		_wire_strategy_row(row, i)


func _wire_strategy_row(row: Control, index: int) -> void:
	_make_clickable(row.get_node("Condition"), _edit_strategy.bind(index))
	_make_clickable(row.get_node("Target"), _edit_strategy.bind(index))
	_make_clickable(row.get_node("Drag") as Control, _move_strategy_up.bind(index))
	_make_clickable(row, _remove_strategy.bind(index))


func _bind_strategy_row(row: Control, strategy: Dictionary, index: int) -> void:
	row.get_node("%Priority").text = str(index + 1)
	row.get_node("%Info").text = PlayerAutoBattleServiceScript.strategy_info_text(strategy)
	row.get_node("%ConditionLabel").text = "条件\n%s" % PlayerAutoBattleServiceScript.strategy_condition_label(strategy)
	row.get_node("%TargetLabel").text = "目标\n%s" % PlayerAutoBattleServiceScript.strategy_target_label(strategy)
	var icon := row.get_node("%Icon") as TextureRect
	var texture := _strategy_icon(strategy)
	icon.texture = texture
	icon.visible = texture != null


func _bind_modes() -> void:
	for spec in MODE_ROWS:
		var preset := str(spec["preset"])
		var button := _modes.get_node(str(spec["node"])) as Button
		button.disabled = preset == _draft_preset


func _bind_settings() -> void:
	for spec in SETTING_ROWS:
		var key := str(spec["key"])
		var row := _settings.get_node(str(spec["node"])) as Control
		row.get_node("%ValueLabel").text = PlayerAutoBattleServiceScript.setting_display(
			key,
			_draft_settings.get(key)
		)


func _select_preset(preset: String) -> void:
	_draft_preset = preset
	_refresh("已切换为%s模式。" % _preset_name(preset))


func _cycle_setting(setting_key: String) -> void:
	var current: Variant = _draft_settings.get(setting_key)
	_draft_settings[setting_key] = PlayerAutoBattleServiceScript.cycle_setting(setting_key, current)
	_refresh("已更新通用设置。")


func _on_add_pressed() -> void:
	var game_session := _game_session()
	for aid_v in game_session.equipped_abilities:
		var aid := str(aid_v).strip_edges()
		if aid == "":
			continue
		var sid := AbilityQueryApplicationScript.combat_id_for(aid)
		if sid <= 0 or _has_skill_strategy(sid):
			continue
		var skill := AbilityQueryApplicationScript.runtime_by_ability_id(aid, game_session.to_dict())
		var template := PlayerAutoBattleServiceScript.skill_strategy_template(
			sid,
			str(skill.get("name", ""))
		)
		_draft_strategies.append((template.get("strategy", {}) as Dictionary).duplicate(true))
		_refresh("已添加策略：%s" % str(template.get("label", "")))
		return
	for template_v in PlayerAutoBattleServiceScript.strategy_templates():
		var template := template_v as Dictionary
		var strategy := (template.get("strategy", {}) as Dictionary).duplicate(true)
		if _has_strategy_id(str(strategy.get("id", ""))):
			continue
		_draft_strategies.append(strategy)
		_refresh("已添加策略：%s" % str(template.get("label", "")))
		return
	_refresh("没有可添加的策略。")


func _remove_strategy(index: int) -> void:
	if index < 0 or index >= _draft_strategies.size():
		return
	_draft_strategies.remove_at(index)
	_refresh("已删除第 %d 条策略。" % (index + 1))


func _move_strategy_up(index: int) -> void:
	if index <= 0 or index >= _draft_strategies.size():
		return
	var temp: Variant = _draft_strategies[index]
	_draft_strategies[index] = _draft_strategies[index - 1]
	_draft_strategies[index - 1] = temp
	_refresh("已上调第 %d 条策略优先级。" % index)


func _edit_strategy(index: int) -> void:
	if index < 0 or index >= _draft_strategies.size():
		return
	_refresh(PlayerAutoBattleServiceScript.strategy_label(_draft_strategies[index] as Dictionary))


func _on_confirm_pressed() -> void:
	var game_session := _game_session()
	game_session.auto_battle_preset = _draft_preset
	game_session.auto_battle_rules = PlayerAutoBattleServiceScript.with_config(
		_draft_preset,
		_draft_strategies,
		_draft_settings
	)
	game_session.auto_battle_enabled = true
	_refresh("策略已保存。")
	await get_tree().process_frame
	_go_back()


func _has_skill_strategy(skill_id: int) -> bool:
	for strategy_v in _draft_strategies:
		if not strategy_v is Dictionary:
			continue
		var action := (strategy_v as Dictionary).get("action", {}) as Dictionary
		if str(action.get("type", "")) == "skill" and int(action.get("skill_id", -1)) == skill_id:
			return true
	return false


func _has_strategy_id(strategy_id: String) -> bool:
	var sid := strategy_id.strip_edges()
	if sid == "":
		return false
	for strategy_v in _draft_strategies:
		if strategy_v is Dictionary and str((strategy_v as Dictionary).get("id", "")) == sid:
			return true
	return false


func _strategy_icon(strategy: Dictionary) -> Texture2D:
	var action := strategy.get("action", {}) as Dictionary
	match str(action.get("type", "")):
		"skill":
			return _entry_icon(
				AbilityQueryApplicationScript.runtime_by_combat_id(
					int(action.get("skill_id", -1))
				)
			)
		"item":
			var slot_index := int(action.get("slot_index", 0))
			var game_session := _game_session()
			var iid := str(game_session.item_slots[slot_index]) if slot_index < game_session.item_slots.size() else ""
			var def := InventoryQueryApplicationScript.definition_by_id(iid)
			if def != null:
				return ItemIconResolverScript.resolve(def.icon_path, null)
		"equip":
			var equip_slot := int(action.get("slot_index", 0))
			var game_session := _game_session()
			var eid := int(game_session.equip_slots[equip_slot]) if equip_slot < game_session.equip_slots.size() else -1
			if eid > 0:
				return _entry_icon(InventoryEquipQueryApplicationScript.equip_by_id(eid))
	return null


func _entry_icon(entry: Dictionary) -> Texture2D:
	if entry.is_empty() or not entry.has("icon") or entry.get("icon") == null:
		return null
	return ZhandouInitDataScript._resolve_icon_texture(entry)


func _preset_name(preset: String) -> String:
	return {
		"balanced": "均衡",
		"aggressive": "激进",
		"conservative": "保守",
	}.get(preset, preset)


func _go_back() -> void:
	var lilian := _lilian_session()
	if lilian != null:
		LilianFlowService.go_back(lilian, SceneManager)
