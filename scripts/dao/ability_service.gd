class_name AbilityService
extends RefCounted
## 技能配置索引与运行时转换：表格 id 对外，战斗技能栏用连续数字 id。

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")
const AbilityCatalogScript := preload(
	"res://scripts/features/ability/infrastructure/ability_catalog.gd"
)

const TIAOXI_ID := "ability.combat.tiaoxi"

static var _combat_index_loaded := false
static var _combat_id_by_ability: Dictionary = {}
static var _ability_id_by_combat_id: Dictionary = {}
static var _catalog := AbilityCatalogScript.new()


static func reload() -> void:
	_catalog.reload()
	_rebuild_combat_index()


static func _rebuild_combat_index() -> void:
	_combat_id_by_ability.clear()
	_ability_id_by_combat_id.clear()
	_ability_id_by_combat_id[0] = TIAOXI_ID
	_combat_id_by_ability[TIAOXI_ID] = 0
	var next_id := 1
	# 战斗层历史上使用数字 skill_id；这里集中生成映射，避免配置表泄漏数字 id。
	for ability_v in _catalog.all_definitions():
		if not ability_v is Dictionary:
			continue
		var ability := ability_v as Dictionary
		var aid := str(ability.get("id", ""))
		if aid == "":
			continue
		var atype := str(ability.get("type", ""))
		if uses_combat_skill_slot(atype):
			_combat_id_by_ability[aid] = next_id
			_ability_id_by_combat_id[next_id] = aid
			next_id += 1
	_combat_index_loaded = true


static func _ensure_combat_index() -> void:
	if not _combat_index_loaded:
		_rebuild_combat_index()


static func table_keys() -> Array[String]:
	return _catalog.table_keys()


static func abilities_in_table(table_key: String) -> Array:
	return _catalog.definitions_in_table(table_key)


static func table_key_for(ability_id: String) -> String:
	return _catalog.table_key_for(ability_id)


static func zhandou_active_abilities() -> Array:
	return abilities_in_table(EnumSkill.LABEL_ZHANDOU_ACTIVE)


static func passive_abilities() -> Array:
	return abilities_in_table(EnumSkill.LABEL_PASSIVE)


## 需编入战斗技能栏的类型（主动施放或手动开关的持续技）。
static func uses_combat_skill_slot(ability_type: String) -> bool:
	return ability_type in ["combat_active", "combat_upkeep"]


## 学会后常驻生效、不占技能栏的类型。
static func is_always_active_passive(ability_type: String) -> bool:
	return ability_type == "combat_passive"


static func all_abilities() -> Array:
	return _catalog.all_definitions()


static func by_id(ability_id: String) -> Dictionary:
	if ability_id == TIAOXI_ID:
		return _tiaoxi_row()
	return _catalog.by_id(ability_id)


static func combat_id_for(ability_id: String) -> int:
	_ensure_combat_index()
	if ability_id == "" or ability_id == "-1":
		return -1
	return int(_combat_id_by_ability.get(ability_id.strip_edges(), -1))


static func ability_id_for_combat_id(combat_id: int) -> String:
	_ensure_combat_index()
	if combat_id == 0:
		return TIAOXI_ID
	return str(_ability_id_by_combat_id.get(combat_id, ""))


static func ability_tier(ability: Dictionary) -> int:
	return EnumItemTier.clamp_tier(int(ability.get("tier", EnumItemTier.Type.lianqi)))


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
		player_major_realm = str(savedata.get("major_realm", "lianqi"))
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
		# 未配置 VFX 时按标签给保守默认值，保证战斗按钮总能播放表现。
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
	# effects 在进入战斗前解析成统一目标结构，战斗域不再理解表格字段别名。
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
	_ensure_combat_index()
	var skills: Dictionary = {}
	skills["0"] = _tiaoxi_runtime()
	for combat_id in _ability_id_by_combat_id.keys():
		if int(combat_id) <= 0:
			continue
		var aid := str(_ability_id_by_combat_id[combat_id])
		skills[str(combat_id)] = to_runtime_dict(aid, savedata)
	return {"battle_time_limit": 200.0, "skills": skills}


static func _tiaoxi_row() -> Dictionary:
	return {
		"id": TIAOXI_ID,
		"name": "调息",
		"type": "combat_active",
		"realm": "lianqi",
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
