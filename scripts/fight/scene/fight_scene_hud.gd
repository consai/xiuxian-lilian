class_name FightSceneHud
extends RefCounted

## 战斗 HUD：头像/血法/护盾/走条/Buff 栏与槽位外观绑定。

const SKILL_BACK := Color(0.933, 0.804, 0.702)

var _refs: FightSceneHudRefs
var _enemy_slot_nodes: Dictionary = {}
var _enemy_actor_nodes: Dictionary = {}


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
		apply_combatant(ctx, "left", player_v as Dictionary)
	var enemy_v: Variant = data.get("enemy", {})
	if enemy_v is Dictionary:
		apply_combatant(ctx, "right", enemy_v as Dictionary)
	var intervals_v: Variant = data.get("intervals", {})
	if intervals_v is Dictionary:
		var id := intervals_v as Dictionary
		_set_interval_bar(_refs.interval_left, id.get("left", {}))
		_set_interval_bar(_refs.interval_right, id.get("right", {}))
	apply_skill_row(ctx.skill_slots, data.get("skills", []), ctx.skill_slot_interactive, "skill")
	apply_skill_row(ctx.equip_slots, data.get("equips", []), ctx.equip_slot_interactive, "equip")
	apply_skill_row(ctx.item_slots, data.get("items", []), ctx.item_slot_interactive, "item")
	collect_enemy_formation_slots()


func apply_combatant(ctx: FightSceneContext, side: String, row: Dictionary) -> void:
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
	else:
		if avatar_v is Texture2D:
			if _refs.interval_right != null:
				_refs.interval_right.set_avatar_texture(avatar_v)
		if sprite_tex_v is Texture2D:
			_refs.sprite_right.texture = sprite_tex_v
		return
	set_combatant_vitals(side, hp, hp_max, mp, mp_max)
	var shield := 0.0
	var attrs_v: Variant = row.get("attrs", null)
	if attrs_v is Dictionary:
		shield = float((attrs_v as Dictionary).get(FightAttr.SHIELD, 0.0))
	set_combatant_shield(side, shield, hp_max)
	if side == "left":
		_apply_player_slot(ctx, row)


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
	collect_enemy_formation_slots()
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
	sync_enemy_header(ctx)
	sync_player_slot(ctx)
	sync_enemy_formation(ctx)
	var intervals_v: Variant = ctx.domain.get_ui_snapshot().get("intervals", {})
	if intervals_v is Dictionary:
		var id := intervals_v as Dictionary
		_set_interval_bar(_refs.interval_left, id.get("left", {}))
		_set_interval_bar(_refs.interval_right, id.get("right", {}))
	sync_skill_cooldowns(ctx)
	sync_item_and_equip_runtime_ui(ctx)


func sync_player_slot(ctx: FightSceneContext) -> void:
	var unit := ctx.domain.player if ctx.domain != null else ctx.battle_player
	if unit == null:
		if _refs.sprite_left != null:
			_refs.sprite_left.visible = false
		return
	var row: Dictionary = ctx.battle_player_row.duplicate(true)
	if row.is_empty():
		row = {
			"name": str(ctx.record_names.get(FightSceneContext.UNIT_PLAYER, "玩家")),
		}
	row["hp"] = unit.hp
	row["hp_max"] = unit.get_hp_max()
	_apply_player_slot(ctx, row)


func _apply_player_slot(ctx: FightSceneContext, row: Dictionary) -> void:
	var slot := _refs.sprite_left
	if slot == null:
		return
	var unit := ctx.domain.player if ctx.domain != null else ctx.battle_player
	if unit == null:
		slot.visible = false
		return
	var dead := unit.hp <= 0.0
	slot.apply_slot(row, unit, {}, true, dead)
	if _refs.vfx != null:
		_ensure_vfx_actor(FightSceneContext.UNIT_PLAYER, _slot_actor_node(slot))


func collect_enemy_formation_slots() -> void:
	if _refs == null or _refs.center == null:
		return
	if not _enemy_slot_nodes.is_empty():
		return
	for child in _refs.center.get_children():
		if child is Node2D and str(child.name).begins_with("EnemySlot_"):
			var slot_index := int(str(child.name).trim_prefix("EnemySlot_"))
			_enemy_slot_nodes[slot_index] = child


func sync_enemy_formation(ctx: FightSceneContext) -> void:
	if ctx.domain == null or _refs.center == null:
		return
	var formation := ctx.domain.get_formation_snapshot()
	var slots_v: Variant = formation.get("slots", [])
	if not slots_v is Array:
		return
	var seen := {}
	_enemy_actor_nodes.clear()
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			continue
		var slot := slot_v as Dictionary
		var slot_index := int(slot.get("slot", -1))
		if slot_index < 0:
			continue
		seen[slot_index] = true
		var node := _enemy_slot_nodes.get(slot_index, null) as Node2D
		if node != null:
			_apply_enemy_slot_node(ctx, node, slot)
	for key in _enemy_slot_nodes.keys():
		if not seen.has(int(key)):
			var old := _enemy_slot_nodes[key] as Node2D
			if old != null:
				old.visible = false


func _apply_enemy_slot_node(ctx: FightSceneContext, node: Node2D, slot: Dictionary) -> void:
	var empty := bool(slot.get("empty", false))
	node.visible = not empty
	if empty:
		return
	var active := bool(slot.get("active", false))
	var dead := bool(slot.get("dead", false))
	var enemy_index := int(slot.get("enemy_index", -1))
	var unit := ctx.domain._enemy_at(enemy_index)
	var row_data: Dictionary = {}
	# 敌人信息
	if enemy_index >= 0 and enemy_index < ctx.battle_enemy_rows.size() and ctx.battle_enemy_rows[enemy_index] is Dictionary:
		#
		row_data = ctx.battle_enemy_rows[enemy_index] as Dictionary
	var intent_row := _resolve_enemy_intent_row(ctx, enemy_index) if active and not dead else {}
	# 应用敌人信息
	if node.has_method("apply_slot"):
		node.call("apply_slot", row_data, unit, intent_row, active, dead)
	var actor_id := str(slot.get("actor_id", ""))
	var actor_node := _slot_actor_node(node)
	if actor_id != "":
		_enemy_actor_nodes[actor_id] = actor_node
		if _refs.vfx != null:
			_ensure_vfx_actor(actor_id, actor_node)
	# 当前敌人
	if bool(slot.get("current", false)):
		_enemy_actor_nodes[FightSceneContext.UNIT_ENEMY] = actor_node
		if _refs.vfx != null:
			_ensure_vfx_actor(FightSceneContext.UNIT_ENEMY, actor_node)


func _resolve_enemy_intent_row(ctx: FightSceneContext, enemy_index: int) -> Dictionary:
	var decision := FightSceneActions.preview_enemy_action(ctx, enemy_index)
	match str(decision.get("action_type", "")):
		"skill":
			return _build_skill_intent_row(
				ctx,
				enemy_index,
				int(decision.get("skill_id", -1)),
				"skill"
			)
		"basic":
			return _build_skill_intent_row(ctx, enemy_index, 0, "basic")
		"item":
			var unit := ctx.domain._enemy_at(enemy_index)
			var slot := unit.get_item_slot_at(int(decision.get("slot_index", -1))) if unit != null else {}
			var item_id := int(slot.get("id", -1))
			var item_cfg := FightObj._lookup_cfg(ctx.item_cfg, item_id)
			return {
				"action_type": "item",
				"item_id": item_id,
				"icon": BattleInitData._resolve_icon_texture(item_cfg),
				"count": int(slot.get("count", 0)),
				"back_color": BattleInitData._quality_back_color(int(item_cfg.get("quality", 1))),
			}
		"equip":
			var unit2 := ctx.domain._enemy_at(enemy_index)
			var slot2 := unit2.get_equip_slot_at(int(decision.get("slot_index", -1))) if unit2 != null else {}
			var equip_id := int(slot2.get("id", -1))
			var equip_cfg := FightObj._lookup_cfg(ctx.equip_cfg, equip_id)
			return {
				"action_type": "equip",
				"equip_id": equip_id,
				"icon": BattleInitData._resolve_icon_texture(equip_cfg),
				"effects": (slot2.get("effects", equip_cfg.get("effects", [])) as Array).duplicate(true),
				"back_color": BattleInitData._quality_back_color(int(equip_cfg.get("quality", 1))),
			}
		_:
			return _build_skill_intent_row(ctx, enemy_index, 0, "basic")


func _build_skill_intent_row(
		ctx: FightSceneContext,
		enemy_index: int,
		skill_id: int,
		action_type: String,
) -> Dictionary:
	var cfg := FightObj._lookup_cfg(ctx.skill_cfg, skill_id)
	var row := {
		"action_type": action_type,
		"skill_id": skill_id,
		"icon": _resolve_skill_cfg_icon(ctx, skill_id),
		"back_color": BattleInitData._quality_back_color(int(cfg.get("quality", 1))),
	}
	if ctx.battle_player == null or ctx.domain == null:
		return row
	var unit := ctx.domain._enemy_at(enemy_index)
	if unit == null:
		return row
	var preview_unit := FightSceneActions._enemy_unit_for_intent_preview(ctx, enemy_index, unit)
	return EnemyIntentPreview.enrich_skill_row(row, preview_unit, ctx.battle_player, cfg, skill_id)


func _resolve_skill_cfg_icon(ctx: FightSceneContext, skill_id: int) -> Texture2D:
	var tex := BattleInitData._resolve_icon_texture(FightObj._lookup_cfg(ctx.skill_cfg, skill_id))
	if tex != null:
		return tex
	return BattleInitData._resolve_icon_texture({"icon": "ui_new/skill_03.png"})


func sync_enemy_header(ctx: FightSceneContext) -> void:
	if ctx.domain == null or ctx.domain.enemy == null:
		return
	ctx.battle_enemy = ctx.domain.enemy
	var idx := ctx.domain.active_enemy_index
	var row: Dictionary = {}
	if idx >= 0 and idx < ctx.battle_enemy_rows.size() and ctx.battle_enemy_rows[idx] is Dictionary:
		row = (ctx.battle_enemy_rows[idx] as Dictionary)
	var avatar := BattleInitData._resolve_avatar_texture(row)
	if avatar != null and _refs.interval_right != null:
		_refs.interval_right.set_avatar_texture(avatar)
	var sprite_v: Variant = row.get("sprite")
	if sprite_v is Texture2D and _refs.sprite_right != null:
		_refs.sprite_right.texture = sprite_v


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
		slot.apply_battle_row(row, slot_kind)
		var usable := bool(row.get("usable", true))
		interactive_out.append(usable)


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
	if not is_instance_valid(_refs.sprite_left):
		push_warning("FightScene: 玩家战斗精灵未就绪，延后注册 VFX 角色")
		ctx.scene.call_deferred("_deferred_register_vfx_actors")
		return
	_register_vfx_actor(FightSceneContext.UNIT_PLAYER, _slot_actor_node(_refs.sprite_left))
	var enemy_node := _actor_node_for_unit(FightSceneContext.UNIT_ENEMY)
	if is_instance_valid(enemy_node):
		_register_vfx_actor(FightSceneContext.UNIT_ENEMY, enemy_node)
	elif is_instance_valid(_refs.sprite_right):
		_register_vfx_actor(FightSceneContext.UNIT_ENEMY, _refs.sprite_right)
	_refs.vfx.refresh_all_actors()
	BattleDebugLog.write("场景", "VFX 角色注册完成", {
		"玩家": sprite_vfx_snapshot(FightSceneContext.UNIT_PLAYER),
		"敌方": sprite_vfx_snapshot(FightSceneContext.UNIT_ENEMY),
	})


func ensure_vfx_actors_for_combat() -> void:
	if _refs.vfx == null:
		return
	if is_instance_valid(_refs.sprite_left):
		_ensure_vfx_actor(FightSceneContext.UNIT_PLAYER, _slot_actor_node(_refs.sprite_left))
	for actor_id in _enemy_actor_nodes.keys():
		var actor_node := _enemy_actor_nodes[actor_id] as Node2D
		if is_instance_valid(actor_node):
			_ensure_vfx_actor(str(actor_id), actor_node)
	var enemy_node := _actor_node_for_unit(FightSceneContext.UNIT_ENEMY)
	if is_instance_valid(enemy_node):
		_ensure_vfx_actor(FightSceneContext.UNIT_ENEMY, enemy_node)
	elif is_instance_valid(_refs.sprite_right):
		_ensure_vfx_actor(FightSceneContext.UNIT_ENEMY, _refs.sprite_right)


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
	var sprite := _actor_node_for_unit(unit_id)
	if not is_instance_valid(sprite) or ctx.scene == null:
		return ctx.scene.size * Vector2(0.5, 0.35) if ctx.scene != null else Vector2.ZERO
	return sprite.get_global_transform_with_canvas().origin + Vector2(0.0, -90.0)


func _actor_node_for_unit(unit_id: String) -> Node2D:
	if unit_id == FightSceneContext.UNIT_PLAYER:
		return _slot_actor_node(_refs.sprite_left)
	if _enemy_actor_nodes.has(unit_id):
		var node := _enemy_actor_nodes[unit_id] as Node2D
		if is_instance_valid(node):
			return node
	if unit_id == FightSceneContext.UNIT_ENEMY and _enemy_actor_nodes.has(FightSceneContext.UNIT_ENEMY):
		var enemy_node := _enemy_actor_nodes[FightSceneContext.UNIT_ENEMY] as Node2D
		if is_instance_valid(enemy_node):
			return enemy_node
	return _refs.sprite_right


func _slot_actor_node(slot: Node2D) -> Node2D:
	if not is_instance_valid(slot):
		return null
	if slot.has_method("actor_sprite"):
		var actor_v: Variant = slot.call("actor_sprite")
		if actor_v is Node2D and is_instance_valid(actor_v):
			return actor_v as Node2D
	return slot


func _register_vfx_actor(unit_id: String, actor: Node2D) -> void:
	if _refs.vfx == null or not is_instance_valid(actor):
		return
	_refs.vfx.register_actor(unit_id, actor, _vfx_settings_for_actor(actor))


func _ensure_vfx_actor(unit_id: String, actor: Node2D) -> void:
	if _refs.vfx == null or not is_instance_valid(actor):
		return
	_refs.vfx.ensure_actor_registered(unit_id, actor, _vfx_settings_for_actor(actor))


func _vfx_settings_for_actor(actor: Node2D) -> CombatVfxSettings:
	if _refs.vfx == null or _refs.vfx.settings == null or not is_instance_valid(actor):
		return null
	var settings := _refs.vfx.settings.duplicate() as CombatVfxSettings
	settings.actor_base_scale = maxf(0.01, maxf(absf(actor.scale.x), absf(actor.scale.y)))
	return settings


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
	slot.modulate = Color.WHITE
	slot.set_icon_tint(tint)
	var press := slot.get_node_or_null("Control")
	if press is Control:
		press.mouse_filter = slot.mouse_filter
		press.modulate = Color.WHITE
