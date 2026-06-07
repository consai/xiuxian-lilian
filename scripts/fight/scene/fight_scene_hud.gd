class_name FightSceneHud
extends RefCounted

## 战斗 HUD：头像/血法/护盾/走条/Buff 栏与槽位外观绑定。

const SKILL_BACK := Color(0.933, 0.804, 0.702)

var _refs: FightSceneHudRefs


func bind(refs: FightSceneHudRefs) -> void:
	_refs = refs


func get_vfx() -> FightVfxManager:
	return _refs.vfx if _refs != null else null


func get_float_layer() -> CombatFloatLayer:
	return _refs.float_layer if _refs != null else null


func get_chk_auto_player() -> CheckButton:
	return _refs.chk_auto_player if _refs != null else null


func apply_battle(ctx: FightSceneContext, data: Dictionary) -> void:
	var player_v: Variant = data.get("player", {})
	if player_v is Dictionary:
		apply_combatant("left", player_v as Dictionary)
	var enemy_v: Variant = data.get("enemy", {})
	if enemy_v is Dictionary:
		apply_combatant("right", enemy_v as Dictionary)
	var intervals_v: Variant = data.get("intervals", {})
	if intervals_v is Dictionary:
		var id := intervals_v as Dictionary
		_set_interval_bar(_refs.interval_left, id.get("left", {}))
		_set_interval_bar(_refs.interval_right, id.get("right", {}))
	apply_skill_row(ctx.skill_slots, data.get("skills", []), ctx.skill_slot_interactive, "skill")
	apply_skill_row(ctx.equip_slots, data.get("equips", []), ctx.equip_slot_interactive, "equip")
	apply_skill_row(ctx.item_slots, data.get("items", []), ctx.item_slot_interactive, "item")


func apply_combatant(side: String, row: Dictionary) -> void:
	if not row.has("hp") or not row.has("hp_max") or not row.has("mp") or not row.has("mp_max"):
		push_error("FightSceneHud.apply_combatant(%s): 缺少 hp/hp_max/mp/mp_max" % side)
		return
	var name_text := str(row.get("name", "")).strip_edges()
	var avatar_v: Variant = row.get("avatar")
	var hp := float(row["hp"])
	var hp_max := float(row["hp_max"])
	var mp := float(row["mp"])
	var mp_max := float(row["mp_max"])
	var sprite_tex_v: Variant = row.get("sprite")
	if side == "left":
		if name_text != "":
			_refs.rolename_left.text = name_text
		if avatar_v is Texture2D:
			_refs.head_left.texture = avatar_v
			if _refs.interval_left != null:
				_refs.interval_left.set_avatar_texture(avatar_v)
		if sprite_tex_v is Texture2D:
			_refs.sprite_left.texture = sprite_tex_v
	else:
		if name_text != "":
			_refs.rolename_right.text = name_text
		if avatar_v is Texture2D:
			_refs.head_right.texture = avatar_v
			if _refs.interval_right != null:
				_refs.interval_right.set_avatar_texture(avatar_v)
		if sprite_tex_v is Texture2D:
			_refs.sprite_right.texture = sprite_tex_v
	set_combatant_vitals(side, hp, hp_max, mp, mp_max)
	var shield := 0.0
	var attrs_v: Variant = row.get("attrs", null)
	if attrs_v is Dictionary:
		shield = float((attrs_v as Dictionary).get(FightAttr.SHIELD, 0.0))
	set_combatant_shield(side, shield, hp_max)


func set_interval(side: String, elapsed: float, cap: float) -> void:
	var track := _refs.interval_left if side == "left" else _refs.interval_right
	if track != null:
		track.set_progress(elapsed, cap)


func set_combatant_vitals(side: String, hp: float, hp_max: float, mp: float, mp_max: float) -> void:
	var hp_bar: ProgressBar
	var hp_val: Label
	var mp_bar: ProgressBar
	var mp_val: Label
	if side == "left":
		hp_bar = _refs.hp_bar_left
		hp_val = _refs.hp_val_left
		mp_bar = _refs.mp_bar_left
		mp_val = _refs.mp_val_left
	else:
		hp_bar = _refs.hp_bar_right
		hp_val = _refs.hp_val_right
		mp_bar = _refs.mp_bar_right
		mp_val = _refs.mp_val_right
	_set_bar_pair(hp_bar, hp_val, hp, hp_max)
	_set_bar_pair(mp_bar, mp_val, mp, mp_max)


func set_combatant_shield(side: String, shield: float, hp_max: float) -> void:
	var shield_bar: ProgressBar
	var shield_badge: HBoxContainer
	var shield_val: Label
	if side == "left":
		shield_bar = _refs.shield_bar_left
		shield_badge = _refs.shield_badge_left
		shield_val = _refs.shield_val_left
	else:
		shield_bar = _refs.shield_bar_right
		shield_badge = _refs.shield_badge_right
		shield_val = _refs.shield_val_right
	var amount := maxf(0.0, shield)
	var has_shield := amount > 0.0
	if shield_bar != null:
		shield_bar.visible = has_shield
		if has_shield:
			var capf := maxf(hp_max, amount)
			shield_bar.min_value = 0.0
			shield_bar.max_value = capf
			shield_bar.value = amount
	if shield_badge != null:
		shield_badge.visible = has_shield
	if shield_val != null:
		if has_shield:
			shield_val.text = str(int(roundf(amount)))
		else:
			shield_val.text = ""


func sync_from_domain(ctx: FightSceneContext) -> void:
	if ctx.domain == null:
		return
	sync_fight_time_label(ctx)
	set_combatant_vitals(
		"left",
		ctx.domain.player.hp,
		ctx.domain.player.get_hp_max(),
		ctx.domain.player.mp,
		ctx.domain.player.get_mp_max()
	)
	set_combatant_shield(
		"left",
		ctx.domain.player.get_attr(FightAttr.SHIELD),
		ctx.domain.player.get_hp_max()
	)
	set_combatant_vitals(
		"right",
		ctx.domain.enemy.hp,
		ctx.domain.enemy.get_hp_max(),
		ctx.domain.enemy.mp,
		ctx.domain.enemy.get_mp_max()
	)
	set_combatant_shield(
		"right",
		ctx.domain.enemy.get_attr(FightAttr.SHIELD),
		ctx.domain.enemy.get_hp_max()
	)
	var intervals_v: Variant = ctx.domain.get_ui_snapshot().get("intervals", {})
	if intervals_v is Dictionary:
		var id := intervals_v as Dictionary
		_set_interval_bar(_refs.interval_left, id.get("left", {}))
		_set_interval_bar(_refs.interval_right, id.get("right", {}))
	sync_skill_cooldowns(ctx)
	sync_item_and_equip_runtime_ui(ctx)
	sync_buff_status_bars(ctx)


func sync_buff_status_bars(ctx: FightSceneContext) -> void:
	if ctx.domain == null:
		return
	if _refs.buff_status_left != null:
		_refs.buff_status_left.sync_buffs(ctx.domain.player.buffs)
	if _refs.buff_status_right != null:
		_refs.buff_status_right.sync_buffs(ctx.domain.enemy.buffs)


func sync_fight_time_label(ctx: FightSceneContext) -> void:
	if _refs.fighttime == null or ctx.domain == null:
		return
	var elapsed := maxf(0.0, ctx.domain.battle_elapsed_advancing)
	var minutes := int(floor(elapsed / 60.0))
	var seconds := elapsed - float(minutes * 60)
	_refs.fighttime.text = "%02d:%04.1f" % [minutes, seconds]


func sync_skill_cooldowns(ctx: FightSceneContext) -> void:
	if ctx.domain == null:
		return
	for i in ctx.skill_slots.size():
		var skill_id := FightSceneActions.skill_id_at(ctx.battle_player, i)
		if skill_id < 0:
			ctx.skill_slots[i].set_cooldown(0.0)
			continue
		if skill_id == 0:
			ctx.skill_slots[i].set_cooldown(0.0, -1.0)
			continue
		var cd := ctx.domain.player.get_skill_cd_at(i)
		var cfg := FightSceneActions.lookup_skill_cfg(ctx, skill_id)
		var slot := ctx.domain.player.get_skill_slot_at(i)
		var total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
		ctx.skill_slots[i].set_cooldown(cd, total)
	for i in ctx.equip_slots.size():
		var equip_slot := ctx.domain.player.get_equip_slot_at(i)
		var equip_id := int(equip_slot.get("id", -1))
		if equip_id < 0:
			ctx.equip_slots[i].set_cooldown(0.0)
			continue
		var cd := ctx.domain.player.get_equip_cd_at(i)
		var cfg := FightObj._lookup_cfg(ctx.equip_cfg, equip_id)
		var total := float(equip_slot.get("cd_total", cfg.get("cd_total", cfg.get("cd", 0.0))))
		ctx.equip_slots[i].set_cooldown(cd, total)


func sync_item_and_equip_runtime_ui(ctx: FightSceneContext) -> void:
	if ctx.domain == null:
		return
	for i in ctx.item_slots.size():
		var slot := ctx.domain.player.get_item_slot_at(i)
		var item_id := int(slot.get("id", -1))
		if item_id < 0:
			ctx.item_slots[i].set_stack_count(-1)
			ctx.item_slots[i].set_cooldown(0.0)
			continue
		var count := int(slot.get("count", 0))
		ctx.item_slots[i].set_stack_count(count)
		var cfg := FightObj._lookup_cfg(ctx.item_cfg, item_id)
		var cd := float(slot.get("cd", 0.0))
		var total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
		ctx.item_slots[i].set_cooldown(cd, total)
	for i in ctx.equip_slots.size():
		var slot := ctx.domain.player.get_equip_slot_at(i)
		var equip_id := int(slot.get("id", -1))
		if equip_id < 0:
			ctx.equip_slots[i].set_cooldown(0.0)
			continue
		var cfg := FightObj._lookup_cfg(ctx.equip_cfg, equip_id)
		var cd := float(slot.get("cd", 0.0))
		var total := float(slot.get("cd_total", cfg.get("cd_total", cfg.get("cd", 0.0))))
		ctx.equip_slots[i].set_cooldown(cd, total)


func sync_runtime_slot_interactive(ctx: FightSceneContext) -> void:
	if ctx.domain == null:
		return
	for i in ctx.skill_slot_interactive.size():
		var skill_id := FightSceneActions.skill_id_at(ctx.battle_player, i)
		ctx.skill_slot_interactive[i] = (
			skill_id >= 0
			and FightSceneActions.can_actor_use_skill_at(ctx, ctx.battle_player, i, skill_id)
		)
	for i in ctx.item_slot_interactive.size():
		ctx.item_slot_interactive[i] = FightSceneActions.can_use_player_item_at(ctx, i)
	for i in ctx.equip_slot_interactive.size():
		ctx.equip_slot_interactive[i] = FightSceneActions.can_use_player_equip_at(ctx, i)


func update_skill_input_enabled(ctx: FightSceneContext) -> void:
	var can_act := (
		ctx.domain != null
		and ctx.domain.can_player_act()
		and not ctx.presentation_busy
	)
	var active_tint := Color.WHITE
	var idle_tint := Color(0.65, 0.65, 0.65, 1.0)
	var empty_tint := Color(0.65, 0.65, 0.65, 0.45)
	for i in ctx.skill_slots.size():
		var usable := i < ctx.skill_slot_interactive.size() and ctx.skill_slot_interactive[i]
		var enabled := can_act and usable
		var tint := active_tint if enabled else (idle_tint if usable else empty_tint)
		_set_slot_input_enabled(ctx.skill_slots[i], tint)
	for i in ctx.item_slots.size():
		var usable := i < ctx.item_slot_interactive.size() and ctx.item_slot_interactive[i]
		var enabled := can_act and usable
		var tint := active_tint if enabled else (idle_tint if usable else empty_tint)
		_set_slot_input_enabled(ctx.item_slots[i], tint)
	for i in ctx.equip_slots.size():
		var usable := i < ctx.equip_slot_interactive.size() and ctx.equip_slot_interactive[i]
		var enabled := can_act and usable
		var tint := active_tint if enabled else (idle_tint if usable else empty_tint)
		_set_slot_input_enabled(ctx.equip_slots[i], tint)


func apply_skill_row(
		slots: Array[OneSkillView],
		rows: Variant,
		interactive_out: Array[bool],
		slot_kind: String = "skill"
) -> void:
	interactive_out.clear()
	var row_arr: Array = rows as Array if rows is Array else []
	for i in slots.size():
		var slot := slots[i]
		if i >= row_arr.size() or _is_empty_slot_row(row_arr[i]):
			slot.clear_slot()
			interactive_out.append(false)
			continue
		var row := row_arr[i] as Dictionary
		var icon_v: Variant = row.get("icon")
		var back_v: Variant = row.get("back_color")
		var back: Color = back_v as Color if back_v is Color else SKILL_BACK
		var tex: Texture2D = icon_v as Texture2D if icon_v is Texture2D else null
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
		match slot_kind:
			"item":
				slot.bind_hover_item(int(row.get("item_id", -1)), tex, int(row.get("count", -1)))
			"equip":
				slot.bind_hover_equip(
					int(row.get("equip_id", row.get("item_id", -1))),
					tex,
					row.get("effects", [])
				)
			_:
				slot.bind_hover_skill(int(row.get("skill_id", -1)), tex)


func setup_battle_vfx(ctx: FightSceneContext) -> void:
	if _refs.vfx == null:
		push_error("FightScene: 请在 fightScene.tscn 中放置 %FightVfxManager 节点")
		return
	_refs.vfx.set_screen_shake_target(_refs.center)
	_refs.vfx.set_projectile_parent(_refs.center)
	register_battle_actors(ctx)


func register_battle_actors(ctx: FightSceneContext) -> void:
	if _refs.vfx == null or ctx.scene == null:
		return
	if not is_instance_valid(_refs.sprite_left) or not is_instance_valid(_refs.sprite_right):
		push_warning("FightScene: 战斗精灵未就绪，延后注册 VFX 角色")
		ctx.scene.call_deferred("_deferred_register_vfx_actors")
		return
	_refs.vfx.register_actor(FightSceneContext.UNIT_PLAYER, _refs.sprite_left)
	_refs.vfx.register_actor(FightSceneContext.UNIT_ENEMY, _refs.sprite_right)
	_refs.vfx.refresh_all_actors()
	BattleDebugLog.write("场景", "VFX 角色注册完成", {
		"玩家": sprite_vfx_snapshot(FightSceneContext.UNIT_PLAYER),
		"敌方": sprite_vfx_snapshot(FightSceneContext.UNIT_ENEMY),
	})


func ensure_vfx_actors_for_combat() -> void:
	if _refs.vfx == null:
		return
	if is_instance_valid(_refs.sprite_left):
		_refs.vfx.ensure_actor_registered(FightSceneContext.UNIT_PLAYER, _refs.sprite_left)
	if is_instance_valid(_refs.sprite_right):
		_refs.vfx.ensure_actor_registered(FightSceneContext.UNIT_ENEMY, _refs.sprite_right)


func sprite_vfx_snapshot(unit_id: String) -> Dictionary:
	if _refs.vfx == null:
		return {"ok": false}
	var vfx := _refs.vfx.get_actor_vfx(unit_id)
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


func unit_screen_pos(ctx: FightSceneContext, unit_id: String) -> Vector2:
	var sprite: Node2D = (
		_refs.sprite_left if unit_id == FightSceneContext.UNIT_PLAYER else _refs.sprite_right
	)
	if not is_instance_valid(sprite) or ctx.scene == null:
		return ctx.scene.size * Vector2(0.5, 0.35) if ctx.scene != null else Vector2.ZERO
	return sprite.get_global_transform_with_canvas().origin + Vector2(0.0, -90.0)


func sync_auto_battle_ui(ctx: FightSceneContext) -> void:
	if _refs.chk_auto_player == null:
		return
	_refs.chk_auto_player.set_block_signals(true)
	_refs.chk_auto_player.button_pressed = ctx.auto_battle_player
	_refs.chk_auto_player.set_block_signals(false)


func clear_battle_log() -> void:
	if _refs.battle_log_panel != null and _refs.battle_log_panel.has_method("clear_log"):
		_refs.battle_log_panel.call("clear_log")
		_refs.battle_log_panel.visible = true
		if _refs.battle_log_panel.has_method("append_plain_line"):
			_refs.battle_log_panel.call("append_plain_line", "[b]战斗开始[/b]")


func render_battle_log_tail(ctx: FightSceneContext, entry: Dictionary) -> void:
	if _refs.battle_log_panel == null:
		return
	if _refs.battle_log_panel.has_method("render_tail"):
		_refs.battle_log_panel.call(
			"render_tail",
			ctx.recorder.get_entries_tail(80),
			ctx.record_formatter,
			ctx.record_names
		)
	elif _refs.battle_log_panel.has_method("append_entry"):
		_refs.battle_log_panel.call("append_entry", entry, ctx.record_formatter, ctx.record_names)


func show_battle_result(ctx: FightSceneContext, summary: Dictionary) -> void:
	if _refs.battle_result_overlay == null:
		return
	if _refs.battle_result_overlay.has_method("apply_summary"):
		_refs.battle_result_overlay.call(
			"apply_summary",
			summary,
			ctx.record_formatter,
			ctx.recorder.get_entries_tail(80),
			ctx.record_names
		)
		_refs.battle_result_overlay.visible = true


func hide_battle_result() -> void:
	if _refs.battle_result_overlay != null:
		_refs.battle_result_overlay.visible = false


static func _is_empty_slot_row(row_v: Variant) -> bool:
	return row_v is Dictionary and bool((row_v as Dictionary).get("empty", false))


static func _set_interval_bar(track: IntervalTrackView, row: Variant) -> void:
	if track == null:
		return
	track.apply_row(row)


static func _set_bar_pair(bar: ProgressBar, val_lbl: Label, cur: float, capv: float) -> void:
	if bar == null:
		return
	var capf := maxf(capv, 0.001)
	var cur_clamped := clampf(cur, 0.0, capf)
	bar.min_value = 0.0
	bar.max_value = capf
	bar.value = cur_clamped
	if val_lbl != null:
		val_lbl.text = "%d/%d" % [int(roundf(cur_clamped)), int(roundf(capf))]


static func _set_slot_input_enabled(slot: OneSkillView, tint: Color) -> void:
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.modulate = tint
	var press := slot.get_node_or_null("Control")
	if press is Control:
		press.mouse_filter = slot.mouse_filter
		press.modulate = tint
