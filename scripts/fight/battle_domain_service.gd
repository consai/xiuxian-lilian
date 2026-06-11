class_name BattleDomainService
extends RefCounted
## 战斗域：四态状态机、实时速度行动进度、CD、整场时限与出手结算。
const CombatEventScript = preload("res://scripts/fight/combat_event.gd")

enum BattleState { ADVANCING, PAUSED, PRESENTATION, END }

const SIDE_PLAYER := "player"
const SIDE_ENEMY := "enemy"

const SIGNAL_PLAYER_READY := "player_ready"
const SIGNAL_ENEMY_READY := "enemy_ready"
const SIGNAL_TIME_LIMIT := "time_limit"
const SIGNAL_PLAYER_DEAD := "player_dead"
const SIGNAL_ENEMY_DEAD := "enemy_dead"

var state: BattleState = BattleState.ADVANCING
var paused_side: String = ""
## 进入 PRESENTATION 时的出手方（避免 paused_side 丢失导致走条不归零）。
var presentation_side: String = ""
var end_reason: String = ""

var player: FightObj
var enemy: FightObj
var skill_cfg: Dictionary = {}
var item_cfg: Dictionary = {}
var equip_cfg: Dictionary = {}

var interval_elapsed_player: float = 0.0
var interval_elapsed_enemy: float = 0.0
## 兼容旧字段名：现在表示固定行动进度上限，而非下一次出手所需秒数。
var interval_T_player: float = CombatBalance.ACTION_PROGRESS_MAX
var interval_T_enemy: float = CombatBalance.ACTION_PROGRESS_MAX
var _overflow_player: float = 0.0
var _overflow_enemy: float = 0.0

var battle_elapsed_advancing: float = 0.0
var battle_time_limit: float = 200.0
var _runtime_events: Array = []
var _passive_tick_accum: float = 0.0


func start_battle(
		p_player: FightObj,
		p_enemy: FightObj,
		p_skill_cfg: Dictionary,
		p_time_limit: float = 200.0,
		p_item_cfg: Dictionary = {},
		p_equip_cfg: Dictionary = {}
) -> void:
	player = p_player
	enemy = p_enemy
	skill_cfg = p_skill_cfg
	item_cfg = p_item_cfg
	equip_cfg = p_equip_cfg
	battle_time_limit = p_time_limit
	battle_elapsed_advancing = 0.0
	interval_elapsed_player = 0.0
	interval_elapsed_enemy = 0.0
	interval_T_player = CombatBalance.ACTION_PROGRESS_MAX
	interval_T_enemy = CombatBalance.ACTION_PROGRESS_MAX
	_overflow_player = 0.0
	_overflow_enemy = 0.0
	paused_side = ""
	presentation_side = ""
	end_reason = ""
	_runtime_events.clear()
	_passive_tick_accum = 0.0
	BattleDebugLog.reset_tick_throttle()
	_set_state(BattleState.ADVANCING, "开战")
	BattleDebugLog.log_domain(self, "开战")
	BattleDebugLog.write("流程", "战斗开始", {
		"时限": battle_time_limit,
		"玩家走条速率": CombatBalance.action_progress_rate_for(player),
		"敌方走条速率": CombatBalance.action_progress_rate_for(enemy),
	})


func tick_advancing(delta: float) -> String:
	if state != BattleState.ADVANCING:
		return ""
	if delta <= 0.0:
		return ""
	player.tick_cooldowns(delta)
	enemy.tick_cooldowns(delta)
	_tick_passive_recovery(delta)
	_drain_runtime_events()
	var dot_end := check_end_after_resolve()
	if dot_end != "":
		return dot_end
	battle_elapsed_advancing += delta
	if battle_elapsed_advancing >= battle_time_limit:
		_set_end(SIGNAL_TIME_LIMIT, "走条推进超时")
		BattleDebugLog.write("走条", "达到战斗时限", get_debug_snapshot())
		return SIGNAL_TIME_LIMIT
	interval_elapsed_player += delta * CombatBalance.action_progress_rate_for(player)
	interval_elapsed_enemy += delta * CombatBalance.action_progress_rate_for(enemy)
	BattleDebugLog.tick_progress(self, delta)
	if interval_elapsed_player >= interval_T_player:
		BattleDebugLog.write("走条", "玩家走条已满", {
			"玩家走条": format_interval(SIDE_PLAYER),
			"敌方走条": format_interval(SIDE_ENEMY),
		})
		return SIGNAL_PLAYER_READY
	if interval_elapsed_enemy >= interval_T_enemy:
		BattleDebugLog.write("走条", "敌方走条已满", {
			"玩家走条": format_interval(SIDE_PLAYER),
			"敌方走条": format_interval(SIDE_ENEMY),
		})
		return SIGNAL_ENEMY_READY
	return ""


func _tick_passive_recovery(delta: float) -> void:
	_passive_tick_accum += delta
	while _passive_tick_accum >= 2.0:
		_passive_tick_accum -= 2.0
		for unit in [player, enemy]:
			if unit == null or unit.is_dead():
				continue
			var mp_gain: float = unit.get_attr(FightAttr.COMBAT_MP_RESTORE_2S, 0.0)
			if mp_gain > 0.0:
				unit.change_mp(mp_gain)


func enter_paused(side: String) -> void:
	if state != BattleState.ADVANCING:
		push_warning("BattleDomainService.enter_paused: invalid state %s" % BattleDebugLog.state_label(state))
		return
	if side != SIDE_PLAYER and side != SIDE_ENEMY:
		push_warning("BattleDomainService.enter_paused: invalid side '%s'" % side)
		return
	paused_side = side
	if side == SIDE_PLAYER:
		_overflow_player = _capture_overflow(interval_elapsed_player, interval_T_player)
		interval_elapsed_player = interval_T_player
	elif side == SIDE_ENEMY:
		_overflow_enemy = _capture_overflow(interval_elapsed_enemy, interval_T_enemy)
		interval_elapsed_enemy = interval_T_enemy
	_set_state(BattleState.PAUSED, "进入暂停(%s)" % BattleDebugLog.side_label(side))
	BattleDebugLog.write("流程", "进入暂停", {
		"出手方": BattleDebugLog.side_label(side),
		"玩家溢出": _overflow_player,
		"敌方溢出": _overflow_enemy,
		"玩家走条": format_interval(SIDE_PLAYER),
		"敌方走条": format_interval(SIDE_ENEMY),
	})


func can_player_act() -> bool:
	return state == BattleState.PAUSED and paused_side == SIDE_PLAYER


func resolve_player_basic() -> Dictionary:
	return _resolve_basic(SIDE_PLAYER)


func resolve_player_skill(skill_id: int) -> Dictionary:
	if not can_player_act():
		BattleDebugLog.write("行动", "玩家技能被拒绝", {
			"技能ID": skill_id,
			"原因": BattleDebugLog.fail_reason_label("not_paused"),
		})
		return _fail_payload("not_paused")
	var result := player.use_skill(skill_id, skill_cfg, enemy)
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "failed"))
		BattleDebugLog.write("行动", "玩家技能失败", {
			"技能ID": skill_id,
			"原因": BattleDebugLog.fail_reason_label(reason),
		})
		return _fail_payload(reason)
	var cfg := _lookup_skill_cfg(skill_id)
	BattleDebugLog.write("行动", "玩家技能结算完成", {
		"技能ID": skill_id,
		"伤害": result.get("damage", 0.0),
		"暴击": result.get("is_crit", false),
		"玩家": BattleDebugLog.log_unit(player, "player"),
		"敌方": BattleDebugLog.log_unit(enemy, "enemy"),
	})
	return _ok_payload(SIDE_PLAYER, SIDE_ENEMY, result, cfg)


func resolve_player_item(slot_index: int) -> Dictionary:
	if not can_player_act():
		return _fail_payload("not_paused")
	var result := player.use_item_at(slot_index, item_cfg, enemy)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var cfg := FightObj._lookup_cfg(item_cfg, int(result.get("item_id", -1)))
	return _ok_payload(SIDE_PLAYER, SIDE_ENEMY, result, cfg)


func resolve_player_equip(slot_index: int) -> Dictionary:
	if not can_player_act():
		return _fail_payload("not_paused")
	var result := player.use_equip_at(slot_index, enemy, equip_cfg)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var equip_id := int(result.get("equip_id", -1))
	var slot := player.get_equip_slot_at(slot_index)
	var cfg := _merge_equip_runtime_cfg(slot, equip_id)
	return _ok_payload(SIDE_PLAYER, SIDE_ENEMY, result, cfg)


func resolve_enemy_basic() -> Dictionary:
	return _resolve_basic(SIDE_ENEMY)


func resolve_enemy_skill(skill_id: int) -> Dictionary:
	if state != BattleState.PAUSED or paused_side != SIDE_ENEMY:
		BattleDebugLog.write("行动", "敌方技能被拒绝", {
			"技能ID": skill_id,
			"原因": BattleDebugLog.fail_reason_label("not_paused"),
		})
		return _fail_payload("not_paused")
	var result := enemy.use_skill(skill_id, skill_cfg, player)
	if not bool(result.get("ok", false)):
		var reason := str(result.get("reason", "failed"))
		BattleDebugLog.write("行动", "敌方技能失败", {
			"技能ID": skill_id,
			"原因": BattleDebugLog.fail_reason_label(reason),
		})
		return _fail_payload(reason)
	var cfg := _lookup_skill_cfg(skill_id)
	BattleDebugLog.write("行动", "敌方技能结算完成", {
		"技能ID": skill_id,
		"伤害": result.get("damage", 0.0),
		"暴击": result.get("is_crit", false),
		"敌方": BattleDebugLog.log_unit(enemy, "enemy"),
		"玩家": BattleDebugLog.log_unit(player, "player"),
	})
	return _ok_payload(SIDE_ENEMY, SIDE_PLAYER, result, cfg)


func resolve_enemy_item(slot_index: int) -> Dictionary:
	if state != BattleState.PAUSED or paused_side != SIDE_ENEMY:
		return _fail_payload("not_paused")
	var result := enemy.use_item_at(slot_index, item_cfg, player)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var cfg := FightObj._lookup_cfg(item_cfg, int(result.get("item_id", -1)))
	return _ok_payload(SIDE_ENEMY, SIDE_PLAYER, result, cfg)


func resolve_enemy_equip(slot_index: int) -> Dictionary:
	if state != BattleState.PAUSED or paused_side != SIDE_ENEMY:
		return _fail_payload("not_paused")
	var result := enemy.use_equip_at(slot_index, player, equip_cfg)
	if not bool(result.get("ok", false)):
		return _fail_payload(str(result.get("reason", "failed")))
	var equip_id := int(result.get("equip_id", -1))
	var slot := enemy.get_equip_slot_at(slot_index)
	var cfg := _merge_equip_runtime_cfg(slot, equip_id)
	return _ok_payload(SIDE_ENEMY, SIDE_PLAYER, result, cfg)


## 表现结束：恢复走条并回到 ADVANCING（可重复调用）。
func finish_presentation() -> void:
	if state != BattleState.PRESENTATION:
		BattleDebugLog.write("表现", "跳过结束表现（状态不符）", {
			"当前状态": BattleDebugLog.state_label(state),
		})
		return
	var side := presentation_side if presentation_side != "" else paused_side
	if side != SIDE_PLAYER and side != SIDE_ENEMY:
		push_warning("BattleDomainService.finish_presentation: invalid actor '%s'" % side)
		side = SIDE_PLAYER
	var before_player := interval_elapsed_player
	var before_enemy := interval_elapsed_enemy
	presentation_side = ""
	_apply_interval_after_action(side)
	paused_side = ""
	_set_state(BattleState.ADVANCING, "表现结束(%s)" % BattleDebugLog.side_label(side))
	BattleDebugLog.write("表现", "表现结束，恢复走条", {
		"出手方": BattleDebugLog.side_label(side),
		"玩家走条前": "%.2f" % before_player,
		"玩家走条后": format_interval(SIDE_PLAYER),
		"敌方走条前": "%.2f" % before_enemy,
		"敌方走条后": format_interval(SIDE_ENEMY),
	})
	BattleDebugLog.log_domain(self, "表现后")


func on_presentation_finished() -> void:
	finish_presentation()


func check_end_after_resolve() -> String:
	if player.is_dead():
		_set_end(SIGNAL_PLAYER_DEAD, "结算后检查胜负")
		BattleDebugLog.write("结束", "玩家阵亡", get_debug_snapshot())
		return SIGNAL_PLAYER_DEAD
	if enemy.is_dead():
		_set_end(SIGNAL_ENEMY_DEAD, "结算后检查胜负")
		BattleDebugLog.write("结束", "敌方阵亡", get_debug_snapshot())
		return SIGNAL_ENEMY_DEAD
	return ""


func get_ui_snapshot() -> Dictionary:
	return {
		"intervals": {
			"left": {"elapsed": interval_elapsed_player, "cap": interval_T_player},
			"right": {"elapsed": interval_elapsed_enemy, "cap": interval_T_enemy},
		},
	}


static func _capture_overflow(elapsed: float, cap: float) -> float:
	return clampf(elapsed - cap, 0.0, cap)


## 编排层开始播 VFX 前调用；此前须已完成数据结算（仍为 PAUSED）。
func begin_presentation(side: String) -> void:
	if state != BattleState.PAUSED:
		push_warning(
			"BattleDomainService.begin_presentation: invalid state %s" % BattleDebugLog.state_label(state)
		)
		return
	if side != SIDE_PLAYER and side != SIDE_ENEMY:
		push_warning("BattleDomainService.begin_presentation: invalid side '%s'" % side)
		return
	if paused_side != side:
		push_warning(
			"BattleDomainService.begin_presentation: side mismatch paused=%s req=%s"
			% [paused_side, side]
		)
		return
	if side == SIDE_PLAYER:
		_overflow_player = _capture_overflow(interval_elapsed_player, interval_T_player)
	elif side == SIDE_ENEMY:
		_overflow_enemy = _capture_overflow(interval_elapsed_enemy, interval_T_enemy)
	presentation_side = side
	_set_state(BattleState.PRESENTATION, "开始表现(%s)" % BattleDebugLog.side_label(side))
	BattleDebugLog.write("表现", "开始播放", {
		"出手方": BattleDebugLog.side_label(side),
		"玩家溢出": _overflow_player,
		"敌方溢出": _overflow_enemy,
	})


## 数据已结算但表现未播时回滚（如 VFX 节点缺失）。
func abort_presentation() -> void:
	if state != BattleState.PRESENTATION:
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
	if side == SIDE_PLAYER:
		interval_elapsed_player = minf(_overflow_player, interval_T_player)
		_overflow_player = 0.0
	elif side == SIDE_ENEMY:
		interval_elapsed_enemy = minf(_overflow_enemy, interval_T_enemy)
		_overflow_enemy = 0.0


func _resolve_basic(side: String) -> Dictionary:
	if state != BattleState.PAUSED:
		BattleDebugLog.write("行动", "普攻被拒绝", {
			"出手方": BattleDebugLog.side_label(side),
			"原因": BattleDebugLog.fail_reason_label("not_paused"),
		})
		return _fail_payload("not_paused")
	if paused_side != side:
		BattleDebugLog.write("行动", "普攻被拒绝", {
			"出手方": BattleDebugLog.side_label(side),
			"当前暂停方": BattleDebugLog.side_label(paused_side),
			"原因": BattleDebugLog.fail_reason_label("wrong_actor"),
		})
		return _fail_payload("wrong_actor")
	var attacker: FightObj
	var defender: FightObj
	var source_id: String
	var target_id: String
	if side == SIDE_PLAYER:
		attacker = player
		defender = enemy
		source_id = SIDE_PLAYER
		target_id = SIDE_ENEMY
	else:
		attacker = enemy
		defender = player
		source_id = SIDE_ENEMY
		target_id = SIDE_PLAYER
	var report := FightObj.resolve_basic_attack(attacker, defender)
	BattleDebugLog.write("行动", "普攻结算完成", {
		"出手方": BattleDebugLog.side_label(side),
		"伤害": report.get("damage", 0.0),
		"暴击": report.get("is_crit", false),
		"攻击方": BattleDebugLog.log_unit(attacker, side),
		"防守方": BattleDebugLog.log_unit(defender, "defender"),
	})
	var cfg: Dictionary = {}
	var basic_v: Variant = _lookup_skill_cfg(0)
	if basic_v is Dictionary:
		cfg = (basic_v as Dictionary).duplicate(true)
	else:
		cfg = {"tags": ["attack", "physical"]}
	return _ok_payload(source_id, target_id, report, cfg)


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
	var cfg := FightObj._lookup_cfg(equip_cfg, equip_id).duplicate(true)
	if slot.is_empty():
		return cfg
	if slot.has("effects"):
		cfg["effects"] = (slot["effects"] as Array).duplicate(true)
	for key in ["vfx_type", "vfx", "mp_cost", "power", "tags"]:
		if slot.has(key):
			cfg[key] = slot[key]
	return cfg


func format_interval(side: String) -> String:
	if side == SIDE_PLAYER:
		return "%.1f/%.0f（速率 %.1f/s，溢出 %.1f）" % [
			interval_elapsed_player, interval_T_player,
			CombatBalance.action_progress_rate_for(player), _overflow_player,
		]
	if side == SIDE_ENEMY:
		return "%.1f/%.0f（速率 %.1f/s，溢出 %.1f）" % [
			interval_elapsed_enemy, interval_T_enemy,
			CombatBalance.action_progress_rate_for(enemy), _overflow_enemy,
		]
	return ""


func get_debug_snapshot() -> Dictionary:
	return {
		"状态": BattleDebugLog.state_label(state),
		"状态ID": state,
		"暂停方": BattleDebugLog.side_label(paused_side),
		"表现方": BattleDebugLog.side_label(presentation_side),
		"结束原因": BattleDebugLog.end_reason_label(end_reason),
		"战斗用时": "%.2f/%.2f" % [battle_elapsed_advancing, battle_time_limit],
		"玩家走条": format_interval(SIDE_PLAYER),
		"敌方走条": format_interval(SIDE_ENEMY),
		"玩家": BattleDebugLog.log_unit(player, "player"),
		"敌方": BattleDebugLog.log_unit(enemy, "enemy"),
	}


func _set_state(next: BattleState, reason: String) -> void:
	if state == next:
		return
	var from := state
	state = next
	BattleDebugLog.log_state(from, next, reason)


func _set_end(reason: String, trigger: String = "") -> void:
	end_reason = reason
	var log_trigger := trigger if trigger != "" else BattleDebugLog.end_reason_label(reason)
	_set_state(BattleState.END, log_trigger)


func _drain_runtime_events() -> void:
	if player != null and player.has_method("pop_runtime_events"):
		for ev in player.call("pop_runtime_events", SIDE_PLAYER):
			if ev is Dictionary:
				_runtime_events.append(ev)
	if enemy != null and enemy.has_method("pop_runtime_events"):
		for ev in enemy.call("pop_runtime_events", SIDE_ENEMY):
			if ev is Dictionary:
				_runtime_events.append(ev)


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
