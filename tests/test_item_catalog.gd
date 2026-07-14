extends SceneTree

const Catalog := preload("res://scripts/features/inventory/infrastructure/item_catalog.gd")
const Query := preload("res://scripts/features/inventory/application/inventory_query_application.gd")
const AbilityQuery := preload("res://scripts/features/ability/application/ability_query_application.gd")
const MethodQuery := preload("res://scripts/features/cultivation/application/cultivation_method_query_application.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _failures: PackedStringArray = []
var _paths := {
	"items": "fixture://item_items.json",
	"templates": "fixture://item_generated_learning_books.json",
	"aliases": "fixture://item_legacy_learning_book_ali.json",
}


func _init() -> void:
	_test_production_contract()
	_test_generated_fields_and_queries()
	_test_deep_copy()
	_test_validation_contract()
	_test_atomic_reload()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: item catalog")
	quit(0)


func _test_production_contract() -> void:
	var definitions := Query.all_definitions()
	_check(definitions.size() == 169, "combined item count remains 169")
	_check(_ids(definitions.slice(0, 47)) == _ids(_sorted_base_rows()), "base segment remains the 47 natural-order exported rows")
	var ability_ids := _ids(AbilityQuery.all_definitions())
	var method_ids := _ids(MethodQuery.all_definitions())
	_check(_targets(definitions.slice(47, 64), "learn_ability_id") == ability_ids.slice(0, 17), "active ability books remain the second segment")
	_check(_targets(definitions.slice(64, 86), "learn_ability_id") == ability_ids.slice(17, 39), "passive ability books remain the third segment")
	_check(_targets(definitions.slice(86, 169), "learn_method_id") == method_ids, "method books remain the final segment")
	_check((definitions[47] as ItemDef).id == "book_skill_skill_lq_001", "active book id generation remains stable")
	_check((definitions[64] as ItemDef).id == "book_skill_passive_0001", "passive book id generation remains stable")
	_check((definitions[86] as ItemDef).id == "book_method_blood_burst_1", "method book id generation remains stable")
	for alias in ["book_method_iron_body", "book_method_leihuo", "book_method_hunyuan"]:
		var resolved := Query.definition_by_id(alias)
		_check(resolved != null and resolved.id != alias, "legacy alias resolves: %s" % alias)


func _test_generated_fields_and_queries() -> void:
	var active := Query.definition_by_id("book_skill_skill_lq_001")
	var passive := Query.definition_by_id("book_skill_passive_0001")
	var method := Query.definition_by_id("book_method_hunyuan_1")
	for pair in [[active, "skill_lq_001", ""], [passive, "passive_0001", ""], [method, "", "method.hunyuan.1"]]:
		var definition := pair[0] as ItemDef
		_check(definition != null, "generated book exists")
		if definition == null:
			continue
		_check(definition.primary_type == "书籍" and definition.stackable == 1 and definition.max_stack == 9, "generated book template fields remain stable")
		_check(definition.learn_ability_id == pair[1] and definition.learn_method_id == pair[2], "generated target field remains stable")
		_check(definition.quality >= 1 and definition.tier >= 1 and definition.icon_path != "", "generated display fields remain complete")
	var roots := _production_roots()
	var fight_id := 0
	for row_v in (roots.items as Dictionary).values():
		var fight_id_v: Variant = (row_v as Dictionary).get("fight_id", 0) if row_v is Dictionary else null
		if fight_id_v != null and int(fight_id_v) > 0:
			fight_id = int(fight_id_v)
			break
	_check(fight_id > 0 and Query.definition_by_fight_id(fight_id) != null, "fight id index remains available")
	var cfg := Query.build_item_cfg({fight_id: {"name": "override"}})
	_check((cfg[fight_id] as Dictionary).get("name") == "override" and (cfg[str(fight_id)] as Dictionary).get("name") == "override", "extra fight cfg overrides int and string keys")
	_check(Query.display_name("missing_item") == "missing_item" and Query.display_name("") == "", "display name fallback remains stable")


func _test_deep_copy() -> void:
	var first := Query.all_definitions()[0] as ItemDef
	var original_name := first.name
	first.name = "mutated"
	first.use_effect.append({"op": "mutated", "args": [[1]]})
	var fresh := Query.definition_by_id(first.id)
	_check(fresh.name == original_name, "definition is cloned")
	_check(fresh.use_effect != first.use_effect, "nested effects are deep-cloned")
	var cfg := Query.build_item_cfg()
	if not cfg.is_empty():
		var key: Variant = cfg.keys()[0]
		if cfg[key] is Dictionary:
			(cfg[key] as Dictionary)["name"] = "mutated"
			_check((Query.build_item_cfg()[key] as Dictionary).get("name") != "mutated", "fight cfg is deep-copied")


func _test_validation_contract() -> void:
	var roots := _production_roots()
	var abilities := AbilityQuery.all_definitions()
	var methods := MethodQuery.all_definitions()
	_expect_code(Catalog.validate_roots([], roots.templates, roots.aliases, abilities, methods, _paths), "invalid_root", _paths.items, "items", "root")
	var items := (roots.items as Dictionary).duplicate(true)
	items[items.keys()[0]] = "bad"
	_expect_code(Catalog.validate_roots(items, roots.templates, roots.aliases, abilities, methods, _paths), "invalid_row", _paths.items, "items", str(items.keys()[0]))
	var templates := (roots.templates as Dictionary).duplicate(true)
	var template_key: Variant = templates.keys()[0]
	var bad_template := (templates[template_key] as Dictionary).duplicate(true)
	bad_template["name_template"] = 7
	templates[template_key] = bad_template
	_expect_code(Catalog.validate_roots(roots.items, templates, roots.aliases, abilities, methods, _paths), "required_string", _paths.templates, "templates", "%s.name_template" % str(template_key))
	items = (roots.items as Dictionary).duplicate(true)
	var keys := items.keys()
	var duplicate := (items[keys[1]] as Dictionary).duplicate(true)
	duplicate["id"] = str(keys[0])
	items[keys[1]] = duplicate
	_expect_code(Catalog.validate_roots(items, roots.templates, roots.aliases, abilities, methods, _paths), "duplicate_item_id", _paths.items, "items", "%s.id" % str(keys[1]))
	items = (roots.items as Dictionary).duplicate(true)
	var target_row := (items[keys[0]] as Dictionary).duplicate(true)
	target_row["learn_ability_id"] = str((abilities[0] as Dictionary).get("id"))
	items[keys[0]] = target_row
	var second_target := (items[keys[1]] as Dictionary).duplicate(true)
	second_target["learn_ability_id"] = str((abilities[0] as Dictionary).get("id"))
	items[keys[1]] = second_target
	_expect_code(Catalog.validate_roots(items, roots.templates, roots.aliases, abilities, methods, _paths), "duplicate_generated_target", _paths.templates, "templates", str((abilities[0] as Dictionary).get("id")))
	var aliases := (roots.aliases as Dictionary).duplicate(true)
	var alias_key: Variant = aliases.keys()[0]
	var alias_row := (aliases[alias_key] as Dictionary).duplicate(true)
	alias_row["value"] = "missing_item"
	aliases[alias_key] = alias_row
	_expect_code(Catalog.validate_roots(roots.items, roots.templates, aliases, abilities, methods, _paths), "alias_target_unknown", _paths.aliases, "aliases", str(alias_key))
	aliases = (roots.aliases as Dictionary).duplicate(true)
	var alias_keys := aliases.keys()
	var a := (aliases[alias_keys[0]] as Dictionary).duplicate(true)
	var b := (aliases[alias_keys[1]] as Dictionary).duplicate(true)
	a["value"] = str(alias_keys[1])
	b["value"] = str(alias_keys[0])
	aliases[alias_keys[0]] = a
	aliases[alias_keys[1]] = b
	_expect_code(Catalog.validate_roots(roots.items, roots.templates, aliases, abilities, methods, _paths), "alias_cycle", _paths.aliases, "aliases", str(alias_keys[0]))


func _test_atomic_reload() -> void:
	var roots := _production_roots()
	var abilities := AbilityQuery.all_definitions()
	var methods := MethodQuery.all_definitions()
	var catalog := Catalog.new()
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots([], roots.templates, roots.aliases, abilities, methods, _paths), "first invalid reload is rejected")
	Engine.print_error_messages = true
	_check(catalog.all_definitions(abilities, methods).is_empty(), "first failure exposes no snapshot")
	_check(catalog.reload_from_roots(roots.items, roots.templates, roots.aliases, abilities, methods, _paths), "valid roots commit")
	var before := catalog.all_definitions(abilities, methods)
	var bad_items := (roots.items as Dictionary).duplicate(true)
	bad_items[bad_items.keys()[0]] = "bad"
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_items, roots.templates, roots.aliases, abilities, methods, _paths), "invalid reload is rejected")
	Engine.print_error_messages = true
	_check(_ids(catalog.all_definitions(abilities, methods)) == _ids(before), "failed reload preserves prior snapshot")
	_expect_code(catalog.collect_errors(), "invalid_row", _paths.items, "items", str(bad_items.keys()[0]))


func _production_roots() -> Dictionary:
	return {
		"items": JsonReaderScript.read_object(Catalog.ITEMS_PATH),
		"templates": JsonReaderScript.read_object(Catalog.TEMPLATES_PATH),
		"aliases": JsonReaderScript.read_object(Catalog.ALIASES_PATH),
	}


func _sorted_base_rows() -> Array:
	var rows := (_production_roots().items as Dictionary)
	var keys: Array = rows.keys()
	keys.sort_custom(preload("res://scripts/core/config/export_table_reader.gd").compare_keys)
	var out: Array = []
	for key in keys:
		out.append(rows[key])
	return out


func _ids(rows: Array) -> Array:
	var out: Array = []
	for row_v in rows:
		if row_v is ItemDef:
			out.append((row_v as ItemDef).id)
		elif row_v is Dictionary:
			out.append(str((row_v as Dictionary).get("id", "")))
	return out


func _targets(rows: Array, field: String) -> Array:
	var out: Array = []
	for row_v in rows:
		out.append((row_v as ItemDef).get(field))
	return out


func _expect_code(errors: PackedStringArray, code: String, path: String, table: String, field: String) -> void:
	var expected := "[item_catalog:%s] file=%s table=%s field=%s" % [code, path, table, field]
	_check(expected in errors, "expected %s, got %s" % [expected, str(errors)])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
