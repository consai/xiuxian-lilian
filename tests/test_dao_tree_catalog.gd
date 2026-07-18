extends SceneTree

const CatalogScript := preload("res://scripts/features/dao/infrastructure/dao_tree_catalog.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")


func _init() -> void:
	Engine.print_error_messages = false
	var roots := _roots()
	var catalog = CatalogScript.new()
	_check(catalog.reload(), "catalog must read all eight production tables")
	_check(catalog.reload_from_roots(roots), "valid dao roots must load")
	_check(catalog.snapshot().get("schemaVersion") == 1, "schema version must decode")
	_check(catalog.metadata().get("skillCount") == 35, "metadata skill count must decode")
	_check(catalog.attributes().size() == 5, "five attributes must load")
	_check(catalog.realms().size() == 9, "nine realms must load")
	_check(catalog.domain_groups().size() == 1, "one domain group must load")
	_check(catalog.domains().size() == 3, "three domains must load")
	_check(catalog.all_skills().size() == 35, "thirty-five skills must load")
	_check(catalog.training().get("base") is Dictionary, "training base must load")
	_check(catalog.realm_order("dujie") == 9, "realm order lookup must work")
	_check(catalog.realm_display_name("zhuji") == "筑基", "realm display lookup must work")
	_check(catalog.skills_in_domain("zhuji").size() == 35, "production skill domains must remain unchanged")
	for skill_v in catalog.all_skills():
		_check((skill_v as Dictionary).get("domain") == "zhuji", "all production skill domains must stay zhuji")
		_check(((skill_v as Dictionary).get("prereqs", []) as Array).is_empty(), "production prereqs must stay empty")
	_check(catalog.skills_in_realm("lianqi").size() > 0, "realm skill lookup must work")
	_check(not catalog.skill_by_id("foundation.breathing").is_empty(), "skill lookup must work")
	_check(not catalog.domain_by_id("zhuji").is_empty(), "domain lookup must work")
	_check(not catalog.realm_by_id("lianqi").is_empty(), "realm lookup must work")
	_assert_natural_order(catalog.domain_groups(), roots.groups as Dictionary, "groups")
	_assert_natural_order(catalog.domains(), roots.domains as Dictionary, "domains")
	_assert_natural_order(catalog.realms(), roots.realms as Dictionary, "realms")
	_assert_natural_order(catalog.all_skills(), roots.skills as Dictionary, "skills")

	var mutated_skill := catalog.skill_by_id("foundation.breathing")
	mutated_skill["name"] = "mutated"
	_check(catalog.skill_by_id("foundation.breathing").get("name") == "吐纳入门", "skill query must deep clone")
	var mutated_snapshot := catalog.snapshot()
	(mutated_snapshot.metadata as Dictionary)["name"] = "mutated"
	_check(catalog.metadata().get("name") == "大道知识树", "snapshot must deep clone")

	var bad_root := roots.duplicate(true)
	bad_root["skills"] = []
	_check(not catalog.reload_from_roots(bad_root), "invalid root must reject")
	_check(_has_error(catalog.collect_errors(), "invalid_root"), "invalid root must have stable error")
	_check(catalog.all_skills().size() == 35, "failed reload must retain prior snapshot")

	var first_fail = CatalogScript.new()
	_check(not first_fail.reload_from_roots(bad_root), "first invalid load must reject")
	_check(first_fail.snapshot().is_empty(), "first invalid load must expose no snapshot")

	var bad_count := roots.duplicate(true)
	(bad_count.attributes as Dictionary).erase("fortune")
	_assert_reject(catalog, bad_count, "row_count")
	var bad_schema := roots.duplicate(true)
	((bad_schema.settings as Dictionary).schemaVersion as Dictionary)["value"] = "2"
	_assert_reject(catalog, bad_schema, "schema_version")
	var bad_key := roots.duplicate(true)
	((bad_key.metadata as Dictionary).name as Dictionary)["key"] = "wrong"
	_assert_reject(catalog, bad_key, "key_mismatch")
	var bad_row := roots.duplicate(true)
	(bad_row.skills as Dictionary)["foundation.breathing"] = "bad"
	_assert_reject(catalog, bad_row, "invalid_row")
	var duplicate_id := roots.duplicate(true)
	((duplicate_id.domains as Dictionary).cultivation as Dictionary)["id"] = "zhuji"
	_assert_reject(catalog, duplicate_id, "duplicate_id")
	var unknown_group_domain := roots.duplicate(true)
	((unknown_group_domain.groups as Dictionary).cultivation_root as Dictionary)["domains"] = ["unknown"]
	_assert_reject(catalog, unknown_group_domain, "unknown_domain")
	var unknown_skill_domain := roots.duplicate(true)
	((unknown_skill_domain.skills as Dictionary)["foundation.breathing"] as Dictionary)["domain"] = "unknown"
	_assert_reject(catalog, unknown_skill_domain, "unknown_domain")
	var unknown_skill_realm := roots.duplicate(true)
	((unknown_skill_realm.skills as Dictionary)["foundation.breathing"] as Dictionary)["realm"] = "unknown"
	_assert_reject(catalog, unknown_skill_realm, "unknown_realm")
	var duplicate_order := roots.duplicate(true)
	((duplicate_order.realms as Dictionary).zhuji as Dictionary)["order"] = 1
	_assert_reject(catalog, duplicate_order, "duplicate_realm_order")
	var metadata_count := roots.duplicate(true)
	((metadata_count.metadata as Dictionary).skillCount as Dictionary)["value"] = "34"
	_assert_reject(catalog, metadata_count, "skill_count")

	print("PASS: dao tree catalog contract")
	quit(0)


func _roots() -> Dictionary:
	return {
		"settings": JsonReaderScript.read_variant("res://data/exportjson/dao_tree.json"),
		"metadata": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_metadata.json"),
		"training": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_training.json"),
		"attributes": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_attributes.json"),
		"realms": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_realms.json"),
		"groups": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_domainGroups.json"),
		"domains": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_domains.json"),
		"skills": JsonReaderScript.read_variant("res://data/exportjson/dao_tree_skills.json"),
	}


func _assert_natural_order(actual: Array, raw: Dictionary, label: String) -> void:
	var expected: Array = raw.keys()
	expected.sort_custom(ExportTableReaderScript.compare_keys)
	_check(actual.size() == expected.size(), label + " natural order size must match")
	for index in expected.size():
		_check(str((actual[index] as Dictionary).get("id", "")) == str(expected[index]), label + " must use natural key order")


func _assert_reject(catalog: RefCounted, roots: Dictionary, code: String) -> void:
	_check(not catalog.reload_from_roots(roots), code + " fixture must reject")
	var first_errors: PackedStringArray = catalog.collect_errors()
	_check(_has_error(first_errors, code), code + " must have stable error")
	_check(not catalog.reload_from_roots(roots), code + " repeated fixture must reject")
	_check(catalog.collect_errors() == first_errors, code + " errors must be stable across retries")
	_check(catalog.all_skills().size() == 35, code + " failure must retain prior snapshot")


func _has_error(errors: PackedStringArray, code: String) -> bool:
	for message in errors:
		if message.contains(":" + code + "]"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
