class_name DidianService
extends RefCounted

const BattleConfigQueryApplicationScript := preload(
	"res://scripts/features/battle/application/battle_config_query_application.gd"
)
const LilianLocationCatalogScript := preload("res://scripts/lilian/lilian_location_catalog.gd")

static var _catalog := LilianLocationCatalogScript.new()


static func all_locations() -> Array:
	return _catalog.all_locations()


static func by_id(location_id: String) -> Dictionary:
	return _catalog.location_by_id(location_id)


static func all_location_ids() -> Array:
	return _catalog.all_location_ids()


static func has_location(location_id: String) -> bool:
	return not by_id(location_id).is_empty()


static func monsters_for_location(location_id: String) -> Array:
	var location := by_id(location_id)
	var out: Array = []
	for monster_id_v in location.get("monsters", []) as Array:
		var monster := BattleConfigQueryApplicationScript.monster_by_id(str(monster_id_v))
		if not monster.is_empty():
			out.append(monster)
	return out


static func enemy_for_location(location_id: String, monster_ref: String) -> Dictionary:
	var ref := monster_ref.strip_edges()
	if ref == "":
		return {}
	var location := by_id(location_id)
	var monster_ids := location.get("monsters", []) as Array
	if monster_ids.has(ref):
		return BattleConfigQueryApplicationScript.monster_by_id(ref)
	var direct := BattleConfigQueryApplicationScript.monster_by_id(ref)
	if not direct.is_empty() and monster_ids.has(str(direct.get("id", ref))):
		return direct
	for monster_id_v in monster_ids:
		var monster := BattleConfigQueryApplicationScript.monster_by_id(str(monster_id_v))
		if monster.is_empty():
			continue
		if str(monster.get("species", "")).strip_edges() == ref:
			return monster
		for tag_v in monster.get("tags", []) as Array:
			if str(tag_v).strip_edges() == ref:
				return monster
	return {}


static func drop_pool_for_location(location_id: String, pool_id: String) -> Dictionary:
	var normalized_pool_id := pool_id.strip_edges()
	if normalized_pool_id.begins_with("monster:"):
		var monster_ref := normalized_pool_id.substr("monster:".length()).strip_edges()
		var monster := enemy_for_location(location_id, monster_ref)
		var entries := BattleConfigQueryApplicationScript.monster_drop_entries(monster)
		return {"entries": entries} if not entries.is_empty() else {}
	var location := by_id(location_id)
	var pools_v: Variant = location.get("drop_pools", {})
	if not pools_v is Dictionary:
		return {}
	var pool_v: Variant = (pools_v as Dictionary).get(normalized_pool_id)
	if not pool_v is Dictionary:
		return {}
	return (pool_v as Dictionary).duplicate(true)
