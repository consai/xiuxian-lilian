class_name XiulianMethodService
extends RefCounted

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")
const CultivationMethodQueryApplicationScript := preload(
	"res://scripts/features/cultivation/application/cultivation_method_query_application.gd"
)

const SLOT_MAIN := "main"
const SLOT_SUPPORT := "support"
const SLOT_SUPPORT_3 := "support_3"
const SLOT_WEIGHTS := {
	"main": 1.0,
	"support_1": 0.4,
	"support_2": 0.4,
	"support_3": 0.4,
}
# 存档 method_mastery 为 0..1，运行时映射为 1..MASTERY_MAX_LEVEL（初学→圆满）
const MASTERY_MAX_LEVEL := 5
const MASTERY_VALUE_RATIOS := [0.0, 0.25, 0.5, 0.75, 1.0]

static func all_methods() -> Array:
	return CultivationMethodQueryApplicationScript.all_definitions()


static func by_id(method_id: String) -> Dictionary:
	return CultivationMethodQueryApplicationScript.definition_by_id(method_id)


static func family_by_id(family_id: String) -> Dictionary:
	return CultivationMethodQueryApplicationScript.family_by_id(family_id)


static func equipped_rows(slots: Dictionary) -> Array:
	var out: Array = []
	for key in ["main", "support_1", "support_2", "support_3"]:
		var row := by_id(str(slots.get(key, "")))
		if not row.is_empty():
			out.append(row)
	return out


static func resolved_knowledge(method_id: String) -> Array:
	return []


static func can_learn(method: Dictionary, savedata: Dictionary, player_major_realm: String = "") -> bool:
	if method.is_empty():
		return false
	return unmet_learning_requirement_lines(method, savedata, player_major_realm).is_empty()


static func learning_condition_unmet(
		method_id: String,
		savedata: Dictionary,
		player_major_realm: String = ""
) -> bool:
	var method := by_id(method_id)
	if method.is_empty():
		return false
	return not unmet_learning_requirement_lines(method, savedata, player_major_realm).is_empty()


static func unmet_learning_requirement_lines(
		method: Dictionary,
		savedata: Dictionary,
		player_major_realm: String = ""
) -> Array[String]:
	var lines: Array[String] = []
	if method.is_empty():
		return lines
	var realm := str(method.get("realm", "lianqi"))
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


static func can_equip(row: Dictionary, slot_key: String) -> bool:
	if row.is_empty():
		return false
	if slot_key == "main":
		return true
	return slot_key.begins_with("support_")


static func cultivation_speed(slots: Dictionary) -> float:
	var main := by_id(str(slots.get("main", "")))
	if main.is_empty():
		return 0.0
	var practice: Dictionary = main.get("practice", {}) as Dictionary
	return maxf(0.0, float(practice.get("efficiency", 1.0)))


static func active_cultivation_method_id(savedata: Dictionary) -> String:
	var method_id := str(savedata.get("current_cultivation_method_id", "")).strip_edges()
	if method_id != "":
		return method_id
	var slots := savedata.get("cultivation_method_slots", {}) as Dictionary
	return str(slots.get("main", "")).strip_edges()


static func cultivation_session_speed(method_id: String, savedata: Dictionary) -> float:
	var method := by_id(method_id)
	if method.is_empty():
		return 0.0
	var speed := 1.0
	var mastery := method_mastery_value_ratio(savedata, method_id)
	for effect_v in method.get("effects", []) as Array:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		if str(effect.get("effectId", "")) != "cultivation_speed":
			continue
		speed += float(effect.get("base", 0.0)) + float(effect.get("masteryGrowth", 0.0)) * mastery
	return clampf(speed, 0.5, 10.0)


static func base_cultivation_gain_breakdown(method_id: String) -> Dictionary:
	var method := by_id(method_id)
	if method.is_empty():
		return {"gain": 0}
	var major_id := str(method.get("realm", "")).strip_edges()
	if major_id == "":
		return {"gain": 0}
	var realm_base := RealmBalanceService.base_daily_cultivation_gain({
		"major_realm": major_id,
		"id": "%s_early" % major_id,
	})
	var family := family_by_id(str(method.get("familyId", "")))
	var quality := EnumQuality.clamp_quality(int(method.get("quality", family.get("quality", 1))))
	var coefficient := 1.0 + float(quality) * 0.2
	return {
		"realm_base": realm_base,
		"quality": quality,
		"coefficient": coefficient,
		"gain": maxi(0, int(round(float(realm_base) * coefficient))),
	}


static func base_cultivation_gain(method_id: String) -> int:
	return int(base_cultivation_gain_breakdown(method_id).get("gain", 0))


static func method_mastery(savedata: Dictionary, method_id: String) -> float:
	var root_v: Variant = savedata.get("method_mastery", {})
	if root_v is Dictionary:
		return clampf(float((root_v as Dictionary).get(method_id.strip_edges(), 0.0)), 0.0, 1.0)
	return 0.0


static func method_mastery_level(savedata: Dictionary, method_id: String) -> int:
	var mastery := method_mastery(savedata, method_id)
	if mastery >= 1.0:
		return MASTERY_MAX_LEVEL
	return clampi(int(floor(mastery * float(MASTERY_MAX_LEVEL))) + 1, 1, MASTERY_MAX_LEVEL)


static func method_mastery_value_ratio(savedata: Dictionary, method_id: String) -> float:
	var level := method_mastery_level(savedata, method_id)
	if level - 1 < MASTERY_VALUE_RATIOS.size():
		return clampf(float(MASTERY_VALUE_RATIOS[level - 1]), 0.0, 1.0)
	if MASTERY_MAX_LEVEL <= 1:
		return method_mastery(savedata, method_id)
	return float(level - 1) / float(MASTERY_MAX_LEVEL - 1)


static func add_method_mastery(savedata: Dictionary, method_id: String, amount: float) -> void:
	if not savedata.get("method_mastery") is Dictionary:
		savedata["method_mastery"] = {}
	var current := method_mastery(savedata, method_id)
	(savedata["method_mastery"] as Dictionary)[method_id.strip_edges()] = clampf(current + amount, 0.0, 1.0)


static func apply_cultivation_cycle(
		savedata: Dictionary,
		practice_xp: float,
		mastery_multiplier: float = 1.0
) -> Dictionary:
	var main_id := active_cultivation_method_id(savedata)
	var method := by_id(main_id)
	if method.is_empty() or practice_xp <= 0.0:
		return {"knowledge": [], "method_id": main_id, "mastery_applied": 0.0}
	var mastery_applied := 0.02 * maxf(0.0, mastery_multiplier)
	add_method_mastery(savedata, main_id, mastery_applied)
	return {
		"knowledge": [],
		"method_id": main_id,
		"mastery_applied": mastery_applied,
	}


static func build_modifiers(slots: Dictionary, savedata: Dictionary) -> Dictionary:
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	var groups: Dictionary = {}
	var sources: Array = []
	var unmapped: Array = []
	for slot_key in SLOT_WEIGHTS.keys():
		var method := by_id(str(slots.get(slot_key, "")))
		if method.is_empty():
			continue
		var method_id := str(method.get("id", ""))
		var slot_weight := float(SLOT_WEIGHTS[slot_key])
		var mastery := method_mastery_value_ratio(savedata, method_id)
		for effect_v in method.get("effects", []) as Array:
			if not effect_v is Dictionary:
				continue
			var effect := effect_v as Dictionary
			var effect_id := str(effect.get("effectId", ""))
			if not EffectResolverScript.has_method_mapping(effect_id):
				unmapped.append({"slot": slot_key, "method_id": method_id, "effect_id": effect_id})
				continue
			var base := float(effect.get("base", 0.0))
			var growth := float(effect.get("masteryGrowth", 0.0))
			var value := (base + growth * mastery) * slot_weight
			var operation := str(effect.get("operation", "add_flat"))
			var group_id := str(effect.get("stackGroup", effect_id))
			var policy := str(effect.get("stackPolicy", "highest"))
			var cap := float(effect.get("cap", INF))
			var weighted_effect := effect.duplicate(true)
			weighted_effect["base"] = value
			weighted_effect["masteryGrowth"] = 0.0
			var resolved := EffectResolverScript.resolve_method_modifiers(
				[weighted_effect], 0.0
			)
			var values := resolved.get("percent", {}) as Dictionary if operation == "add_percent" \
				else resolved.get("flat", {}) as Dictionary
			if effect_id == "combat_mp_restore_2s":
				values = {EnumPlayerAttr.COMBAT_MP_RESTORE_2S: value}
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
				"slot": slot_key,
				"weight": slot_weight,
				"method_id": method_id,
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


static func breakthrough_bonus(method_id: String) -> float:
	var row := by_id(method_id)
	for effect_v in row.get("effects", []) as Array:
		if effect_v is Dictionary and str((effect_v as Dictionary).get("effectId", "")) == "breakthrough_bonus":
			return float((effect_v as Dictionary).get("base", 0.0))
	return 0.0


static func _is_movement_method(row: Dictionary) -> bool:
	var family := family_by_id(str(row.get("familyId", "")))
	var role := str(family.get("role", ""))
	return role.find("遁法") >= 0 or role.find("身法") >= 0
