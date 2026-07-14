extends SceneTree

const MonsterCatalogScript := preload(
	"res://scripts/features/battle/infrastructure/monster_catalog.gd"
)
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	var raw := JsonReaderScript.read_object(MonsterCatalogScript.PATH)
	_check(raw.size() == 10, "protected monster export must contain 10 rows")
	_check(MonsterCatalogScript.validate_table(raw).is_empty(), "production monster export must pass raw schema")
	_check(MonsterCatalogScript.all_monsters_snapshot() == raw, "Catalog must preserve the raw exported table")
	var ids := MonsterCatalogScript.all_monster_ids()
	_check(ids.size() == 10, "Catalog must index all 10 monsters")
	_check(ids == _sorted_copy(ids), "monster ids must be deterministic")

	var first := MonsterCatalogScript.monster_by_id("qinglan_wolf")
	_check(str(first.get("name", "")) == "青牙狼", "known monster row changed")
	_check((first.get("dropitem", []) as Array)[0] == ["item", "items_LingCao", "1", "3", "5"], "raw five-cell drop row changed")
	(first["dropitem"] as Array)[0][1] = "mutated"
	(first["skills"] as Array).append(999)
	var fresh := MonsterCatalogScript.monster_by_id("qinglan_wolf")
	_check((fresh.get("dropitem", []) as Array)[0][1] == "items_LingCao", "query must deep-copy nested drop rows")
	_check(not (fresh.get("skills", []) as Array).has(999), "query must deep-copy skills")
	var snapshot := MonsterCatalogScript.all_monsters_snapshot()
	(snapshot["qinglan_wolf"] as Dictionary)["name"] = "mutated snapshot"
	_check(str(MonsterCatalogScript.monster_by_id("qinglan_wolf").get("name", "")) == "青牙狼", "snapshot must not mutate Catalog cache")

	var bad_id := raw.duplicate(true)
	(bad_id["qinglan_wolf"] as Dictionary)["id"] = "wrong"
	_expect_error_prefix(MonsterCatalogScript.validate_table(bad_id, "fixture://guaiwu.json"), "[monster_catalog:id_mismatch]")
	var bad_drop := raw.duplicate(true)
	(bad_drop["qinglan_wolf"] as Dictionary)["dropitem"] = [["item", "items_LingCao", "1", "3"]]
	_expect_error_prefix(MonsterCatalogScript.validate_table(bad_drop, "fixture://guaiwu.json"), "[monster_catalog:invalid_drop_row]")
	var bad_skills := raw.duplicate(true)
	(bad_skills["qinglan_wolf"] as Dictionary)["skills"] = ["1"]
	_expect_error_prefix(MonsterCatalogScript.validate_table(bad_skills, "fixture://guaiwu.json"), "[monster_catalog:invalid_skill_id]")
	var bad_stat := raw.duplicate(true)
	(bad_stat["qinglan_wolf"] as Dictionary)["hp_max"] = "75"
	_expect_error_prefix(MonsterCatalogScript.validate_table(bad_stat, "fixture://guaiwu.json"), "[monster_catalog:invalid_stat]")

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("test_monster_catalog: PASS")
	quit(0)


func _expect_error_prefix(errors: PackedStringArray, prefix: String) -> void:
	for message in errors:
		if str(message).begins_with(prefix):
			return
	_failures.append("expected error prefix %s, got %s" % [prefix, str(errors)])


func _sorted_copy(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
