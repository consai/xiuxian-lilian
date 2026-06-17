class_name FightSceneActions
extends RefCounted

## 槽位校验、出手解析与敌方 AI 决策。

const EnemyAiServiceScript = preload("res://scripts/fight/ai/enemy_ai_service.gd")
const EnemyAiTypesScript = preload("res://scripts/fight/ai/enemy_ai_types.gd")

const BLOCK_OK := "ok"
const BLOCK_BATTLE_BUSY := "battle_busy"
const BLOCK_EMPTY_SLOT := "empty_slot"
const BLOCK_COOLDOWN := "cooldown"
const BLOCK_INSUFFICIENT_MP := "insufficient_mp"
const BLOCK_NO_COUNT := "no_count"


static func skill_id_at(actor: FightObj, index: int) -> int:
	if index < 0 or not actor.skills is Array or index >= (actor.skills as Array).size():
		return -1
	var slot_v: Variant = (actor.skills as Array)[index]
	if not slot_v is Dictionary:
		return -1
	return int((slot_v as Dictionary).get("id", -1))


static func find_basic_attack_slot(actor: FightObj) -> int:
	if not actor.skills is Array:
		return -1
	for i in (actor.skills as Array).size():
		if skill_id_at(actor, i) == 0:
			return i
	return -1


static func find_auto_skill_slot(
		ctx: FightSceneContext,
		actor: FightObj,
		check_interactive: bool
) -> int:
	if not actor.skills is Array:
		return -1
	var interactive := ctx.skill_slot_interactive
	for i in (actor.skills as Array).size():
		if check_interactive:
			if i >= interactive.size() or not interactive[i]:
				continue
		var skill_id := skill_id_at(actor, i)
		if skill_id < 0:
			continue
		if can_actor_use_skill_at(ctx, actor, i, skill_id):
			return i
	return -1


static func can_actor_use_skill_at(
		ctx: FightSceneContext,
		actor: FightObj,
		index: int,
		skill_id: int
) -> bool:
	if skill_id <= 0:
		return true
	if actor.get_skill_slot_at(index).is_empty():
		return false
	if actor.get_skill_cd_at(index) > 0.0:
		return false
	var cfg := lookup_skill_cfg(ctx, skill_id)
	if cfg.is_empty():
		return false
	return actor.can_pay_costs(cfg)


static func can_use_player_item_at(ctx: FightSceneContext, index: int) -> bool:
	if ctx.domain == null or index < 0 or index >= ctx.item_slots.size():
		return false
	var slot := ctx.domain.player.get_item_slot_at(index)
	var item_id := int(slot.get("id", -1))
	if item_id < 0:
		return false
	if float(slot.get("cd", 0.0)) > 0.0:
		return false
	if int(slot.get("count", 0)) <= 0:
		return false
	var cfg := FightObj._lookup_cfg(ctx.item_cfg, item_id)
	if cfg.is_empty():
		return false
	return ctx.domain.player.can_pay_costs(cfg)


static func can_use_player_equip_at(ctx: FightSceneContext, index: int) -> bool:
	if ctx.domain == null or index < 0 or index >= ctx.equip_slots.size():
		return false
	var slot := ctx.domain.player.get_equip_slot_at(index)
	var equip_id := int(slot.get("id", -1))
	if equip_id < 0:
		return false
	if float(slot.get("cd", 0.0)) > 0.0:
		return false
	var cfg := FightObj._lookup_cfg(ctx.equip_cfg, equip_id)
	if cfg.is_empty():
		return false
	var cost_cfg := _slot_cost_cfg(slot, cfg)
	return ctx.domain.player.can_pay_costs(cost_cfg)


static func get_skill_block_reason(ctx: FightSceneContext, index: int) -> Dictionary:
	if ctx.domain == null or ctx.battle_player == null:
		return battle_busy_reason()
	if ctx.presentation_busy or not ctx.domain.can_player_act():
		return battle_busy_reason()
	if index < 0 or index >= ctx.battle_player.skills.size():
		return empty_slot_reason()
	var skill_id := skill_id_at(ctx.battle_player, index)
	if skill_id < 0:
		return empty_slot_reason()
	if skill_id <= 0:
		return ok_reason()
	var slot := ctx.battle_player.get_skill_slot_at(index)
	if slot.is_empty():
		return empty_slot_reason()
	var cd := ctx.battle_player.get_skill_cd_at(index)
	if cd > 0.0:
		return build_cooldown_reason(cd)
	var cfg := lookup_skill_cfg(ctx, skill_id)
	if cfg.is_empty():
		return empty_slot_reason()
	var need := FightObj.combat_resource_cost(cfg)
	var have := ctx.domain.player.mp
	if have < need:
		return build_insufficient_mp_reason(need, have)
	return ok_reason()


static func get_item_block_reason(ctx: FightSceneContext, index: int) -> Dictionary:
	if ctx.domain == null:
		return battle_busy_reason()
	if ctx.presentation_busy or not ctx.domain.can_player_act():
		return battle_busy_reason()
	if index < 0 or index >= ctx.item_slots.size():
		return empty_slot_reason()
	var slot := ctx.domain.player.get_item_slot_at(index)
	var item_id := int(slot.get("id", -1))
	if item_id < 0:
		return empty_slot_reason()
	var cd := float(slot.get("cd", 0.0))
	if cd > 0.0:
		return build_cooldown_reason(cd)
	var count := int(slot.get("count", 0))
	if count <= 0:
		return build_no_count_reason(count)
	var cfg := FightObj._lookup_cfg(ctx.item_cfg, item_id)
	var need := FightObj.combat_resource_cost(cfg)
	var have := ctx.domain.player.mp
	if have < need:
		return build_insufficient_mp_reason(need, have)
	return ok_reason()


static func get_equip_block_reason(ctx: FightSceneContext, index: int) -> Dictionary:
	if ctx.domain == null:
		return battle_busy_reason()
	if ctx.presentation_busy or not ctx.domain.can_player_act():
		return battle_busy_reason()
	if index < 0 or index >= ctx.equip_slots.size():
		return empty_slot_reason()
	var slot := ctx.domain.player.get_equip_slot_at(index)
	var equip_id := int(slot.get("id", -1))
	if equip_id < 0:
		return empty_slot_reason()
	var cd := float(slot.get("cd", 0.0))
	if cd > 0.0:
		return build_cooldown_reason(cd)
	var cfg := FightObj._lookup_cfg(ctx.equip_cfg, equip_id)
	var cost_cfg := _slot_cost_cfg(slot, cfg)
	var need := FightObj.combat_resource_cost(cost_cfg)
	var have := ctx.domain.player.mp
	if have < need:
		return build_insufficient_mp_reason(need, have)
	return ok_reason()


static func slot_view_for_type(ctx: FightSceneContext, slot_type: String, index: int) -> OneSkillView:
	match slot_type:
		"skill":
			return ctx.skill_slots[index] if index >= 0 and index < ctx.skill_slots.size() else null
		"item":
			return ctx.item_slots[index] if index >= 0 and index < ctx.item_slots.size() else null
		"equip":
			return ctx.equip_slots[index] if index >= 0 and index < ctx.equip_slots.size() else null
		_:
			return null


static func handle_blocked_slot_click(
		ctx: FightSceneContext,
		slot_type: String,
		index: int,
		reason: Dictionary
) -> void:
	var code := str(reason.get("code", BLOCK_EMPTY_SLOT))
	if code == BLOCK_OK:
		return
	var text := str(reason.get("text", "当前不可行动"))
	var slot := slot_view_for_type(ctx, slot_type, index)
	if slot != null:
		slot.play_blocked_feedback()
	emit_blocked_click_log(ctx, slot_type, index, reason)
	emit_block_reason_intent(ctx, slot_type, index, code, text)


static func resolve_player_slot(ctx: FightSceneContext, index: int, skill_id: int) -> Dictionary:
	var payload: Dictionary
	if skill_id <= 0:
		payload = ctx.domain.resolve_player_basic()
	else:
		payload = ctx.domain.resolve_player_skill(skill_id)
	if not bool(payload.get("ok", false)):
		BattleDebugLog.write("场景", "玩家出手失败", {
			"槽位": index,
			"技能ID": skill_id,
			"原因": BattleDebugLog.fail_reason_label(str(payload.get("reason", ""))),
		})
		return {}
	return payload


static func resolve_side_slot(
		ctx: FightSceneContext,
		side: String,
		index: int,
		skill_id: int
) -> Dictionary:
	if side == BattleDomainService.SIDE_PLAYER:
		return resolve_player_slot(ctx, index, skill_id)
	var payload: Dictionary
	if skill_id <= 0:
		payload = ctx.domain.resolve_enemy_basic()
	else:
		payload = ctx.domain.resolve_enemy_skill(skill_id)
	if not bool(payload.get("ok", false)):
		return {}
	return payload


static func resolve_enemy_action_with_ai(ctx: FightSceneContext) -> Dictionary:
	if ctx.domain == null or ctx.battle_player == null:
		return {}
	ctx.battle_enemy = ctx.domain.enemy
	if ctx.battle_enemy == null:
		return {}
	var prev_phase := ""
	var runtime := _enemy_ai_runtime_for_current(ctx)
	if runtime != null:
		prev_phase = runtime.last_phase_id
	var domain_ctx := {
		"battle_elapsed": ctx.domain.battle_elapsed_advancing,
	}
	var decision := EnemyAiServiceScript.decide_enemy_action(
		ctx.battle_enemy,
		ctx.battle_player,
		ctx.skill_cfg,
		_enemy_ai_cfg_for_current(ctx),
		_enemy_ai_runtime_for_current(ctx),
		domain_ctx,
		ctx.item_cfg,
		ctx.equip_cfg
	)
	if runtime != null:
		var new_phase := str(decision.get("phase_id", runtime.last_phase_id))
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
			payload = ctx.domain.resolve_enemy_basic()
			desc = {"action_kind": BattleRecordTypes.ACTION_BASIC, "action_id": 0}
		EnemyAiTypesScript.ACTION_SKILL:
			var sid := int(decision.get("skill_id", -1))
			payload = ctx.domain.resolve_enemy_skill(sid)
			desc = {"action_kind": BattleRecordTypes.ACTION_SKILL, "action_id": sid}
		EnemyAiTypesScript.ACTION_ITEM:
			payload = ctx.domain.resolve_enemy_item(int(decision.get("slot_index", -1)))
			desc = descriptor_for_item(payload)
		EnemyAiTypesScript.ACTION_EQUIP:
			payload = ctx.domain.resolve_enemy_equip(int(decision.get("slot_index", -1)))
			desc = descriptor_for_equip(payload)
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


static func resolve_player_action_with_ai(ctx: FightSceneContext) -> Dictionary:
	if ctx.domain == null or ctx.battle_player == null:
		return {}
	ctx.battle_enemy = ctx.domain.enemy
	if ctx.battle_enemy == null:
		return {}
	var decision := EnemyAiServiceScript.decide_enemy_action(
		ctx.battle_player,
		ctx.battle_enemy,
		ctx.skill_cfg,
		ctx.player_ai_cfg,
		ctx.player_ai_runtime,
		{"battle_elapsed": ctx.domain.battle_elapsed_advancing},
		ctx.item_cfg,
		ctx.equip_cfg
	)
	if not bool(decision.get("ok", false)):
		return {}
	var payload: Dictionary
	var desc: Dictionary
	match str(decision.get("action_type", "")):
		EnemyAiTypesScript.ACTION_BASIC:
			payload = ctx.domain.resolve_player_basic()
			desc = {"action_kind": BattleRecordTypes.ACTION_BASIC, "action_id": 0}
		EnemyAiTypesScript.ACTION_SKILL:
			var sid := int(decision.get("skill_id", -1))
			payload = ctx.domain.resolve_player_skill(sid)
			desc = {"action_kind": BattleRecordTypes.ACTION_SKILL, "action_id": sid}
		EnemyAiTypesScript.ACTION_ITEM:
			payload = ctx.domain.resolve_player_item(int(decision.get("slot_index", -1)))
			desc = descriptor_for_item(payload)
		EnemyAiTypesScript.ACTION_EQUIP:
			payload = ctx.domain.resolve_player_equip(int(decision.get("slot_index", -1)))
			desc = descriptor_for_equip(payload)
		_:
			return {}
	return {"payload": payload, "descriptor": desc} if bool(payload.get("ok", false)) else {}


static func _enemy_ai_cfg_for_current(ctx: FightSceneContext) -> Dictionary:
	if ctx.domain == null:
		return ctx.enemy_ai_cfg
	var idx := ctx.domain.active_enemy_index
	if idx >= 0 and idx < ctx.battle_enemy_rows.size():
		var row_v: Variant = ctx.battle_enemy_rows[idx]
		if row_v is Dictionary:
			var ai_v: Variant = (row_v as Dictionary).get("ai")
			if ai_v is Dictionary:
				return (ai_v as Dictionary).duplicate(true)
	return ctx.enemy_ai_cfg


static func _enemy_ai_runtime_for_current(ctx: FightSceneContext) -> EnemyAiRuntimeState:
	if ctx.domain == null:
		return ctx.enemy_ai_runtime
	var idx := ctx.domain.active_enemy_index
	if idx >= 0 and idx < ctx.enemy_ai_runtimes.size():
		var runtime_v: Variant = ctx.enemy_ai_runtimes[idx]
		return runtime_v as EnemyAiRuntimeState if runtime_v is EnemyAiRuntimeState else ctx.enemy_ai_runtime
	return ctx.enemy_ai_runtime


static func preview_enemy_action(ctx: FightSceneContext, enemy_index: int) -> Dictionary:
	if ctx.domain == null or ctx.battle_player == null:
		return {"action_type": EnemyAiTypesScript.ACTION_BASIC, "skill_id": 0, "slot_index": -1}
	var unit := ctx.domain._enemy_at(enemy_index)
	if unit == null:
		return {"action_type": EnemyAiTypesScript.ACTION_BASIC, "skill_id": 0, "slot_index": -1}
	var ai_cfg := ctx.enemy_ai_cfg
	if enemy_index >= 0 and enemy_index < ctx.battle_enemy_rows.size():
		var row_v: Variant = ctx.battle_enemy_rows[enemy_index]
		if row_v is Dictionary:
			var ai_v: Variant = (row_v as Dictionary).get("ai")
			if ai_v is Dictionary:
				ai_cfg = (ai_v as Dictionary).duplicate(true)
	var preview_unit := _enemy_unit_for_intent_preview(ctx, enemy_index, unit)
	var decision := EnemyAiServiceScript.decide_enemy_action(
		preview_unit,
		ctx.battle_player,
		ctx.skill_cfg,
		ai_cfg,
		null,
		{"battle_elapsed": ctx.domain.battle_elapsed_advancing},
		ctx.item_cfg,
		ctx.equip_cfg,
		false
	)
	if not bool(decision.get("ok", false)):
		return {"action_type": EnemyAiTypesScript.ACTION_BASIC, "skill_id": 0, "slot_index": -1}
	return decision


static func _enemy_unit_for_intent_preview(
		ctx: FightSceneContext,
		enemy_index: int,
		unit: FightObj
) -> FightObj:
	if ctx.domain == null or unit == null:
		return unit
	var advancing_seconds: float = ctx.domain.advancing_seconds_until_enemy_turn(enemy_index)
	return FightObj.duplicate_with_advancing_projection(unit, advancing_seconds)


static func descriptor_for_skill_or_basic(skill_id: int) -> Dictionary:
	if skill_id <= 0:
		return {"action_kind": BattleRecordTypes.ACTION_BASIC, "action_id": 0}
	return {"action_kind": BattleRecordTypes.ACTION_SKILL, "action_id": int(skill_id)}


static func descriptor_for_item(payload: Dictionary) -> Dictionary:
	var report_v: Variant = payload.get("report", {})
	if report_v is Dictionary:
		return {
			"action_kind": BattleRecordTypes.ACTION_ITEM,
			"action_id": int((report_v as Dictionary).get("item_id", -1)),
		}
	return {"action_kind": BattleRecordTypes.ACTION_ITEM, "action_id": -1}


static func descriptor_for_equip(payload: Dictionary) -> Dictionary:
	var report_v: Variant = payload.get("report", {})
	if report_v is Dictionary:
		return {
			"action_kind": BattleRecordTypes.ACTION_EQUIP,
			"action_id": int((report_v as Dictionary).get("equip_id", -1)),
		}
	return {"action_kind": BattleRecordTypes.ACTION_EQUIP, "action_id": -1}


static func lookup_skill_cfg(ctx: FightSceneContext, skill_id: int) -> Dictionary:
	if ctx.skill_cfg.has(skill_id):
		var v: Variant = ctx.skill_cfg[skill_id]
		return v as Dictionary if v is Dictionary else {}
	var ks := str(skill_id)
	if ctx.skill_cfg.has(ks):
		var v2: Variant = ctx.skill_cfg[ks]
		return v2 as Dictionary if v2 is Dictionary else {}
	return {}


static func _slot_cost_cfg(slot: Dictionary, base_cfg: Dictionary) -> Dictionary:
	var cost_cfg := base_cfg.duplicate(true)
	if slot.has("costs"):
		cost_cfg["costs"] = slot.get("costs", [])
	elif slot.has("mp_cost"):
		cost_cfg["mp_cost"] = slot.get("mp_cost", 0.0)
	return cost_cfg


static func ok_reason() -> Dictionary:
	return {"code": BLOCK_OK, "text": ""}


static func battle_busy_reason() -> Dictionary:
	return {"code": BLOCK_BATTLE_BUSY, "text": "当前不可行动"}


static func empty_slot_reason() -> Dictionary:
	return {"code": BLOCK_EMPTY_SLOT, "text": "该槽位未配置"}


static func build_cooldown_reason(remaining: float) -> Dictionary:
	return {
		"code": BLOCK_COOLDOWN,
		"text": "冷却中 %.1fs" % maxf(remaining, 0.0),
		"remain": maxf(remaining, 0.0),
	}


static func build_insufficient_mp_reason(need: float, have: float) -> Dictionary:
	return {
		"code": BLOCK_INSUFFICIENT_MP,
		"text": "灵力不足（需要%d）" % int(ceil(need)),
		"need": maxf(need, 0.0),
		"have": maxf(have, 0.0),
	}


static func build_no_count_reason(count: int) -> Dictionary:
	return {"code": BLOCK_NO_COUNT, "text": "次数不足", "count": count}


static func emit_blocked_click_log(
		ctx: FightSceneContext,
		slot_type: String,
		index: int,
		reason: Dictionary
) -> void:
	var elapsed := 0.0
	if ctx.domain != null:
		elapsed = maxf(0.0, ctx.domain.battle_elapsed_advancing)
	BattleDebugLog.write("slot_click_blocked", "玩家点击不可用槽位", {
		"slot_type": slot_type,
		"index": index,
		"reason_code": str(reason.get("code", "")),
		"text": str(reason.get("text", "")),
		"battle_time": elapsed,
	})


static func emit_block_reason_intent(
		ctx: FightSceneContext,
		slot_type: String,
		index: int,
		reason_code: String,
		text: String
) -> void:
	if text == "" or ctx.scene == null:
		return
	var de: Node = ctx.scene.get_node_or_null("/root/DataEvents")
	if de == null or not de.has_method("emit_tip_intent"):
		return
	var tone := "loss" if reason_code in [BLOCK_INSUFFICIENT_MP, BLOCK_NO_COUNT] else "neutral"
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
