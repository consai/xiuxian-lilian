class_name FightSceneCombatFlow
extends RefCounted

## 战斗主循环：域层推进、出手调度、结算与结束。


func process_frame(ctx: FightSceneContext, hud: FightSceneHud, presentation: FightScenePresentation, delta: float) -> void:
	if ctx.domain == null:
		return
	match ctx.domain.state:
		BattleDomainService.BattleState.ADVANCING:
			var ready_signal := ctx.domain.tick_advancing(delta)
			presentation.consume_runtime_events(ctx, hud)
			hud.sync_from_domain(ctx)
			hud.sync_runtime_slot_interactive(ctx)
			hud.update_skill_input_enabled(ctx)
			match ready_signal:
				BattleDomainService.SIGNAL_PLAYER_READY:
					BattleDebugLog.write("场景", "玩家走条满，进入暂停")
					ctx.domain.enter_paused(BattleDomainService.SIDE_PLAYER)
					hud.update_skill_input_enabled(ctx)
					schedule_side_act(ctx, BattleDomainService.SIDE_PLAYER)
				BattleDomainService.SIGNAL_ENEMY_READY:
					BattleDebugLog.write("场景", "敌方走条满，进入暂停")
					ctx.battle_enemy = ctx.domain.enemy
					ctx.domain.enter_paused(BattleDomainService.SIDE_ENEMY)
					hud.update_skill_input_enabled(ctx)
					schedule_side_act(ctx, BattleDomainService.SIDE_ENEMY)
				BattleDomainService.SIGNAL_TIME_LIMIT:
					BattleDebugLog.write("场景", "战斗超时，结束")
					return_battle_end(ctx, hud, ctx.domain.end_reason)
				BattleDomainService.SIGNAL_PLAYER_DEAD, BattleDomainService.SIGNAL_ENEMY_DEAD:
					BattleDebugLog.write("场景", "走条阶段判定战斗结束", {
						"原因": BattleDebugLog.end_reason_label(ready_signal),
					})
					return_battle_end(ctx, hud, ready_signal)
		BattleDomainService.BattleState.PAUSED, BattleDomainService.BattleState.PRESENTATION:
			hud.sync_from_domain(ctx)
			hud.sync_runtime_slot_interactive(ctx)
			hud.update_skill_input_enabled(ctx)
		_:
			pass


func schedule_side_act(ctx: FightSceneContext, side: String) -> void:
	if side == BattleDomainService.SIDE_PLAYER:
		if not ctx.auto_battle_player:
			return
		if ctx.player_act_scheduled:
			return
		ctx.player_act_scheduled = true
		if ctx.scene != null:
			ctx.scene.call_deferred("_deferred_side_act", side)
	elif side == BattleDomainService.SIDE_ENEMY:
		if ctx.enemy_act_scheduled:
			return
		ctx.enemy_act_scheduled = true
		if ctx.scene != null:
			ctx.scene.call_deferred("_deferred_side_act", side)


func side_act_and_present(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		presentation: FightScenePresentation,
		side: String,
		on_battle_ended: Callable
) -> void:
	if side == BattleDomainService.SIDE_PLAYER:
		ctx.player_act_scheduled = false
	else:
		ctx.enemy_act_scheduled = false
	if ctx.domain == null or ctx.presentation_busy:
		return
	if ctx.domain.state != BattleDomainService.BattleState.PAUSED:
		return
	if ctx.domain.paused_side != side:
		return
	if side == BattleDomainService.SIDE_ENEMY:
		ctx.battle_enemy = ctx.domain.enemy
		var enemy_resolved := FightSceneActions.resolve_enemy_action_with_ai(ctx)
		var enemy_payload: Dictionary = enemy_resolved.get("payload", {}) as Dictionary
		var enemy_desc: Dictionary = enemy_resolved.get("descriptor", {}) as Dictionary
		if enemy_payload.is_empty():
			BattleDebugLog.write("场景", "敌方 AI 行为不可用，降级普攻")
			enemy_payload = ctx.domain.resolve_enemy_basic()
			enemy_desc = {"action_kind": BattleRecordTypes.ACTION_BASIC, "action_id": 0}
			if not bool(enemy_payload.get("ok", false)):
				BattleDebugLog.write("场景", "敌方降级普攻失败，安全推进状态机避免卡死", {
					"原因": BattleDebugLog.fail_reason_label(str(enemy_payload.get("reason", ""))),
				})
				ctx.domain.begin_presentation(BattleDomainService.SIDE_ENEMY)
				ctx.domain.finish_presentation()
				return
		BattleDebugLog.write("场景", "敌方 AI 出手，进入表现")
		commit_combat_resolution(ctx, hud, enemy_payload, enemy_desc)
		hud.sync_from_domain(ctx)
		await presentation.run_presentation(ctx, hud, enemy_payload, on_battle_ended)
		return
	if side == BattleDomainService.SIDE_PLAYER and not ctx.player_ai_cfg.is_empty():
		var player_resolved := FightSceneActions.resolve_player_action_with_ai(ctx)
		var player_payload: Dictionary = player_resolved.get("payload", {}) as Dictionary
		var player_desc: Dictionary = player_resolved.get("descriptor", {}) as Dictionary
		if not player_payload.is_empty():
			commit_combat_resolution(ctx, hud, player_payload, player_desc)
			hud.sync_from_domain(ctx)
			await presentation.run_presentation(ctx, hud, player_payload, on_battle_ended)
			return
	if side == BattleDomainService.SIDE_ENEMY:
		ctx.battle_enemy = ctx.domain.enemy
	var actor := ctx.battle_player if side == BattleDomainService.SIDE_PLAYER else ctx.battle_enemy
	var check_interactive := side == BattleDomainService.SIDE_PLAYER
	var slot_index := FightSceneActions.find_auto_skill_slot(ctx, actor, check_interactive)
	var skill_id := FightSceneActions.skill_id_at(actor, slot_index)
	if slot_index < 0:
		BattleDebugLog.write("场景", "自动战斗无可用技能，尝试普攻", {
			"出手方": BattleDebugLog.side_label(side),
		})
		skill_id = 0
		slot_index = FightSceneActions.find_basic_attack_slot(actor)
		if slot_index < 0:
			BattleDebugLog.write("场景", "自动战斗无法出手", {"出手方": BattleDebugLog.side_label(side)})
			return
	var payload := FightSceneActions.resolve_side_slot(ctx, side, slot_index, skill_id)
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
	commit_combat_resolution(
		ctx,
		hud,
		payload,
		FightSceneActions.descriptor_for_skill_or_basic(skill_id)
	)
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func on_skill_pressed(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		presentation: FightScenePresentation,
		index: int,
		on_battle_ended: Callable
) -> void:
	ctx.player_act_scheduled = false
	var reason := FightSceneActions.get_skill_block_reason(ctx, index)
	if str(reason.get("code", "")) != FightSceneActions.BLOCK_OK:
		FightSceneActions.handle_blocked_slot_click(ctx, "skill", index, reason)
		return
	var skill_id := FightSceneActions.skill_id_at(ctx.battle_player, index)
	if skill_id < 0:
		return
	var payload := FightSceneActions.resolve_player_slot(ctx, index, skill_id)
	if payload.is_empty():
		return
	BattleDebugLog.write("场景", "玩家出手成功，进入表现", {
		"槽位": index,
		"技能ID": skill_id,
	})
	commit_combat_resolution(
		ctx,
		hud,
		payload,
		FightSceneActions.descriptor_for_skill_or_basic(skill_id)
	)
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func on_item_pressed(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		presentation: FightScenePresentation,
		index: int,
		on_battle_ended: Callable
) -> void:
	ctx.player_act_scheduled = false
	var reason := FightSceneActions.get_item_block_reason(ctx, index)
	if str(reason.get("code", "")) != FightSceneActions.BLOCK_OK:
		FightSceneActions.handle_blocked_slot_click(ctx, "item", index, reason)
		return
	var payload := ctx.domain.resolve_player_item(index)
	if not bool(payload.get("ok", false)):
		return
	commit_combat_resolution(ctx, hud, payload, FightSceneActions.descriptor_for_item(payload))
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func on_equip_pressed(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		presentation: FightScenePresentation,
		index: int,
		on_battle_ended: Callable
) -> void:
	ctx.player_act_scheduled = false
	var reason := FightSceneActions.get_equip_block_reason(ctx, index)
	if str(reason.get("code", "")) != FightSceneActions.BLOCK_OK:
		FightSceneActions.handle_blocked_slot_click(ctx, "equip", index, reason)
		return
	var payload := ctx.domain.resolve_player_equip(index)
	if not bool(payload.get("ok", false)):
		return
	commit_combat_resolution(ctx, hud, payload, FightSceneActions.descriptor_for_equip(payload))
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func commit_combat_resolution(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		payload: Dictionary,
		descriptor: Dictionary
) -> void:
	if ctx.domain == null or ctx.recorder == null:
		return
	if payload == null or not bool(payload.get("ok", false)):
		return
	var entry: Dictionary = ctx.recorder.record_resolution(
		payload,
		descriptor,
		ctx.domain.battle_elapsed_advancing
	)
	hud.render_battle_log_tail(ctx, entry)


func return_battle_end(ctx: FightSceneContext, hud: FightSceneHud, reason: String) -> void:
	if ctx.domain == null or ctx.scene == null:
		return
	var float_layer := hud.get_float_layer()
	if float_layer != null:
		float_layer.clear_all()
	if ctx.recorder != null:
		var summary: Dictionary = ctx.recorder.finalize(
			reason,
			ctx.domain.battle_elapsed_advancing,
			ctx.record_names
		)
		summary["player_runtime"] = {
			"hp": ctx.domain.player.hp,
			"mp": ctx.domain.player.mp,
			"items": FightObj._duplicate_slot_array(ctx.domain.player.items),
		}
		if ctx.scene.has_signal("battle_finished"):
			ctx.scene.emit_signal("battle_finished", summary)
		var display_summary := summary.duplicate(true)
		if ExpeditionState != null and ExpeditionState.active and ExpeditionState.phase == "battle":
			display_summary["rewards"] = ExpeditionState.pending_battle_rewards.duplicate(true)
		hud.show_battle_result(ctx, display_summary)
	var player_hp := ctx.domain.player.hp if ctx.domain.player != null else -1.0
	var enemy_hp := ctx.domain.enemy.hp if ctx.domain.enemy != null else 0.0
	BattleDebugLog.write("结束", "战斗结束", {
		"原因": BattleDebugLog.end_reason_label(reason),
		"玩家生命": player_hp,
		"敌方生命": enemy_hp,
		"敌方数量": ctx.domain.enemies.size(),
		"快照": ctx.domain.get_debug_snapshot(),
	})
	BattleDebugLog.clear_domain()
	ctx.scene.set_process(false)
	hud.update_skill_input_enabled(ctx)
