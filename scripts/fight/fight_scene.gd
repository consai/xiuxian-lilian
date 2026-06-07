extends Control

## 战斗界面：布局在 [code]fightScene.tscn[/code]；脚本绑定双方头像/血法、走条、技能与法宝栏。
## 编排 [BattleDomainService] 四态循环，表现由 [FightVfxManager] 驱动。

const SCENE_ID := "fight_scene"
const SKILL_ICON := preload("res://assets/art/ui_new/skill_01.png")
const SKILL_BACK := Color(0.933, 0.804, 0.702)
const CombatEventScript = preload("res://scripts/fight/combat_event.gd")
const CombatReportScript = preload("res://scripts/fight/combat_report.gd")
const BattleRecorderScript = preload("res://scripts/fight/battle_recorder.gd")
const BattleRecordTypesScript = preload("res://scripts/fight/battle_record_types.gd")
const BattleRecordFormatterScript = preload("res://scripts/fight/battle_record_formatter.gd")
const BattleLogPanelViewScript = preload("res://scripts/fight/battle_log_panel_view.gd")
const EnemyAiServiceScript = preload("res://scripts/fight/ai/enemy_ai_service.gd")
const EnemyAiTypesScript = preload("res://scripts/fight/ai/enemy_ai_types.gd")
const EnemyAiRuntimeStateScript = preload("res://scripts/fight/ai/enemy_ai_runtime_state.gd")
const BattleSetupScript = preload("res://scripts/fight/battle_setup.gd")

const UNIT_PLAYER := "player"
const UNIT_ENEMY := "enemy"

const _SKILL_HOTKEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const _EQUIP_HOTKEYS: Array[Key] = [KEY_Q, KEY_W]
const _ITEM_HOTKEYS: Array[Key] = [KEY_E, KEY_R]
const _BLOCK_OK := "ok"
const _BLOCK_BATTLE_BUSY := "battle_busy"
const _BLOCK_EMPTY_SLOT := "empty_slot"
const _BLOCK_COOLDOWN := "cooldown"
const _BLOCK_INSUFFICIENT_MP := "insufficient_mp"
const _BLOCK_NO_COUNT := "no_count"

## 技能栏 index → 技能 id；[code]0[/code] 表示该格为普攻（无配置表条目）。由进战数据写入。

signal skill_slot_pressed(index: int)
signal equip_slot_pressed(index: int)
signal item_slot_pressed(index: int)
signal battle_finished(summary: Dictionary)

@onready var _head_left: TextureRect = %head_left
@onready var _rolename_left: Label = %rolename_left
@onready var _hp_bar_left: ProgressBar = %shengming_left
@onready var _hp_val_left: Label = %hp_val_left
@onready var _mp_bar_left: ProgressBar = %fali_left
@onready var _mp_val_left: Label = %mp_val_left
@onready var _head_right: TextureRect = %head_right
@onready var _rolename_right: Label = %rolename_right
@onready var _hp_bar_right: ProgressBar = %shengming_right
@onready var _hp_val_right: Label = %hp_val_right
@onready var _mp_bar_right: ProgressBar = %fali_right
@onready var _mp_val_right: Label = %mp_val_right
@onready var _interval_left: IntervalTrackView = %interval_left
@onready var _interval_right: IntervalTrackView = %interval_right
@onready var _fighttime: Label = %fighttime
@onready var _sprite_left: Sprite2D = %sprite_left
@onready var _sprite_right: Sprite2D = %sprite_right
@onready var _center: Control = $center
@onready var _chk_auto_player: CheckButton = %auto
@onready var _vfx: FightVfxManager = %FightVfxManager
@onready var _float_layer: CombatFloatLayer = %CombatFloatLayer
@onready var _battle_log_panel = %BattleLogPanel
@onready var _battle_result_overlay = %BattleResultOverlay

var _skill_slots: Array[OneSkillView] = []
var _equip_slots: Array[OneSkillView] = []
var _item_slots: Array[OneSkillView] = []
var _skill_slot_interactive: Array[bool] = []
var _equip_slot_interactive: Array[bool] = []
var _item_slot_interactive: Array[bool] = []
var _presentation_busy: bool = false
var _player_act_scheduled: bool = false
var _enemy_act_scheduled: bool = false

var _auto_battle_player: bool = false
var _auto_battle_enemy: bool = true

var skill_cfg: Dictionary = {}
var _item_cfg: Dictionary = {}
var _equip_cfg: Dictionary = {}
var _enemy_ai_cfg: Dictionary = {}
var _enemy_ai_runtime: EnemyAiRuntimeState
var _battle_player: FightObj
var _battle_enemy: FightObj
var _domain: BattleDomainService
var _battle_time_limit: float = 0.0
var _init_ok: bool = false

var _recorder = BattleRecorderScript.new()
var _record_formatter = BattleRecordFormatterScript.new()
var _record_names: Dictionary = {}
var _battle_session_id: String = ""

@export_group("Auto Battle")
## 玩家走条满后自动从技能栏 1→5 选第一个可用技能；默认关闭。
@export var default_auto_battle_player: bool = false
## 敌方走条满后自动选招；默认开启。
@export var default_auto_battle_enemy: bool = true

@export_group("Editor")
## 仅编辑器直开 [code]fightScene.tscn[/code] 时使用；正式进战请 [BattleInitData.set_pending]。
@export var editor_battle_init: Dictionary = {}
## 无 pending / 未填 [member editor_battle_init] 时，编辑器内用 [BattleInitData.sample_for_editor]（导出版无效）。
@export var editor_auto_sample: bool = true

@export_group("Debug")
@export var battle_debug_enabled: bool = true
## 为 true 时约每秒打印 ADVANCING 走条进度（控制台过滤 [Battle]）。
@export var battle_debug_verbose_tick: bool = false


func _ready() -> void:
	BattleDebugLog.enabled = battle_debug_enabled
	BattleDebugLog.verbose_tick = battle_debug_verbose_tick
	_skill_slots.assign([
		%skill_1 as OneSkillView,
		%skill_2 as OneSkillView,
		%skill_3 as OneSkillView,
		%skill_4 as OneSkillView,
		%skill_5 as OneSkillView,
	])
	_equip_slots.assign([
		%equip_1 as OneSkillView,
		%equip_2 as OneSkillView,
	])
	_item_slots.assign([
		%item_1 as OneSkillView,
		%item_2 as OneSkillView,
	])
	_bind_signals()
	_setup_auto_battle_ui()
	_setup_battle_vfx()
	_init_ok = _try_initialize_battle()
	if not _init_ok:
		set_process(false)
		return
	if _battle_result_overlay != null and _battle_result_overlay.has_signal("close_requested"):
		if not _battle_result_overlay.is_connected(
			"close_requested",
			Callable(self, "_on_battle_result_close_requested")
		):
			_battle_result_overlay.connect(
				"close_requested",
				Callable(self, "_on_battle_result_close_requested")
			)
	call_deferred("_sync_ui_from_domain")
	set_process(true)


func _process(delta: float) -> void:
	if _domain == null:
		return
	match _domain.state:
		BattleDomainService.BattleState.ADVANCING:
			var ready_signal := _domain.tick_advancing(delta)
			_consume_runtime_events()
			_sync_ui_from_domain()
			_update_skill_input_enabled()
			match ready_signal:
				BattleDomainService.SIGNAL_PLAYER_READY:
					BattleDebugLog.write("场景", "玩家走条满，进入暂停")
					_domain.enter_paused(BattleDomainService.SIDE_PLAYER)
					_update_skill_input_enabled()
					_schedule_side_act(BattleDomainService.SIDE_PLAYER)
				BattleDomainService.SIGNAL_ENEMY_READY:
					BattleDebugLog.write("场景", "敌方走条满，进入暂停")
					_domain.enter_paused(BattleDomainService.SIDE_ENEMY)
					_update_skill_input_enabled()
					_schedule_side_act(BattleDomainService.SIDE_ENEMY)
				BattleDomainService.SIGNAL_TIME_LIMIT:
					BattleDebugLog.write("场景", "战斗超时，结束")
					_on_battle_ended(_domain.end_reason)
				BattleDomainService.SIGNAL_PLAYER_DEAD, BattleDomainService.SIGNAL_ENEMY_DEAD:
					BattleDebugLog.write("场景", "走条阶段判定战斗结束", {
						"原因": BattleDebugLog.end_reason_label(ready_signal),
					})
					_on_battle_ended(ready_signal)
		BattleDomainService.BattleState.PAUSED, BattleDomainService.BattleState.PRESENTATION:
			_sync_ui_from_domain()
			_update_skill_input_enabled()
		_:
			pass


func _bind_signals() -> void:
	for i in _skill_slots.size():
		var idx := i
		_connect_slot_click(_skill_slots[i], func() -> void:
			_trigger_skill_slot(idx)
		)
	for i in _equip_slots.size():
		var idx := i
		_connect_slot_click(_equip_slots[i], func() -> void:
			_trigger_equip_slot(idx)
		)
	for i in _item_slots.size():
		var idx := i
		_connect_slot_click(_item_slots[i], func() -> void:
			_trigger_item_slot(idx)
		)
	if _vfx != null:
		_vfx.event_finished.connect(_on_vfx_event_finished)
		if not _vfx.queue_finished.is_connected(_on_vfx_queue_finished):
			_vfx.queue_finished.connect(_on_vfx_queue_finished)
	if not item_slot_pressed.is_connected(_on_item_slot_pressed):
		item_slot_pressed.connect(_on_item_slot_pressed)
	if not equip_slot_pressed.is_connected(_on_equip_slot_pressed):
		equip_slot_pressed.connect(_on_equip_slot_pressed)


func _setup_auto_battle_ui() -> void:
	_auto_battle_player = default_auto_battle_player
	_auto_battle_enemy = default_auto_battle_enemy
	_sync_auto_battle_ui()
	if _chk_auto_player != null:
		_chk_auto_player.toggled.connect(_on_auto_player_toggled)


func _on_auto_player_toggled(pressed: bool) -> void:
	_set_auto_battle_player(pressed)


func _on_auto_enemy_toggled(pressed: bool) -> void:
	_auto_battle_enemy = pressed


func _set_auto_battle_player(enabled: bool) -> void:
	if _auto_battle_player == enabled:
		return
	_auto_battle_player = enabled
	_sync_auto_battle_ui()
	if (
		enabled
		and _domain != null
		and _domain.state == BattleDomainService.BattleState.PAUSED
		and _domain.paused_side == BattleDomainService.SIDE_PLAYER
	):
		_schedule_side_act(BattleDomainService.SIDE_PLAYER)


func _toggle_auto_battle_player() -> void:
	_set_auto_battle_player(not _auto_battle_player)


func _sync_auto_battle_ui() -> void:
	if _chk_auto_player != null:
		_chk_auto_player.set_block_signals(true)
		_chk_auto_player.button_pressed = _auto_battle_player
		_chk_auto_player.set_block_signals(false)


func _connect_slot_click(slot: OneSkillView, on_click: Callable) -> void:
	var press := slot.get_node_or_null("Control")
	if press is PressScale:
		press.clicked.connect(on_click)


func _unhandled_input(event: InputEvent) -> void:
	if not _init_ok or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var skill_idx := _SKILL_HOTKEYS.find(code)
	if skill_idx >= 0:
		get_viewport().set_input_as_handled()
		_trigger_skill_slot(skill_idx)
		return
	var equip_idx := _EQUIP_HOTKEYS.find(code)
	if equip_idx >= 0:
		get_viewport().set_input_as_handled()
		_trigger_equip_slot(equip_idx)
		return
	var item_idx := _ITEM_HOTKEYS.find(code)
	if item_idx >= 0:
		get_viewport().set_input_as_handled()
		_trigger_item_slot(item_idx)
		return
	if code == KEY_U:
		get_viewport().set_input_as_handled()
		_toggle_auto_battle_player()
		return


func _trigger_skill_slot(index: int) -> void:
	_on_skill_slot_pressed(index)
	skill_slot_pressed.emit(index)


func _trigger_item_slot(index: int) -> void:
	if index < 0 or index >= _item_slots.size():
		return
	item_slot_pressed.emit(index)


func _trigger_equip_slot(index: int) -> void:
	if index < 0 or index >= _equip_slots.size():
		return
	equip_slot_pressed.emit(index)


## 由 [BattleInitData.resolve] 消费进战数据；外部请 [BattleInitData.set_pending] / [method goto_fight_scene]。
func initialize_battle(data: Dictionary) -> bool:
	return _apply_battle_setup(BattleInitData.resolve(data))


func _try_initialize_battle() -> bool:
	var data := BattleInitData.take_pending(get_tree())
	if data.is_empty() and not editor_battle_init.is_empty():
		data = editor_battle_init.duplicate(true)
	if data.is_empty() and editor_auto_sample and OS.has_feature("editor"):
		data = BattleInitData.sample_for_editor()
		push_warning(
			"FightScene: 编辑器直开，已使用 sample_for_editor()。"
			+ "正式进战请 BattleInitData.set_pending(tree, data)。"
		)
	if data.is_empty():
		push_error(
			"FightScene: 缺少战斗初始化数据。请 BattleInitData.set_pending(tree, data) 后切场景，"
			+ "或在编辑器填写 editor_battle_init（或开启 editor_auto_sample）。"
		)
		return false
	return initialize_battle(data)


func _apply_battle_setup(setup: BattleSetupScript) -> bool:
	if setup == null:
		push_error("FightScene: BattleInitData.resolve 失败，无法开战")
		return false
	_battle_player = setup.player
	_battle_enemy = setup.enemy
	skill_cfg = setup.skill_cfg
	_battle_time_limit = setup.battle_time_limit
	_apply_auto_battle_from_init(setup.auto_battle)
	_battle_session_id = setup.battle_session_id
	_record_names = setup.record_names.duplicate(true)
	_item_cfg = setup.item_cfg.duplicate(true)
	_equip_cfg = setup.equip_cfg.duplicate(true)
	_enemy_ai_cfg = setup.get_enemy_ai_cfg()
	_enemy_ai_runtime = EnemyAiRuntimeStateScript.new()
	apply_battle(setup.ui_payload)
	_register_battle_actors()
	_start_battle()
	BattleDebugLog.write("场景", "战斗初始化完成", {
		"玩家气血": _battle_player.hp,
		"敌方气血": _battle_enemy.hp,
		"玩家速度": _battle_player.get_attr(FightObj.ATTR_SPD),
		"玩家走条周期": CombatBalance.interval_cap_for(_battle_player),
		"敌方速度": _battle_enemy.get_attr(FightObj.ATTR_SPD),
		"敌方走条周期": CombatBalance.interval_cap_for(_battle_enemy),
		"时限": _battle_time_limit,
	})
	return true


## 仅刷新 UI 展示（头像、走条、槽位外观）；逻辑态以 [FightObj] / [BattleDomainService] 为准。
## 进战请走 [BattleInitData.resolve]，勿将 [method BattleInitData.build_apply_battle_payload] 产出当作进战源。
func apply_battle(data: Dictionary) -> void:
	var player: Variant = data.get("player", {})
	if player is Dictionary:
		_apply_combatant("left", player as Dictionary)
	var enemy: Variant = data.get("enemy", {})
	if enemy is Dictionary:
		_apply_combatant("right", enemy as Dictionary)
	var intervals: Variant = data.get("intervals", {})
	if intervals is Dictionary:
		var id := intervals as Dictionary
		_set_interval_bar(_interval_left, id.get("left", {}))
		_set_interval_bar(_interval_right, id.get("right", {}))
	_apply_skill_row(_skill_slots, data.get("skills", []), _skill_slot_interactive)
	_apply_skill_row(_equip_slots, data.get("equips", []), _equip_slot_interactive)
	_apply_skill_row(_item_slots, data.get("items", []), _item_slot_interactive)


func set_interval(side: String, elapsed: float, cap: float) -> void:
	var track := _interval_left if side == "left" else _interval_right
	if track != null:
		track.set_progress(elapsed, cap)


func set_combatant_vitals(side: String, hp: float, hp_max: float, mp: float, mp_max: float) -> void:
	var hp_bar: ProgressBar
	var hp_val: Label
	var mp_bar: ProgressBar
	var mp_val: Label
	if side == "left":
		hp_bar = _hp_bar_left
		hp_val = _hp_val_left
		mp_bar = _mp_bar_left
		mp_val = _mp_val_left
	else:
		hp_bar = _hp_bar_right
		hp_val = _hp_val_right
		mp_bar = _mp_bar_right
		mp_val = _mp_val_right
	_set_bar_pair(hp_bar, hp_val, hp, hp_max)
	_set_bar_pair(mp_bar, mp_val, mp, mp_max)


func _apply_combatant(side: String, row: Dictionary) -> void:
	if not row.has("hp") or not row.has("hp_max") or not row.has("mp") or not row.has("mp_max"):
		push_error("FightScene._apply_combatant(%s): 缺少 hp/hp_max/mp/mp_max" % side)
		return
	var name_text := str(row.get("name", "")).strip_edges()
	var avatar: Variant = row.get("avatar")
	var hp: float = float(row["hp"])
	var hp_max: float = float(row["hp_max"])
	var mp: float = float(row["mp"])
	var mp_max: float = float(row["mp_max"])
	var sprite_tex: Variant = row.get("sprite")
	if side == "left":
		if name_text != "":
			_rolename_left.text = name_text
		if avatar is Texture2D:
			_head_left.texture = avatar
			if _interval_left != null:
				_interval_left.set_avatar_texture(avatar)
		if sprite_tex is Texture2D:
			_sprite_left.texture = sprite_tex
	else:
		if name_text != "":
			_rolename_right.text = name_text
		if avatar is Texture2D:
			_head_right.texture = avatar
			if _interval_right != null:
				_interval_right.set_avatar_texture(avatar)
		if sprite_tex is Texture2D:
			_sprite_right.texture = sprite_tex
	set_combatant_vitals(side, hp, hp_max, mp, mp_max)


func _apply_skill_row(slots: Array[OneSkillView], rows: Variant, interactive_out: Array[bool]) -> void:
	interactive_out.clear()
	var row_arr: Array = rows as Array if rows is Array else []
	for i in slots.size():
		var slot := slots[i]
		if i >= row_arr.size() or _is_empty_slot_row(row_arr[i]):
			slot.clear_slot()
			interactive_out.append(false)
			continue
		var row := row_arr[i] as Dictionary
		var icon: Variant = row.get("icon")
		var back_v: Variant = row.get("back_color")
		var back: Color = back_v as Color if back_v is Color else SKILL_BACK
		var tex: Texture2D = icon as Texture2D if icon is Texture2D else null
		slot.setup(str(row.get("name", "")), tex, back)
		var count_v = row.get("count", null)
		if count_v is int:
			slot.set_stack_count(int(count_v))
		else:
			slot.set_stack_count(-1)
		var cd_rem := float(row.get("cd_remaining", 0.0))
		var cd_total := float(row.get("cd_total", -1.0))
		slot.set_cooldown(cd_rem, cd_total)
		var usable := bool(row.get("usable", true))
		interactive_out.append(usable)


static func _is_empty_slot_row(row_v: Variant) -> bool:
	return row_v is Dictionary and bool((row_v as Dictionary).get("empty", false))


func _set_interval_bar(track: IntervalTrackView, row: Variant) -> void:
	if track == null:
		return
	track.apply_row(row)


func _set_bar_pair(bar: ProgressBar, val_lbl: Label, cur: float, capv: float) -> void:
	if bar == null:
		return
	var capf := maxf(capv, 0.001)
	var cur_clamped := clampf(cur, 0.0, capf)
	bar.min_value = 0.0
	bar.max_value = capf
	bar.value = cur_clamped
	if val_lbl != null:
		val_lbl.text = "%d/%d" % [int(roundf(cur_clamped)), int(roundf(capf))]


func _setup_battle_vfx() -> void:
	if _vfx == null:
		push_error("FightScene: 请在 fightScene.tscn 中放置 %FightVfxManager 节点")
		return
	_vfx.set_screen_shake_target(_center)
	_vfx.set_projectile_parent(_center)
	_register_battle_actors()


func _register_battle_actors() -> void:
	if _vfx == null:
		return
	if not is_instance_valid(_sprite_left) or not is_instance_valid(_sprite_right):
		push_warning("FightScene: 战斗精灵未就绪，延后注册 VFX 角色")
		call_deferred("_register_battle_actors")
		return
	_vfx.register_actor(UNIT_PLAYER, _sprite_left)
	_vfx.register_actor(UNIT_ENEMY, _sprite_right)
	_vfx.refresh_all_actors()
	BattleDebugLog.write("场景", "VFX 角色注册完成", {
		"玩家": _sprite_vfx_snapshot(UNIT_PLAYER),
		"敌方": _sprite_vfx_snapshot(UNIT_ENEMY),
	})


func _ensure_vfx_actors_for_combat() -> void:
	if _vfx == null:
		return
	if is_instance_valid(_sprite_left):
		_vfx.ensure_actor_registered(UNIT_PLAYER, _sprite_left)
	if is_instance_valid(_sprite_right):
		_vfx.ensure_actor_registered(UNIT_ENEMY, _sprite_right)


func _sprite_vfx_snapshot(unit_id: String) -> Dictionary:
	if _vfx == null:
		return {"ok": false}
	var vfx := _vfx.get_actor_vfx(unit_id)
	if vfx == null:
		return {"ok": false, "单位": unit_id}
	var actor := vfx.get_actor()
	if not is_instance_valid(actor):
		return {"ok": false, "单位": unit_id}
	return {
		"ok": true,
		"pos": "(%.1f, %.1f)" % [actor.position.x, actor.position.y],
		"rest": "(%.1f, %.1f)" % [vfx.get_rest_position().x, vfx.get_rest_position().y],
	}


func _start_battle() -> void:
	_domain = BattleDomainService.new()
	BattleDebugLog.set_domain(_domain)
	_domain.start_battle(_battle_player, _battle_enemy, skill_cfg, _battle_time_limit, _item_cfg, _equip_cfg)
	if _recorder != null:
		_recorder.begin({
			"session_id": _battle_session_id,
			"player_name": str(_record_names.get(BattleRecordTypesScript.UNIT_PLAYER, "")),
			"enemy_name": str(_record_names.get(BattleRecordTypesScript.UNIT_ENEMY, "")),
		})
	if _float_layer != null:
		_float_layer.clear_all()
	if _battle_log_panel != null and _battle_log_panel.has_method("clear_log"):
		_battle_log_panel.call("clear_log")
		_battle_log_panel.visible = true
		if _battle_log_panel.has_method("append_plain_line"):
			_battle_log_panel.call("append_plain_line", "[b]战斗开始[/b]")
	_sync_ui_from_domain()
	_update_skill_input_enabled()


func _sync_ui_from_domain() -> void:
	if _domain == null:
		return
	_sync_fight_time_label()
	set_combatant_vitals(
		"left",
		_domain.player.hp,
		_domain.player.get_hp_max(),
		_domain.player.mp,
		_domain.player.get_mp_max()
	)
	set_combatant_vitals(
		"right",
		_domain.enemy.hp,
		_domain.enemy.get_hp_max(),
		_domain.enemy.mp,
		_domain.enemy.get_mp_max()
	)
	var intervals: Variant = _domain.get_ui_snapshot().get("intervals", {})
	if intervals is Dictionary:
		var id := intervals as Dictionary
		_set_interval_bar(_interval_left, id.get("left", {}))
		_set_interval_bar(_interval_right, id.get("right", {}))
	_sync_skill_cooldowns()
	_sync_item_and_equip_runtime_ui()
	_sync_runtime_slot_interactive()


func _sync_fight_time_label() -> void:
	if _fighttime == null or _domain == null:
		return
	var elapsed := maxf(0.0, _domain.battle_elapsed_advancing)
	var minutes := int(floor(elapsed / 60.0))
	var seconds := elapsed - float(minutes * 60)
	_fighttime.text = "%02d:%04.1f" % [minutes, seconds]


func _sync_skill_cooldowns() -> void:
	if _domain == null:
		return
	for i in _skill_slots.size():
		var skill_id := _skill_id_at(_battle_player, i)
		if skill_id < 0:
			_skill_slots[i].set_cooldown(0.0)
			continue
		if skill_id == 0:
			_skill_slots[i].set_cooldown(0.0, -1.0)
			continue
		var cd := _domain.player.get_skill_cd_at(i)
		var cfg := _lookup_skill_cfg(skill_id)
		var slot := _domain.player.get_skill_slot_at(i)
		var total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
		_skill_slots[i].set_cooldown(cd, total)
	for i in _equip_slots.size():
		var equip_slot := _domain.player.get_equip_slot_at(i)
		var equip_id := int(equip_slot.get("id", -1))
		if equip_id < 0:
			_equip_slots[i].set_cooldown(0.0)
			continue
		var cd := _domain.player.get_equip_cd_at(i)
		var cfg := FightObj._lookup_cfg(_equip_cfg, equip_id)
		var total := float(equip_slot.get("cd_total", cfg.get("cd_total", cfg.get("cd", 0.0))))
		_equip_slots[i].set_cooldown(cd, total)


func _sync_item_and_equip_runtime_ui() -> void:
	if _domain == null:
		return
	for i in _item_slots.size():
		var slot := _domain.player.get_item_slot_at(i)
		var item_id := int(slot.get("id", -1))
		if item_id < 0:
			_item_slots[i].set_stack_count(-1)
			_item_slots[i].set_cooldown(0.0)
			continue
		var count := int(slot.get("count", 0))
		_item_slots[i].set_stack_count(count)
		var cfg := FightObj._lookup_cfg(_item_cfg, item_id)
		var cd := float(slot.get("cd", 0.0))
		var total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
		_item_slots[i].set_cooldown(cd, total)
	for i in _equip_slots.size():
		var slot := _domain.player.get_equip_slot_at(i)
		var equip_id := int(slot.get("id", -1))
		if equip_id < 0:
			_equip_slots[i].set_cooldown(0.0)
			continue
		var cfg := FightObj._lookup_cfg(_equip_cfg, equip_id)
		var cd := float(slot.get("cd", 0.0))
		var total := float(slot.get("cd_total", cfg.get("cd_total", cfg.get("cd", 0.0))))
		_equip_slots[i].set_cooldown(cd, total)


func _sync_runtime_slot_interactive() -> void:
	if _domain == null:
		return
	for i in _skill_slot_interactive.size():
		var skill_id := _skill_id_at(_battle_player, i)
		_skill_slot_interactive[i] = skill_id >= 0 and _can_actor_use_skill_at(_battle_player, i, skill_id)
	for i in _item_slot_interactive.size():
		_item_slot_interactive[i] = _can_use_player_item_at(i)
	for i in _equip_slot_interactive.size():
		_equip_slot_interactive[i] = _can_use_player_equip_at(i)


func _can_use_player_item_at(index: int) -> bool:
	if _domain == null or index < 0 or index >= _item_slots.size():
		return false
	var slot := _domain.player.get_item_slot_at(index)
	var item_id := int(slot.get("id", -1))
	if item_id < 0:
		return false
	if float(slot.get("cd", 0.0)) > 0.0:
		return false
	if int(slot.get("count", 0)) <= 0:
		return false
	var cfg := FightObj._lookup_cfg(_item_cfg, item_id)
	if cfg.is_empty():
		return false
	return _domain.player.mp >= float(cfg.get("mp_cost", 0.0))


func _can_use_player_equip_at(index: int) -> bool:
	if _domain == null or index < 0 or index >= _equip_slots.size():
		return false
	var slot := _domain.player.get_equip_slot_at(index)
	var equip_id := int(slot.get("id", -1))
	if equip_id < 0:
		return false
	if float(slot.get("cd", 0.0)) > 0.0:
		return false
	var cfg := FightObj._lookup_cfg(_equip_cfg, equip_id)
	if cfg.is_empty():
		return false
	var need := float(slot.get("mp_cost", cfg.get("mp_cost", 0.0)))
	return _domain.player.mp >= need


func _update_skill_input_enabled() -> void:
	var can_act := (
		_domain != null
		and _domain.can_player_act()
		and not _presentation_busy
	)
	var active_tint := Color.WHITE
	var idle_tint := Color(0.65, 0.65, 0.65, 1.0)
	var empty_tint := Color(0.65, 0.65, 0.65, 0.45)
	for i in _skill_slots.size():
		var usable := i < _skill_slot_interactive.size() and _skill_slot_interactive[i]
		var enabled := can_act and usable
		var tint := active_tint if enabled else (idle_tint if usable else empty_tint)
		_set_slot_input_enabled(_skill_slots[i], enabled, tint)
	for i in _item_slots.size():
		var usable := i < _item_slot_interactive.size() and _item_slot_interactive[i]
		var enabled := can_act and usable
		var tint := active_tint if enabled else (idle_tint if usable else empty_tint)
		_set_slot_input_enabled(_item_slots[i], enabled, tint)
	for i in _equip_slots.size():
		var usable := i < _equip_slot_interactive.size() and _equip_slot_interactive[i]
		var enabled := can_act and usable
		var tint := active_tint if enabled else (idle_tint if usable else empty_tint)
		_set_slot_input_enabled(_equip_slots[i], enabled, tint)


func _set_slot_input_enabled(slot: OneSkillView, _enabled: bool, tint: Color) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.modulate = tint
	var press := slot.get_node_or_null("Control")
	if press is Control:
		press.mouse_filter = slot.mouse_filter
		press.modulate = tint


func enqueue_battle_vfx(data: Dictionary) -> void:
	if _vfx == null:
		return
	_vfx.enqueue_dict(data)


func play_battle_vfx_queue() -> void:
	if _vfx != null:
		await _vfx.play_queue()


func _on_vfx_event_finished(_event: BattleVfxEvent) -> void:
	_sync_ui_from_domain()


func _on_vfx_queue_finished() -> void:
	if _domain == null or not _presentation_busy:
		return
	if _domain.state == BattleDomainService.BattleState.PRESENTATION:
		# 收口统一在 _run_presentation；这里只保留观测日志，避免双通道状态竞争。
		BattleDebugLog.write("场景", "VFX 队列结束事件", {
			"状态": BattleDebugLog.state_label(_domain.state),
			"表现中": _presentation_busy,
		})


func _apply_auto_battle_from_init(auto_battle: Dictionary) -> void:
	if auto_battle.is_empty():
		return
	if auto_battle.has("player"):
		_auto_battle_player = bool(auto_battle["player"])
	if auto_battle.has("enemy"):
		_auto_battle_enemy = bool(auto_battle["enemy"])
	_sync_auto_battle_ui()


func _on_skill_slot_pressed(index: int) -> void:
	_player_act_scheduled = false
	var reason := _get_skill_block_reason(index)
	if str(reason.get("code", "")) != _BLOCK_OK:
		_handle_blocked_slot_click("skill", index, reason)
		return
	var skill_id := _skill_id_at(_battle_player, index)
	if skill_id < 0:
		return
	var payload := _resolve_player_slot(index, skill_id)
	if payload.is_empty():
		return
	BattleDebugLog.write("场景", "玩家出手成功，进入表现", {
		"槽位": index,
		"技能ID": skill_id,
	})
	_commit_combat_resolution(payload, _descriptor_for_skill_or_basic(skill_id))
	_sync_ui_from_domain()
	await _run_presentation(payload)


func _on_item_slot_pressed(index: int) -> void:
	_player_act_scheduled = false
	var reason := _get_item_block_reason(index)
	if str(reason.get("code", "")) != _BLOCK_OK:
		_handle_blocked_slot_click("item", index, reason)
		return
	var payload := _domain.resolve_player_item(index)
	if not bool(payload.get("ok", false)):
		return
	_commit_combat_resolution(payload, _descriptor_for_item(payload))
	_sync_ui_from_domain()
	await _run_presentation(payload)


func _on_equip_slot_pressed(index: int) -> void:
	_player_act_scheduled = false
	var reason := _get_equip_block_reason(index)
	if str(reason.get("code", "")) != _BLOCK_OK:
		_handle_blocked_slot_click("equip", index, reason)
		return
	var payload := _domain.resolve_player_equip(index)
	if not bool(payload.get("ok", false)):
		return
	_commit_combat_resolution(payload, _descriptor_for_equip(payload))
	_sync_ui_from_domain()
	await _run_presentation(payload)


func _schedule_side_act(side: String) -> void:
	if side == BattleDomainService.SIDE_PLAYER:
		if not _auto_battle_player:
			return
		if _player_act_scheduled:
			return
		_player_act_scheduled = true
		call_deferred("_side_act_and_present", side)
	elif side == BattleDomainService.SIDE_ENEMY:
		if _enemy_act_scheduled:
			return
		_enemy_act_scheduled = true
		call_deferred("_side_act_and_present", side)


func _side_act_and_present(side: String) -> void:
	if side == BattleDomainService.SIDE_PLAYER:
		_player_act_scheduled = false
	else:
		_enemy_act_scheduled = false
	if _domain == null or _presentation_busy:
		return
	if _domain.state != BattleDomainService.BattleState.PAUSED:
		return
	if _domain.paused_side != side:
		return
	if side == BattleDomainService.SIDE_ENEMY:
		var enemy_resolved := _resolve_enemy_action_with_ai()
		var enemy_payload: Dictionary = enemy_resolved.get("payload", {}) as Dictionary
		var enemy_desc: Dictionary = enemy_resolved.get("descriptor", {}) as Dictionary
		if enemy_payload.is_empty():
			BattleDebugLog.write("场景", "敌方 AI 行为不可用，降级普攻")
			enemy_payload = _domain.resolve_enemy_basic()
			enemy_desc = {"action_kind": BattleRecordTypesScript.ACTION_BASIC, "action_id": 0}
			if not bool(enemy_payload.get("ok", false)):
				BattleDebugLog.write("场景", "敌方降级普攻失败，安全推进状态机避免卡死", {
					"原因": BattleDebugLog.fail_reason_label(str(enemy_payload.get("reason", ""))),
				})
				_domain.begin_presentation(BattleDomainService.SIDE_ENEMY)
				_domain.finish_presentation()
				return
		BattleDebugLog.write("场景", "敌方 AI 出手，进入表现")
		_commit_combat_resolution(enemy_payload, enemy_desc)
		_sync_ui_from_domain()
		await _run_presentation(enemy_payload)
		return
	var actor := _battle_player if side == BattleDomainService.SIDE_PLAYER else _battle_enemy
	var check_interactive := side == BattleDomainService.SIDE_PLAYER
	var slot_index := _find_auto_skill_slot(actor, _skill_slot_interactive, check_interactive)
	var skill_id := _skill_id_at(actor, slot_index)
	if slot_index < 0:
		BattleDebugLog.write("场景", "自动战斗无可用技能，尝试普攻", {
			"出手方": BattleDebugLog.side_label(side),
		})
		skill_id = 0
		slot_index = _find_basic_attack_slot(actor)
		if slot_index < 0:
			BattleDebugLog.write("场景", "自动战斗无法出手", {"出手方": BattleDebugLog.side_label(side)})
			return
	var payload := _resolve_side_slot(side, slot_index, skill_id)
	if payload.is_empty():
		BattleDebugLog.write("场景", "自动战斗出手失败", {
			"出手方": BattleDebugLog.side_label(side),
			"槽位": slot_index,
			"技能ID": skill_id,
		})
		return
	BattleDebugLog.write("场景", "自动战斗出手，进入表现", {
		"出手方": BattleDebugLog.side_label(side),
		"槽位": slot_index,
		"技能ID": skill_id,
	})
	_commit_combat_resolution(payload, _descriptor_for_skill_or_basic(skill_id))
	_sync_ui_from_domain()
	await _run_presentation(payload)


func _skill_id_at(actor: FightObj, index: int) -> int:
	if index < 0 or not actor.skills is Array or index >= (actor.skills as Array).size():
		return -1
	var slot_v: Variant = (actor.skills as Array)[index]
	if not slot_v is Dictionary:
		return -1
	return int((slot_v as Dictionary).get("id", -1))


func _find_basic_attack_slot(actor: FightObj) -> int:
	if not actor.skills is Array:
		return -1
	for i in (actor.skills as Array).size():
		if _skill_id_at(actor, i) == 0:
			return i
	return -1


func _find_auto_skill_slot(
		actor: FightObj,
		interactive: Array[bool],
		check_interactive: bool
) -> int:
	if not actor.skills is Array:
		return -1
	for i in (actor.skills as Array).size():
		if check_interactive:
			if i >= interactive.size() or not interactive[i]:
				continue
		var skill_id := _skill_id_at(actor, i)
		if skill_id < 0:
			continue
		if _can_actor_use_skill_at(actor, i, skill_id):
			return i
	return -1


func _can_actor_use_skill_at(actor: FightObj, index: int, skill_id: int) -> bool:
	if skill_id <= 0:
		return true
	if actor.get_skill_slot_at(index).is_empty():
		return false
	if actor.get_skill_cd_at(index) > 0.0:
		return false
	var cfg := _lookup_skill_cfg(skill_id)
	if cfg.is_empty():
		return false
	return actor.mp >= float(cfg.get("mp_cost", 0.0))


func _ok_reason() -> Dictionary:
	return {"code": _BLOCK_OK, "text": ""}


func _battle_busy_reason() -> Dictionary:
	return {"code": _BLOCK_BATTLE_BUSY, "text": "当前不可行动"}


func _empty_slot_reason() -> Dictionary:
	return {"code": _BLOCK_EMPTY_SLOT, "text": "该槽位未配置"}


func _build_cooldown_reason(remaining: float) -> Dictionary:
	return {
		"code": _BLOCK_COOLDOWN,
		"text": "冷却中 %.1fs" % maxf(remaining, 0.0),
		"remain": maxf(remaining, 0.0),
	}


func _build_insufficient_mp_reason(need: float, have: float) -> Dictionary:
	return {
		"code": _BLOCK_INSUFFICIENT_MP,
		"text": "灵力不足（需要%d）" % int(ceil(need)),
		"need": maxf(need, 0.0),
		"have": maxf(have, 0.0),
	}


func _build_no_count_reason(count: int) -> Dictionary:
	return {"code": _BLOCK_NO_COUNT, "text": "次数不足", "count": count}


func _get_skill_block_reason(index: int) -> Dictionary:
	if _domain == null or _battle_player == null:
		return _battle_busy_reason()
	if _presentation_busy or not _domain.can_player_act():
		return _battle_busy_reason()
	if index < 0 or index >= _battle_player.skills.size():
		return _empty_slot_reason()
	var skill_id := _skill_id_at(_battle_player, index)
	if skill_id < 0:
		return _empty_slot_reason()
	if skill_id <= 0:
		return _ok_reason()
	var slot := _battle_player.get_skill_slot_at(index)
	if slot.is_empty():
		return _empty_slot_reason()
	var cd := _battle_player.get_skill_cd_at(index)
	if cd > 0.0:
		return _build_cooldown_reason(cd)
	var cfg := _lookup_skill_cfg(skill_id)
	if cfg.is_empty():
		return _empty_slot_reason()
	var need := float(cfg.get("mp_cost", 0.0))
	var have := _domain.player.mp
	if have < need:
		return _build_insufficient_mp_reason(need, have)
	return _ok_reason()


func _get_item_block_reason(index: int) -> Dictionary:
	if _domain == null:
		return _battle_busy_reason()
	if _presentation_busy or not _domain.can_player_act():
		return _battle_busy_reason()
	if index < 0 or index >= _item_slots.size():
		return _empty_slot_reason()
	var slot := _domain.player.get_item_slot_at(index)
	var item_id := int(slot.get("id", -1))
	if item_id < 0:
		return _empty_slot_reason()
	var cd := float(slot.get("cd", 0.0))
	if cd > 0.0:
		return _build_cooldown_reason(cd)
	var count := int(slot.get("count", 0))
	if count <= 0:
		return _build_no_count_reason(count)
	var cfg := FightObj._lookup_cfg(_item_cfg, item_id)
	var need := float(cfg.get("mp_cost", 0.0))
	var have := _domain.player.mp
	if have < need:
		return _build_insufficient_mp_reason(need, have)
	return _ok_reason()


func _get_equip_block_reason(index: int) -> Dictionary:
	if _domain == null:
		return _battle_busy_reason()
	if _presentation_busy or not _domain.can_player_act():
		return _battle_busy_reason()
	if index < 0 or index >= _equip_slots.size():
		return _empty_slot_reason()
	var slot := _domain.player.get_equip_slot_at(index)
	var equip_id := int(slot.get("id", -1))
	if equip_id < 0:
		return _empty_slot_reason()
	var cd := float(slot.get("cd", 0.0))
	if cd > 0.0:
		return _build_cooldown_reason(cd)
	var cfg := FightObj._lookup_cfg(_equip_cfg, equip_id)
	var need := float(slot.get("mp_cost", cfg.get("mp_cost", 0.0)))
	var have := _domain.player.mp
	if have < need:
		return _build_insufficient_mp_reason(need, have)
	return _ok_reason()


func _slot_view_for_type(slot_type: String, index: int) -> OneSkillView:
	match slot_type:
		"skill":
			return _skill_slots[index] if index >= 0 and index < _skill_slots.size() else null
		"item":
			return _item_slots[index] if index >= 0 and index < _item_slots.size() else null
		"equip":
			return _equip_slots[index] if index >= 0 and index < _equip_slots.size() else null
		_:
			return null


func _handle_blocked_slot_click(slot_type: String, index: int, reason: Dictionary) -> void:
	var code := str(reason.get("code", _BLOCK_EMPTY_SLOT))
	if code == _BLOCK_OK:
		return
	var text := str(reason.get("text", "当前不可行动"))
	var slot := _slot_view_for_type(slot_type, index)
	if slot != null:
		slot.play_blocked_feedback()
	_emit_blocked_click_log(slot_type, index, reason)
	_emit_block_reason_intent(slot_type, index, code, text)


func _emit_blocked_click_log(slot_type: String, index: int, reason: Dictionary) -> void:
	var elapsed := 0.0
	if _domain != null:
		elapsed = maxf(0.0, _domain.battle_elapsed_advancing)
	BattleDebugLog.write("slot_click_blocked", "玩家点击不可用槽位", {
		"slot_type": slot_type,
		"index": index,
		"reason_code": str(reason.get("code", "")),
		"text": str(reason.get("text", "")),
		"battle_time": elapsed,
	})


func _emit_block_reason_intent(slot_type: String, index: int, reason_code: String, text: String) -> void:
	if text == "":
		return
	var de: Node = get_node_or_null("/root/DataEvents")
	if de == null or not de.has_method("emit_tip_intent"):
		return
	var tone := "loss" if reason_code in [_BLOCK_INSUFFICIENT_MP, _BLOCK_NO_COUNT] else "neutral"
	de.emit_tip_intent({
		"id": "fight_block_%d" % Time.get_ticks_msec(),
		"schema_version": 1,
		"type": "block_reason",
		"text": text,
		"tone": tone,
		"channel": "combat_block",
		"source": "fight_scene",
		"created_at_ms": Time.get_ticks_msec(),
		"throttle_key": "fight_block.%s.%d.%s" % [slot_type, index, reason_code],
		"throttle_ms": 700,
		"ttl_ms": 900,
		"context": {
			"slot_type": slot_type,
			"index": index,
			"reason_code": reason_code,
		},
	})


func _resolve_player_slot(index: int, skill_id: int) -> Dictionary:
	var payload: Dictionary
	if skill_id <= 0:
		payload = _domain.resolve_player_basic()
	else:
		payload = _domain.resolve_player_skill(skill_id)
	if not bool(payload.get("ok", false)):
		BattleDebugLog.write("场景", "玩家出手失败", {
			"槽位": index,
			"技能ID": skill_id,
			"原因": BattleDebugLog.fail_reason_label(str(payload.get("reason", ""))),
		})
		return {}
	return payload


func _resolve_side_slot(side: String, index: int, skill_id: int) -> Dictionary:
	if side == BattleDomainService.SIDE_PLAYER:
		return _resolve_player_slot(index, skill_id)
	var payload: Dictionary
	if skill_id <= 0:
		payload = _domain.resolve_enemy_basic()
	else:
		payload = _domain.resolve_enemy_skill(skill_id)
	if not bool(payload.get("ok", false)):
		return {}
	return payload


func _resolve_enemy_action_with_ai() -> Dictionary:
	if _domain == null or _battle_enemy == null or _battle_player == null:
		return {}
	var prev_phase := ""
	if _enemy_ai_runtime != null:
		prev_phase = _enemy_ai_runtime.last_phase_id
	var domain_ctx := {
		"battle_elapsed": _domain.battle_elapsed_advancing,
	}
	var decision := EnemyAiServiceScript.decide_enemy_action(
		_battle_enemy,
		_battle_player,
		skill_cfg,
		_enemy_ai_cfg,
		_enemy_ai_runtime,
		domain_ctx,
		_item_cfg,
		_equip_cfg
	)
	if _enemy_ai_runtime != null:
		var new_phase := str(decision.get("phase_id", _enemy_ai_runtime.last_phase_id))
		if new_phase != "" and new_phase != prev_phase:
			BattleDebugLog.write("场景", "敌方 AI 阶段切换", {
				"from": prev_phase,
				"to": new_phase,
			})
	var action_type := str(decision.get("action_type", ""))
	if not bool(decision.get("ok", false)):
		BattleDebugLog.write("场景", "敌方 AI 决策失败", {
			"原因": str(decision.get("reason", "")),
			"phase_id": str(decision.get("phase_id", "")),
		})
		return {}
	var desc: Dictionary = {}
	var payload: Dictionary
	match action_type:
		EnemyAiTypesScript.ACTION_BASIC:
			payload = _domain.resolve_enemy_basic()
			desc = {"action_kind": BattleRecordTypesScript.ACTION_BASIC, "action_id": 0}
		EnemyAiTypesScript.ACTION_SKILL:
			var sid := int(decision.get("skill_id", -1))
			payload = _domain.resolve_enemy_skill(sid)
			desc = {"action_kind": BattleRecordTypesScript.ACTION_SKILL, "action_id": sid}
		EnemyAiTypesScript.ACTION_ITEM:
			payload = _domain.resolve_enemy_item(int(decision.get("slot_index", -1)))
			desc = _descriptor_for_item(payload)
		EnemyAiTypesScript.ACTION_EQUIP:
			payload = _domain.resolve_enemy_equip(int(decision.get("slot_index", -1)))
			desc = _descriptor_for_equip(payload)
		_:
			return {}
	if not bool(payload.get("ok", false)):
		BattleDebugLog.write("场景", "敌方 AI 出手失败", {
			"动作": action_type,
			"技能ID": int(decision.get("skill_id", -1)),
			"原因": BattleDebugLog.fail_reason_label(str(payload.get("reason", ""))),
		})
		return {}
	return {"payload": payload, "descriptor": desc}


func _commit_combat_resolution(payload: Dictionary, descriptor: Dictionary) -> void:
	if _domain == null or _recorder == null:
		return
	if payload == null or not bool(payload.get("ok", false)):
		return
	var entry: Dictionary = _recorder.record_resolution(payload, descriptor, _domain.battle_elapsed_advancing)
	_on_record_entry_committed(entry)


func _descriptor_for_skill_or_basic(skill_id: int) -> Dictionary:
	if skill_id <= 0:
		return {"action_kind": BattleRecordTypesScript.ACTION_BASIC, "action_id": 0}
	return {"action_kind": BattleRecordTypesScript.ACTION_SKILL, "action_id": int(skill_id)}


func _descriptor_for_item(payload: Dictionary) -> Dictionary:
	var report_v: Variant = payload.get("report", {})
	if report_v is Dictionary:
		return {
			"action_kind": BattleRecordTypesScript.ACTION_ITEM,
			"action_id": int((report_v as Dictionary).get("item_id", -1)),
		}
	return {"action_kind": BattleRecordTypesScript.ACTION_ITEM, "action_id": -1}


func _descriptor_for_equip(payload: Dictionary) -> Dictionary:
	var report_v: Variant = payload.get("report", {})
	if report_v is Dictionary:
		return {
			"action_kind": BattleRecordTypesScript.ACTION_EQUIP,
			"action_id": int((report_v as Dictionary).get("equip_id", -1)),
		}
	return {"action_kind": BattleRecordTypesScript.ACTION_EQUIP, "action_id": -1}


func _on_record_entry_committed(_entry: Dictionary) -> void:
	if _battle_log_panel == null or _recorder == null or _record_formatter == null:
		return
	# 重绘尾部，避免运行时 append 状态不一致导致“有数据无显示”。
	if _battle_log_panel.has_method("render_tail"):
		_battle_log_panel.call(
			"render_tail",
			_recorder.get_entries_tail(80),
			_record_formatter,
			_record_names
		)
	else:
		_battle_log_panel.append_entry(_entry, _record_formatter, _record_names)


func _on_battle_result_close_requested() -> void:
	if _battle_result_overlay == null:
		return
	_battle_result_overlay.visible = false


func _run_presentation(payload: Dictionary) -> void:
	if _domain == null:
		return
	if not bool(payload.get("ok", false)):
		return
	var source_id := str(payload.get("source_id", ""))
	var target_id := str(payload.get("target_id", ""))
	var report: Dictionary = payload.get("report", {}) as Dictionary
	var cfg: Dictionary = payload.get("cfg", {}) as Dictionary
	_presentation_busy = true
	_sync_ui_from_domain()
	BattleDebugLog.write("场景", "开始表现流程", {
		"来源": BattleDebugLog.side_label(source_id),
		"目标": BattleDebugLog.side_label(target_id),
		"伤害": report.get("damage", 0.0),
		"暴击": report.get("is_crit", false),
		"特效类型": _vfx_type_from_cfg(cfg),
	})
	BattleDebugLog.log_domain(_domain, "表现前")
	_domain.begin_presentation(source_id)
	if _domain.state != BattleDomainService.BattleState.PRESENTATION:
		BattleDebugLog.write("场景", "开始表现失败，跳过此次表现", {
			"来源": BattleDebugLog.side_label(source_id),
			"域状态": BattleDebugLog.state_label(_domain.state),
		})
		_presentation_busy = false
		_update_skill_input_enabled()
		return
	_update_skill_input_enabled()
	await _play_combat_vfx(source_id, target_id, report, cfg)
	BattleDebugLog.write("场景", "VFX 播放 await 返回")
	_domain.finish_presentation()
	var end_reason := _domain.check_end_after_resolve()
	_presentation_busy = false
	_sync_ui_from_domain()
	_update_skill_input_enabled()
	BattleDebugLog.write("场景", "表现流程结束", {
		"结束原因": BattleDebugLog.end_reason_label(end_reason),
		"域状态": BattleDebugLog.state_label(_domain.state),
	})
	BattleDebugLog.log_domain(_domain, "表现后")
	if end_reason != "":
		_on_battle_ended(end_reason)
	elif _domain.state == BattleDomainService.BattleState.END:
		_on_battle_ended(_domain.end_reason)


func _play_combat_vfx(source_id: String, target_id: String, result: Dictionary, cfg: Dictionary) -> void:
	_ensure_vfx_actors_for_combat()
	_spawn_combat_floats(source_id, target_id, result, cfg)
	if _vfx == null:
		_sync_ui_from_domain()
		return
	_vfx.clear_queue()
	var vfx_binding := CombatVfxSequenceResolver.vfx_binding_from_skill_cfg(cfg)
	if vfx_binding.is_empty():
		vfx_binding = {"preset": _preset_for_vfx_type(_vfx_type_from_cfg(cfg))}
	var extra := {"vfx": vfx_binding}
	BattleDebugLog.write("场景", "入队战斗 VFX", {
		"来源": BattleDebugLog.side_label(source_id),
		"目标": BattleDebugLog.side_label(target_id),
		"preset": str(vfx_binding.get("preset", "")),
		"特效类型": _vfx_type_from_cfg(cfg),
		"施法者快照": _sprite_vfx_snapshot(source_id),
	})
	enqueue_battle_vfx({
		"source_id": source_id,
		"target_id": target_id,
		"damage_value": float(result.get("damage", 0.0)),
		"is_crit": bool(result.get("is_crit", false)),
		"skill_type": _vfx_type_from_cfg(cfg),
		"extra": extra,
	})
	await play_battle_vfx_queue()
	_sync_ui_from_domain()


static func _vfx_type_from_cfg(cfg: Dictionary) -> String:
	var explicit := str(cfg.get("vfx_type", "")).strip_edges().to_lower()
	if explicit != "":
		return explicit
	var tags: Variant = cfg.get("tags", [])
	if tags is Array:
		for tag_v in tags as Array:
			var tag := str(tag_v).strip_edges().to_lower()
			if tag in ["magic", "spell", "ranged", "remote", "远程", "法术"]:
				return "ranged"
	return "melee"


static func _preset_for_vfx_type(vfx_type: String) -> String:
	return CombatVfxPresetLibrary.legacy_preset_for_vfx_type(vfx_type)


func _lookup_skill_cfg(skill_id: int) -> Dictionary:
	if skill_cfg.has(skill_id):
		var v: Variant = skill_cfg[skill_id]
		return v as Dictionary if v is Dictionary else {}
	var ks := str(skill_id)
	if skill_cfg.has(ks):
		var v2: Variant = skill_cfg[ks]
		return v2 as Dictionary if v2 is Dictionary else {}
	return {}


func _spawn_combat_floats(source_id: String, target_id: String, report: Dictionary, cfg: Dictionary) -> void:
	if _float_layer == null:
		return
	BattleDebugLog.write("飘字", "FightScene._spawn_combat_floats 调用", {
		"来源": BattleDebugLog.side_label(source_id),
		"目标": BattleDebugLog.side_label(target_id),
		"damage": report.get("damage", 0.0),
		"heal": report.get("heal", 0.0),
		"mp_gain": report.get("mp_gain", 0.0),
		"shield_absorbed": report.get("shield_absorbed", 0.0),
		"buff_names": report.get("buff_names", []),
	})
	_spawn_float_items(CombatFloatPresenter.build_spawns(source_id, target_id, report, cfg))


func _spawn_float_items(items: Array) -> void:
	if _float_layer == null:
		return
	for item in items:
		if not item is Dictionary:
			continue
		var row := item as Dictionary
		var unit_id := str(row.get("unit_id", ""))
		_float_layer.spawn(
			str(row.get("text", "")),
			_unit_screen_pos(unit_id),
			str(row.get("tone", "damage")),
			unit_id
		)


func _on_buff_expired(buff_id: String, unit_id: String) -> void:
	# 不展示飘字，但保留日志，避免“接线了但没有效果”的误判。
	BattleDebugLog.write("飘字", "Buff 到期（不展示飘字）", {
		"单位": BattleDebugLog.side_label(unit_id),
		"buff_id": buff_id,
	})


func _on_buff_tick_damage(report: Dictionary, unit_id: String) -> void:
	if _float_layer == null:
		return
	var damage := float(report.get("damage", 0.0))
	var shield_absorbed := float(report.get("shield_absorbed", 0.0))
	if damage <= 0.0 and shield_absorbed <= 0.0:
		return
	var buff_name := str(report.get(CombatReportScript.KEY_BUFF_NAME, "")).strip_edges()
	if _domain != null and _recorder != null:
		var entry: Dictionary = _recorder.record_buff_tick(unit_id, report, buff_name, _domain.battle_elapsed_advancing)
		_on_record_entry_committed(entry)
	_spawn_float_items(CombatFloatPresenter.build_buff_tick_spawns(unit_id, report, buff_name, _record_names))


func _consume_runtime_events() -> void:
	if _domain == null:
		return
	for ev_v in _domain.consume_runtime_events():
		if not ev_v is Dictionary:
			continue
		var ev := ev_v as Dictionary
		var unit_id := str(ev.get(CombatEventScript.KEY_UNIT_ID, ""))
		match str(ev.get(CombatEventScript.KEY_TYPE, "")):
			CombatEventScript.TYPE_BUFF_TICK_DAMAGE:
				var report_v: Variant = ev.get(CombatEventScript.KEY_REPORT, {})
				if report_v is Dictionary:
					_on_buff_tick_damage(CombatReportScript.normalize_report(report_v as Dictionary), unit_id)
			CombatEventScript.TYPE_BUFF_EXPIRED:
				_on_buff_expired(str(ev.get(CombatEventScript.KEY_BUFF_ID, "")), unit_id)


func _unit_screen_pos(unit_id: String) -> Vector2:
	var sprite: Node2D = _sprite_left if unit_id == UNIT_PLAYER else _sprite_right
	if not is_instance_valid(sprite):
		return size * Vector2(0.5, 0.35)
	return sprite.get_global_transform_with_canvas().origin + Vector2(0.0, -90.0)


func _exit_tree() -> void:
	BattleDebugLog.clear_domain()


func _on_battle_ended(reason: String) -> void:
	if _domain == null:
		return
	if _float_layer != null:
		_float_layer.clear_all()
	if _recorder != null:
		var summary: Dictionary = _recorder.finalize(reason, _domain.battle_elapsed_advancing, _record_names)
		battle_finished.emit(summary)
		if _battle_result_overlay != null and _battle_result_overlay.has_method("apply_summary"):
			_battle_result_overlay.call(
				"apply_summary",
				summary,
				_record_formatter,
				_recorder.get_entries_tail(10),
				_record_names
			)
			_battle_result_overlay.visible = true
	BattleDebugLog.write("结束", "战斗结束", {
		"原因": BattleDebugLog.end_reason_label(reason),
		"玩家生命": _domain.player.hp,
		"敌方生命": _domain.enemy.hp,
		"快照": _domain.get_debug_snapshot(),
	})
	BattleDebugLog.clear_domain()
	set_process(false)
	_update_skill_input_enabled()
