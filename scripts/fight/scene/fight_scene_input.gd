class_name FightSceneInput
extends RefCounted

## 战斗场景输入：热键、槽位点击与自动战斗 UI。

const SKILL_HOTKEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const EQUIP_HOTKEYS: Array[Key] = [KEY_Q, KEY_W]
const ITEM_HOTKEYS: Array[Key] = [KEY_E, KEY_R]

var _ctx: FightSceneContext
var _hud: FightSceneHud
var _on_skill: Callable
var _on_schedule_player_act: Callable


func setup(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		on_skill: Callable,
		on_schedule_player_act: Callable
) -> void:
	_ctx = ctx
	_hud = hud
	_on_skill = on_skill
	_on_schedule_player_act = on_schedule_player_act


func bind_signals(scene: Control) -> void:
	for i in _ctx.skill_slots.size():
		var idx := i
		_connect_slot_click(_ctx.skill_slots[i], func() -> void:
			trigger_skill_slot(scene, idx)
		)
	for i in _ctx.equip_slots.size():
		var idx := i
		_connect_slot_click(_ctx.equip_slots[i], func() -> void:
			trigger_equip_slot(scene, idx)
		)
	for i in _ctx.item_slots.size():
		var idx := i
		_connect_slot_click(_ctx.item_slots[i], func() -> void:
			trigger_item_slot(scene, idx)
		)
	var chk := _hud.get_chk_auto_player()
	if chk != null and not chk.toggled.is_connected(_on_auto_player_toggled):
		chk.toggled.connect(_on_auto_player_toggled)


func setup_auto_battle(default_player: bool, default_enemy: bool) -> void:
	_ctx.auto_battle_player = default_player
	_ctx.auto_battle_enemy = default_enemy
	_hud.sync_auto_battle_ui(_ctx)


func handle_unhandled_input(event: InputEvent, scene: Control) -> void:
	if not _ctx.init_ok or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var skill_idx := SKILL_HOTKEYS.find(code)
	if skill_idx >= 0:
		scene.get_viewport().set_input_as_handled()
		trigger_skill_slot(scene, skill_idx)
		return
	var equip_idx := EQUIP_HOTKEYS.find(code)
	if equip_idx >= 0:
		scene.get_viewport().set_input_as_handled()
		trigger_equip_slot(scene, equip_idx)
		return
	var item_idx := ITEM_HOTKEYS.find(code)
	if item_idx >= 0:
		scene.get_viewport().set_input_as_handled()
		trigger_item_slot(scene, item_idx)
		return
	if code == KEY_U:
		scene.get_viewport().set_input_as_handled()
		toggle_auto_battle_player()


func trigger_skill_slot(scene: Control, index: int) -> void:
	if _on_skill.is_valid():
		_on_skill.call(index)
	if scene.has_signal("skill_slot_pressed"):
		scene.emit_signal("skill_slot_pressed", index)


func trigger_item_slot(scene: Control, index: int) -> void:
	if index < 0 or index >= _ctx.item_slots.size():
		return
	if scene.has_signal("item_slot_pressed"):
		scene.emit_signal("item_slot_pressed", index)


func trigger_equip_slot(scene: Control, index: int) -> void:
	if index < 0 or index >= _ctx.equip_slots.size():
		return
	if scene.has_signal("equip_slot_pressed"):
		scene.emit_signal("equip_slot_pressed", index)


func set_auto_battle_player(enabled: bool) -> void:
	if _ctx.auto_battle_player == enabled:
		return
	_ctx.auto_battle_player = enabled
	_hud.sync_auto_battle_ui(_ctx)
	if (
		enabled
		and _ctx.domain != null
		and _ctx.domain.state == EnumBattleState.State.PAUSED
		and _ctx.domain.paused_side == EnumBattleSide.PLAYER
		and _on_schedule_player_act.is_valid()
	):
		_on_schedule_player_act.call()


func toggle_auto_battle_player() -> void:
	set_auto_battle_player(not _ctx.auto_battle_player)


func _on_auto_player_toggled(pressed: bool) -> void:
	set_auto_battle_player(pressed)


static func _connect_slot_click(slot: OneSkillView, on_click: Callable) -> void:
	var press := slot.get_node_or_null("Control")
	if press is PressScale:
		press.clicked.connect(on_click)
