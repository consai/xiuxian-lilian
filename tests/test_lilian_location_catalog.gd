extends SceneTree

const Catalog := preload("res://scripts/lilian/lilian_location_catalog.gd")
const DidianServiceScript := preload("res://scripts/lilian/didian_service.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	_test_production_tables()
	_test_runtime_normalization_and_copy()
	_test_didian_facade_behavior()
	_test_validation_contract()
	_test_atomic_failure()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: lilian location catalog")
	quit(0)


func _test_production_tables() -> void:
	var catalog := Catalog.new()
	var raw_schema := ExportTableReaderScript.read_settings(Catalog.SCHEMA_PATH)
	var raw_locations := ExportTableReaderScript.read_keyed_rows(Catalog.LOCATIONS_PATH)
	_check(catalog.collect_errors().is_empty(), "production location tables validate")
	_check(catalog.schema() == raw_schema, "schema remains in exported shape")
	_check(int(catalog.schema().get("schema_version", 0)) == 3, "location schema remains version 3")
	_check(catalog.all_location_ids().size() == 4, "production location count remains 4")
	_check(catalog.all_location_ids() == _sorted_copy(catalog.all_location_ids()), "location ids are sorted")
	_check(catalog.all_locations().size() == 4, "all_locations returns every production row")
	for key_v in raw_locations.keys():
		var key := str(key_v)
		_check(str((raw_locations[key_v] as Dictionary).get("key", "")) == key, "raw row key matches %s" % key)
		_check(str(catalog.location_by_id(key).get("id", "")) == key, "query injects runtime id %s" % key)
	_check(not raw_locations["wild_wolf_valley"].has("materials"), "reader omits null materials")
	_check(not catalog.location_by_id("wild_wolf_valley").has("materials"), "catalog preserves missing materials")


func _test_runtime_normalization_and_copy() -> void:
	var catalog := Catalog.new()
	var raw_locations := ExportTableReaderScript.read_keyed_rows(Catalog.LOCATIONS_PATH)
	var raw := raw_locations["qinglan_mountain"] as Dictionary
	var location := catalog.location_by_id("qinglan_mountain")
	var event_pool := location.get("event_pool", []) as Array
	_check(event_pool.size() == 13, "qinglan event pool remains 13 entries")
	for index in event_pool.size():
		var expected_id := str((raw.get("event_pool", []) as Array)[index])
		var entry := event_pool[index] as Dictionary
		_check(str(entry.get("id", "")) == expected_id, "event pool order remains stable at %d" % index)
		_check(int(entry.get("weight", 0)) == 1, "event pool weight remains 1 at %d" % index)
	_check(location.get("materials") == raw.get("materials"), "materials remain in decoded exported shape")
	_check(location.get("drop_pools") == raw.get("drop_pools"), "drop pools remain in decoded exported shape")
	_check(location.get("danger") == raw.get("danger"), "numeric cells remain unchanged")
	var pools := location["drop_pools"] as Dictionary
	var herbs := pools["herbs"] as Dictionary
	var first_entry := (herbs["entries"] as Array)[0] as Dictionary
	_check((first_entry["variants"] as Array).size() == 3, "nested reward variants remain intact")
	_check(
		(((first_entry["variants"] as Array)[1] as Dictionary)["conditions"] as Array).size() == 1,
		"nested reward conditions remain intact"
	)
	(location["materials"] as Array).clear()
	(pools["herbs"] as Dictionary)["entries"] = []
	(event_pool[0] as Dictionary)["id"] = "mutated"
	var fresh := catalog.location_by_id("qinglan_mountain")
	_check((fresh["materials"] as Array).size() == 3, "materials query is a deep copy")
	_check((((fresh["drop_pools"] as Dictionary)["herbs"] as Dictionary)["entries"] as Array).size() > 0, "drop pools query is a deep copy")
	_check(str(((fresh["event_pool"] as Array)[0] as Dictionary)["id"]) == "qinglan_mountain__travel", "event pool query is a deep copy")
	_check(catalog.location_by_id("missing_location").is_empty(), "unknown id is query-safe")


func _test_didian_facade_behavior() -> void:
	_check(DidianServiceScript.all_location_ids().size() == 4, "Didian facade exposes four locations")
	_check(DidianServiceScript.all_location_ids() == _sorted_copy(DidianServiceScript.all_location_ids()), "Didian ids are sorted")
	_check(str(DidianServiceScript.by_id("qinglan_mountain").get("name", "")) == "青岚山脉", "Didian lookup keeps location name")
	_check(DidianServiceScript.has_location("qinglan_mountain"), "Didian has_location recognizes known id")
	_check(not DidianServiceScript.has_location("missing_location"), "Didian has_location rejects unknown id")
	_check(DidianServiceScript.monsters_for_location("qinglan_mountain").size() == 3, "location monster list remains three")
	_check(str(DidianServiceScript.enemy_for_location("qinglan_mountain", "qinglan_wolf").get("id", "")) == "qinglan_wolf", "enemy lookup by id remains stable")
	_check(str(DidianServiceScript.enemy_for_location("qinglan_mountain", "beast").get("id", "")) == "qinglan_wolf", "enemy lookup by species remains stable")
	_check(DidianServiceScript.enemy_for_location("qinglan_mountain", "missing_enemy").is_empty(), "unknown enemy remains query-safe")
	var location_pool := DidianServiceScript.drop_pool_for_location("qinglan_mountain", "herbs")
	_check(not (location_pool.get("entries", []) as Array).is_empty(), "location drop pool remains available")
	var monster_pool := DidianServiceScript.drop_pool_for_location("qinglan_mountain", "monster:qinglan_wolf")
	_check(not (monster_pool.get("entries", []) as Array).is_empty(), "monster drop pool remains available")
	_check(DidianServiceScript.drop_pool_for_location("qinglan_mountain", "missing_pool").is_empty(), "unknown drop pool remains query-safe")


func _test_validation_contract() -> void:
	var schema := ExportTableReaderScript.read_settings(Catalog.SCHEMA_PATH)
	var locations := ExportTableReaderScript.read_keyed_rows(Catalog.LOCATIONS_PATH)
	var paths := {"schema": "fixture://didian.json", "locations": "fixture://didian_locations.json"}
	var bad_schema := schema.duplicate(true)
	bad_schema["schema_version"] = 2
	var errors := Catalog.validate_tables(bad_schema, locations, paths)
	_expect_code(errors, "schema_version_unsupported", paths["schema"], "schema_version")
	var bad := locations.duplicate(true)
	(bad["qinglan_mountain"] as Dictionary)["key"] = "wrong"
	errors = Catalog.validate_tables(schema, bad, paths)
	_expect_code(errors, "row_key_mismatch", paths["locations"], "qinglan_mountain.key")
	bad = locations.duplicate(true)
	(bad["qinglan_mountain"] as Dictionary)["event_pool"] = "event:1"
	errors = Catalog.validate_tables(schema, bad, paths)
	_expect_code(errors, "string_array_type", paths["locations"], "qinglan_mountain.event_pool")
	bad = locations.duplicate(true)
	(bad["qinglan_mountain"] as Dictionary)["materials"] = "material:pool"
	errors = Catalog.validate_tables(schema, bad, paths)
	_expect_code(errors, "materials_type", paths["locations"], "qinglan_mountain.materials")
	bad = locations.duplicate(true)
	((bad["qinglan_mountain"] as Dictionary)["drop_pools"] as Dictionary)["herbs"] = "item:1"
	errors = Catalog.validate_tables(schema, bad, paths)
	_expect_code(errors, "pool_type", paths["locations"], "qinglan_mountain.drop_pools.herbs")
	bad = locations.duplicate(true)
	var materials := ((bad["qinglan_mountain"] as Dictionary)["materials"] as Array).duplicate(true)
	(materials[0] as Dictionary)["drop_pool"] = "missing_pool"
	(bad["qinglan_mountain"] as Dictionary)["materials"] = materials
	errors = Catalog.validate_tables(schema, bad, paths)
	_expect_code(errors, "material_pool_unknown", paths["locations"], "qinglan_mountain.materials[0].drop_pool")
	var fewer_rows := locations.duplicate(true)
	fewer_rows.erase("wild_wolf_valley")
	_check(Catalog.validate_tables(schema, fewer_rows, paths).is_empty(), "schema does not hardcode production row count")


func _test_atomic_failure() -> void:
	var missing_path := "res:/" + "/missing_lilian_locations_fixture.json"
	var catalog := Catalog.new({"locations": missing_path})
	Engine.print_error_messages = false
	var rows := catalog.all_locations()
	var schema := catalog.schema()
	var errors := catalog.collect_errors()
	Engine.print_error_messages = true
	_check(rows.is_empty(), "one failed file clears all location rows")
	_check(schema.is_empty(), "one failed file clears schema cache")
	_expect_code(errors, "unreadable_file", missing_path, "root")


func _expect_code(errors: PackedStringArray, code: String, path: String, field: String) -> void:
	var expected := "[lilian_location_catalog:%s] file=%s field=%s" % [code, path, field]
	_check(expected in errors, "expected %s, got %s" % [expected, str(errors)])


func _sorted_copy(values: Array) -> Array:
	var sorted := values.duplicate()
	sorted.sort_custom(ExportTableReaderScript.compare_keys)
	return sorted


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
