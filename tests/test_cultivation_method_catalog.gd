extends SceneTree

const Catalog := preload(
	"res://scripts/features/cultivation/infrastructure/cultivation_method_catalog.gd"
)
const Query := preload(
	"res://scripts/features/cultivation/application/cultivation_method_query_application.gd"
)
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	_test_production_tables()
	_test_stable_order_and_deep_copy()
	_test_runtime_effect_alias()
	_test_validation_contract()
	_test_atomic_failure()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: cultivation method catalog")
	quit(0)


func _test_production_tables() -> void:
	var catalog := Catalog.new()
	_check(catalog.collect_errors().is_empty(), "production tables validate")
	var methods := catalog.all_definitions()
	_check(methods.size() == 83, "production method count remains 83")
	var families := ExportTableReaderScript.read_keyed_rows(Catalog.FAMILIES_PATH)
	var effects := ExportTableReaderScript.read_keyed_rows(Catalog.EFFECT_CATALOG_PATH)
	_check(families.size() == 15, "production family count remains 15")
	_check(effects.size() == 175, "production effect count remains 175")
	_check(str(catalog.family_by_id("method.hunyuan").get("name", "")) == "混元归一经", "known family remains stable")
	_check(str(catalog.definition_by_id("method.hunyuan.1").get("name", "")) == "混元归一经·练气篇", "known method remains stable")
	_check(catalog.definition_by_id("missing_method").is_empty(), "unknown method is query-safe")
	_check(catalog.family_by_id("missing_family").is_empty(), "unknown family is query-safe")


func _test_stable_order_and_deep_copy() -> void:
	var raw_methods := ExportTableReaderScript.read_row_array(Catalog.METHODS_PATH)
	var methods := Query.all_definitions()
	_check(methods.size() == raw_methods.size(), "query returns every method")
	for index in methods.size():
		_check(str((methods[index] as Dictionary).get("id", "")) == str((raw_methods[index] as Dictionary).get("id", "")), "natural method order remains stable at %d" % index)
	var method := Query.definition_by_id("method.hunyuan.1")
	(method["practice"] as Dictionary)["efficiency"] = 999.0
	((method["effects"] as Array)[0] as Dictionary)["effectId"] = "mutated"
	var fresh := Query.definition_by_id("method.hunyuan.1")
	_check(float((fresh["practice"] as Dictionary)["efficiency"]) == 1.0, "practice query is a deep copy")
	_check(str(((fresh["effects"] as Array)[0] as Dictionary)["effectId"]) == "max_health", "effect query is a deep copy")
	var family := Query.family_by_id("method.hunyuan")
	(family["methodIds"] as Array).clear()
	_check((Query.family_by_id("method.hunyuan")["methodIds"] as Array).size() == 9, "family query is a deep copy")


func _test_runtime_effect_alias() -> void:
	var method := Query.definition_by_id("method.hunyuan.6")
	var has_runtime_alias := false
	for effect_v in method.get("effects", []) as Array:
		if effect_v is Dictionary and str((effect_v as Dictionary).get("effectId", "")) == "void_resistance":
			has_runtime_alias = true
	_check(has_runtime_alias, "runtime void effect id remains unchanged and validates through runtimeKey")


func _test_validation_contract() -> void:
	var tables := _production_tables()
	var paths := _fixture_paths()
	var settings := (tables.settings as Dictionary).duplicate(true)
	settings["schemaVersion"] = 1
	_expect_code(Catalog.validate_tables(settings, tables.metadata, tables.families, tables.methods, tables.effects, paths), "schema_version_unsupported", paths.settings, "schemaVersion")
	settings = (tables.settings as Dictionary).duplicate(true)
	settings["configId"] = "wrong"
	_expect_code(Catalog.validate_tables(settings, tables.metadata, tables.families, tables.methods, tables.effects, paths), "config_id_invalid", paths.settings, "configId")
	var metadata := (tables.metadata as Dictionary).duplicate(true)
	metadata["methodCount"] = 82
	_expect_code(Catalog.validate_tables(tables.settings, metadata, tables.families, tables.methods, tables.effects, paths), "metadata_count_mismatch", paths.metadata, "methodCount")
	var fewer_methods := (tables.methods as Dictionary).duplicate(true)
	fewer_methods.erase("method.heavy_sword.1")
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, fewer_methods, tables.effects, paths), "row_count_mismatch", paths.methods, "root")
	var families := (tables.families as Dictionary).duplicate(true)
	var hunyuan := (families["method.hunyuan"] as Dictionary).duplicate(true)
	hunyuan["methodIds"] = "bad"
	families["method.hunyuan"] = hunyuan
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, families, tables.methods, tables.effects, paths), "string_array_invalid", paths.families, "method.hunyuan.methodIds")
	families = (tables.families as Dictionary).duplicate(true)
	hunyuan = (families["method.hunyuan"] as Dictionary).duplicate(true)
	var ids := (hunyuan["methodIds"] as Array).duplicate()
	ids[1] = ids[0]
	hunyuan["methodIds"] = ids
	families["method.hunyuan"] = hunyuan
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, families, tables.methods, tables.effects, paths), "duplicate_id", paths.families, "method.hunyuan.methodIds[1]")
	var methods := (tables.methods as Dictionary).duplicate(true)
	var duplicate := (methods["method.heavy_sword.1"] as Dictionary).duplicate(true)
	duplicate["id"] = "method.hunyuan.1"
	methods["method.heavy_sword.1"] = duplicate
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, methods, tables.effects, paths), "duplicate_method_id", paths.methods, "method.heavy_sword.1.id")
	methods = (tables.methods as Dictionary).duplicate(true)
	var second := (methods["method.hunyuan.2"] as Dictionary).duplicate(true)
	second["familyId"] = "missing.family"
	methods["method.hunyuan.2"] = second
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, methods, tables.effects, paths), "method_family_mismatch", paths.methods, "method.hunyuan.2.familyId")
	methods = (tables.methods as Dictionary).duplicate(true)
	second = (methods["method.hunyuan.2"] as Dictionary).duplicate(true)
	second["predecessorId"] = null
	methods["method.hunyuan.2"] = second
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, methods, tables.effects, paths), "predecessor_mismatch", paths.methods, "method.hunyuan.2.predecessorId")
	methods = (tables.methods as Dictionary).duplicate(true)
	var first := (methods["method.hunyuan.1"] as Dictionary).duplicate(true)
	var method_effects := (first["effects"] as Array).duplicate(true)
	(method_effects[0] as Dictionary)["attributes"] = "bad"
	first["effects"] = method_effects
	methods["method.hunyuan.1"] = first
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, methods, tables.effects, paths), "effect_attributes_invalid", paths.methods, "method.hunyuan.1.effects[0].attributes")
	methods = (tables.methods as Dictionary).duplicate(true)
	first = (methods["method.hunyuan.1"] as Dictionary).duplicate(true)
	method_effects = (first["effects"] as Array).duplicate(true)
	(method_effects[0] as Dictionary)["effectId"] = "missing_effect"
	first["effects"] = method_effects
	methods["method.hunyuan.1"] = first
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, methods, tables.effects, paths), "effect_reference_unknown", paths.methods, "method.hunyuan.1.effects[0].effectId")
	var effects := (tables.effects as Dictionary).duplicate(true)
	var effect_row := (effects["lianxu_resistance"] as Dictionary).duplicate(true)
	effect_row["runtimeKey"] = "void_survival"
	effects["lianxu_resistance"] = effect_row
	_expect_code(Catalog.validate_tables(tables.settings, tables.metadata, tables.families, tables.methods, effects, paths), "effect_alias_conflict", paths.effects, "void_survival")


func _test_atomic_failure() -> void:
	var missing_path := "res:/" + "/missing_cultivation_methods_fixture.json"
	var catalog := Catalog.new({"methods": missing_path})
	Engine.print_error_messages = false
	var methods := catalog.all_definitions()
	var errors := catalog.collect_errors()
	Engine.print_error_messages = true
	_check(methods.is_empty(), "one failed file clears the full method catalog")
	_check(catalog.family_by_id("method.hunyuan").is_empty(), "one failed file clears family cache")
	_expect_code(errors, "unreadable_file", missing_path, "root")


func _production_tables() -> Dictionary:
	return {
		"settings": ExportTableReaderScript.read_settings(Catalog.SETTINGS_PATH),
		"metadata": ExportTableReaderScript.read_settings(Catalog.METADATA_PATH),
		"families": ExportTableReaderScript.read_keyed_rows(Catalog.FAMILIES_PATH),
		"methods": ExportTableReaderScript.read_keyed_rows(Catalog.METHODS_PATH),
		"effects": ExportTableReaderScript.read_keyed_rows(Catalog.EFFECT_CATALOG_PATH),
	}


func _fixture_paths() -> Dictionary:
	return {
		"settings": "fixture://xiulian_methods.json",
		"metadata": "fixture://xiulian_methods_metadata.json",
		"families": "fixture://xiulian_methods_families.json",
		"methods": "fixture://xiulian_methods_methods.json",
		"effects": "fixture://xiulian_methods_effectCatalog.json",
	}


func _expect_code(errors: PackedStringArray, code: String, path: String, field: String) -> void:
	var expected := "[cultivation_method_catalog:%s] file=%s field=%s" % [code, path, field]
	_check(expected in errors, "expected %s, got %s" % [expected, str(errors)])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
