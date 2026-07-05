class_name AbilityService
extends RefCounted

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")

const PATH := "res://data/exportjson/jineng.json"
const TIAOXI_ID := "ability.combat.tiaoxi"

static var _bundle: Dictionary = {}
static var _abilities_by_id: Dictionary = {}
static var _abilities_by_table: Dictionary = {}
static var _table_by_ability_id: Dictionary = {}
static var _combat_id_by_ability: Dictionary = {}
static var _ability_by_combat_id: Dictionary = {}


static func reload() -> void:
	_bundle = JsonLoader.load_abilities_bundle()
	_abilities_by_id.clear()
	_abilities_by_table.clear()
	_table_by_ability_id.clear()
	_combat_id_by_ability.clear()
	_ability_by_combat_id.clear()
	_ability_by_combat_id[0] = _tiaoxi_row()
	_combat_id_by_ability[TIAOXI_ID] = 0
	for table_key in EnumAbilityTable.LOAD_ORDER:
		_abilities_by_table[table_key] = {}
	var tables_v: Variant = _bundle.get("tables", {})
	if tables_v is Dictionary and not (tables_v as Dictionary).is_empty():
		for table_key_v in (tables_v as Dictionary).keys():
			var table_key := str(table_key_v)
			if not _abilities_by_table.has(table_key):
				_abilities_by_table[table_key] = {}
			_index_table_rows(table_key, (tables_v as Dictionary).get(table_key_v, []) as Array)
	else:
		_index_table_rows_from_merged(_bundle.get("abilities", []) as Array)
	var next_id := 1
	for ability_v in _bundle.get("abilities", []) as Array:
		if not ability_v is Dictionary:
			continue
		var ability := ability_v as Dictionary
		var aid := str(ability.get("id", ""))
		if aid == "":
			continue
		var atype := str(ability.get("type", ""))
		if uses_combat_skill_slot(atype):
			_combat_id_by_ability[aid] = next_id
			_ability_by_combat_id[next_id] = ability
			next_id += 1


static func _index_table_rows(table_key: String, rows: Array) -> void:
	for ability_v in rows:
		if not ability_v is Dictionary:
			continue
		var ability := ability_v as Dictionary
		var aid := str(ability.get("id", ""))
		if aid == "":
			continue
		_abilities_by_id[aid] = ability
		(_abilities_by_table[table_key] as Dictionary)[aid] = ability
		_table_by_ability_id[aid] = table_key


static func _index_table_rows_from_merged(rows: Array) -> void:
	for ability_v in rows:
		if not ability_v is Dictionary:
			continue
		var ability := ability_v as Dictionary
		var aid := str(ability.get("id", ""))
		if aid == "":
			continue
		var table_key := _infer_table_key(str(ability.get("type", "")))
		if table_key == "":
			continue
		if not _abilities_by_table.has(table_key):
			_abilities_by_table[table_key] = {}
		_abilities_by_id[aid] = ability
		(_abilities_by_table[table_key] as Dictionary)[aid] = ability
		_table_by_ability_id[aid] = table_key


static func _infer_table_key(ability_type: String) -> String:
	match ability_type:
		"combat_active", "combat_upkeep":
			return EnumAbilityTable.LABEL_ZHANDOU_ACTIVE
		"combat_passive":
			return EnumAbilityTable.LABEL_ZHANDOU_PASSIVE
		"general_passive":
			return EnumAbilityTable.LABEL_TONGYONG_PASSIVE
		_:
			return ""


static func table_keys() -> Array[String]:
	bundle()
	var out: Array[String] = []
	for table_key in EnumAbilityTable.LOAD_ORDER:
		if (_abilities_by_table.get(table_key, {}) as Dictionary).size() > 0:
			out.append(table_key)
	for table_key in _abilities_by_table.keys():
		var key := str(table_key)
		if key not in out and (_abilities_by_table.get(key, {}) as Dictionary).size() > 0:
			out.append(key)
	return out


static func abilities_in_table(table_key: String) -> Array:
	bundle()
	var out: Array = []
	var table_map: Variant = _abilities_by_table.get(table_key.strip_edges(), {})
	if not table_map is Dictionary:
		return out
	for ability_v in (table_map as Dictionary).values():
		if ability_v is Dictionary:
			out.append((ability_v as Dictionary).duplicate(true))
	return out


static func table_key_for(ability_id: String) -> String:
	bundle()
	return str(_table_by_ability_id.get(ability_id.strip_edges(), ""))


static func zhandou_active_abilities() -> Array:
	return abilities_in_table(EnumAbilityTable.LABEL_ZHANDOU_ACTIVE)


static func zhandou_passive_abilities() -> Array:
	return abilities_in_table(EnumAbilityTable.LABEL_ZHANDOU_PASSIVE)


static func tongyong_passive_abilities() -> Array:
	return abilities_in_table(EnumAbilityTable.LABEL_TONGYONG_PASSIVE)


## 需编入战斗技能栏的类型（主动施放或手动开关的持续技）。
static func uses_combat_skill_slot(ability_type: String) -> bool:
	return ability_type in ["combat_active", "combat_upkeep"]


## 学会后常驻生效、不占技能栏的类型。
static func is_always_active_passive(ability_type: String) -> bool:
	return ability_type in ["combat_passive", "general_passive"]


static func bundle() -> Dictionary:
	if _bundle.is_empty():
		reload()
	return _bundle


static func all_abilities() -> Array:
	bundle()
	var out: Array = []
	for key in _abilities_by_id.keys():
		out.append(by_id(str(key)))
	return out


static func by_id(ability_id: String) -> Dictionary:
	bundle()
	var row: Variant = _abilities_by_id.get(ability_id.strip_edges())
	if row is Dictionary:
		return (row as Dictionary).duplicate(true)
	if ability_id == TIAOXI_ID:
		return _tiaoxi_row()
	return {}


static func combat_id_for(ability_id: String) -> int:
	bundle()
	if ability_id == "" or ability_id == "-1":
		return -1
	return int(_combat_id_by_ability.get(ability_id.strip_edges(), -1))


static func ability_id_for_combat_id(combat_id: int) -> String:
	bundle()
	if combat_id == 0:
		return TIAOXI_ID
	var row: Variant = _ability_by_combat_id.get(combat_id)
	if row is Dictionary:
		return str((row as Dictionary).get("id", ""))
	return ""


static func ability_tier(ability: Dictionary) -> int:
	return EnumItemTier.clamp_tier(int(ability.get("tier", EnumItemTier.Type.QI)))


## 技能配置仅用 tier；大境界 id 由阶位推导。
static func ability_realm_id(ability: Dictionary) -> String:
	return EnumItemTier.realm_id_for_tier(ability_tier(ability))


static func can_learn(ability_id: String, savedata: Dictionary, player_major_realm: String) -> bool:
	var ability := by_id(ability_id)
	if ability.is_empty():
		return false
	return unmet_learning_requirement_lines(ability, savedata, player_major_realm).is_empty()


static func learning_condition_unmet(
		ability_id: String,
		savedata: Dictionary,
		player_major_realm: String = ""
) -> bool:
	var ability := by_id(ability_id)
	if ability.is_empty():
		return false
	return not unmet_learning_requirement_lines(ability, savedata, player_major_realm).is_empty()


static func unmet_learning_requirement_lines(
		ability: Dictionary,
		savedata: Dictionary,
		player_major_realm: String = ""
) -> Array[String]:
	var lines: Array[String] = []
	if ability.is_empty():
		return lines
	var realm := ability_realm_id(ability)
	if player_major_realm == "":
		player_major_realm = str(savedata.get("major_realm", "qi"))
	if not DaoTreeServiceScript.meets_realm_gate(realm, player_major_realm):
		var current_realm := str(savedata.get("realm_name", "")).strip_edges()
		if current_realm == "":
			current_realm = DaoTreeServiceScript.realm_display_name(player_major_realm)
		lines.append(StringsZh.format_template(
			StringsZh.getp("item_info.learn_req_realm", "境界要求：{need}（当前：{current}）"),
			{
				"need": DaoTreeServiceScript.realm_display_name(realm),
				"current": current_realm,
			}
		))
	return lines


static func to_runtime_dict(ability_id: String, _savedata: Dictionary) -> Dictionary:
	var combat_id := combat_id_for(ability_id)
	if combat_id < 0 and ability_id != TIAOXI_ID:
		return {}
	if ability_id == TIAOXI_ID or combat_id == 0:
		return _tiaoxi_runtime()
	var ability := by_id(ability_id)
	if ability.is_empty():
		return {}
	var combat: Dictionary = ability.get("combat", {}) as Dictionary
	var costs := _runtime_costs(combat)
	var mp_cost := _total_runtime_cost(costs)
	var tags: Array = (ability.get("tags", []) as Array).duplicate(true)
	var vfx_type := str(ability.get("vfx_type", "")).strip_edges().to_lower()
	if vfx_type == "":
		vfx_type = "melee"
		if tags.has("spell") or tags.has("ranged"):
			vfx_type = "ranged"
		if tags.has("mobility") or tags.has("shield"):
			vfx_type = "buff"
	var configured_vfx := ability.has("vfx") or ability.has("vfx_file") or ability.has("vfx_preset")
	var vfx: Variant = ability.get("vfx", "")
	if ability.has("vfx_file"):
		vfx = str(ability.get("vfx_file", "")).strip_edges()
	elif ability.has("vfx_preset"):
		vfx = str(ability.get("vfx_preset", "")).strip_edges()
	if not configured_vfx:
		vfx = "status_cast"
		if vfx_type == "ranged":
			vfx = "ranged_default"
		elif vfx_type == "melee":
			vfx = "melee_default"
	var icon_path := _runtime_icon_path(ability, combat_id)
	var combat_target := EnumZhandouTargetArg.normalize_pair(
		combat.get("target", EnumZhandouTarget.LABEL_ENEMY),
		combat.get("targetArg", combat.get("target_arg", ""))
	)
	var out := {
		"id": combat_id,
		"ability_id": ability_id,
		"ability_type": str(ability.get("type", "")),
		"activation": str(combat.get("activation", "cast")),
		"name": str(ability.get("name", "")),
		"desc": str(ability.get("description", "")),
		"costs": costs,
		"cost_text": _format_cost_text(costs),
		"mp_cost": mp_cost,
		"cd": float(combat.get("cooldown", 0.0)),
		"cd_total": float(combat.get("cooldown", 0.0)),
		"power": maxf(0.0, float(combat.get("powerScale", 1.0))) * 1000.0,
		"tier": maxi(1, int(ability.get("tier", 1))),
		"quality": clampi(int(ability.get("quality", 1)), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME),
		"vfx_type": vfx_type,
		"vfx": vfx,
		"tags": tags,
		"target": str(combat_target.get("target", EnumZhandouTarget.LABEL_ENEMY)),
		"effects": EffectResolverScript.resolve_combat_effects(
			ability.get("effects", []) as Array,
			str(combat_target.get("target", EnumZhandouTarget.LABEL_ENEMY)),
			str(combat_target.get("target_arg", ""))
		),
	}
	var combat_target_arg := str(combat_target.get("target_arg", ""))
	if combat_target_arg != "":
		out["target_arg"] = combat_target_arg
	if icon_path != "":
		out["icon"] = icon_path
	return out


static func build_skill_cfg(savedata: Dictionary) -> Dictionary:
	bundle()
	var skills: Dictionary = {}
	skills["0"] = _tiaoxi_runtime()
	for combat_id in _ability_by_combat_id.keys():
		if int(combat_id) <= 0:
			continue
		var ability := _ability_by_combat_id[combat_id] as Dictionary
		var aid := str(ability.get("id", ""))
		skills[str(combat_id)] = to_runtime_dict(aid, savedata)
	return {"battle_time_limit": 200.0, "skills": skills}


static func _tiaoxi_row() -> Dictionary:
	return {
		"id": TIAOXI_ID,
		"name": "调息",
		"type": "combat_active",
		"realm": "qi",
		"description": "盘膝调息，按法力恢复速度恢复灵力。",
		"tags": ["restore", "support"],
		"combat": {
			"target": EnumZhandouTarget.LABEL_SELF,
			"castTime": 0.0,
			"cooldown": 0.0,
			"costs": [],
		},
		"effects": [],
		"learningRequirements": {"knowledge": []},
	}


static func _tiaoxi_runtime() -> Dictionary:
	return {
		"id": 0,
		"ability_id": TIAOXI_ID,
		"name": "调息",
		"desc": "盘膝调息，按法力恢复速度恢复灵力。",
		"icon": "ui_new/skill_03.png",
		"costs": [],
		"cost_text": "",
		"mp_cost": 0.0,
		"cd": 0.0,
		"cd_total": 0.0,
		"power": 0.0,
		"tier": 1,
		"quality": 1,
		"vfx_type": "buff",
		"vfx": "status_cast",
		"tags": ["restore", "support"],
		"target": EnumZhandouTarget.LABEL_SELF,
		"effects": [],
		"is_tiaoxi": true,
	}


static func _runtime_icon_path(ability: Dictionary, combat_id: int) -> String:
	var direct := str(ability.get("icon", ability.get("icon_path", ""))).strip_edges()
	if direct != "":
		return direct
	if combat_id == 0:
		return "ui_new/skill_01.png"
	var tags: Array = ability.get("tags", []) as Array
	if tags.has("poison"):
		return "ui_new/skill_02.png"
	if tags.has("shield"):
		return "ui_new/skill_06.png"
	if tags.has("fire"):
		return "ui_new/skill_05.png"
	if tags.has("spell") or tags.has("ranged"):
		return "ui_new/skill_05.png"
	if tags.has("mobility"):
		return "ui_new/skill_04.png"
	if tags.has("heal") or tags.has("restore"):
		return "ui_new/skill_03.png"
	if tags.has("attack") or tags.has("physical"):
		return "ui_new/skill_01.png"
	return "ui_new/skill_03.png"


static func _runtime_costs(combat: Dictionary) -> Array:
	var out: Array = []
	var costs_v: Variant = combat.get("costs", [])
	if not costs_v is Array:
		return out
	for cost_v in costs_v as Array:
		if not cost_v is Dictionary:
			continue
		var cost := cost_v as Dictionary
		var resource := str(cost.get("resource", "mana")).strip_edges().to_lower()
		var value := maxf(0.0, float(cost.get("value", 0.0)))
		if value <= 0.0:
			continue
		out.append({"resource": resource, "value": value})
	return out


static func _total_runtime_cost(costs: Array) -> float:
	var total := 0.0
	for cost_v in costs:
		if cost_v is Dictionary:
			total += float((cost_v as Dictionary).get("value", 0.0))
	return total


static func _format_cost_text(costs: Array) -> String:
	if costs.is_empty():
		return ""
	var labels: PackedStringArray = []
	for cost_v in costs:
		if not cost_v is Dictionary:
			continue
		var cost := cost_v as Dictionary
		labels.append("%s %s" % [
			_resource_label(str(cost.get("resource", "mana"))),
			_format_cost_value(float(cost.get("value", 0.0))),
		])
	return "、".join(labels)


static func _resource_label(resource: String) -> String:
	match resource.strip_edges().to_lower():
		"stamina":
			return "体力"
		"spirit":
			return "神魂"
		_:
			return "法力"


static func _format_cost_value(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
