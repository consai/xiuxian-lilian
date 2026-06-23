class_name KnowledgeStudyService
extends RefCounted

const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")


static func study_policy(skill: Dictionary) -> Dictionary:
	var explicit_v: Variant = skill.get("independentStudy", {})
	if explicit_v is Dictionary:
		var explicit := explicit_v as Dictionary
		return {
			"enabled": bool(explicit.get("enabled", true)),
			"efficiency": maxf(0.0, float(explicit.get("efficiency", 1.0))),
		}
	return {"enabled": true, "efficiency": 1.0}


static func can_study(
	savedata: Dictionary,
	skill_id: String,
	player_major_realm: String
) -> Dictionary:
	var sid := skill_id.strip_edges()
	var skill := DaoTreeServiceScript.skill_by_id(sid)
	if skill.is_empty():
		return {"ok": false, "error": "未知知识"}
	var policy := study_policy(skill)
	if not bool(policy.get("enabled", true)):
		return {"ok": false, "error": "该知识无法自主学习"}
	if not DaoTreeServiceScript.meets_realm_gate(str(skill.get("realm", "")), player_major_realm):
		return {
			"ok": false,
			"error": "境界不足，需要%s" % DaoTreeServiceScript.realm_display_name(str(skill.get("realm", ""))),
		}
	if not DaoTreeServiceScript.prereqs_met(sid, KnowledgeServiceScript.effective_levels_map(savedata)):
		return {"ok": false, "error": "前置知识不足"}
	var effective := KnowledgeServiceScript.effective_level(savedata, sid)
	if int(floor(effective)) >= int(skill.get("maxLevel", 5)):
		return {"ok": false, "error": "该知识已圆满"}
	return {"ok": true, "policy": policy}


static func preview(
	savedata: Dictionary,
	skill_id: String,
	days: int,
	player_major_realm: String
) -> Dictionary:
	var gate := can_study(savedata, skill_id, player_major_realm)
	if not bool(gate.get("ok", false)):
		return gate
	var safe_days := maxi(1, days)
	var sid := skill_id.strip_edges()
	var skill := DaoTreeServiceScript.skill_by_id(sid)
	var policy := gate.get("policy", {}) as Dictionary
	var speed := DaoTreeServiceScript.training_speed(
		sid,
		savedata.get("foundations", {}) as Dictionary,
		savedata.get("aptitudes", {}) as Dictionary
	)
	var xp := maxf(1.0, speed * safe_days * float(policy.get("efficiency", 1.0)))
	var before := KnowledgeServiceScript.get_entry(savedata, sid)
	var projected := savedata.duplicate(true)
	var applied := KnowledgeServiceScript.apply_xp(projected, sid, xp, "self_study")
	var after := KnowledgeServiceScript.get_entry(projected, sid)
	var level := int(before.get("level", 0))
	var next_level := mini(level + 1, int(skill.get("maxLevel", 5)))
	var req := DaoTreeServiceScript.required_xp_for_level(sid, next_level) if next_level > level else 0.0
	var remaining_to_next := maxf(0.0, req - float(before.get("xp", 0.0)))
	var estimated_days_to_next := 0
	if speed > 0.0 and remaining_to_next > 0.0:
		estimated_days_to_next = int(ceil(remaining_to_next / maxf(0.01, speed * float(policy.get("efficiency", 1.0)))))
	return {
		"ok": true,
		"skill_id": sid,
		"skill_name": str(skill.get("name", sid)),
		"days": safe_days,
		"xp": float(applied.get("applied", 0.0)),
		"levels_gained": int(applied.get("levels_gained", 0)),
		"level_before": int(before.get("level", 0)),
		"level_after": int(after.get("level", 0)),
		"progress_before": KnowledgeServiceScript.level_progress_percent(savedata, sid),
		"progress_after": KnowledgeServiceScript.level_progress_percent(projected, sid),
		"training_speed": speed,
		"rank": int(skill.get("rank", 1)),
		"points_to_next": remaining_to_next,
		"estimated_days_to_next": estimated_days_to_next,
	}


static func apply_study(savedata: Dictionary, skill_id: String, days: int, player_major_realm: String) -> Dictionary:
	var result := preview(savedata, skill_id, days, player_major_realm)
	if not bool(result.get("ok", false)):
		return result
	var applied := KnowledgeServiceScript.apply_xp(savedata, skill_id, float(result.get("xp", 0.0)), "self_study")
	result["xp"] = float(applied.get("applied", 0.0))
	result["levels_gained"] = int(applied.get("levels_gained", 0))
	return result


static func studyable_skills(savedata: Dictionary, player_major_realm: String) -> Array:
	var rows: Array = []
	for skill_v in DaoTreeServiceScript.config().get("skills", []) as Array:
		if not skill_v is Dictionary:
			continue
		var skill := skill_v as Dictionary
		var sid := str(skill.get("id", ""))
		var gate := can_study(savedata, sid, player_major_realm)
		if not bool(gate.get("ok", false)):
			continue
		var entry := KnowledgeServiceScript.get_entry(savedata, sid)
		rows.append({
			"id": sid,
			"name": str(skill.get("name", sid)),
			"domain": str(skill.get("domain", "")),
			"realm": str(skill.get("realm", "")),
			"level": int(entry.get("level", 0)),
			"progress": KnowledgeServiceScript.level_progress_percent(savedata, sid),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a.get("domain", "")) == str(b.get("domain", "")):
			return str(a.get("name", "")) < str(b.get("name", ""))
		return str(a.get("domain", "")) < str(b.get("domain", ""))
	)
	return rows
