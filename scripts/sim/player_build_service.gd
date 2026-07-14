class_name PlayerBuildService
extends RefCounted

const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
const InventoryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_application.gd"
)
const TagServiceScript := preload("res://scripts/sim/tag_service.gd")


static func build_snapshot(savedata: Dictionary, runtime: Dictionary = {}) -> Dictionary:
	var abilities := _equipped_abilities(savedata)
	var methods := _equipped_methods(savedata)
	var treasures := _equipped_treasures(savedata)
	var tag_stats := TagServiceScript.collect_tag_stats(abilities)
	tag_stats = TagServiceScript.merge_tag_stats(tag_stats, TagServiceScript.collect_tag_stats(methods))
	tag_stats = TagServiceScript.merge_tag_stats(tag_stats, TagServiceScript.collect_tag_stats(treasures))
	return {
		"realm": {
			"index": int(savedata.get("realm_index", 0)),
			"name": str(savedata.get("realm_name", "")),
		},
		"spirit_roots": savedata.get("aptitudes", {}).duplicate(true) if savedata.get("aptitudes", {}) is Dictionary else {},
		"attrs": (savedata.get("attrs", {}) as Dictionary).duplicate(true),
		"hp": float(runtime.get("hp", savedata.get("hp", 100.0))),
		"mp": float(runtime.get("mp", savedata.get("mp", 100.0))),
		"abilities": abilities,
		"methods": methods,
		"treasures": treasures,
		"tag_stats": tag_stats,
	}


static func build_battle_snapshot(savedata: Dictionary, runtime: Dictionary = {}) -> Dictionary:
	var build := build_snapshot(savedata, runtime)
	var skills: Array = []
	for aid_v in savedata.get("equipped_abilities", []) as Array:
		var aid := str(aid_v)
		var combat_id := AbilityServiceScript.combat_id_for(aid) if aid != "" else -1
		skills.append({"id": combat_id, "cd": 0.0})
	while skills.size() < 5:
		skills.append({"id": -1, "cd": 0.0})
	if not _skills_include_id(skills, 0):
		for i in skills.size():
			if int((skills[i] as Dictionary).get("id", -1)) < 0:
				# 首个空槽填入内置调息（combat id 0）
				skills[i] = {"id": 0, "cd": 0.0}
				break
	var equips: Array = []
	for eid_v in savedata.get("equip_slots", []) as Array:
		var eid := int(eid_v)
		var equip_row := {"id": eid, "cd": 0.0}
		if eid > 0:
			var cfg := _equip_by_id(eid)
			equip_row["effects"] = (cfg.get("effects", []) as Array).duplicate(true)
			equip_row["cd_total"] = float(cfg.get("cd_total", cfg.get("cd", 0.0)))
		equips.append(equip_row)
	return {
		"name": str(savedata.get("player_name", "")),
		"icon": str(savedata.get("player_icon", "")),
		"hp": float(build.get("hp", 100.0)),
		"mp": float(build.get("mp", 100.0)),
		"attrs": build.get("attrs", {}),
		"skills": skills,
		"equips": equips,
		"items": InventoryApplicationScript.build_battle_item_slots(
			runtime.get("inventory", savedata.get("inventory", {})) as Dictionary,
			runtime.get("item_slots", savedata.get("item_slots", [])) as Array
		),
		"build": build,
		"tag_stats": build.get("tag_stats", {}),
		"passive_ids": _battle_passive_ids(savedata),
	}


static func _battle_passive_ids(savedata: Dictionary) -> Array:
	var out: Array = []
	for aid_v in savedata.get("unlocked_abilities", []) as Array:
		var aid: String = str(aid_v).strip_edges()
		if aid == "":
			continue
		var row: Dictionary = AbilityServiceScript.by_id(aid)
		if row.is_empty():
			continue
		if AbilityServiceScript.is_always_active_passive(str(row.get("type", ""))):
			out.append(aid)
	return out


static func _equipped_abilities(savedata: Dictionary) -> Array:
	var out: Array = []
	for aid_v in savedata.get("equipped_abilities", []) as Array:
		var aid := str(aid_v).strip_edges()
		if aid == "":
			continue
		var row := AbilityServiceScript.by_id(aid)
		if not row.is_empty():
			out.append(row)
	return out


static func _equipped_methods(savedata: Dictionary) -> Array:
	var out: Array = []
	var slots := savedata.get("cultivation_method_slots", {}) as Dictionary
	for key in ["main", "support_1", "support_2", "support_3"]:
		var row := XiulianMethodServiceScript.by_id(str(slots.get(key, "")))
		if not row.is_empty():
			out.append(row)
	return out


static func _equipped_treasures(savedata: Dictionary) -> Array:
	var out: Array = []
	for eid_v in savedata.get("equip_slots", []) as Array:
		var row := _equip_by_id(int(eid_v))
		if not row.is_empty():
			out.append(row)
	return out


static func _skills_include_id(skills: Array, skill_id: int) -> bool:
	for slot_v in skills:
		if slot_v is Dictionary and int((slot_v as Dictionary).get("id", -1)) == skill_id:
			return true
	return false


static func _equip_by_id(equip_id: int) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("equip_by_id"):
		return cm.call("equip_by_id", equip_id) as Dictionary
	return {}


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
