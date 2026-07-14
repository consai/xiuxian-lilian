extends SceneTree

const Catalog := preload("res://scripts/lilian/lilian_event_catalog.gd")
const EventService := preload("res://scripts/lilian/lilian_event_service.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

class FakeDataStore:
	extends Node

	var runtime := {"active": true, "generated_events": {}}

	func lilian_runtime() -> Dictionary:
		return runtime


var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_production_tables()
	_test_deep_copy_and_query_contract()
	_test_complex_cells_and_runtime_shape()
	_test_generated_event_precedence()
	_test_intrinsic_validation()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: lilian event catalog")
	quit(0)


func _test_production_tables() -> void:
	var common_schema := ExportTableReaderScript.read_settings(Catalog.COMMON_SCHEMA_PATH)
	var explicit_schema := ExportTableReaderScript.read_settings(Catalog.EXPLICIT_SCHEMA_PATH)
	var common_rows := ExportTableReaderScript.read_keyed_rows(Catalog.COMMON_EVENTS_PATH)
	var explicit_rows := ExportTableReaderScript.read_keyed_rows(Catalog.EXPLICIT_EVENTS_PATH)
	_check(Catalog.collect_errors().is_empty(), "production event tables validate")
	_check(Catalog.common_schema() == common_schema, "common schema remains in exported shape")
	_check(Catalog.explicit_schema() == explicit_schema, "explicit schema remains in exported shape")
	_check(int(Catalog.common_schema().get("schema_version", 0)) == 2, "common schema is version 2")
	_check(int(Catalog.explicit_schema().get("schema_version", 0)) == 2, "explicit schema is version 2")
	_check(Catalog.all_common_ids().size() == 39, "common event count remains 39")
	_check(Catalog.all_explicit_ids().size() == 14, "explicit event count remains 14")
	_check(Catalog.all_common_ids() == _sorted_copy(Catalog.all_common_ids()), "common ids are sorted")
	_check(Catalog.all_explicit_ids() == _sorted_copy(Catalog.all_explicit_ids()), "explicit ids are sorted")
	for id_v in common_rows.keys():
		var id := str(id_v)
		_check(str((common_rows[id_v] as Dictionary).get("id", "")) == id, "common key/id %s" % id)
	for id_v in explicit_rows.keys():
		var id := str(id_v)
		_check(str((explicit_rows[id_v] as Dictionary).get("id", "")) == id, "explicit key/id %s" % id)
	_check(not Catalog.explicit_by_id("tutorial_valley_herbs").is_empty(), "orphan tutorial row is loaded and validated")


func _test_deep_copy_and_query_contract() -> void:
	var common := Catalog.common_by_id("qinglan_mountain__wandering_cultivator")
	(common["options"] as Array).clear()
	_check(
		(Catalog.common_by_id("qinglan_mountain__wandering_cultivator")["options"] as Array).size() == 2,
		"common nested rows are deep copies"
	)
	var explicit := Catalog.explicit_by_id("mist_creek_chain_choice")
	(explicit["options"] as Array).clear()
	_check(
		(Catalog.explicit_by_id("mist_creek_chain_choice")["options"] as Array).size() == 2,
		"explicit nested rows are deep copies"
	)
	_check(Catalog.static_by_id("missing_event").is_empty(), "unknown catalog id is query-safe")
	_check(EventService.by_id("missing_event").is_empty(), "unknown application id remains query-safe")


func _test_complex_cells_and_runtime_shape() -> void:
	var common_rows := ExportTableReaderScript.read_keyed_rows(Catalog.COMMON_EVENTS_PATH)
	var explicit_rows := ExportTableReaderScript.read_keyed_rows(Catalog.EXPLICIT_EVENTS_PATH)
	var common_id := "qinglan_mountain__wandering_cultivator"
	var explicit_id := "mist_creek_chain_choice"
	_check(Catalog.common_by_id(common_id) == common_rows[common_id], "common options/effects/results stay unchanged")
	_check(Catalog.explicit_by_id(explicit_id) == explicit_rows[explicit_id], "explicit choices/triggers stay unchanged")
	var battle := Catalog.explicit_by_id("qinglan_wolf")
	_check(battle.get("enemy_count") is String, "enemy_count remains a String")
	_check(str(battle.get("enemy_count")) == "2", "enemy_count string value remains 2")
	var enemies := EventService.build_battle_enemies({
		"enemy": {"id": "fixture", "name": "fixture", "attrs": {"hp_max": 10.0}},
		"enemy_count": battle.get("enemy_count"),
		"type": "battle",
		"difficulty": 1,
	})
	_check(enemies.size() == 2, "runtime still converts enemy_count String to two enemies")
	var location := {"event_pool": [common_id, {"id": explicit_id}, "missing_event"]}
	var pool := EventService.event_pool_for_location(location)
	_check(pool.size() == 2, "event pool still skips unknown ids")
	_check(str((pool[0] as Dictionary).get("id", "")) == common_id, "event pool keeps source order")
	_check(str((pool[1] as Dictionary).get("id", "")) == explicit_id, "event pool resolves dictionary ids")


func _test_generated_event_precedence() -> void:
	var existing := root.get_node_or_null("DataStore")
	var data_store: Node = existing
	var owns_fixture := false
	if data_store == null:
		data_store = FakeDataStore.new()
		data_store.name = "DataStore"
		root.add_child(data_store)
		owns_fixture = true
	var runtime := data_store.call("lilian_runtime") as Dictionary
	var previous_active: Variant = runtime.get("active")
	var previous_generated: Variant = runtime.get("generated_events", {}).duplicate(true)
	runtime["active"] = true
	runtime["generated_events"] = {
		"qinglan_wolf": {"id": "qinglan_wolf", "source": "generated"},
	}
	var event := EventService.by_id("qinglan_wolf")
	_check(str(event.get("source", "")) == "generated", "generated event still overrides explicit config")
	runtime["active"] = previous_active
	runtime["generated_events"] = previous_generated
	if owns_fixture:
		root.remove_child(data_store)
		data_store.free()


func _test_intrinsic_validation() -> void:
	var common_schema := ExportTableReaderScript.read_settings(Catalog.COMMON_SCHEMA_PATH)
	var explicit_schema := ExportTableReaderScript.read_settings(Catalog.EXPLICIT_SCHEMA_PATH)
	var common_rows := ExportTableReaderScript.read_keyed_rows(Catalog.COMMON_EVENTS_PATH)
	var explicit_rows := ExportTableReaderScript.read_keyed_rows(Catalog.EXPLICIT_EVENTS_PATH)
	var paths := {
		"common_schema": "fixture://common_schema.json",
		"common_events": "fixture://common_events.json",
		"explicit_schema": "fixture://explicit_schema.json",
		"explicit_events": "fixture://explicit_events.json",
	}
	var bad_common := common_rows.duplicate(true)
	(bad_common["qinglan_mountain__travel"] as Dictionary)["id"] = "wrong"
	var errors := Catalog.validate_tables(common_schema, bad_common, explicit_schema, explicit_rows, paths)
	_expect_code(errors, "row_id_mismatch", "fixture://common_events.json", "qinglan_mountain__travel.id")
	var bad_explicit := explicit_rows.duplicate(true)
	bad_explicit["qinglan_mountain__travel"] = (common_rows["qinglan_mountain__travel"] as Dictionary).duplicate(true)
	errors = Catalog.validate_tables(common_schema, common_rows, explicit_schema, bad_explicit, paths)
	_expect_code(errors, "duplicate_event_id", "fixture://explicit_events.json", "qinglan_mountain__travel")
	bad_explicit = explicit_rows.duplicate(true)
	var chain := (bad_explicit["mist_creek_chain_tracks"] as Dictionary).duplicate(true)
	var options := (chain["options"] as Array).duplicate(true)
	(options[0] as Dictionary)["trigger_event"] = "missing_trigger"
	(options[1] as Dictionary)["id"] = str((options[0] as Dictionary)["id"])
	chain["options"] = options
	bad_explicit["mist_creek_chain_tracks"] = chain
	errors = Catalog.validate_tables(common_schema, common_rows, explicit_schema, bad_explicit, paths)
	_expect_code(errors, "option_id_duplicate", "fixture://explicit_events.json", "mist_creek_chain_tracks.options[1].id")
	_expect_code(errors, "unknown_trigger_event", "fixture://explicit_events.json", "mist_creek_chain_tracks.options[0].trigger_event")
	bad_explicit = explicit_rows.duplicate(true)
	(bad_explicit["qinglan_wolf"] as Dictionary)["enemy_count"] = 2
	errors = Catalog.validate_tables(common_schema, common_rows, explicit_schema, bad_explicit, paths)
	_expect_code(errors, "enemy_count_type", "fixture://explicit_events.json", "qinglan_wolf.enemy_count")
	var bad_schema := common_schema.duplicate(true)
	bad_schema["schema_version"] = 1
	errors = Catalog.validate_tables(bad_schema, common_rows, explicit_schema, explicit_rows, paths)
	_expect_code(errors, "schema_version_unsupported", "fixture://common_schema.json", "schema_version")


func _expect_code(errors: PackedStringArray, code: String, path: String, field: String) -> void:
	var expected := "[lilian_event_catalog:%s] file=%s field=%s" % [code, path, field]
	_check(expected in errors, "expected %s, got %s" % [expected, str(errors)])


func _sorted_copy(values: Array) -> Array:
	var sorted := values.duplicate()
	sorted.sort_custom(ExportTableReaderScript.compare_keys)
	return sorted


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
