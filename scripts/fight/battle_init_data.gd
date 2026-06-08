class_name BattleInitData
extends RefCounted
## 进战唯一入口：外部只提交 combatant 字典，由 [method resolve] 生成 [BattleSetup]（[FightObj] + UI 快照）。
## 进战前可 [method set_pending] / [method goto_fight_scene]，由 [FightScene] 在 _ready 消费。
const BattleSetupScript = preload("res://scripts/fight/battle_setup.gd")
const BattleRecordTypesScript = preload("res://scripts/fight/battle_record_types.gd")
const EnumQualityScript = preload("res://scripts/enum/enum_quality.gd")

const META_SCHEMA_VERSION := 2

const SETUP_KEYS := ["player", "enemy", "battle_time_limit"]
const COMBATANT_KEYS := ["hp", "mp", "attrs", "skills"]
const ATTR_KEYS := FightAttr.CORE_KEYS

## 进战时出手速度 [member FightObj.ATTR_SPD] 相对基础值的随机浮动比例（±5% → 0.95~1.05）。
const DEFAULT_SPD_JITTER_RATIO := 0.05


static func set_pending(
		tree: SceneTree,
		data: Dictionary,
		source: String = "unknown",
		session_id: String = ""
) -> String:
	var sid := session_id.strip_edges()
	if sid == "":
		sid = _new_battle_session_id()
	var payload := data.duplicate(true)
	payload["battle_session_id"] = sid
	var envelope := {
		"schema": META_SCHEMA_VERSION,
		"battle_session_id": sid,
		"source": source,
		"created_unix": int(Time.get_unix_time_from_system()),
		"payload": payload,
	}
	_data_store().set_battle_pending_init(envelope)
	return sid


static func take_pending(_tree: SceneTree = null, required_session_id: String = "") -> Dictionary:
	var envelope: Dictionary = _data_store().take_battle_pending_init()
	if envelope.is_empty():
		return {}
	if envelope.has("payload"):
		var sid := str(envelope.get("battle_session_id", "")).strip_edges()
		var required := required_session_id.strip_edges()
		if required != "" and sid != "" and sid != required:
			push_error(
				"BattleInitData.take_pending: session mismatch required=%s actual=%s" % [required, sid]
			)
			return {}
		var payload_v: Variant = envelope.get("payload", {})
		return payload_v as Dictionary if payload_v is Dictionary else {}
	return envelope


static func goto_fight_scene(tree: SceneTree, data: Dictionary, scene_path: String = "res://scenes/fightScene.tscn") -> bool:
	var errors := collect_errors(data)
	if not errors.is_empty():
		for msg in errors:
			push_error("BattleInitData: %s" % msg)
		return false
	var merged := merge_skill_cfg_from_tables(data)
	set_pending(tree, merged, "goto_fight_scene")
	tree.change_scene_to_file(scene_path)
	return true


## 合并表、校验并构建 [BattleSetup]；失败返回 [code]null[/code]（默认 [method push_error]）。
static func resolve(data: Dictionary, log_errors: bool = true) -> BattleSetupScript:
	var errors := collect_errors(data)
	if not errors.is_empty():
		if log_errors:
			for msg in errors:
				push_error("BattleInitData.resolve: %s" % msg)
		return null
	return _build_setup(merge_skill_cfg_from_tables(data))


## 校验进战数据；不创建 [FightObj]、不输出错误日志。
static func collect_errors(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		errors.append("初始化数据为空")
		return errors
	if is_ui_apply_payload(data):
		errors.append(
			"检测到 apply_battle UI 快照（顶层 intervals/skills 且 combatant 无 attrs）；"
			+ "请改用含 player/enemy.attrs 与 skills 的 combatant 进战数据"
		)
		return errors
	var merged := merge_skill_cfg_from_tables(data)
	errors.append_array(validate_setup(merged))
	return errors


## 是否误将 [method build_apply_battle_payload] 产出当作进战源（combatant 须含 attrs）。
static func is_ui_apply_payload(data: Dictionary) -> bool:
	var player_v: Variant = data.get("player")
	if not player_v is Dictionary:
		return false
	var player := player_v as Dictionary
	if player.has("attrs"):
		return false
	if data.has("battle_time_limit"):
		return true
	var enemy_v: Variant = data.get("enemy")
	if enemy_v is Dictionary and not (enemy_v as Dictionary).has("attrs"):
		if data.has("intervals") or data.has("skills"):
			return true
	return false


static func is_combatant_row(row: Dictionary) -> bool:
	for key in COMBATANT_KEYS:
		if not row.has(key):
			return false
	return true


## 将 [code]data/skill.json[/code] 与可选的 [code]skill_cfg[/code] 覆盖合并进 [param data]。
static func merge_skill_cfg_from_tables(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var partial: Dictionary = {}
	var existing: Variant = out.get("skill_cfg")
	if existing is Dictionary and not (existing as Dictionary).is_empty():
		partial = (existing as Dictionary).duplicate(true)
	var cm := _get_config_manager()
	if cm != null and cm.has_method("build_skill_cfg"):
		out["skill_cfg"] = cm.call("build_skill_cfg", partial)
	else:
		out["skill_cfg"] = _build_skill_cfg_fallback(partial)
	var item_partial: Dictionary = {}
	var existing_item: Variant = out.get("item_cfg")
	if existing_item is Dictionary and not (existing_item as Dictionary).is_empty():
		item_partial = (existing_item as Dictionary).duplicate(true)
	if cm != null and cm.has_method("build_item_cfg"):
		out["item_cfg"] = cm.call("build_item_cfg", item_partial)
	else:
		out["item_cfg"] = _build_item_cfg_fallback(item_partial)
	var equip_partial: Dictionary = {}
	var existing_equip: Variant = out.get("equip_cfg")
	if existing_equip is Dictionary and not (existing_equip as Dictionary).is_empty():
		equip_partial = (existing_equip as Dictionary).duplicate(true)
	if cm != null and cm.has_method("build_equip_cfg"):
		out["equip_cfg"] = cm.call("build_equip_cfg", equip_partial)
	else:
		out["equip_cfg"] = _build_equip_cfg_fallback(equip_partial)
	if not out.has("battle_time_limit"):
		if cm != null and cm.has_method("battle_time_limit_default"):
			out["battle_time_limit"] = cm.call("battle_time_limit_default")
		else:
			var bundle: Dictionary = JsonLoader.load_skills_bundle()
			out["battle_time_limit"] = maxf(1.0, float(bundle.get("battle_time_limit", 200.0)))
	return out


static func validate_setup(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		errors.append("初始化数据为空")
		return errors
	for key in SETUP_KEYS:
		if not data.has(key):
			errors.append("缺少顶层字段 '%s'" % key)
	var player_v: Variant = data.get("player")
	if player_v is Dictionary:
		_append_combatant_errors(errors, "player", player_v as Dictionary)
	else:
		errors.append("player 必须为 Dictionary")
	var enemy_v: Variant = data.get("enemy")
	if enemy_v is Dictionary:
		_append_combatant_errors(errors, "enemy", enemy_v as Dictionary)
	else:
		errors.append("enemy 必须为 Dictionary")
	if not data.has("skill_cfg"):
		errors.append("缺少 skill_cfg（请先调用 merge_skill_cfg_from_tables）")
	var skill_cfg_v: Variant = data.get("skill_cfg")
	if skill_cfg_v != null and not skill_cfg_v is Dictionary:
		errors.append("skill_cfg 必须为 Dictionary")
	elif skill_cfg_v is Dictionary and player_v is Dictionary:
		_validate_slot_ids(errors, "player.skills", (player_v as Dictionary).get("skills"), skill_cfg_v as Dictionary)
		if enemy_v is Dictionary:
			_validate_slot_ids(errors, "enemy.skills", (enemy_v as Dictionary).get("skills"), skill_cfg_v as Dictionary)
			_validate_enemy_ai_cfg(errors, enemy_v as Dictionary, skill_cfg_v as Dictionary)
	var limit_v: Variant = data.get("battle_time_limit")
	if limit_v != null and not (limit_v is int or limit_v is float):
		errors.append("battle_time_limit 必须为数值")
	elif limit_v is int or limit_v is float:
		if float(limit_v) <= 0.0:
			errors.append("battle_time_limit 必须大于 0")
	if data.has("item_cfg") and not data.get("item_cfg") is Dictionary:
		errors.append("item_cfg 必须为 Dictionary")
	var item_cfg_v: Variant = data.get("item_cfg")
	if player_v is Dictionary:
		var p_items: Variant = (player_v as Dictionary).get("items", [])
		if _slot_array_has_item(p_items) and not data.has("item_cfg"):
			errors.append("player.items 含有效物品时必须提供 item_cfg")
		elif p_items is Array and item_cfg_v is Dictionary:
			_validate_item_slot_ids(errors, "player.items", p_items, item_cfg_v)
	if data.has("equip_cfg") and not data.get("equip_cfg") is Dictionary:
		errors.append("equip_cfg 必须为 Dictionary")
	var equip_cfg_v: Variant = data.get("equip_cfg")
	if player_v is Dictionary and equip_cfg_v is Dictionary:
		var p_equips: Variant = (player_v as Dictionary).get("equips", [])
		if p_equips is Array:
			_validate_equip_slot_ids(errors, "player.equips", p_equips, equip_cfg_v)
	return errors


static func _validate_slot_ids(
		errors: PackedStringArray,
		label: String,
		slots_v: Variant,
		skill_cfg: Dictionary
) -> void:
	if slots_v == null:
		return
	if not slots_v is Array:
		errors.append("%s 必须为 Array" % label)
		return
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			continue
		var sid := int((slot_v as Dictionary).get("id", -1))
		if sid > 0 and FightObj._lookup_cfg(skill_cfg, sid).is_empty():
			errors.append("%s 含技能 %d 但 skill_cfg 无对应配置" % [label, sid])


static func _validate_item_slot_ids(
		errors: PackedStringArray,
		label: String,
		slots_v: Variant,
		item_cfg_v: Variant
) -> void:
	if slots_v == null:
		return
	if not slots_v is Array:
		errors.append("%s 必须为 Array" % label)
		return
	if not item_cfg_v is Dictionary:
		return
	var item_cfg := item_cfg_v as Dictionary
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			continue
		var iid := int((slot_v as Dictionary).get("id", -1))
		if iid >= 0 and FightObj._lookup_cfg(item_cfg, iid).is_empty():
			errors.append("%s 含物品 %d 但 item_cfg 无对应配置" % [label, iid])


static func _validate_equip_slot_ids(
		errors: PackedStringArray,
		label: String,
		slots_v: Variant,
		equip_cfg_v: Variant
) -> void:
	if slots_v == null:
		return
	if not slots_v is Array:
		errors.append("%s 必须为 Array" % label)
		return
	if not equip_cfg_v is Dictionary:
		return
	var equip_cfg := equip_cfg_v as Dictionary
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			continue
		var eid := int((slot_v as Dictionary).get("id", -1))
		if eid >= 0 and FightObj._lookup_cfg(equip_cfg, eid).is_empty():
			errors.append("%s 含法宝 %d 但 equip_cfg 无对应配置" % [label, eid])


static func _slot_array_has_item(slots_v: Variant) -> bool:
	if not slots_v is Array:
		return false
	for slot_v in slots_v as Array:
		if slot_v is Dictionary and int((slot_v as Dictionary).get("id", -1)) >= 0:
			var slot := slot_v as Dictionary
			if int(slot.get("count", 1)) > 0:
				return true
	return false


static func _validate_enemy_ai_cfg(
		errors: PackedStringArray,
		enemy_row: Dictionary,
		skill_cfg: Dictionary
) -> void:
	var ai_v: Variant = enemy_row.get("ai", null)
	if ai_v == null:
		return
	if not ai_v is Dictionary:
		errors.append("enemy.ai 必须为 Dictionary")
		return
	var ai := ai_v as Dictionary
	var version := 1
	var version_v: Variant = ai.get("version", 1)
	if not (version_v is int or version_v is float):
		errors.append("enemy.ai.version 必须为数值")
	elif int(version_v) <= 0:
		errors.append("enemy.ai.version 必须大于 0")
	else:
		version = int(version_v)
	var phases_v: Variant = ai.get("phases", [])
	if phases_v is Array and not (phases_v as Array).is_empty():
		_validate_enemy_ai_phases(errors, enemy_row, skill_cfg, phases_v as Array)
		return
	if version >= 2:
		errors.append("enemy.ai.version=2 需提供非空 phases 数组")
		return
	_validate_enemy_ai_policy_block(errors, enemy_row, skill_cfg, ai, "enemy.ai")


static func _validate_enemy_ai_phases(
		errors: PackedStringArray,
		enemy_row: Dictionary,
		skill_cfg: Dictionary,
		phases: Array
) -> void:
	var seen_ids := {}
	for i in phases.size():
		var phase_v: Variant = phases[i]
		if not phase_v is Dictionary:
			errors.append("enemy.ai.phases[%d] 必须为 Dictionary" % i)
			continue
		var phase := phase_v as Dictionary
		var phase_id := str(phase.get("id", "")).strip_edges()
		if phase_id == "":
			errors.append("enemy.ai.phases[%d].id 不能为空" % i)
			continue
		if seen_ids.has(phase_id):
			errors.append("enemy.ai.phases 含重复 id: %s" % phase_id)
			continue
		seen_ids[phase_id] = true
		var prefix := "enemy.ai.phases[%d](%s)" % [i, phase_id]
		_validate_enemy_ai_when(errors, phase.get("enter_when", {}), prefix + ".enter_when")
		_validate_enemy_ai_policy_block(
			errors,
			enemy_row,
			skill_cfg,
			phase,
			prefix
		)


static func _validate_enemy_ai_policy_block(
		errors: PackedStringArray,
		enemy_row: Dictionary,
		skill_cfg: Dictionary,
		block: Dictionary,
		prefix: String
) -> void:
	var policy := str(block.get("policy", "priority")).strip_edges().to_lower()
	if policy == "":
		policy = "priority"
	if policy != "priority" and policy != "rule_list":
		errors.append("%s.policy 仅支持 priority | rule_list" % prefix)
		return
	if policy == "priority":
		_validate_enemy_ai_skill_priority(errors, enemy_row, skill_cfg, block.get("skill_priority", []), prefix)
	elif policy == "rule_list":
		_validate_enemy_ai_rules(errors, enemy_row, skill_cfg, block.get("rules", []), prefix)


static func _validate_enemy_ai_skill_priority(
		errors: PackedStringArray,
		enemy_row: Dictionary,
		skill_cfg: Dictionary,
		pref_v: Variant,
		prefix: String
) -> void:
	if pref_v == null:
		return
	if not pref_v is Array:
		errors.append("%s.skill_priority 必须为 Array[int]" % prefix)
		return
	var seen := {}
	var enemy_skills := _collect_enemy_skill_ids(enemy_row.get("skills"))
	for v in pref_v as Array:
		if not (v is int or v is float):
			errors.append("%s.skill_priority 仅允许整数技能 id" % prefix)
			continue
		var sid := int(v)
		if sid <= 0:
			errors.append("%s.skill_priority 仅允许 >0 的技能 id" % prefix)
			continue
		if seen.has(sid):
			errors.append("%s.skill_priority 含重复技能 id %d" % prefix)
			continue
		seen[sid] = true
		if not enemy_skills.has(sid):
			errors.append("%s.skill_priority 技能 %d 不在 enemy.skills 中" % prefix)
			continue
		if FightObj._lookup_cfg(skill_cfg, sid).is_empty():
			errors.append("%s.skill_priority 技能 %d 在 skill_cfg 中无配置" % [prefix, sid])


static func _validate_enemy_ai_rules(
		errors: PackedStringArray,
		enemy_row: Dictionary,
		skill_cfg: Dictionary,
		rules_v: Variant,
		prefix: String
) -> void:
	if not rules_v is Array:
		errors.append("%s.rules 必须为 Array" % prefix)
		return
	var rules := rules_v as Array
	if rules.is_empty():
		errors.append("%s.rules 不能为空" % prefix)
		return
	for ri in rules.size():
		var rule_v: Variant = rules[ri]
		if not rule_v is Dictionary:
			errors.append("%s.rules[%d] 必须为 Dictionary" % [prefix, ri])
			continue
		var rule := rule_v as Dictionary
		_validate_enemy_ai_when(errors, rule.get("when", null), "%s.rules[%d].when" % [prefix, ri])
		var action_v: Variant = rule.get("action", null)
		if not action_v is Dictionary:
			errors.append("%s.rules[%d].action 必须为 Dictionary" % [prefix, ri])
			continue
		_validate_enemy_ai_action(errors, enemy_row, skill_cfg, action_v as Dictionary, "%s.rules[%d].action" % [prefix, ri])


static func _validate_enemy_ai_when(
		errors: PackedStringArray,
		when_v: Variant,
		prefix: String
) -> void:
	if when_v == null:
		return
	if not when_v is Dictionary:
		errors.append("%s 必须为 Dictionary" % prefix)
		return
	var allowed := {
		"self_hp_ratio_lte": true,
		"self_hp_ratio_gte": true,
		"target_hp_ratio_lte": true,
		"target_hp_ratio_gte": true,
		"self_mp_gte": true,
		"skill_ready": true,
		"skill_on_cd": true,
		"has_buff": true,
		"not_has_buff": true,
		"item_count_gte": true,
		"equip_ready": true,
		"battle_elapsed_gte": true,
	}
	for key in (when_v as Dictionary).keys():
		if not allowed.has(str(key)):
			errors.append("%s 含未知算子: %s" % [prefix, str(key)])


static func _validate_enemy_ai_action(
		errors: PackedStringArray,
		enemy_row: Dictionary,
		skill_cfg: Dictionary,
		action: Dictionary,
		prefix: String
) -> void:
	var action_type := str(action.get("type", "")).strip_edges().to_lower()
	if action_type == "":
		errors.append("%s.type 不能为空" % prefix)
		return
	match action_type:
		"skill":
			var sid := int(action.get("skill_id", -1))
			if sid <= 0:
				errors.append("%s.skill_id 必须 >0" % prefix)
			elif not _collect_enemy_skill_ids(enemy_row.get("skills")).has(sid):
				errors.append("%s 技能 %d 不在 enemy.skills 中" % [prefix, sid])
			elif FightObj._lookup_cfg(skill_cfg, sid).is_empty():
				errors.append("%s 技能 %d 在 skill_cfg 中无配置" % [prefix, sid])
		"basic":
			pass
		"item":
			var slot_index := int(action.get("slot_index", -1))
			if slot_index < 0:
				errors.append("%s.slot_index 无效" % prefix)
			elif not _enemy_item_slot_has_id(enemy_row, slot_index):
				errors.append("%s 道具槽 %d 无有效 item id" % [prefix, slot_index])
		"equip":
			var equip_slot := int(action.get("slot_index", -1))
			if equip_slot < 0:
				errors.append("%s.slot_index 无效" % prefix)
			elif not _enemy_equip_slot_has_id(enemy_row, equip_slot):
				errors.append("%s 法器槽 %d 无有效 equip id" % [prefix, equip_slot])
		_:
			errors.append("%s.type 仅支持 skill|basic|item|equip" % prefix)


static func _enemy_item_slot_has_id(enemy_row: Dictionary, slot_index: int) -> bool:
	var items_v: Variant = enemy_row.get("items", [])
	if not items_v is Array or slot_index >= (items_v as Array).size():
		return false
	var slot_v: Variant = (items_v as Array)[slot_index]
	if not slot_v is Dictionary:
		return false
	return int((slot_v as Dictionary).get("id", -1)) >= 0


static func _enemy_equip_slot_has_id(enemy_row: Dictionary, slot_index: int) -> bool:
	var equips_v: Variant = enemy_row.get("equips", [])
	if not equips_v is Array or slot_index >= (equips_v as Array).size():
		return false
	var slot_v: Variant = (equips_v as Array)[slot_index]
	if not slot_v is Dictionary:
		return false
	return int((slot_v as Dictionary).get("id", -1)) >= 0


static func _collect_enemy_skill_ids(slots_v: Variant) -> Dictionary:
	var out := {}
	if not slots_v is Array:
		return out
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			continue
		var sid := int((slot_v as Dictionary).get("id", -1))
		if sid > 0:
			out[sid] = true
	return out


static func _build_setup(merged: Dictionary) -> BattleSetupScript:
	var setup := BattleSetupScript.new()
	var player_row: Dictionary = (merged["player"] as Dictionary).duplicate(true)
	var enemy_row: Dictionary = (merged["enemy"] as Dictionary).duplicate(true)
	_apply_spd_jitter_from_setup(player_row, enemy_row, merged)
	setup.player_row = player_row
	setup.enemy_row = enemy_row
	setup.player = create_fight_obj("player", player_row)
	setup.enemy = create_fight_obj("enemy", enemy_row)
	if setup.player == null or setup.enemy == null:
		push_error("BattleInitData._build_setup: 无法创建 FightObj")
		return null
	setup.skill_cfg = (merged["skill_cfg"] as Dictionary).duplicate(true)
	setup.battle_time_limit = float(merged["battle_time_limit"])
	setup.battle_session_id = str(merged.get("battle_session_id", "")).strip_edges()
	setup.item_cfg = {}
	if merged.has("item_cfg") and merged["item_cfg"] is Dictionary:
		setup.item_cfg = (merged["item_cfg"] as Dictionary).duplicate(true)
	setup.equip_cfg = {}
	if merged.has("equip_cfg") and merged["equip_cfg"] is Dictionary:
		setup.equip_cfg = (merged["equip_cfg"] as Dictionary).duplicate(true)
	var auto_v: Variant = merged.get("auto_battle")
	if auto_v is Dictionary:
		setup.auto_battle = (auto_v as Dictionary).duplicate(true)
	setup.record_names = {
		BattleRecordTypesScript.UNIT_PLAYER: str(player_row.get("name", "")).strip_edges(),
		BattleRecordTypesScript.UNIT_ENEMY: str(enemy_row.get("name", "")).strip_edges(),
	}
	setup.ui_payload = build_apply_battle_payload(
		setup.player,
		setup.enemy,
		player_row,
		enemy_row,
		setup.skill_cfg,
		setup.item_cfg,
		setup.equip_cfg
	)
	return setup


static func _apply_spd_jitter_from_setup(
		player_row: Dictionary,
		enemy_row: Dictionary,
		data: Dictionary
) -> void:
	if not data.has("spd_jitter_ratio"):
		return
	var ratio_v: Variant = data["spd_jitter_ratio"]
	if not (ratio_v is int or ratio_v is float):
		return
	var ratio := float(ratio_v)
	if not player_row.has("spd_jitter_ratio"):
		player_row["spd_jitter_ratio"] = ratio
	if not enemy_row.has("spd_jitter_ratio"):
		enemy_row["spd_jitter_ratio"] = ratio


static func create_fight_obj(side: String, row: Dictionary) -> FightObj:
	var errors := PackedStringArray()
	_append_combatant_errors(errors, side, row)
	if not errors.is_empty():
		for msg in errors:
			push_error("FightObj.from_combatant(%s): %s" % [side, msg])
		return null
	var jitter_ratio := _resolve_spd_jitter_ratio(row)
	var fight_dict := _combatant_to_fight_dict(row)
	_apply_spd_jitter(fight_dict, jitter_ratio)
	var unit := FightObj.new(fight_dict)
	unit.clamp_vitals()
	return unit


static func build_apply_battle_payload(
		player: FightObj,
		enemy: FightObj,
		player_row: Dictionary,
		enemy_row: Dictionary,
		skill_cfg: Dictionary,
		item_cfg: Dictionary,
		equip_cfg: Dictionary
) -> Dictionary:
	return {
		"player": _combatant_ui_row(player, player_row),
		"enemy": _combatant_ui_row(enemy, enemy_row),
		"intervals": {
			"left": {"elapsed": 0.0, "cap": _interval_cap(player)},
			"right": {"elapsed": 0.0, "cap": _interval_cap(enemy)},
		},
		"skills": build_skills_ui(player, skill_cfg),
		"equips": build_equips_ui(player_row.get("equips", []), equip_cfg),
		"items": build_items_ui(player, item_cfg),
	}


static func build_skills_ui(player: FightObj, skill_cfg: Dictionary) -> Array:
	var rows: Array = []
	if not player.skills is Array:
		return rows
	for slot_v in player.skills as Array:
		if not slot_v is Dictionary:
			rows.append({"empty": true})
			continue
		var slot := slot_v as Dictionary
		var skill_id := int(slot.get("id", -1))
		if skill_id < 0:
			rows.append({"empty": true})
			continue
		if skill_id == 0:
			var basic := {
				"skill_id": 0,
				"name": "普攻",
				"cd_remaining": float(slot.get("cd", 0.0)),
				"cd_total": -1.0,
			}
			var basic_cfg := FightObj._lookup_cfg(skill_cfg, 0)
			if basic_cfg is Dictionary:
				var ba := basic_cfg as Dictionary
				var ba_name := str(ba.get("name", "")).strip_edges()
				if ba_name != "":
					basic["name"] = ba_name
				var basic_icon := _resolve_icon_texture(ba)
				if basic_icon != null:
					basic["icon"] = basic_icon
				basic["back_color"] = _quality_back_color(int(ba.get("quality", 1)))
			rows.append(basic)
			continue
		var cfg := FightObj._lookup_cfg(skill_cfg, skill_id)
		if cfg.is_empty():
			push_error("BattleInitData: skills 含技能 %d 但 skill_cfg 无配置" % skill_id)
			rows.append({"empty": true})
			continue
		var cd_total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
		var icon := _resolve_icon_texture(cfg)
		var row := {
			"skill_id": skill_id,
			"name": str(cfg.get("name", "")),
			"cd_remaining": float(slot.get("cd", 0.0)),
			"cd_total": cd_total,
		}
		if icon != null:
			row["icon"] = icon
		row["back_color"] = _quality_back_color(int(cfg.get("quality", 1)))
		rows.append(row)
	return rows


static func build_items_ui(player: FightObj, item_cfg: Dictionary) -> Array:
	var slot_rows: Variant = []
	if player.items is Array:
		slot_rows = player.items
	return build_slot_items_ui(slot_rows, item_cfg)


static func build_slot_items_ui(slots_v: Variant, item_cfg: Dictionary) -> Array:
	var rows: Array = []
	if not slots_v is Array:
		return rows
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			rows.append({"empty": true})
			continue
		var slot := slot_v as Dictionary
		var item_id := int(slot.get("id", -1))
		if item_id < 0:
			rows.append({"empty": true})
			continue
		var count := int(slot.get("count", 0))
		var cfg := FightObj._lookup_cfg(item_cfg, item_id)
		var row := {
			"name": str(cfg.get("name", str(item_id))),
			"item_id": item_id,
			"count": count,
			"usable": count > 0,
			"cd_remaining": float(slot.get("cd", 0.0)),
			"cd_total": float(slot.get("cd_total", cfg.get("cd", 0.0))),
		}
		var icon := _resolve_icon_texture(cfg)
		if icon != null:
			row["icon"] = icon
		row["back_color"] = _quality_back_color(int(cfg.get("quality", 1)))
		rows.append(row)
	return rows


static func build_equips_ui(slots_v: Variant, equip_cfg: Dictionary) -> Array:
	var rows: Array = []
	if not slots_v is Array:
		return rows
	for slot_v in slots_v as Array:
		if not slot_v is Dictionary:
			rows.append({"empty": true})
			continue
		var slot := slot_v as Dictionary
		var equip_id := int(slot.get("id", -1))
		if equip_id < 0:
			rows.append({"empty": true})
			continue
		var cfg := FightObj._lookup_cfg(equip_cfg, equip_id)
		if cfg.is_empty():
			push_error("BattleInitData: equips 含法宝 %d 但 equip_cfg 无配置" % equip_id)
			rows.append({"empty": true})
			continue
		var row := {
			"equip_id": equip_id,
			"name": str(cfg.get("name", str(equip_id))),
			"item_id": equip_id,
			"cd_remaining": float(slot.get("cd", 0.0)),
			"cd_total": float(slot.get("cd_total", cfg.get("cd_total", cfg.get("cd", 0.0)))),
		}
		var effects_v: Variant = slot.get("effects", cfg.get("effects", []))
		if effects_v is Array and not (effects_v as Array).is_empty():
			row["effects"] = (effects_v as Array).duplicate(true)
		var icon := _resolve_icon_texture(cfg)
		if icon != null:
			row["icon"] = icon
		row["back_color"] = _quality_back_color(int(cfg.get("quality", 1)))
		rows.append(row)
	return rows


static func _append_combatant_errors(errors: PackedStringArray, side: String, row: Dictionary) -> void:
	for key in COMBATANT_KEYS:
		if not row.has(key):
			errors.append("%s 缺少字段 '%s'" % [side, key])
	var skills_v: Variant = row.get("skills")
	if skills_v != null and not skills_v is Array:
		errors.append("%s.skills 必须为 Array" % side)
	var items_v: Variant = row.get("items")
	if items_v != null and not items_v is Array:
		errors.append("%s.items 必须为 Array" % side)
	var equips_v: Variant = row.get("equips")
	if equips_v != null and not equips_v is Array:
		errors.append("%s.equips 必须为 Array" % side)
	var attrs_v: Variant = row.get("attrs")
	if attrs_v is Dictionary:
		for msg in FightAttr.validate_core(attrs_v as Dictionary):
			errors.append("%s.%s" % [side, msg])
	else:
		if row.has("attrs"):
			errors.append("%s.attrs 必须为 Dictionary" % side)


static func _resolve_spd_jitter_ratio(row: Dictionary) -> float:
	if bool(row.get("disable_spd_jitter", false)):
		return 0.0
	var custom: Variant = row.get("spd_jitter_ratio")
	if custom is int or custom is float:
		return maxf(0.0, float(custom))
	return DEFAULT_SPD_JITTER_RATIO


static func _apply_spd_jitter(fight_dict: Dictionary, ratio: float) -> void:
	var attrs_v: Variant = fight_dict.get("attrs")
	if attrs_v is Dictionary:
		FightAttr.apply_spd_jitter(attrs_v as Dictionary, ratio)


static func _combatant_to_fight_dict(row: Dictionary) -> Dictionary:
	var out := {
		"hp": float(row["hp"]),
		"mp": float(row["mp"]),
		"attrs": (row["attrs"] as Dictionary).duplicate(true),
		"skills": FightObj._normalize_slot_array(row.get("skills")),
	}
	if row.has("items"):
		out["items"] = FightObj._normalize_slot_array(row.get("items"))
	if row.has("equips"):
		out["equips"] = FightObj._normalize_slot_array(row.get("equips"))
	if row.has("next_action_time"):
		out["next_action_time"] = float(row["next_action_time"])
	return out


static func _combatant_ui_row(unit: FightObj, row: Dictionary) -> Dictionary:
	var ui := {
		"name": str(row.get("name", "")),
		"hp": unit.hp,
		"hp_max": unit.get_hp_max(),
		"mp": unit.mp,
		"mp_max": unit.get_mp_max(),
	}
	var avatar_tex := _resolve_avatar_texture(row)
	if avatar_tex != null:
		ui["avatar"] = avatar_tex
	if row.get("sprite") is Texture2D:
		ui["sprite"] = row["sprite"]
	return ui


static func _interval_cap(unit: FightObj) -> float:
	return CombatBalance.interval_cap_for(unit)


## 编辑器直开战斗场景 / 测试进战用 stub；技能来自 [code]data/skill.json[/code]，道具来自 [code]data/item.json[/code]（[code]items_FightTestDan[/code] / [code]fight_id=9001[/code]）。
static func sample_for_editor() -> Dictionary:
	var out := {
		"player": {
			"name": "清风剑仙",
			"icon": "jueshe/sprite_002.png",
			"hp": 60.0,
			"mp": 30.0,
			"attrs": FightAttr.from_stat_block({
				FightAttr.CRIT: 10.0,
				FightAttr.CRIT_DAMAGE: 150.0,
			}),
			"skills": [
				{"id": 1, "cd": 0.0},
				{"id": -1, "cd": 0.0},
				{"id": 2, "cd": 0.0},
				{"id": 3, "cd": 0.0},
				{"id": 0, "cd": 0.0},
			],
			"equips": [
				{
					"id": 5001,
					"cd": 0.0,
					"effects": [
						{"type": "damage", "value": 10.0, "target": "enemy"},
						{"type": "restore_mp", "value": 0.0, "target": "self"},
					],
				},
				{"id": -1, "cd": 0.0},
			],
			"items": [
				{"id": 9001, "count": 5, "cd": 0.0},
				{"id": 9001, "count": 3, "cd": 0.0},
				],
		},
		"enemy": {
			"name": "赤焰妖狼",
			"icon": "jueshe/sprite_003.png",
			"hp": 100.0,
			"mp": 50.0,
			"ai": {
				"version": 2,
				"phases": [
					{
						"id": "normal",
						"enter_when": {"self_hp_ratio_lte": 1.0},
						"policy": "rule_list",
						"rules": [
							{
								"id": "shield",
								"when": {"self_hp_ratio_lte": 0.5},
								"action": {"type": "skill", "skill_id": 2},
							},
							{
								"id": "poison",
								"when": {"skill_ready": 3},
								"action": {"type": "skill", "skill_id": 3},
							},
							{"action": {"type": "basic"}},
						],
					},
					{
						"id": "enrage",
						"enter_when": {"self_hp_ratio_lte": 0.3},
						"once": true,
						"policy": "priority",
						"skill_priority": [1, 3],
					},
				],
			},
			"attrs": FightAttr.from_stat_block({
				FightAttr.MP_MAX: 50.0,
				FightAttr.ATK: 80.0,
				FightAttr.CRIT: 5.0,
				FightAttr.CRIT_DAMAGE: 150.0,
			}),
			"skills": [
				{"id": 3, "cd": 0.0},
				{"id": 1, "cd": 0.0},
				{"id": 2, "cd": 0.0},
				{"id": -1, "cd": 0.0},
				{"id": 0, "cd": 0.0},
			],
			"equips": [
				{"id": -1, "cd": 0.0},
				{"id": -1, "cd": 0.0},
			],
			"items": [
				{"id": -1, "cd": 0.0},
				{"id": -1, "cd": 0.0},
				],
		},
	}
	return merge_skill_cfg_from_tables(out)


static func _get_config_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")


static func _build_skill_cfg_fallback(partial: Dictionary) -> Dictionary:
	var bundle: Dictionary = JsonLoader.load_skills_bundle()
	var out: Dictionary = {}
	var skills_v: Variant = bundle.get("skills", [])
	if skills_v is Array:
		for sv in skills_v as Array:
			if not sv is SkillDef:
				continue
			var row := (sv as SkillDef).to_runtime_dict()
			var sid := int(row.get("id", -1))
			if sid < 0:
				continue
			out[sid] = row
			out[str(sid)] = row
	if partial.is_empty():
		return out
	for k in partial.keys():
		var key_str := str(k)
		if key_str == "basic_attack":
			var ba_v: Variant = partial[k]
			if ba_v is Dictionary:
				var merged := out.get(0, out.get("0", {})) as Dictionary
				if not merged is Dictionary:
					merged = {}
				for bk in (ba_v as Dictionary).keys():
					merged[bk] = (ba_v as Dictionary)[bk]
				out[0] = merged
				out["0"] = merged
			continue
		var ev: Variant = partial[k]
		if not ev is Dictionary:
			continue
		var entry := (ev as Dictionary).duplicate(true)
		if key_str.is_valid_int():
			var iid := int(key_str)
			out[iid] = entry
			out[str(iid)] = entry
		else:
			out[key_str] = entry
	return out


static func _build_item_cfg_fallback(partial: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for it in JsonLoader.load_items():
		if it == null or not it is ItemDef:
			continue
		var def := it as ItemDef
		if not def.has_fight_config():
			continue
		var row := def.to_fight_runtime_dict()
		var fid := int(row.get("id", 0))
		if fid <= 0:
			continue
		out[fid] = row
		out[str(fid)] = row
	if partial.is_empty():
		return out
	for k in partial.keys():
		var key_str := str(k)
		var ev: Variant = partial[k]
		if not ev is Dictionary:
			continue
		var entry := (ev as Dictionary).duplicate(true)
		if key_str.is_valid_int():
			var iid := int(key_str)
			out[iid] = entry
			out[str(iid)] = entry
		else:
			out[key_str] = entry
	return out


static func _build_equip_cfg_fallback(partial: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for ev in JsonLoader.load_equips_bundle().get("equips", []):
		if ev == null or not ev is EquipDef:
			continue
		var row := (ev as EquipDef).to_runtime_dict()
		var eid := int(row.get("id", 0))
		if eid <= 0:
			continue
		out[eid] = row
		out[str(eid)] = row
	if partial.is_empty():
		return out
	for k in partial.keys():
		var key_str := str(k)
		var ev: Variant = partial[k]
		if not ev is Dictionary:
			continue
		var entry := (ev as Dictionary).duplicate(true)
		if key_str.is_valid_int():
			var iid := int(key_str)
			out[iid] = entry
			out[str(iid)] = entry
		else:
			out[key_str] = entry
	return out


static func _resolve_icon_texture(cfg: Dictionary) -> Texture2D:
	var icon_v: Variant = cfg.get("icon")
	if icon_v is Texture2D:
		return icon_v
	var path := str(icon_v).strip_edges()
	if path == "":
		return null
	if not path.begins_with("res://"):
		path = "res://assets/art/%s" % path
	if ResourceLoader.exists(path):
		var res: Variant = load(path)
		if res is Texture2D:
			return res
	push_error("BattleInitData: 无法加载技能/物品图标 '%s'" % path)
	return null


static func _resolve_avatar_texture(row: Dictionary) -> Texture2D:
	var avatar_v: Variant = row.get("avatar")
	if avatar_v is Texture2D:
		return avatar_v
	# 允许角色数据仅提供 icon 字段，战斗 UI 统一用作头像展示。
	var icon_tex := _resolve_icon_texture(row)
	if icon_tex != null:
		return icon_tex
	return null


static func _new_battle_session_id() -> String:
	return "battle_%d_%d" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]


static func _quality_back_color(quality: int) -> Color:
	return EnumQualityScript.get_color(maxi(1, quality))


static func _data_store() -> Node:
	return DataStore
