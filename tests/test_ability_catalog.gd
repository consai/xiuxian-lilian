extends SceneTree

const Catalog := preload("res://scripts/features/ability/infrastructure/ability_catalog.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _failures: PackedStringArray = []
var _paths := {
	"active": "fixture://zhandou_active.json",
	"passive": "fixture://passive.json",
}


func _init() -> void:
	_test_production_tables()
	_test_deep_copy_and_order()
	_test_validation_contract()
	_test_atomic_reload_contract()
	_test_unreadable_path_error()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: ability catalog")
	quit(0)


func _test_production_tables() -> void:
	var catalog := Catalog.new()
	_check(catalog.collect_errors().is_empty(), "production ability roots validate")
	_check(catalog.table_keys() == ["zhandou_active", "passive"], "table order remains active then passive")
	_check(catalog.definitions_in_table("zhandou_active").size() == 17, "active count remains 17")
	_check(catalog.definitions_in_table("passive").size() == 22, "passive count remains 22")
	_check(catalog.all_definitions().size() == 39, "merged ability count remains 39")
	_check(str(catalog.by_id("skill_lq_001").get("name", "")) == "引火诀", "known active ability remains stable")
	_check(str(catalog.by_id("passive_0001").get("name", "")) == "铁骨", "known passive ability remains stable")
	_check(catalog.table_key_for("skill_lq_001") == "zhandou_active", "active table index remains stable")
	_check(catalog.table_key_for("passive_0001") == "passive", "passive table index remains stable")
	_check(catalog.by_id("missing_ability").is_empty(), "unknown ability is query-safe")


func _test_deep_copy_and_order() -> void:
	var catalog := Catalog.new()
	var ids: Array = []
	for row_v in catalog.all_definitions():
		ids.append(str((row_v as Dictionary).get("id", "")))
	_check(ids.front() == "skill_lq_001" and ids[16] == "skill_lq_2005" and ids[17] == "passive_0001", "definition order remains deterministic")
	var active := catalog.by_id("skill_lq_001")
	active["name"] = "mutated"
	(active["combat"] as Dictionary)["cooldown"] = 999.0
	(active["effects"] as Array).clear()
	var fresh := catalog.by_id("skill_lq_001")
	_check(str(fresh.get("name", "")) == "引火诀", "definition name is deep-copied")
	_check(float((fresh["combat"] as Dictionary).get("cooldown", -1.0)) == 1.0, "nested combat is deep-copied")
	_check(not (fresh["effects"] as Array).is_empty(), "nested effects are deep-copied")
	var table := catalog.definitions_in_table("passive")
	(table[0] as Dictionary)["name"] = "mutated"
	_check(str((catalog.definitions_in_table("passive")[0] as Dictionary).get("name", "")) == "铁骨", "table snapshot is deep-copied")


func _test_validation_contract() -> void:
	var roots := _production_roots()
	var errors := Catalog.validate_roots([], roots.passive, _paths)
	_expect_code(errors, "invalid_root", _paths.active, "zhandou_active", "root")
	errors = Catalog.validate_roots({"abilities": []}, roots.passive, _paths)
	_expect_code(errors, "legacy_wrapper", _paths.active, "zhandou_active", "root.abilities")
	var active := (roots.active as Dictionary).duplicate(true)
	active["skill_lq_001"] = "bad"
	errors = Catalog.validate_roots(active, roots.passive, _paths)
	_expect_code(errors, "invalid_row", _paths.active, "zhandou_active", "skill_lq_001")
	active = (roots.active as Dictionary).duplicate(true)
	var row := (active["skill_lq_001"] as Dictionary).duplicate(true)
	row["tier"] = "1"
	active["skill_lq_001"] = row
	errors = Catalog.validate_roots(active, roots.passive, _paths)
	_expect_code(errors, "invalid_integer", _paths.active, "zhandou_active", "skill_lq_001.tier")
	active = (roots.active as Dictionary).duplicate(true)
	row = (active["skill_lq_001"] as Dictionary).duplicate(true)
	row["effects"] = "damage"
	active["skill_lq_001"] = row
	errors = Catalog.validate_roots(active, roots.passive, _paths)
	_expect_code(errors, "invalid_effects", _paths.active, "zhandou_active", "skill_lq_001.effects")
	active = (roots.active as Dictionary).duplicate(true)
	active.erase("skill_lq_001")
	errors = Catalog.validate_roots(active, roots.passive, _paths)
	_expect_code(errors, "active_count", _paths.active, "zhandou_active", "root")
	var passive := (roots.passive as Dictionary).duplicate(true)
	var duplicate := (passive["passive_0001"] as Dictionary).duplicate(true)
	passive.erase("passive_0001")
	duplicate["id"] = "skill_lq_001"
	passive["skill_lq_001"] = duplicate
	errors = Catalog.validate_roots(roots.active, passive, _paths)
	_expect_code(errors, "duplicate_id", _paths.passive, "passive", "skill_lq_001")


func _test_atomic_reload_contract() -> void:
	var roots := _production_roots()
	var catalog := Catalog.new()
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots([], roots.passive, _paths), "first invalid reload is rejected")
	Engine.print_error_messages = true
	_check(catalog.all_definitions().is_empty(), "first failed reload exposes no definitions")
	_expect_code(catalog.collect_errors(), "invalid_root", _paths.active, "zhandou_active", "root")
	_check(catalog.reload_from_roots(roots.active, roots.passive, _paths), "valid roots commit")
	var before := catalog.all_definitions()
	var bad_active := (roots.active as Dictionary).duplicate(true)
	bad_active["skill_lq_001"] = "bad"
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_active, roots.passive, _paths), "invalid reload is rejected")
	Engine.print_error_messages = true
	_check(catalog.all_definitions() == before, "failed reload preserves the previous complete snapshot")
	_expect_code(catalog.collect_errors(), "invalid_row", _paths.active, "zhandou_active", "skill_lq_001")


func _test_unreadable_path_error() -> void:
	var missing := "res:/" + "/missing_ability_catalog_fixture.json"
	var catalog := Catalog.new({"active": missing})
	Engine.print_error_messages = false
	var rows := catalog.all_definitions()
	var errors := catalog.collect_errors()
	Engine.print_error_messages = true
	_check(rows.is_empty(), "unreadable first load exposes no definitions")
	_expect_code(errors, "unreadable_file", missing, "zhandou_active", "root")


func _production_roots() -> Dictionary:
	return {
		"active": JsonReaderScript.read_object(Catalog.ACTIVE_PATH),
		"passive": JsonReaderScript.read_object(Catalog.PASSIVE_PATH),
	}


func _expect_code(errors: PackedStringArray, code: String, path: String, table: String, field: String) -> void:
	var expected := "[ability_catalog:%s] file=%s table=%s field=%s" % [code, path, table, field]
	_check(expected in errors, "expected %s, got %s" % [expected, str(errors)])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
