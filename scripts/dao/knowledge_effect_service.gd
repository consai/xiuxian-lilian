class_name KnowledgeEffectService
extends RefCounted

const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")

static var _bundle: Dictionary = {}
static var _effects_by_skill: Dictionary = {}


static func reload() -> void:
	_bundle = JsonLoader.load_knowledge_effects_bundle()
	_reindex()


static func bundle() -> Dictionary:
	if _bundle.is_empty():
		reload()
	return _bundle


static func all_effects() -> Array:
	bundle()
	return (_bundle.get("effects", []) as Array).duplicate(true)


static func effects_for_skill(skill_id: String) -> Array:
	bundle()
	var rows_v: Variant = _effects_by_skill.get(skill_id.strip_edges(), [])
	return (rows_v as Array).duplicate(true) if rows_v is Array else []


static func build_modifiers(savedata: Dictionary) -> Dictionary:
	return resolve_modifiers(savedata, all_effects())


static func replace_effects_for_tests(rows: Array) -> void:
	_bundle = {
		"schemaVersion": 1,
		"configId": "knowledge_effects_test",
		"effects": rows.duplicate(true),
	}
	_reindex()


static func resolve_modifiers(savedata: Dictionary, rows: Array) -> Dictionary:
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	var groups: Dictionary = {}
	var sources: Array = []
	var unmapped: Array = []
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var skill_id := str(row.get("skillId", row.get("id", ""))).strip_edges()
		if skill_id == "":
			continue
		var required_level := int(row.get("level", 1))
		var current_level := int(floorf(KnowledgeServiceScript.effective_level(savedata, skill_id)))
		if current_level < required_level:
			continue
		var effect_id := str(row.get("effectId", "")).strip_edges()
		if not EffectResolverScript.has_method_mapping(effect_id):
			unmapped.append({
				"skill_id": skill_id,
				"level": required_level,
				"effect_id": effect_id,
			})
			continue
		var value := float(row.get("base", 0.0))
		var operation := str(row.get("operation", "add_flat"))
		var group_id := str(row.get("stackGroup", "knowledge:%s:%s" % [skill_id, effect_id]))
		var policy := str(row.get("stackPolicy", "add_capped"))
		var cap := float(row.get("cap", INF))
		var weighted_effect := row.duplicate(true)
		weighted_effect["base"] = value
		weighted_effect["masteryGrowth"] = 0.0
		var resolved := EffectResolverScript.resolve_method_modifiers([weighted_effect], 0.0, 1.0)
		var values := resolved.get("percent", {}) as Dictionary if operation == "add_percent" \
			else resolved.get("flat", {}) as Dictionary
		if effect_id == "combat_mp_restore_2s":
			values = {FightAttr.COMBAT_MP_RESTORE_2S: value}
			operation = "add_flat"
		for attr_key in values.keys():
			var aggregate_key := "%s|%s|%s" % [operation, group_id, str(attr_key)]
			var current: Dictionary = groups.get(aggregate_key, {
				"operation": operation,
				"attr": str(attr_key),
				"policy": policy,
				"cap": cap,
				"value": 0.0,
			})
			var effect_value := float(values[attr_key])
			if policy in ["highest", "unique"]:
				current["value"] = minf(float(current["cap"]), maxf(float(current["value"]), effect_value))
			else:
				current["value"] = minf(float(current["cap"]), float(current["value"]) + effect_value)
			groups[aggregate_key] = current
		sources.append({
			"skill_id": skill_id,
			"level": required_level,
			"effect_id": effect_id,
			"value": value,
		})
	for group_v in groups.values():
		var group := group_v as Dictionary
		var target := percent if str(group["operation"]) == "add_percent" else flat
		var attr := str(group["attr"])
		target[attr] = float(target.get(attr, 0.0)) + float(group["value"])
	return {
		"flat": flat,
		"percent": percent,
		"sources": sources,
		"unmapped": unmapped,
	}


static func collect_config_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for row_v in all_effects():
		if not row_v is Dictionary:
			errors.append("知识效果包含非对象项")
			continue
		var row := row_v as Dictionary
		var skill_id := str(row.get("skillId", row.get("id", ""))).strip_edges()
		if DaoTreeServiceScript.skill_by_id(skill_id).is_empty():
			errors.append("知识效果引用未知知识: %s" % skill_id)
			continue
		var level := int(row.get("level", 0))
		var max_level := int(DaoTreeServiceScript.skill_by_id(skill_id).get("maxLevel", 5))
		if level < 1 or level > max_level:
			errors.append("知识效果 %s level 必须在 1~%d 之间" % [skill_id, max_level])
		var effect_id := str(row.get("effectId", "")).strip_edges()
		if not EffectResolverScript.has_method_mapping(effect_id):
			errors.append("知识效果 %s 的效果 %s 未映射到属性运行时" % [skill_id, effect_id])
		var operation := str(row.get("operation", "add_flat"))
		if not operation in ["add_flat", "add_percent"]:
			errors.append("知识效果 %s 的 operation 无效: %s" % [skill_id, operation])
		if str(row.get("stackPolicy", "add_capped")) == "add_capped" and not row.has("cap"):
			errors.append("知识效果 %s 的效果 %s 使用 add_capped 但缺少 cap" % [skill_id, effect_id])
	return errors


static func _reindex() -> void:
	_effects_by_skill.clear()
	for row_v in _bundle.get("effects", []) as Array:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var skill_id := str(row.get("skillId", row.get("id", ""))).strip_edges()
		if skill_id == "":
			continue
		if not _effects_by_skill.has(skill_id):
			_effects_by_skill[skill_id] = []
		(_effects_by_skill[skill_id] as Array).append(row)
