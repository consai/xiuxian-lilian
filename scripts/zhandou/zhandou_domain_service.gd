class_name ZhandouDomainService
extends RefCounted
## 战斗域：四态状态机、实时速度行动进度、CD、整场时限与出手结算。
const ZhandouEventScript = preload("res://scripts/zhandou/zhandou_event.gd")

const SIGNAL_PLAYER_READY := "player_ready"
const SIGNAL_ENEMY_READY := "enemy_ready"
const SIGNAL_TIME_LIMIT := "time_limit"
const SIGNAL_PLAYER_DEAD := "player_dead"
const SIGNAL_ENEMY_DEAD := "enemy_dead"
const SIGNAL_PLAYER_ESCAPED := "player_escaped"

const DEFAULT_FORMATION_COLUMNS := 3
const DEFAULT_FORMATION_ROWS := 5
const DEFAULT_ACTIVE_COLUMNS := 1
const FORMATION_MODE_COLUMNS := EnumBattleFormationMode.LABEL_COLUMNS
const FORMATION_MODE_WAVES := EnumBattleFormationMode.LABEL_WAVES

var state: EnumBattleState.State = EnumBattleState.State.ADVANCING
var paused_side: String = ""
## 进入 PRESENTATION 时的出手方（避免 paused_side 丢失导致走条不归零）。
var presentation_side: String = ""
var end_reason: String = ""

var player: ZhandouObj
var enemy: ZhandouObj
## 全部敌人运行时对象；阵型槽位保存的是这个数组里的索引。
var enemies: Array = []
## 当前目标/行动者在 enemies 中的索引。
var active_enemy_index: int = 0
var acting_enemy_index: int = -1
var active_enemy_slot: int = 0
var acting_enemy_slot: int = -1
var formation_columns: int = DEFAULT_FORMATION_COLUMNS
var formation_rows: int = DEFAULT_FORMATION_ROWS
var active_columns: int = DEFAULT_ACTIVE_COLUMNS
var formation_rank_size: int = 0
var formation_mode: String = FORMATION_MODE_COLUMNS
var enemy_formation_slots: Array = []
var enemy_reserve_indices: Array = []
var enemy_waves: Array = []
var active_wave_index: int = 0
var skill_cfg: Dictionary = {}
var item_cfg: Dictionary = {}
var equip_cfg: Dictionary = {}

var interval_elapsed_player: float = 0.0
var interval_elapsed_enemy: float = 0.0
var interval_elapsed_enemies: Array = []
## 兼容旧字段名：现在表示固定行动进度上限，而非下一次出手所需秒数。
var interval_T_player: float = ZhandouBalance.ACTION_PROGRESS_MAX
var interval_T_enemy: float = ZhandouBalance.ACTION_PROGRESS_MAX
var _overflow_player: float = 0.0
var _overflow_enemy: float = 0.0
var _overflow_enemies: Array = []

var battle_elapsed_advancing: float = 0.0
var battle_time_limit: float = 200.0
var _runtime_events: Array = []
var _passive_tick_accum: float = 0.0


func start_battle(
		p_player: ZhandouObj,
		p_enemy: ZhandouObj,
		p_skill_cfg: Dictionary,
		p_time_limit: float = 200.0,
		p_item_cfg: Dictionary = {},
		p_equip_cfg: Dictionary = {}
) -> void:
	start_battle_many(
		p_player,
		[p_enemy],
		p_skill_cfg,
		p_time_limit,
		p_item_cfg,
		p_equip_cfg
	)


func start_battle_many(
		p_player: ZhandouObj,
		p_enemies: Array,
		p_skill_cfg: Dictionary,
		p_time_limit: float = 200.0,
		p_item_cfg: Dictionary = {},
		p_equip_cfg: Dictionary = {},
		p_formation: Dictionary = {}
) -> void:
	player = p_player
	_apply_formation_config(p_formation)
	enemies = []
	for enemy_v in p_enemies:
		if enemy_v is ZhandouObj:
			enemies.append(enemy_v)
	if enemies.is_empty() and enemy != null:
		enemies.append(enemy)
	_rebuild_formation_slots()
	_compact_formation()
	active_enemy_index = _first_active_enemy_index()
	acting_enemy_index = -1
	active_enemy_slot = _slot_for_enemy_index(active_enemy_index)
	acting_enemy_slot = -1
	enemy = _enemy_at(active_enemy_index)
	skill_cfg = p_skill_cfg
	item_cfg = p_item_cfg
	equip_cfg = p_equip_cfg
	battle_time_limit = p_time_limit
	battle_elapsed_advancing = 0.0
	interval_elapsed_player = 0.0
	interval_elapsed_enemy = 0.0
	interval_elapsed_enemies.clear()
	interval_T_player = ZhandouBalance.ACTION_PROGRESS_MAX
	interval_T_enemy = ZhandouBalance.ACTION_PROGRESS_MAX
	_overflow_player = 0.0
	_overflow_enemy = 0.0
	_overflow_enemies.clear()
	for _i in enemies.size():
		interval_elapsed_enemies.append(0.0)
		_overflow_enemies.append(0.0)
	paused_side = ""
	presentation_side = ""
	end_reason = ""
	_runtime_events.clear()
	_passive_tick_accum = 0.0
	ZhandouDebugLog.reset_tick_throttle()
	_set_state(EnumBattleState.State.ADVANCING, "开战")
	ZhandouDebugLog.log_domain(self, "开战")
	ZhandouDebugLog.write("流程", "战斗开始", {
		"时限": battle_time_limit,
		"玩家走条速率": ZhandouBalance.action_progress_rate_for(player),
		"敌方走条速率": ZhandouBalance.action_progress_rate_for(enemy),
		"敌方数量": enemies.size(),
		"阵型": "%dx%d" % [formation_columns, formation_rows],
	})


func tick_advancing(delta: float) -> String:
	if state != EnumBattleState.State.ADVANCING:
		return ""
	if delta <= 0.0:
		return ""
	player.tick_cooldowns(delta)
	for idx in _active_enemy_indices():
		var active_unit := _enemy_at(idx)
		if active_unit != null and not active_unit.is_dead():
			active_unit.tick_cooldowns(delta)
	_tick_passive_recovery(delta)
	_drain_runtime_events()
	var dot_end := check_end_after_resolve()
	if dot_end != "":
		return dot_end
	battle_elapsed_advancing += delta
	if battle_elapsed_advancing >= battle_time_limit:
		_set_end(SIGNAL_TIME_LIMIT, "走条推进超时")
		ZhandouDebugLog.write("走条", "达到战斗时限", get_debug_snapshot())
		return SIGNAL_TIME_LIMIT
	interval_elapsed_player += delta * ZhandouBalance.action_progress_rate_for(player)
	for i in _active_enemy_indices():
		var unit := _enemy_at(i)
		if unit == null or unit.is_dead():
			continue
		interval_elapsed_enemies[i] = float(interval_elapsed_enemies[i]) + delta * ZhandouBalance.action_progress_rate_for(unit)
	_sync_legacy_enemy_interval()
	ZhandouDebugLog.tick_progress(self, delta)
	if interval_elapsed_player >= interval_T_player:
		ZhandouDebugLog.write("走条", "玩家走条已满", {
			"玩家走条": format_interval(EnumBattleSide.PLAYER),
			"敌方走条": format_interval(EnumBattleSide.ENEMY),
		})
		return SIGNAL_PLAYER_READY
	var ready_enemy := _first_ready_enemy_index()
	if ready_enemy >= 0:
		active_enemy_index = ready_enemy
		active_enemy_slot = _slot_for_enemy_index(active_enemy_index)
		enemy = _enemy_at(active_enemy_index)
		_sync_legacy_enemy_interval()
		ZhandouDebugLog.write("走条", "敌方走条已满", {
			"玩家走条": format_interval(EnumBattleSide.PLAYER),
			"敌方走条": format_interval(EnumBattleSide.ENEMY),
			"敌方序号": active_enemy_index + 1,
		})
		return SIGNAL_ENEMY_READY
	return ""


func _tick_passive_recovery(delta: float) -> void:
	_passive_tick_accum += delta
	while _passive_tick_accum >= 2.0:
		_passive_tick_accum -= 2.0
		for unit in _all_alive_units():
			if unit == null or unit.is_dead():
				continue
			var mp_gain: float = unit.get_attr(ZhandouAttr.COMBAT_MP_RESTORE_2S, 0.0)
			if mp_gain > 0.0:
				unit.change_mp(mp_gain)


func enter_paused(side: String) -> void:
	if state != EnumBattleState.State.ADVANCING:
		push_warning("ZhandouDomainService.enter_paused: invalid state %s" % ZhandouDebugLog.state_label(state))
		return
	if side != EnumBattleSide.PLAYER and side != EnumBattleSide.ENEMY:
		push_warning("ZhandouDomainService.enter_paused: invalid side '%s'" % side)
		return
	paused_side = side
	if side == EnumBattleSide.PLAYER:
		_overflow_player = _capture_overflow(interval_elapsed_player, interval_T_player)
		interval_elapsed_player = interval_T_player
	elif side == EnumBattleSide.ENEMY:
		acting_enemy_index = active_enemy_index
		acting_enemy_slot = active_enemy_slot
		_overflow_enemies[acting_enemy_index] = _capture_overflow(
			float(interval_elapsed_enemies[acting_enemy_index]),
			interval_T_enemy
		)
		interval_elapsed_enemies[acting_enemy_index] = interval_T_enemy
		_sync_legacy_enemy_interval()
	_set_state(EnumBattleState.State.PAUSED, "进入暂停(%s)" % ZhandouDebugLog.side_label(side))
	ZhandouDebugLog.write("流程", "进入暂停", {
		"出手方": ZhandouDebugLog.side_label(side),
		"玩家溢出": _overflow_player,
		"敌方溢出": _overflow_enemy,
		"玩家走条": format_interval(EnumBattleSide.PLAYER),
		"敌方走条": format_interval(EnumBattleSide.ENEMY),
	})


func can_player_act() -> bool:
	return state == EnumBattleState.State.PAUSED and paused_side == EnumBattleSide.PLAYER


## 场上可追击敌人中的最高 spd（多怪取 max，与走条属性一致）。
func max_active_enemy_spd() -> float:
	var max_spd := 0.0
	for i in _active_enemy_indices():
		var unit := _enemy_at(i)
		if unit == null or unit.is_dead():
			continue
		max_spd = maxf(max_spd, unit.get_attr(ZhandouObj.ATTR_SPD))
	if max_spd <= 0.0:
		for unit_v in enemies:
			if unit_v is ZhandouObj and not (unit_v as ZhandouObj).is_dead():
				max_spd = maxf(max_spd, (unit_v as ZhandouObj).get_attr(ZhandouObj.ATTR_SPD))
	return maxf(ZhandouBalance.SPD_FLOOR, max_spd)


## 玩家回合尝试逃跑；成功则进入 END，失败则消耗回合并可能吃追击伤。
func try_escape(bonus_flat: float = 0.0, fail_count: int = 0) -> Dictionary:
	if not can_player_act():
		return {"ok": false, "reason": "not_paused"}
	if player == null or player.is_dead():
		return {"ok": false, "reason": "player_dead"}
	var max_spd := max_active_enemy_spd()
	var player_spd := player.get_attr(ZhandouObj.ATTR_SPD)
	var chance := ZhandouBalance.escape_success_chance(player_spd, max_spd, bonus_flat, fail_count)
	var success := randf() < chance
	if success:
		_set_end(SIGNAL_PLAYER_ESCAPED, "玩家逃跑成功")
		ZhandouDebugLog.write("行动", "逃跑成功", {
			"成功率": "%.0f%%" % (chance * 100.0),
			"玩家速度": player_spd,
			"敌方最高速度": max_spd,
		})
		return {
			"ok": true,
			"success": true,
			"chance": chance,
			"player_spd": player_spd,
			"max_enemy_spd": max_spd,
		}
	var chase := _apply_escape_chase_damage()
	_apply_interval_after_action(EnumBattleSide.PLAYER)
	paused_side = ""
	_set_state(EnumBattleState.State.ADVANCING, "逃跑失败")
	var end_after := check_end_after_resolve()
	ZhandouDebugLog.write("行动", "逃跑失败", {
		"成功率": "%.0f%%" % (chance * 100.0),
		"追击伤害": chase,
		"玩家气血": player.hp if player != null else 0.0,
	})
	return {
		"ok": true,
		"success": false,
		"chance": chance,
		"chase_damage": chase,
		"player_spd": player_spd,
		"max_enemy_spd": max_spd,
		"end_reason": end_after,
	}


func _apply_escape_chase_damage() -> float:
	var fastest: ZhandouObj = null
	var best_spd := -1.0
	for i in _active_enemy_indices():
		var unit := _enemy_at(i)
		if unit == null or unit.is_dead():
			continue
		var spd := unit.get_attr(ZhandouObj.ATTR_SPD)
		if spd > best_spd:
			best_spd = spd
			fastest = unit
	if fastest == null or player == null:
		return 0.0
	var atk := maxf(
		fastest.get_attr(ZhandouAttr.PHYSICAL_ATK),
		fastest.get_attr(ZhandouAttr.MAGIC_ATK)
	)
	var dmg := ZhandouBalance.escape_chase_damage(atk)
	player.be_attacked(dmg)
	return dmg


func resolve_player_basic() -> Dictionary:
	return _resolve_basic(EnumBattleSide.PLAYER)


func resolve_player_skill(skill_id: int) -> Dictionary:
	if not can_player_act():
		ZhandouDebugLog.write("行动", "玩家技能被拒绝", {
			"技能ID": skill_id,
			"原因": ZhandouDebugLog.fail_reason_label("not_paused"),
		})
		return _fail_payload("not_paused")
	var target := _current_enemy()
	var result := player.use_skill(skill_id, skill_cfg, target)
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "failed"))
		ZhandouDebugLog.write("行动", "玩家技能失败", {
			"技能ID": skill_id,
			"原因": ZhandouDebugLog.fail_reason_label(reason),
		})
		return _fail_payload(reason)
	var cfg := _lookup_skill_cfg(skill_id)
	ZhandouDebugLog.write("行动", "玩家技能结算完成", {
		"技能ID": skill_id,
		"伤害": result.get("damage", 0.0),
		"玩家": ZhandouDebugLog.log_unit(player, "player"),
		"敌方": ZhandouDebugLog.log_unit(enemy, "enemy"),
	})
	return _with_actor_ids(_ok_payload(EnumBattleSide.PLAYER, EnumBattleSide.ENEMY, result, cfg), EnumBattleSide.PLAYER, _enemy_index_for_unit(target))


func resolve_player_item(slot_index: int) -> Dictionary:
	if not can_player_act():
		return _fail_payload("not_paused")
	var target := _current_enemy()
	var result := player.use_item_at(slot_index, item_cfg, target)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var cfg := ZhandouObj._lookup_cfg(item_cfg, int(result.get("item_id", -1)))
	return _with_actor_ids(_ok_payload(EnumBattleSide.PLAYER, EnumBattleSide.ENEMY, result, cfg), EnumBattleSide.PLAYER, _enemy_index_for_unit(target))


func resolve_player_equip(slot_index: int) -> Dictionary:
	if not can_player_act():
		return _fail_payload("not_paused")
	var target := _current_enemy()
	var result := player.use_equip_at(slot_index, target, equip_cfg)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var equip_id := int(result.get("equip_id", -1))
	var slot := player.get_equip_slot_at(slot_index)
	var cfg := _merge_equip_runtime_cfg(slot, equip_id)
	return _with_actor_ids(_ok_payload(EnumBattleSide.PLAYER, EnumBattleSide.ENEMY, result, cfg), EnumBattleSide.PLAYER, _enemy_index_for_unit(target))


func resolve_enemy_basic() -> Dictionary:
	return _resolve_basic(EnumBattleSide.ENEMY)


func resolve_enemy_skill(skill_id: int) -> Dictionary:
	if state != EnumBattleState.State.PAUSED or paused_side != EnumBattleSide.ENEMY:
		ZhandouDebugLog.write("行动", "敌方技能被拒绝", {
			"技能ID": skill_id,
			"原因": ZhandouDebugLog.fail_reason_label("not_paused"),
		})
		return _fail_payload("not_paused")
	enemy = _current_enemy()
	var result := enemy.use_skill(skill_id, skill_cfg, player)
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "failed"))
		ZhandouDebugLog.write("行动", "敌方技能失败", {
			"技能ID": skill_id,
			"原因": ZhandouDebugLog.fail_reason_label(reason),
		})
		return _fail_payload(reason)
	var cfg := _lookup_skill_cfg(skill_id)
	ZhandouDebugLog.write("行动", "敌方技能结算完成", {
		"技能ID": skill_id,
		"伤害": result.get("damage", 0.0),
		"敌方": ZhandouDebugLog.log_unit(enemy, "enemy"),
		"玩家": ZhandouDebugLog.log_unit(player, "player"),
	})
	return _with_actor_ids(_ok_payload(EnumBattleSide.ENEMY, EnumBattleSide.PLAYER, result, cfg), EnumBattleSide.ENEMY, active_enemy_index)


func resolve_enemy_item(slot_index: int) -> Dictionary:
	if state != EnumBattleState.State.PAUSED or paused_side != EnumBattleSide.ENEMY:
		return _fail_payload("not_paused")
	enemy = _current_enemy()
	var result := enemy.use_item_at(slot_index, item_cfg, player)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var cfg := ZhandouObj._lookup_cfg(item_cfg, int(result.get("item_id", -1)))
	return _with_actor_ids(_ok_payload(EnumBattleSide.ENEMY, EnumBattleSide.PLAYER, result, cfg), EnumBattleSide.ENEMY, active_enemy_index)


func resolve_enemy_equip(slot_index: int) -> Dictionary:
	if state != EnumBattleState.State.PAUSED or paused_side != EnumBattleSide.ENEMY:
		return _fail_payload("not_paused")
	enemy = _current_enemy()
	var result := enemy.use_equip_at(slot_index, player, equip_cfg)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var equip_id := int(result.get("equip_id", -1))
	var slot := enemy.get_equip_slot_at(slot_index)
	var cfg := _merge_equip_runtime_cfg(slot, equip_id)
	return _with_actor_ids(_ok_payload(EnumBattleSide.ENEMY, EnumBattleSide.PLAYER, result, cfg), EnumBattleSide.ENEMY, active_enemy_index)


## 表现结束：恢复走条并回到 ADVANCING（可重复调用）。
func finish_presentation() -> void:
	if state != EnumBattleState.State.PRESENTATION:
		ZhandouDebugLog.write("表现", "跳过结束表现（状态不符）", {
			"当前状态": ZhandouDebugLog.state_label(state),
		})
		return
	var side := presentation_side if presentation_side != "" else paused_side
	if side != EnumBattleSide.PLAYER and side != EnumBattleSide.ENEMY:
		push_warning("ZhandouDomainService.finish_presentation: invalid actor '%s'" % side)
		side = EnumBattleSide.PLAYER
	var before_player := interval_elapsed_player
	var before_enemy := interval_elapsed_enemy
	presentation_side = ""
	_apply_interval_after_action(side)
	if side == EnumBattleSide.ENEMY:
		acting_enemy_index = -1
		acting_enemy_slot = -1
	paused_side = ""
	_set_state(EnumBattleState.State.ADVANCING, "表现结束(%s)" % ZhandouDebugLog.side_label(side))
	ZhandouDebugLog.write("表现", "表现结束，恢复走条", {
		"出手方": ZhandouDebugLog.side_label(side),
		"玩家走条前": "%.2f" % before_player,
		"玩家走条后": format_interval(EnumBattleSide.PLAYER),
		"敌方走条前": "%.2f" % before_enemy,
		"敌方走条后": format_interval(EnumBattleSide.ENEMY),
	})
	ZhandouDebugLog.log_domain(self, "表现后")


func on_presentation_finished() -> void:
	finish_presentation()


func check_end_after_resolve() -> String:
	if player.is_dead():
		_set_end(SIGNAL_PLAYER_DEAD, "结算后检查胜负")
		ZhandouDebugLog.write("结束", "玩家阵亡", get_debug_snapshot())
		return SIGNAL_PLAYER_DEAD
	_compact_formation()
	if _all_enemies_dead():
		_set_end(SIGNAL_ENEMY_DEAD, "结算后检查胜负")
		ZhandouDebugLog.write("结束", "敌方阵亡", get_debug_snapshot())
		return SIGNAL_ENEMY_DEAD
	_refresh_active_enemy()
	return ""


func get_ui_snapshot() -> Dictionary:
	return {
		"intervals": {
			"left": {"elapsed": interval_elapsed_player, "cap": interval_T_player},
			"right": {"elapsed": interval_elapsed_enemy, "cap": interval_T_enemy},
		},
		"enemy_index": active_enemy_index,
		"enemy_count": enemies.size(),
		"formation": get_formation_snapshot(),
	}


static func _capture_overflow(elapsed: float, cap: float) -> float:
	return clampf(elapsed - cap, 0.0, cap)


## 编排层开始播 VFX 前调用；此前须已完成数据结算（仍为 PAUSED）。
func begin_presentation(side: String) -> void:
	if state != EnumBattleState.State.PAUSED:
		push_warning(
			"ZhandouDomainService.begin_presentation: invalid state %s" % ZhandouDebugLog.state_label(state)
		)
		return
	if side != EnumBattleSide.PLAYER and side != EnumBattleSide.ENEMY:
		push_warning("ZhandouDomainService.begin_presentation: invalid side '%s'" % side)
		return
	if paused_side != side:
		push_warning(
			"ZhandouDomainService.begin_presentation: side mismatch paused=%s req=%s"
			% [paused_side, side]
		)
		return
	if side == EnumBattleSide.PLAYER:
		_overflow_player = _capture_overflow(interval_elapsed_player, interval_T_player)
	elif side == EnumBattleSide.ENEMY:
		var idx := _acting_enemy_index()
		_overflow_enemies[idx] = _capture_overflow(float(interval_elapsed_enemies[idx]), interval_T_enemy)
		_sync_legacy_enemy_interval()
	presentation_side = side
	_set_state(EnumBattleState.State.PRESENTATION, "开始表现(%s)" % ZhandouDebugLog.side_label(side))
	ZhandouDebugLog.write("表现", "开始播放", {
		"出手方": ZhandouDebugLog.side_label(side),
		"玩家溢出": _overflow_player,
		"敌方溢出": _overflow_enemy,
	})


## 数据已结算但表现未播时回滚（如 VFX 节点缺失）。
func abort_presentation() -> void:
	if state != EnumBattleState.State.PRESENTATION:
		return
	finish_presentation()


func consume_runtime_events() -> Array:
	if _runtime_events.is_empty():
		return []
	var out := _runtime_events.duplicate(true)
	_runtime_events.clear()
	return out


func _apply_interval_after_action(side: String) -> void:
	# 出手后重置行动进度，再加回越过 100 的溢出进度。
	if side == EnumBattleSide.PLAYER:
		interval_elapsed_player = minf(_overflow_player, interval_T_player)
		_overflow_player = 0.0
	elif side == EnumBattleSide.ENEMY:
		var idx := _acting_enemy_index()
		interval_elapsed_enemies[idx] = minf(float(_overflow_enemies[idx]), interval_T_enemy)
		_overflow_enemies[idx] = 0.0
		_sync_legacy_enemy_interval()


func _resolve_basic(side: String) -> Dictionary:
	if state != EnumBattleState.State.PAUSED:
		ZhandouDebugLog.write("行动", "普攻被拒绝", {
			"出手方": ZhandouDebugLog.side_label(side),
			"原因": ZhandouDebugLog.fail_reason_label("not_paused"),
		})
		return _fail_payload("not_paused")
	if paused_side != side:
		ZhandouDebugLog.write("行动", "普攻被拒绝", {
			"出手方": ZhandouDebugLog.side_label(side),
			"当前暂停方": ZhandouDebugLog.side_label(paused_side),
			"原因": ZhandouDebugLog.fail_reason_label("wrong_actor"),
		})
		return _fail_payload("wrong_actor")
	var attacker: ZhandouObj
	var defender: ZhandouObj
	var source_id: String
	var target_id: String
	if side == EnumBattleSide.PLAYER:
		attacker = player
		defender = _current_enemy()
		source_id = EnumBattleSide.PLAYER
		target_id = EnumBattleSide.ENEMY
	else:
		enemy = _current_enemy()
		attacker = enemy
		defender = player
		source_id = EnumBattleSide.ENEMY
		target_id = EnumBattleSide.PLAYER
	var report := ZhandouObj.resolve_basic_attack(attacker, defender)
	ZhandouDebugLog.write("行动", "普攻结算完成", {
		"出手方": ZhandouDebugLog.side_label(side),
		"伤害": report.get("damage", 0.0),
		"攻击方": ZhandouDebugLog.log_unit(attacker, side),
		"防守方": ZhandouDebugLog.log_unit(defender, "defender"),
	})
	var cfg: Dictionary = {}
	var basic_v: Variant = _lookup_skill_cfg(0)
	if basic_v is Dictionary:
		cfg = (basic_v as Dictionary).duplicate(true)
	else:
		cfg = {"tags": ["attack", "physical"]}
	var payload := _ok_payload(source_id, target_id, report, cfg)
	if side == EnumBattleSide.PLAYER:
		return _with_actor_ids(payload, EnumBattleSide.PLAYER, _enemy_index_for_unit(defender))
	return _with_actor_ids(payload, EnumBattleSide.ENEMY, active_enemy_index)


func _lookup_skill_cfg(skill_id: int) -> Dictionary:
	if skill_cfg.has(skill_id):
		var v: Variant = skill_cfg[skill_id]
		return v as Dictionary if v is Dictionary else {}
	var ks := str(skill_id)
	if skill_cfg.has(ks):
		var v2: Variant = skill_cfg[ks]
		return v2 as Dictionary if v2 is Dictionary else {}
	return {}


func _merge_equip_runtime_cfg(slot: Dictionary, equip_id: int) -> Dictionary:
	var cfg := ZhandouObj._lookup_cfg(equip_cfg, equip_id).duplicate(true)
	if slot.is_empty():
		return cfg
	if slot.has("effects"):
		cfg["effects"] = (slot["effects"] as Array).duplicate(true)
	for key in ["vfx_type", "vfx", "costs", "cost_text", "mp_cost", "power", "tags"]:
		if slot.has(key):
			cfg[key] = slot[key]
	return cfg


func format_interval(side: String) -> String:
	if side == EnumBattleSide.PLAYER:
		return "%.1f/%.0f（速率 %.1f/s，溢出 %.1f）" % [
			interval_elapsed_player, interval_T_player,
			ZhandouBalance.action_progress_rate_for(player), _overflow_player,
		]
	if side == EnumBattleSide.ENEMY:
		return "%.1f/%.0f（速率 %.1f/s，溢出 %.1f，slot %d）" % [
			interval_elapsed_enemy, interval_T_enemy,
			ZhandouBalance.action_progress_rate_for(enemy), _overflow_enemy,
			active_enemy_slot,
		]
	return ""


func get_debug_snapshot() -> Dictionary:
	return {
		"状态": ZhandouDebugLog.state_label(state),
		"状态ID": state,
		"暂停方": ZhandouDebugLog.side_label(paused_side),
		"表现方": ZhandouDebugLog.side_label(presentation_side),
		"结束原因": ZhandouDebugLog.end_reason_label(end_reason),
		"战斗用时": "%.2f/%.2f" % [battle_elapsed_advancing, battle_time_limit],
		"玩家走条": format_interval(EnumBattleSide.PLAYER),
		"敌方走条": format_interval(EnumBattleSide.ENEMY),
		"玩家": ZhandouDebugLog.log_unit(player, "player"),
		"敌方": ZhandouDebugLog.log_unit(enemy, "enemy"),
		"阵型": get_formation_snapshot(),
	}


func _set_state(next: EnumBattleState.State, reason: String) -> void:
	if state == next:
		return
	var from := state
	state = next
	ZhandouDebugLog.log_state(from, next, reason)


func _set_end(reason: String, trigger: String = "") -> void:
	end_reason = reason
	var log_trigger := trigger if trigger != "" else ZhandouDebugLog.end_reason_label(reason)
	_set_state(EnumBattleState.State.END, log_trigger)


func _drain_runtime_events() -> void:
	if player != null and player.has_method("pop_runtime_events"):
		for ev in player.call("pop_runtime_events", EnumBattleSide.PLAYER):
			if ev is Dictionary:
				_runtime_events.append(ev)
	if enemy != null and enemy.has_method("pop_runtime_events"):
		pass
	for unit_v in enemies:
		if unit_v is ZhandouObj and (unit_v as ZhandouObj).has_method("pop_runtime_events"):
			for ev in (unit_v as ZhandouObj).call("pop_runtime_events", EnumBattleSide.ENEMY):
				if ev is Dictionary:
					_runtime_events.append(ev)


func _enemy_at(index: int) -> ZhandouObj:
	if index < 0 or index >= enemies.size():
		return null
	var unit_v: Variant = enemies[index]
	return unit_v as ZhandouObj if unit_v is ZhandouObj else null


func _current_enemy() -> ZhandouObj:
	if paused_side == EnumBattleSide.ENEMY and acting_enemy_index >= 0:
		active_enemy_index = acting_enemy_index
		active_enemy_slot = acting_enemy_slot
	var current := _enemy_at(active_enemy_index)
	if current == null or current.is_dead() or not _is_active_enemy_index(active_enemy_index):
		_refresh_active_enemy()
		current = _enemy_at(active_enemy_index)
	enemy = current
	_sync_legacy_enemy_interval()
	return enemy


func _refresh_active_enemy() -> void:
	_compact_formation()
	if enemies.is_empty():
		enemy = null
		return
	if active_enemy_index >= 0 and active_enemy_index < enemies.size() and _is_active_enemy_index(active_enemy_index):
		var active := _enemy_at(active_enemy_index)
		if active != null and not active.is_dead():
			enemy = active
			active_enemy_slot = _slot_for_enemy_index(active_enemy_index)
			_sync_legacy_enemy_interval()
			return
	for i in _active_enemy_indices():
		var candidate := _enemy_at(i)
		if candidate != null and not candidate.is_dead():
			active_enemy_index = i
			active_enemy_slot = _slot_for_enemy_index(i)
			enemy = candidate
			_sync_legacy_enemy_interval()
			return
	enemy = null


func _first_ready_enemy_index() -> int:
	for i in _active_enemy_indices():
		var unit := _enemy_at(i)
		if unit == null or unit.is_dead():
			continue
		if float(interval_elapsed_enemies[i]) >= interval_T_enemy:
			return i
	return -1


func _acting_enemy_index() -> int:
	if acting_enemy_index >= 0 and acting_enemy_index < enemies.size():
		return acting_enemy_index
	return clampi(active_enemy_index, 0, maxi(0, enemies.size() - 1))


func _all_enemies_dead() -> bool:
	for unit_v in enemies:
		if unit_v is ZhandouObj and not (unit_v as ZhandouObj).is_dead():
			return false
	return true


func _all_alive_units() -> Array:
	var out: Array = []
	if player != null and not player.is_dead():
		out.append(player)
	for unit_v in enemies:
		if unit_v is ZhandouObj and not (unit_v as ZhandouObj).is_dead() and _is_active_enemy_index(enemies.find(unit_v)):
			out.append(unit_v)
	return out


func _sync_legacy_enemy_interval() -> void:
	if active_enemy_index >= 0 and active_enemy_index < interval_elapsed_enemies.size():
		interval_elapsed_enemy = float(interval_elapsed_enemies[active_enemy_index])
	if active_enemy_index >= 0 and active_enemy_index < _overflow_enemies.size():
		_overflow_enemy = float(_overflow_enemies[active_enemy_index])


func _apply_formation_config(cfg: Dictionary) -> void:
	formation_mode = EnumBattleFormationMode.normalize_label(cfg.get("mode", FORMATION_MODE_COLUMNS))
	if formation_mode == "":
		formation_mode = FORMATION_MODE_COLUMNS
	formation_columns = clampi(int(cfg.get("columns", DEFAULT_FORMATION_COLUMNS)), 1, 6)
	formation_rows = clampi(int(cfg.get("rows", DEFAULT_FORMATION_ROWS)), 1, 8)
	active_columns = clampi(int(cfg.get("active_columns", DEFAULT_ACTIVE_COLUMNS)), 1, formation_columns)
	formation_rank_size = clampi(int(cfg.get("rank_size", 0)), 0, formation_rows)
	enemy_waves = _normalize_enemy_waves(cfg.get("waves", []))
	active_wave_index = 0
	if formation_mode == FORMATION_MODE_WAVES and enemy_waves.is_empty():
		formation_mode = FORMATION_MODE_COLUMNS


func _normalize_enemy_waves(raw: Variant) -> Array:
	var waves: Array = []
	if not raw is Array:
		return waves
	for wave_v in raw as Array:
		if not wave_v is Array:
			continue
		var wave: Array = []
		for idx_v in wave_v as Array:
			var idx := int(idx_v)
			if idx >= 0 and not wave.has(idx):
				wave.append(idx)
		if not wave.is_empty():
			waves.append(wave)
	return waves


func _formation_capacity() -> int:
	return formation_columns * formation_rows


func _slot_index(column: int, row: int) -> int:
	return column * formation_rows + row


func _slot_column(slot: int) -> int:
	return int(floor(float(slot) / float(maxi(1, formation_rows))))


func _slot_row(slot: int) -> int:
	return slot % maxi(1, formation_rows)


func _rebuild_formation_slots() -> void:
	enemy_formation_slots.clear()
	enemy_reserve_indices.clear()
	var cap := _formation_capacity()
	for i in cap:
		enemy_formation_slots.append(-1)
	if formation_mode == FORMATION_MODE_WAVES:
		_rebuild_wave_formation_slots()
		return
	if formation_rank_size > 0:
		var ordered_slots := _rank_limited_slot_order()
		for i in mini(ordered_slots.size(), enemies.size()):
			enemy_formation_slots[int(ordered_slots[i])] = i
		for i in range(ordered_slots.size(), enemies.size()):
			enemy_reserve_indices.append(i)
		return
	if formation_rows == DEFAULT_FORMATION_ROWS and enemies.size() <= formation_rows:
		var centered_rows := _centered_row_order()
		for i in enemies.size():
			var row := int(centered_rows[i])
			enemy_formation_slots[_slot_index(0, row)] = i
		return
	for i in mini(cap, enemies.size()):
		enemy_formation_slots[i] = i
	for i in range(cap, enemies.size()):
		enemy_reserve_indices.append(i)


func _rebuild_wave_formation_slots() -> void:
	for slot in enemy_formation_slots.size():
		enemy_formation_slots[slot] = -1
	enemy_reserve_indices.clear()
	active_wave_index = _first_alive_wave_index(active_wave_index)
	var active_wave := _current_wave()
	var rows := _centered_row_order()
	for i in mini(active_wave.size(), rows.size()):
		var idx := int(active_wave[i])
		var unit := _enemy_at(idx)
		if unit != null and not unit.is_dead():
			var row := int(rows[i])
			enemy_formation_slots[_slot_index(0, row)] = idx
	for wave_i in enemy_waves.size():
		var wave := enemy_waves[wave_i] as Array
		for idx_v in wave:
			var idx := int(idx_v)
			if active_wave.has(idx):
				continue
			var unit := _enemy_at(idx)
			if unit != null and not unit.is_dead() and not enemy_reserve_indices.has(idx):
				enemy_reserve_indices.append(idx)


func _compact_formation() -> void:
	if formation_mode == FORMATION_MODE_WAVES:
		_compact_wave_formation()
		return
	_purge_dead_from_formation_slots()
	_purge_dead_from_reserve()
	var advance_width := _formation_advance_width()
	_compact_formation_within_rank(advance_width)
	while not _front_formation_has_living(advance_width):
		if not _can_shift_formation_forward(advance_width):
			break
		_shift_formation_columns_forward(advance_width)
	active_enemy_index = _first_active_enemy_index()
	active_enemy_slot = _slot_for_enemy_index(active_enemy_index)
	enemy = _enemy_at(active_enemy_index)
	_sync_legacy_enemy_interval()


func _formation_advance_width() -> int:
	if formation_rank_size > 0:
		return mini(formation_rank_size, formation_columns)
	return 1


func _purge_dead_from_formation_slots() -> void:
	for slot in enemy_formation_slots.size():
		var idx := int(enemy_formation_slots[slot])
		var unit := _enemy_at(idx)
		if idx < 0 or unit == null or unit.is_dead():
			enemy_formation_slots[slot] = -1


func _purge_dead_from_reserve() -> void:
	for i in range(enemy_reserve_indices.size() - 1, -1, -1):
		var reserve_idx := int(enemy_reserve_indices[i])
		var reserve_unit := _enemy_at(reserve_idx)
		if reserve_unit == null or reserve_unit.is_dead():
			enemy_reserve_indices.remove_at(i)


## rank_size>0 时，同一排内从右向左补位；标准列阵不在此步跨列前移。
func _compact_formation_within_rank(rank_width: int) -> void:
	if rank_width <= 1:
		return
	for row in formation_rows:
		for col in rank_width - 1:
			var slot := _slot_index(col, row)
			if int(enemy_formation_slots[slot]) >= 0:
				continue
			for next_col in range(col + 1, rank_width):
				var next_slot := _slot_index(next_col, row)
				var next_idx := int(enemy_formation_slots[next_slot])
				if next_idx >= 0:
					enemy_formation_slots[slot] = next_idx
					enemy_formation_slots[next_slot] = -1
					break


func _column_has_living_enemy(col: int) -> bool:
	for row in formation_rows:
		var idx := int(enemy_formation_slots[_slot_index(col, row)])
		if idx < 0:
			continue
		var unit := _enemy_at(idx)
		if unit != null and not unit.is_dead():
			return true
	return false


func _front_formation_has_living(width: int) -> bool:
	for col in mini(width, formation_columns):
		if _column_has_living_enemy(col):
			return true
	return false


func _can_shift_formation_forward(width: int) -> bool:
	for col in range(width, formation_columns):
		if _column_has_living_enemy(col):
			return true
	for reserve_idx in enemy_reserve_indices:
		var unit := _enemy_at(int(reserve_idx))
		if unit != null and not unit.is_dead():
			return true
	return false


func _shift_formation_columns_forward(width: int) -> void:
	if width <= 0 or width >= formation_columns:
		return
	for row in formation_rows:
		for col in range(formation_columns - width):
			var dst := _slot_index(col, row)
			var src := _slot_index(col + width, row)
			enemy_formation_slots[dst] = enemy_formation_slots[src]
		for col in range(formation_columns - width, formation_columns):
			enemy_formation_slots[_slot_index(col, row)] = _pop_next_reserve_alive()


func _compact_wave_formation() -> void:
	active_wave_index = _first_alive_wave_index(active_wave_index)
	_rebuild_wave_formation_slots()
	active_enemy_index = _first_active_enemy_index()
	active_enemy_slot = _slot_for_enemy_index(active_enemy_index)
	enemy = _enemy_at(active_enemy_index)
	_sync_legacy_enemy_interval()


func _current_wave() -> Array:
	if active_wave_index < 0 or active_wave_index >= enemy_waves.size():
		return []
	return (enemy_waves[active_wave_index] as Array).duplicate()


func _first_alive_wave_index(start_index: int) -> int:
	for wave_i in range(maxi(0, start_index), enemy_waves.size()):
		if _wave_has_alive(enemy_waves[wave_i] as Array):
			return wave_i
	return enemy_waves.size()


func _wave_has_alive(wave: Array) -> bool:
	for idx_v in wave:
		var unit := _enemy_at(int(idx_v))
		if unit != null and not unit.is_dead():
			return true
	return false


func _pop_next_reserve_alive() -> int:
	while not enemy_reserve_indices.is_empty():
		var idx := int(enemy_reserve_indices.pop_front())
		var unit := _enemy_at(idx)
		if unit != null and not unit.is_dead():
			return idx
	return -1


func _active_enemy_indices() -> Array:
	if formation_mode == FORMATION_MODE_WAVES:
		var wave_active: Array = []
		for idx_v in _current_wave():
			var idx := int(idx_v)
			var unit := _enemy_at(idx)
			if unit != null and not unit.is_dead():
				wave_active.append(idx)
		return wave_active
	var out: Array = []
	var rows := _active_row_order()
	for col in active_columns:
		for row_v in rows:
			var row := int(row_v)
			var slot := _slot_index(col, row)
			if slot < 0 or slot >= enemy_formation_slots.size():
				continue
			var idx := int(enemy_formation_slots[slot])
			var unit := _enemy_at(idx)
			if idx >= 0 and unit != null and not unit.is_dead():
				out.append(idx)
	return out


func _is_active_enemy_index(index: int) -> bool:
	if index < 0:
		return false
	if formation_mode == FORMATION_MODE_WAVES:
		return _current_wave().has(index)
	var rows := _active_row_order()
	for col in active_columns:
		for row_v in rows:
			var row := int(row_v)
			var slot := _slot_index(col, row)
			if slot < enemy_formation_slots.size() and int(enemy_formation_slots[slot]) == index:
				return true
	return false


func _first_active_enemy_index() -> int:
	var active := _active_enemy_indices()
	if active.is_empty():
		return -1
	return int(active[0])


func _slot_for_enemy_index(index: int) -> int:
	for slot in enemy_formation_slots.size():
		if int(enemy_formation_slots[slot]) == index:
			return slot
	return -1


func _centered_row_order() -> Array:
	var out: Array = []
	var center := int(floor(float(formation_rows) / 2.0))
	out.append(center)
	for offset in range(1, formation_rows):
		var upper := center - offset
		var lower := center + offset
		if upper >= 0:
			out.append(upper)
		if lower < formation_rows:
			out.append(lower)
	return out


func _rank_limited_slot_order() -> Array:
	var out: Array = []
	var rows := _centered_row_order()
	var per_row := clampi(formation_rank_size, 1, formation_columns)
	for row_v in rows:
		var row := int(row_v)
		for col in mini(per_row, formation_columns):
			out.append(_slot_index(col, row))
	return out


func _active_row_order() -> Array:
	if formation_rows == DEFAULT_FORMATION_ROWS:
		return _centered_row_order()
	var out: Array = []
	for row in formation_rows:
		out.append(row)
	return out


func actor_id_for_enemy_index(index: int) -> String:
	var slot := _slot_for_enemy_index(index)
	if slot < 0:
		return EnumBattleSide.ENEMY
	return "enemy_%d_%d" % [_slot_column(slot), _slot_row(slot)]


func get_formation_snapshot() -> Dictionary:
	var slots: Array = []
	for slot in enemy_formation_slots.size():
		var idx := int(enemy_formation_slots[slot])
		var unit := _enemy_at(idx)
		if idx < 0 or unit == null:
			slots.append({"empty": true, "slot": slot, "column": _slot_column(slot), "row": _slot_row(slot)})
			continue
		slots.append({
			"empty": false,
			"dead": unit.is_dead(),
			"slot": slot,
			"enemy_index": idx,
			"actor_id": actor_id_for_enemy_index(idx),
			"column": _slot_column(slot),
			"row": _slot_row(slot),
			"active": _is_active_enemy_index(idx),
			"current": idx == active_enemy_index,
			"hp": unit.hp,
			"hp_max": unit.get_hp_max(),
			"mp": unit.mp,
			"mp_max": unit.get_mp_max(),
			"interval": {
				"elapsed": float(interval_elapsed_enemies[idx]) if idx < interval_elapsed_enemies.size() else 0.0,
				"cap": interval_T_enemy,
			},
		})
	return {
		"columns": formation_columns,
		"rows": formation_rows,
		"active_columns": active_columns,
		"rank_size": formation_rank_size,
		"mode": formation_mode,
		"current_wave": active_wave_index,
		"slots": slots,
		"reserve_count": enemy_reserve_indices.size(),
	}


## 距离指定敌人轮到行动还需经过的走条推进时长（秒）；暂停/表现阶段返回 0。
func advancing_seconds_until_enemy_turn(enemy_index: int) -> float:
	if state == EnumBattleState.State.END:
		return 0.0
	if not _is_active_enemy_index(enemy_index):
		return 0.0
	var unit := _enemy_at(enemy_index)
	if unit == null or unit.is_dead():
		return 0.0
	if enemy_index >= interval_elapsed_enemies.size():
		return 0.0
	if state == EnumBattleState.State.PAUSED:
		if paused_side == EnumBattleSide.ENEMY:
			var acting_idx := _acting_enemy_index()
			if enemy_index == acting_idx or (acting_idx < 0 and enemy_index == active_enemy_index):
				return 0.0
		return 0.0
	if state == EnumBattleState.State.PRESENTATION:
		return 0.0
	var elapsed := float(interval_elapsed_enemies[enemy_index])
	if elapsed >= interval_T_enemy:
		return 0.0
	var rate := ZhandouBalance.action_progress_rate_for(unit)
	if rate <= 0.0:
		return 0.0
	return (interval_T_enemy - elapsed) / rate


func _enemy_index_for_unit(unit: ZhandouObj) -> int:
	if unit == null:
		return -1
	for i in enemies.size():
		if enemies[i] == unit:
			return i
	return -1


func _with_actor_ids(payload: Dictionary, source_side: String, target_enemy_index: int) -> Dictionary:
	if payload.is_empty():
		return payload
	if source_side == EnumBattleSide.PLAYER:
		payload["source_actor_id"] = EnumBattleSide.PLAYER
		payload["target_actor_id"] = actor_id_for_enemy_index(target_enemy_index)
	else:
		payload["source_actor_id"] = actor_id_for_enemy_index(target_enemy_index)
		payload["target_actor_id"] = EnumBattleSide.PLAYER
	return payload


static func _ok_payload(
		source_id: String,
		target_id: String,
		report: Dictionary,
		cfg: Dictionary
) -> Dictionary:
	return {
		"ok": true,
		"source_id": source_id,
		"target_id": target_id,
		"report": report,
		"cfg": cfg,
	}


static func _fail_payload(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
