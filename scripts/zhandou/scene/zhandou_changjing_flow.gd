class_name ZhandouChangjingFlow
extends RefCounted

## 战斗主循环：域层推进、出手调度、结算与结束。


func process_frame(ctx: ZhandouChangjingContext, hud: ZhandouChangjingHud, presentation: ZhandouChangjingPresentation, delta: float) -> void:
	if ctx.domain == null:
		return
	match ctx.domain.state:
		EnumBattleState.State.ADVANCING:
			var ready_signal := ctx.domain.tick_advancing(delta)
			presentation.consume_runtime_events(ctx, hud)
			hud.sync_from_domain(ctx)
			hud.sync_runtime_slot_interactive(ctx)
			hud.update_skill_input_enabled(ctx)
			match ready_signal:
				ZhandouDomainService.SIGNAL_PLAYER_READY:
					ZhandouDebugLog.write("场景", "玩家走条满，进入暂停")
					ctx.domain.enter_paused(EnumBattleSide.PLAYER)
					hud.update_skill_input_enabled(ctx)
					schedule_side_act(ctx, EnumBattleSide.PLAYER)
				ZhandouDomainService.SIGNAL_ENEMY_READY:
					ZhandouDebugLog.write("场景", "敌方走条满，进入暂停")
					ctx.battle_enemy = ctx.domain.enemy
					ctx.domain.enter_paused(EnumBattleSide.ENEMY)
					hud.update_skill_input_enabled(ctx)
					schedule_side_act(ctx, EnumBattleSide.ENEMY)
				ZhandouDomainService.SIGNAL_TIME_LIMIT:
					ZhandouDebugLog.write("场景", "战斗超时，结束")
					return_battle_end(ctx, hud, ctx.domain.end_reason)
				ZhandouDomainService.SIGNAL_PLAYER_DEAD, ZhandouDomainService.SIGNAL_ENEMY_DEAD:
					ZhandouDebugLog.write("场景", "走条阶段判定战斗结束", {
						"原因": ZhandouDebugLog.end_reason_label(ready_signal),
					})
					return_battle_end(ctx, hud, ready_signal)
		EnumBattleState.State.PAUSED, EnumBattleState.State.PRESENTATION:
			hud.sync_from_domain(ctx)
			hud.sync_runtime_slot_interactive(ctx)
			hud.update_skill_input_enabled(ctx)
		_:
			pass


func schedule_side_act(ctx: ZhandouChangjingContext, side: String) -> void:
	if side == EnumBattleSide.PLAYER:
		if not ctx.auto_battle_player:
			return
		if ctx.player_act_scheduled:
			return
		ctx.player_act_scheduled = true
		if ctx.scene != null:
			ctx.scene.call_deferred("_deferred_side_act", side)
	elif side == EnumBattleSide.ENEMY:
		if ctx.enemy_act_scheduled:
			return
		ctx.enemy_act_scheduled = true
		if ctx.scene != null:
			ctx.scene.call_deferred("_deferred_side_act", side)


func side_act_and_present(
		ctx: ZhandouChangjingContext,
		hud: ZhandouChangjingHud,
		presentation: ZhandouChangjingPresentation,
		side: String,
		on_battle_ended: Callable
) -> void:
	if side == EnumBattleSide.PLAYER:
		ctx.player_act_scheduled = false
	else:
		ctx.enemy_act_scheduled = false
	if ctx.domain == null or ctx.presentation_busy:
		return
	if ctx.domain.state != EnumBattleState.State.PAUSED:
		return
	if ctx.domain.paused_side != side:
		return
	if side == EnumBattleSide.ENEMY:
		ctx.battle_enemy = ctx.domain.enemy
		var enemy_resolved := ZhandouChangjingActions.resolve_enemy_action_with_ai(ctx)
		var enemy_payload: Dictionary = enemy_resolved.get("payload", {}) as Dictionary
		var enemy_desc: Dictionary = enemy_resolved.get("descriptor", {}) as Dictionary
		if enemy_payload.is_empty():
			ZhandouDebugLog.write("场景", "敌方 AI 行为不可用，降级普攻")
			enemy_payload = ctx.domain.resolve_enemy_basic()
			enemy_desc = {"action_kind": ZhandouRecordTypes.ACTION_BASIC, "action_id": 0}
			if not bool(enemy_payload.get("ok", false)):
				ZhandouDebugLog.write("场景", "敌方降级普攻失败，安全推进状态机避免卡死", {
					"原因": ZhandouDebugLog.fail_reason_label(str(enemy_payload.get("reason", ""))),
				})
				ctx.domain.begin_presentation(EnumBattleSide.ENEMY)
				ctx.domain.finish_presentation()
				return
		ZhandouDebugLog.write("场景", "敌方 AI 出手，进入表现")
		commit_combat_resolution(ctx, hud, enemy_payload, enemy_desc)
		hud.sync_from_domain(ctx)
		await presentation.run_presentation(ctx, hud, enemy_payload, on_battle_ended)
		return
	if side == EnumBattleSide.PLAYER and not ctx.player_ai_cfg.is_empty():
		var player_resolved := ZhandouChangjingActions.resolve_player_action_with_ai(ctx)
		var player_payload: Dictionary = player_resolved.get("payload", {}) as Dictionary
		var player_desc: Dictionary = player_resolved.get("descriptor", {}) as Dictionary
		if not player_payload.is_empty():
			commit_combat_resolution(ctx, hud, player_payload, player_desc)
			hud.sync_from_domain(ctx)
			await presentation.run_presentation(ctx, hud, player_payload, on_battle_ended)
			return
	if side == EnumBattleSide.ENEMY:
		ctx.battle_enemy = ctx.domain.enemy
	var actor := ctx.battle_player if side == EnumBattleSide.PLAYER else ctx.battle_enemy
	var check_interactive := side == EnumBattleSide.PLAYER
	var slot_index := ZhandouChangjingActions.find_auto_skill_slot(ctx, actor, check_interactive)
	var skill_id := ZhandouChangjingActions.skill_id_at(actor, slot_index)
	if slot_index < 0:
		ZhandouDebugLog.write("场景", "自动战斗无可用技能，尝试普攻", {
			"出手方": ZhandouDebugLog.side_label(side),
		})
		skill_id = 0
		slot_index = ZhandouChangjingActions.find_basic_attack_slot(actor)
		if slot_index < 0:
			ZhandouDebugLog.write("场景", "自动战斗无法出手", {"出手方": ZhandouDebugLog.side_label(side)})
			return
	var payload := ZhandouChangjingActions.resolve_side_slot(ctx, side, slot_index, skill_id)
	if payload.is_empty():
		ZhandouDebugLog.write("场景", "自动战斗出手失败", {
			"出手方": ZhandouDebugLog.side_label(side),
			"槽位": slot_index,
			"技能ID": skill_id,
		})
		return
	ZhandouDebugLog.write("场景", "自动战斗出手，进入表现", {
		"出手方": ZhandouDebugLog.side_label(side),
		"槽位": slot_index,
		"技能ID": skill_id,
	})
	commit_combat_resolution(
		ctx,
		hud,
		payload,
		ZhandouChangjingActions.descriptor_for_skill_or_basic(skill_id)
	)
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func on_skill_pressed(
		ctx: ZhandouChangjingContext,
		hud: ZhandouChangjingHud,
		presentation: ZhandouChangjingPresentation,
		index: int,
		on_battle_ended: Callable
) -> void:
	ctx.player_act_scheduled = false
	var reason := ZhandouChangjingActions.get_skill_block_reason(ctx, index)
	if str(reason.get("code", "")) != ZhandouChangjingActions.BLOCK_OK:
		ZhandouChangjingActions.handle_blocked_slot_click(ctx, "skill", index, reason)
		return
	var skill_id := ZhandouChangjingActions.skill_id_at(ctx.battle_player, index)
	if skill_id < 0:
		return
	var payload := ZhandouChangjingActions.resolve_player_slot(ctx, index, skill_id)
	if payload.is_empty():
		return
	ZhandouDebugLog.write("场景", "玩家出手成功，进入表现", {
		"槽位": index,
		"技能ID": skill_id,
	})
	commit_combat_resolution(
		ctx,
		hud,
		payload,
		ZhandouChangjingActions.descriptor_for_skill_or_basic(skill_id)
	)
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func on_escape_pressed(ctx: ZhandouChangjingContext, hud: ZhandouChangjingHud) -> void:
	ctx.player_act_scheduled = false
	if not hud.can_attempt_escape(ctx):
		return
	var result := ctx.domain.try_escape(ctx.escape_bonus, ctx.escape_fail_count)
	if not bool(result.get("ok", false)):
		return
	if bool(result.get("success", false)):
		ZhandouDebugLog.write("场景", "玩家逃跑成功，结束战斗")
		return_battle_end(ctx, hud, ZhandouDomainService.SIGNAL_PLAYER_ESCAPED)
		return
	ctx.escape_fail_count += 1
	var chase := float(result.get("chase_damage", 0.0))
	if chase > 0.0:
		hud.spawn_unit_float(ctx, ZhandouChangjingContext.UNIT_PLAYER, "-%d" % int(chase), "damage")
	hud.spawn_unit_float(ctx, ZhandouChangjingContext.UNIT_PLAYER, "逃跑失败!", "skill")
	hud.sync_from_domain(ctx)
	hud.sync_runtime_slot_interactive(ctx)
	hud.update_skill_input_enabled(ctx)
	var end_after := str(result.get("end_reason", "")).strip_edges()
	if end_after != "":
		return_battle_end(ctx, hud, end_after)


func on_item_pressed(
		ctx: ZhandouChangjingContext,
		hud: ZhandouChangjingHud,
		presentation: ZhandouChangjingPresentation,
		index: int,
		on_battle_ended: Callable
) -> void:
	ctx.player_act_scheduled = false
	var reason := ZhandouChangjingActions.get_item_block_reason(ctx, index)
	if str(reason.get("code", "")) != ZhandouChangjingActions.BLOCK_OK:
		ZhandouChangjingActions.handle_blocked_slot_click(ctx, "item", index, reason)
		return
	var payload := ctx.domain.resolve_player_item(index)
	if not bool(payload.get("ok", false)):
		return
	commit_combat_resolution(ctx, hud, payload, ZhandouChangjingActions.descriptor_for_item(payload))
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func on_equip_pressed(
		ctx: ZhandouChangjingContext,
		hud: ZhandouChangjingHud,
		presentation: ZhandouChangjingPresentation,
		index: int,
		on_battle_ended: Callable
) -> void:
	ctx.player_act_scheduled = false
	var reason := ZhandouChangjingActions.get_equip_block_reason(ctx, index)
	if str(reason.get("code", "")) != ZhandouChangjingActions.BLOCK_OK:
		ZhandouChangjingActions.handle_blocked_slot_click(ctx, "equip", index, reason)
		return
	var payload := ctx.domain.resolve_player_equip(index)
	if not bool(payload.get("ok", false)):
		return
	commit_combat_resolution(ctx, hud, payload, ZhandouChangjingActions.descriptor_for_equip(payload))
	hud.sync_from_domain(ctx)
	await presentation.run_presentation(ctx, hud, payload, on_battle_ended)


func commit_combat_resolution(
		ctx: ZhandouChangjingContext,
		hud: ZhandouChangjingHud,
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


func return_battle_end(ctx: ZhandouChangjingContext, hud: ZhandouChangjingHud, reason: String) -> void:
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
			"items": ZhandouObj._duplicate_slot_array(ctx.domain.player.items),
		}
		if ctx.scene.has_signal("battle_finished"):
			ctx.scene.emit_signal("battle_finished", summary)
		var display_summary := summary.duplicate(true)
		if LilianState != null and LilianState.active and LilianState.phase == "battle":
			display_summary["rewards"] = LilianState.pending_battle_rewards.duplicate(true)
		hud.show_battle_result(ctx, display_summary)
	var player_hp := ctx.domain.player.hp if ctx.domain.player != null else -1.0
	var enemy_hp := ctx.domain.enemy.hp if ctx.domain.enemy != null else 0.0
	ZhandouDebugLog.write("结束", "战斗结束", {
		"原因": ZhandouDebugLog.end_reason_label(reason),
		"玩家生命": player_hp,
		"敌方生命": enemy_hp,
		"敌方数量": ctx.domain.enemies.size(),
		"快照": ctx.domain.get_debug_snapshot(),
	})
	ZhandouDebugLog.clear_domain()
	ctx.scene.set_process(false)
	hud.update_skill_input_enabled(ctx)
