class_name FightScenePresentation
extends RefCounted

## 战斗表现：VFX 队列、飘字与域层 PRESENTATION 状态衔接。

const CombatEventScript = preload("res://scripts/fight/combat_event.gd")
const CombatReportScript = preload("res://scripts/fight/combat_report.gd")


func consume_runtime_events(ctx: FightSceneContext, hud: FightSceneHud) -> void:
	if ctx.domain == null:
		return
	for ev_v in ctx.domain.consume_runtime_events():
		if not ev_v is Dictionary:
			continue
		var ev := ev_v as Dictionary
		var unit_id := str(ev.get(CombatEventScript.KEY_UNIT_ID, ""))
		match str(ev.get(CombatEventScript.KEY_TYPE, "")):
			EnumCombatEventType.LABEL_BUFF_TICK_DAMAGE:
				var report_v: Variant = ev.get(CombatEventScript.KEY_REPORT, {})
				if report_v is Dictionary:
					_on_buff_tick_damage(
						ctx,
						hud,
						CombatReportScript.normalize_report(report_v as Dictionary),
						unit_id
					)
			EnumCombatEventType.LABEL_BUFF_EXPIRED:
				_on_buff_expired(str(ev.get(CombatEventScript.KEY_BUFF_ID, "")), unit_id)


func run_presentation(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		payload: Dictionary,
		on_record: Callable
) -> void:
	if ctx.domain == null:
		return
	if not bool(payload.get("ok", false)):
		return
	var source_id := str(payload.get("source_id", ""))
	var target_id := str(payload.get("target_id", ""))
	var source_actor_id := str(payload.get("source_actor_id", source_id))
	var target_actor_id := str(payload.get("target_actor_id", target_id))
	var report: Dictionary = payload.get("report", {}) as Dictionary
	var cfg: Dictionary = payload.get("cfg", {}) as Dictionary
	ctx.presentation_busy = true
	hud.sync_from_domain(ctx)
	hud.sync_runtime_slot_interactive(ctx)
	hud.update_skill_input_enabled(ctx)
	BattleDebugLog.write("场景", "开始表现流程", {
		"来源": BattleDebugLog.side_label(source_id),
		"目标": BattleDebugLog.side_label(target_id),
		"伤害": report.get("damage", 0.0),
		"特效类型": vfx_type_from_cfg(cfg),
	})
	BattleDebugLog.log_domain(ctx.domain, "表现前")
	ctx.domain.begin_presentation(source_id)
	if ctx.domain.state != EnumBattleState.State.PRESENTATION:
		BattleDebugLog.write("场景", "开始表现失败，跳过此次表现", {
			"来源": BattleDebugLog.side_label(source_id),
			"域状态": BattleDebugLog.state_label(ctx.domain.state),
		})
		ctx.presentation_busy = false
		hud.update_skill_input_enabled(ctx)
		return
	hud.update_skill_input_enabled(ctx)
	await play_combat_vfx(ctx, hud, source_actor_id, target_actor_id, report, cfg)
	BattleDebugLog.write("场景", "VFX 播放 await 返回")
	ctx.domain.finish_presentation()
	var end_reason := ctx.domain.check_end_after_resolve()
	ctx.presentation_busy = false
	hud.sync_from_domain(ctx)
	hud.sync_runtime_slot_interactive(ctx)
	hud.update_skill_input_enabled(ctx)
	BattleDebugLog.write("场景", "表现流程结束", {
		"结束原因": BattleDebugLog.end_reason_label(end_reason),
		"域状态": BattleDebugLog.state_label(ctx.domain.state),
	})
	BattleDebugLog.log_domain(ctx.domain, "表现后")
	if end_reason != "":
		if on_record.is_valid():
			on_record.call(end_reason)
	elif ctx.domain.state == EnumBattleState.State.END:
		if on_record.is_valid():
			on_record.call(ctx.domain.end_reason)


func play_combat_vfx(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		source_id: String,
		target_id: String,
		result: Dictionary,
		cfg: Dictionary
) -> void:
	hud.ensure_vfx_actors_for_combat()
	spawn_combat_floats(ctx, hud, source_id, target_id, result, cfg)
	var vfx := hud.get_vfx()
	if vfx == null:
		hud.sync_from_domain(ctx)
		return
	vfx.clear_queue()
	var vfx_binding := CombatVfxSequenceResolver.vfx_binding_from_skill_cfg(cfg)
	if vfx_binding.is_empty():
		vfx_binding = {"preset": preset_for_vfx_type(vfx_type_from_cfg(cfg))}
	var extra := {"vfx": vfx_binding}
	BattleDebugLog.write("场景", "入队战斗 VFX", {
		"来源": BattleDebugLog.side_label(source_id),
		"目标": BattleDebugLog.side_label(target_id),
		"preset": str(vfx_binding.get("preset", "")),
		"特效类型": vfx_type_from_cfg(cfg),
		"施法者快照": hud.sprite_vfx_snapshot(source_id),
	})
	enqueue_battle_vfx(ctx, hud, {
		"source_id": source_id,
		"target_id": target_id,
		"damage_value": float(result.get("damage", 0.0)),
		"skill_type": vfx_type_from_cfg(cfg),
		"extra": extra,
	})
	await play_battle_vfx_queue(hud)
	hud.sync_from_domain(ctx)


func enqueue_battle_vfx(ctx: FightSceneContext, hud: FightSceneHud, data: Dictionary) -> void:
	var vfx := hud.get_vfx()
	if vfx != null:
		vfx.enqueue_dict(data)


func play_battle_vfx_queue(hud: FightSceneHud) -> void:
	var vfx := hud.get_vfx()
	if vfx != null:
		await vfx.play_queue()


func on_vfx_event_finished(ctx: FightSceneContext, hud: FightSceneHud) -> void:
	hud.sync_from_domain(ctx)
	hud.sync_runtime_slot_interactive(ctx)
	hud.update_skill_input_enabled(ctx)


func on_vfx_queue_finished(ctx: FightSceneContext) -> void:
	if ctx.domain == null or not ctx.presentation_busy:
		return
	if ctx.domain.state == EnumBattleState.State.PRESENTATION:
		BattleDebugLog.write("场景", "VFX 队列结束事件", {
			"状态": BattleDebugLog.state_label(ctx.domain.state),
			"表现中": ctx.presentation_busy,
		})


func spawn_combat_floats(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		source_id: String,
		target_id: String,
		report: Dictionary,
		cfg: Dictionary
) -> void:
	if hud.get_float_layer() == null:
		return
	BattleDebugLog.write("飘字", "FightScenePresentation.spawn_combat_floats 调用", {
		"来源": BattleDebugLog.side_label(source_id),
		"目标": BattleDebugLog.side_label(target_id),
		"damage": report.get("damage", 0.0),
		"heal": report.get("heal", 0.0),
		"mp_gain": report.get("mp_gain", 0.0),
		"shield_absorbed": report.get("shield_absorbed", 0.0),
		"buff_names": report.get("buff_names", []),
	})
	spawn_float_items(ctx, hud, CombatFloatPresenter.build_spawns(source_id, target_id, report, cfg))


func spawn_float_items(ctx: FightSceneContext, hud: FightSceneHud, items: Array) -> void:
	var float_layer := hud.get_float_layer()
	if float_layer == null:
		return
	for item in items:
		if not item is Dictionary:
			continue
		var row := item as Dictionary
		var unit_id := str(row.get("unit_id", ""))
		float_layer.spawn(
			str(row.get("text", "")),
			hud.unit_screen_pos(ctx, unit_id),
			str(row.get("tone", "damage")),
			unit_id
		)


func _on_buff_expired(buff_id: String, unit_id: String) -> void:
	BattleDebugLog.write("飘字", "Buff 到期（不展示飘字）", {
		"单位": BattleDebugLog.side_label(unit_id),
		"buff_id": buff_id,
	})


func _on_buff_tick_damage(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		report: Dictionary,
		unit_id: String
) -> void:
	if hud.get_float_layer() == null:
		return
	var damage := float(report.get("damage", 0.0))
	var shield_absorbed := float(report.get("shield_absorbed", 0.0))
	if damage <= 0.0 and shield_absorbed <= 0.0:
		return
	var buff_name := str(report.get(CombatReportScript.KEY_BUFF_NAME, "")).strip_edges()
	if ctx.domain != null and ctx.recorder != null:
		var entry: Dictionary = ctx.recorder.record_buff_tick(
			unit_id,
			report,
			buff_name,
			ctx.domain.battle_elapsed_advancing
		)
		hud.render_battle_log_tail(ctx, entry)
	spawn_float_items(
		ctx,
		hud,
		CombatFloatPresenter.build_buff_tick_spawns(unit_id, report, buff_name, ctx.record_names)
	)


static func vfx_type_from_cfg(cfg: Dictionary) -> String:
	var explicit := str(cfg.get("vfx_type", "")).strip_edges().to_lower()
	if explicit != "":
		return explicit
	var tags_v: Variant = cfg.get("tags", [])
	if tags_v is Array:
		for tag_v in tags_v as Array:
			var tag := str(tag_v).strip_edges().to_lower()
			if tag in ["magic", "spell", "ranged", "remote", "远程", "法术"]:
				return "ranged"
	return "melee"


static func preset_for_vfx_type(vfx_type: String) -> String:
	return CombatVfxPresetLibrary.legacy_preset_for_vfx_type(vfx_type)
