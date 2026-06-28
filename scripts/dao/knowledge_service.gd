class_name KnowledgeService
extends RefCounted

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")

const KNOWLEDGE_KEY := "knowledge"
const METHOD_MASTERY_KEY := "method_mastery"


static func default_knowledge_entry() -> Dictionary:
	return {"level": 0, "xp": 0.0, "marked": false, "growth_source": ""}


static func get_entry(savedata: Dictionary, skill_id: String) -> Dictionary:
	var root_v: Variant = savedata.get(KNOWLEDGE_KEY, {})
	if not root_v is Dictionary:
		return default_knowledge_entry()
	var row_v: Variant = (root_v as Dictionary).get(skill_id.strip_edges())
	if row_v is Dictionary:
		var out := (row_v as Dictionary).duplicate(true)
		out["level"] = clampi(int(out.get("level", 0)), 0, 5)
		out["xp"] = maxf(0.0, float(out.get("xp", 0.0)))
		out["marked"] = bool(out.get("marked", false))
		out["growth_source"] = str(out.get("growth_source", ""))
		return out
	return default_knowledge_entry()


static func set_entry(savedata: Dictionary, skill_id: String, entry: Dictionary) -> void:
	if not savedata.get(KNOWLEDGE_KEY) is Dictionary:
		savedata[KNOWLEDGE_KEY] = {}
	(savedata[KNOWLEDGE_KEY] as Dictionary)[skill_id.strip_edges()] = entry.duplicate(true)


static func level_progress_percent(savedata: Dictionary, skill_id: String) -> float:
	var effective := effective_level(savedata, skill_id)
	var skill := DaoTreeServiceScript.skill_by_id(skill_id)
	var max_level := int(skill.get("maxLevel", 5))
	var level := int(floor(effective))
	if level >= max_level:
		return 100.0
	return clampf(effective - float(level), 0.0, 1.0) * 100.0


static func entry_before_gain(
	savedata: Dictionary,
	skill_id: String,
	xp_gained: float,
	levels_gained: int
) -> Dictionary:
	var sid := skill_id.strip_edges()
	var entry := get_entry(savedata, sid).duplicate(true)
	var level := int(entry.get("level", 0))
	var xp := float(entry.get("xp", 0.0))
	var remaining := maxf(0.0, xp_gained)
	while remaining > 0.0:
		if xp >= remaining:
			entry["xp"] = xp - remaining
			entry["level"] = level
			return entry
		remaining -= xp
		if levels_gained <= 0:
			entry["xp"] = 0.0
			entry["level"] = level
			return entry
		levels_gained -= 1
		level = maxi(0, level - 1)
		entry["level"] = level
		if level <= 0:
			entry["xp"] = 0.0
			return entry
		xp = DaoTreeServiceScript.required_xp_for_level(sid, level + 1)
	entry["level"] = level
	entry["xp"] = xp
	return entry


static func gain_progress_snapshot(
	savedata: Dictionary,
	skill_id: String,
	xp_gained: float,
	levels_gained: int
) -> Dictionary:
	var after_pct := level_progress_percent(savedata, skill_id)
	var before_savedata := savedata.duplicate(true)
	set_entry(
		before_savedata,
		skill_id,
		entry_before_gain(savedata, skill_id, xp_gained, levels_gained)
	)
	var before_pct := level_progress_percent(before_savedata, skill_id)
	return {
		"before": before_pct,
		"after": after_pct,
		"gain": maxf(0.0, after_pct - before_pct),
	}


static func effective_level(savedata: Dictionary, skill_id: String) -> float:
	var entry := get_entry(savedata, skill_id)
	var level := int(entry.get("level", 0))
	if level >= int(DaoTreeServiceScript.skill_by_id(skill_id).get("maxLevel", 5)):
		return float(level)
	var req := DaoTreeServiceScript.required_xp_for_level(skill_id, level + 1)
	if req <= 0.0:
		return float(level)
	return float(level) + float(entry.get("xp", 0.0)) / req


static func effective_levels_map(savedata: Dictionary) -> Dictionary:
	var out := {}
	for skill_v in DaoTreeServiceScript.config().get("skills", []) as Array:
		if not skill_v is Dictionary:
			continue
		var sid := str((skill_v as Dictionary).get("id", ""))
		if sid != "":
			out[sid] = effective_level(savedata, sid)
	return out


static func apply_xp(savedata: Dictionary, skill_id: String, amount: float, source_id: String = "") -> Dictionary:
	var sid := skill_id.strip_edges()
	if sid == "" or amount <= 0.0:
		return {"applied": 0.0, "levels_gained": 0}
	var skill := DaoTreeServiceScript.skill_by_id(sid)
	if skill.is_empty():
		return {"applied": 0.0, "levels_gained": 0}
	var max_level := int(skill.get("maxLevel", 5))
	var entry := get_entry(savedata, sid)
	var level := int(entry.get("level", 0))
	if level >= max_level:
		return {"applied": 0.0, "levels_gained": 0}
	var remaining := amount
	var levels_gained := 0
	while remaining > 0.0 and level < max_level:
		var req := DaoTreeServiceScript.required_xp_for_level(sid, level + 1)
		var have := float(entry.get("xp", 0.0))
		var need := maxf(0.0, req - have)
		if remaining < need:
			entry["xp"] = have + remaining
			remaining = 0.0
			break
		remaining -= need
		level += 1
		levels_gained += 1
		entry["level"] = level
		entry["xp"] = 0.0
	if source_id != "" and level < max_level:
		entry["growth_source"] = source_id
	elif level >= max_level:
		entry["growth_source"] = ""
	entry["level"] = level
	set_entry(savedata, sid, entry)
	return {"applied": amount - remaining, "levels_gained": levels_gained}


static func grant_level(savedata: Dictionary, skill_id: String, level: int, marked: bool = false) -> void:
	var sid := skill_id.strip_edges()
	var skill := DaoTreeServiceScript.skill_by_id(sid)
	if skill.is_empty():
		return
	var entry := get_entry(savedata, sid)
	entry["level"] = clampi(level, 0, int(skill.get("maxLevel", 5)))
	entry["xp"] = 0.0
	entry["marked"] = marked
	if entry["level"] >= int(skill.get("maxLevel", 5)):
		entry["growth_source"] = ""
	set_entry(savedata, sid, entry)


static func toggle_mark(savedata: Dictionary, skill_id: String) -> bool:
	var entry := get_entry(savedata, skill_id)
	entry["marked"] = not bool(entry.get("marked", false))
	set_entry(savedata, skill_id, entry)
	return bool(entry["marked"])


static func total_learned_points(savedata: Dictionary) -> int:
	var total := 0
	for skill_v in DaoTreeServiceScript.config().get("skills", []) as Array:
		if not skill_v is Dictionary:
			continue
		var sid := str((skill_v as Dictionary).get("id", ""))
		if sid == "":
			continue
		total += int(get_entry(savedata, sid).get("level", 0))
	return total


static func meets_knowledge_requirements(savedata: Dictionary, requirements: Array) -> bool:
	for req_v in requirements:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		var sid := str(req.get("skillId", req.get("id", "")))
		var need := int(req.get("level", 1))
		if effective_level(savedata, sid) < float(need):
			return false
	return true


static func list_growth_routes(savedata: Dictionary, skill_id: String) -> Array:
	var sid := skill_id.strip_edges()
	var out: Array = []
	for method_v in XiulianMethodServiceScript.all_methods():
		var method := method_v as Dictionary
		for row_v in XiulianMethodServiceScript.resolved_knowledge(str(method.get("id", ""))) as Array:
			if not row_v is Dictionary:
				continue
			var row := row_v as Dictionary
			if str(row.get("skillId", "")) != sid:
				continue
			if not bool(row.get("gainFromCultivation", true)):
				continue
			var status := "available"
			if not XiulianMethodServiceScript.can_learn(method, savedata):
				status = "locked"
			elif not (savedata.get("unlocked_methods", []) as Array).has(str(method.get("id", ""))):
				status = "missing"
			out.append({
				"type": "cultivation",
				"status": status,
				"method_id": str(method.get("id", "")),
				"name": str(method.get("name", "")),
			})
	return out


static func related_abilities(skill_id: String) -> Array:
	var out: Array = []
	for ability_v in AbilityServiceScript.all_abilities():
		var ability := ability_v as Dictionary
		for row_v in (ability.get("learningRequirements", {}) as Dictionary).get("knowledge", []) as Array:
			if not row_v is Dictionary:
				continue
			var sid := str((row_v as Dictionary).get("skillId", (row_v as Dictionary).get("id", "")))
			if sid == skill_id:
				out.append(ability.duplicate(true))
				break
	return out


static func related_methods(skill_id: String) -> Array:
	var out: Array = []
	for method_v in XiulianMethodServiceScript.all_methods():
		var method := method_v as Dictionary
		for row_v in XiulianMethodServiceScript.resolved_knowledge(str(method.get("id", ""))) as Array:
			if row_v is Dictionary and str((row_v as Dictionary).get("skillId", "")) == skill_id:
				out.append(method.duplicate(true))
				break
	return out


static func related_method_families(skill_id: String) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for method_v in related_methods(skill_id):
		var method := method_v as Dictionary
		var family_id := str(method.get("familyId", ""))
		if family_id == "":
			var solo_name := str(method.get("name", ""))
			if solo_name == "" or seen.has(solo_name):
				continue
			seen[solo_name] = true
			out.append({"name": solo_name})
			continue
		if seen.has(family_id):
			continue
		seen[family_id] = true
		var family := XiulianMethodServiceScript.family_by_id(family_id)
		out.append(family if not family.is_empty() else {"name": str(method.get("name", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return out
