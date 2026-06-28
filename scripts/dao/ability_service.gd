class_name AbilityService
extends RefCounted

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")

const PATH := "res://data/abilities.yaml"  # 索引；分表见 abilityTables
const BASIC_STRIKE_ID := "ability.combat.basic_strike"

static var _bundle: Dictionary = {}
static var _abilities_by_id: Dictionary = {}
static var _combat_id_by_ability: Dictionary = {}
static var _ability_by_combat_id: Dictionary = {}


static func reload() -> void:
	_bundle = JsonLoader.load_abilities_bundle()
	_abilities_by_id.clear()
	_combat_id_by_ability.clear()
	_ability_by_combat_id.clear()
	_ability_by_combat_id[0] = _basic_strike_row()
	_combat_id_by_ability[BASIC_STRIKE_ID] = 0
	var next_id := 1
	for ability_v in _bundle.get("abilities", []) as Array:
		if not ability_v is Dictionary:
			continue
		var ability := ability_v as Dictionary
		var aid := str(ability.get("id", ""))
		if aid == "":
			continue
		_abilities_by_id[aid] = ability
		var atype := str(ability.get("type", ""))
		if uses_combat_skill_slot(atype):
			_combat_id_by_ability[aid] = next_id
			_ability_by_combat_id[next_id] = ability
			next_id += 1


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
	if ability_id == BASIC_STRIKE_ID:
		return _basic_strike_row()
	return {}


static func combat_id_for(ability_id: String) -> int:
	bundle()
	if ability_id == "" or ability_id == "-1":
		return -1
	return int(_combat_id_by_ability.get(ability_id.strip_edges(), -1))


static func ability_id_for_combat_id(combat_id: int) -> String:
	bundle()
	if combat_id == 0:
		return BASIC_STRIKE_ID
	var row: Variant = _ability_by_combat_id.get(combat_id)
	if row is Dictionary:
		return str((row as Dictionary).get("id", ""))
	return ""


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
	var reqs: Dictionary = ability.get("learningRequirements", {}) as Dictionary
	var realm := str(reqs.get("realm", ability.get("realm", "qi")))
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
	for req_v in reqs.get("knowledge", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		var sid := str(req.get("skillId", req.get("id", ""))).strip_edges()
		if sid == "":
			continue
		var need := int(req.get("level", 1))
		var have := int(floorf(KnowledgeServiceScript.effective_level(savedata, sid)))
		if have >= need:
			continue
		var skill := DaoTreeServiceScript.skill_by_id(sid)
		var skill_name := str(skill.get("name", sid))
		lines.append(StringsZh.format_template(
			StringsZh.getp(
				"item_info.learn_req_knowledge",
				"知识要求：{name} ≥ {need} 级（当前 {current} 级）"
			),
			{"name": skill_name, "need": str(need), "current": str(have)}
		))
	return lines


static func to_runtime_dict(ability_id: String, _savedata: Dictionary) -> Dictionary:
	var combat_id := combat_id_for(ability_id)
	if combat_id < 0 and ability_id != BASIC_STRIKE_ID:
		return {}
	if ability_id == BASIC_STRIKE_ID or combat_id == 0:
		return _basic_strike_runtime()
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
		"effects": EffectResolverScript.resolve_combat_effects(ability.get("effects", []) as Array),
	}
	if icon_path != "":
		out["icon"] = icon_path
	return out


static func build_skill_cfg(savedata: Dictionary) -> Dictionary:
	bundle()
	var skills: Dictionary = {}
	skills["0"] = _basic_strike_runtime()
	for combat_id in _ability_by_combat_id.keys():
		if int(combat_id) <= 0:
			continue
		var ability := _ability_by_combat_id[combat_id] as Dictionary
		var aid := str(ability.get("id", ""))
		skills[str(combat_id)] = to_runtime_dict(aid, savedata)
	return {"battle_time_limit": 200.0, "skills": skills}


static func _basic_strike_row() -> Dictionary:
	return {
		"id": BASIC_STRIKE_ID,
		"name": "普攻",
		"type": "combat_active",
		"realm": "qi",
		"description": "基础近战攻击。",
		"tags": ["attack", "physical"],
		"combat": {"target": EnumZhandouTarget.LABEL_ENEMY, "castTime": 0.0, "cooldown": 0.0, "costs": []},
		"effects": [{
			"effectId": "damage_physical",
			"base": 12,
			"operation": "add_flat",
			"target": EnumZhandouTarget.LABEL_ENEMY,
		}],
		"learningRequirements": {"realm": "qi", "knowledge": []},
	}


static func _basic_strike_runtime() -> Dictionary:
	return {
		"id": 0,
		"ability_id": BASIC_STRIKE_ID,
		"name": "普攻",
		"desc": "基础近战攻击。",
		"icon": _runtime_icon_path(_basic_strike_row(), 0),
		"costs": [],
		"cost_text": "",
		"mp_cost": 0.0,
		"cd": 0.0,
		"cd_total": 0.0,
		"power": 1000.0,
		"tier": 1,
		"quality": 1,
		"vfx_type": "melee",
		"vfx": "melee_default",
		"tags": ["attack", "physical"],
		"effects": [{
			"type": EnumCombatEffectType.LABEL_DAMAGE,
			"damage_type": "physical",
			"value": 12.0,
			"target": EnumZhandouTarget.LABEL_ENEMY,
		}],
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
