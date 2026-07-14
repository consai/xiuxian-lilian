class_name ItemCatalog
extends RefCounted

const ITEMS_PATH := "res://data/exportjson/item_items.json"
const TEMPLATES_PATH := "res://data/exportjson/item_generated_learning_books.json"
const ALIASES_PATH := "res://data/exportjson/item_legacy_learning_book_ali.json"
const EXPECTED_BASE_COUNT := 47
const EXPECTED_TEMPLATE_COUNT := 2
const EXPECTED_ALIAS_COUNT := 3

const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const ItemDefScript := preload("res://scripts/features/inventory/domain/item_def.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _definitions: Array = []
var _by_id: Dictionary = {}
var _by_fight_id: Dictionary = {}
var _aliases: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = {
		"items": str(paths.get("items", ITEMS_PATH)),
		"templates": str(paths.get("templates", TEMPLATES_PATH)),
		"aliases": str(paths.get("aliases", ALIASES_PATH)),
	}


func reload(ability_definitions: Array, method_definitions: Array) -> bool:
	_load_attempted = true
	var roots: Dictionary = {}
	var errors: PackedStringArray = []
	for table in ["items", "templates", "aliases"]:
		var path := str(_paths[table])
		var root_v: Variant = JsonReaderScript.read_variant(path)
		if root_v == null:
			errors.append(_message("unreadable_file", path, table, "root"))
		elif not root_v is Dictionary:
			errors.append(_message("invalid_root", path, table, "root"))
		else:
			roots[table] = root_v
	if not errors.is_empty():
		return _reject(errors)
	return _commit_roots(
		roots.items,
		roots.templates,
		roots.aliases,
		ability_definitions,
		method_definitions,
		_paths
	)


func reload_from_roots(
		items_root: Variant,
		templates_root: Variant,
		aliases_root: Variant,
		ability_definitions: Array,
		method_definitions: Array,
		paths: Dictionary = {}
) -> bool:
	_load_attempted = true
	return _commit_roots(
		items_root,
		templates_root,
		aliases_root,
		ability_definitions,
		method_definitions,
		_resolved_fixture_paths(paths)
	)


func all_definitions(ability_definitions: Array, method_definitions: Array) -> Array:
	_ensure_loaded(ability_definitions, method_definitions)
	var out: Array = []
	if not _valid:
		return out
	for definition_v in _definitions:
		out.append((definition_v as ItemDef).clone())
	return out


func definition_by_id(
		item_id: String,
		ability_definitions: Array,
		method_definitions: Array
) -> ItemDef:
	_ensure_loaded(ability_definitions, method_definitions)
	if not _valid:
		return null
	var canonical_id := _resolve_alias(item_id.strip_edges(), _aliases)
	var found_v: Variant = _by_id.get(canonical_id)
	return (found_v as ItemDef).clone() if found_v is ItemDef else null


func definition_by_fight_id(
		fight_id: int,
		ability_definitions: Array,
		method_definitions: Array
) -> ItemDef:
	_ensure_loaded(ability_definitions, method_definitions)
	if not _valid or fight_id <= 0:
		return null
	var found_v: Variant = _by_fight_id.get(fight_id)
	return (found_v as ItemDef).clone() if found_v is ItemDef else null


func aliases(ability_definitions: Array, method_definitions: Array) -> Dictionary:
	_ensure_loaded(ability_definitions, method_definitions)
	return _aliases.duplicate(true) if _valid else {}


func collect_errors() -> PackedStringArray:
	return _errors.duplicate()


static func validate_roots(
		items_root: Variant,
		templates_root: Variant,
		aliases_root: Variant,
		ability_definitions: Array,
		method_definitions: Array,
		paths: Dictionary = {}
) -> PackedStringArray:
	var resolved_paths := _resolved_fixture_paths(paths)
	var errors: PackedStringArray = []
	_validate_root(items_root, str(resolved_paths.items), "items", errors)
	_validate_root(templates_root, str(resolved_paths.templates), "templates", errors)
	_validate_root(aliases_root, str(resolved_paths.aliases), "aliases", errors)
	if not errors.is_empty():
		return errors
	_validate_item_rows(items_root as Dictionary, str(resolved_paths.items), errors)
	_validate_template_rows(templates_root as Dictionary, str(resolved_paths.templates), errors)
	_validate_alias_rows(aliases_root as Dictionary, str(resolved_paths.aliases), errors)
	var source_ids := _validate_source_definitions(ability_definitions, method_definitions, errors)
	if not errors.is_empty():
		return errors
	var candidate_rows := _build_candidate_rows(
		items_root as Dictionary,
		templates_root as Dictionary,
		ability_definitions,
		method_definitions
	)
	_validate_candidate_references(candidate_rows, aliases_root as Dictionary, source_ids, resolved_paths, errors)
	return errors


func _ensure_loaded(ability_definitions: Array, method_definitions: Array) -> void:
	if not _load_attempted:
		reload(ability_definitions, method_definitions)


func _commit_roots(
		items_root: Variant,
		templates_root: Variant,
		aliases_root: Variant,
		ability_definitions: Array,
		method_definitions: Array,
		paths: Dictionary
) -> bool:
	var errors := validate_roots(
		items_root,
		templates_root,
		aliases_root,
		ability_definitions,
		method_definitions,
		paths
	)
	if not errors.is_empty():
		return _reject(errors)
	var candidate_rows := _build_candidate_rows(
		items_root as Dictionary,
		templates_root as Dictionary,
		ability_definitions,
		method_definitions
	)
	var candidate_definitions: Array = []
	var candidate_by_id: Dictionary = {}
	var candidate_by_fight_id: Dictionary = {}
	for row_v in candidate_rows:
		var definition: ItemDef = ItemDefScript.from_dict(row_v as Dictionary)
		if definition == null:
			return _reject(PackedStringArray([_message(
				"definition_build_failed", str(paths.items), "items", str((row_v as Dictionary).get("id", ""))
			)]))
		candidate_definitions.append(definition)
		candidate_by_id[definition.id] = definition
		if definition.fight_id > 0:
			candidate_by_fight_id[definition.fight_id] = definition
	var candidate_aliases := _alias_map(aliases_root as Dictionary)
	_definitions = candidate_definitions
	_by_id = candidate_by_id
	_by_fight_id = candidate_by_fight_id
	_aliases = candidate_aliases
	_errors.clear()
	_valid = true
	return true


func _reject(errors: PackedStringArray) -> bool:
	_errors = errors.duplicate()
	for message in _errors:
		push_error(message)
	return false


static func _build_candidate_rows(
		items_root: Dictionary,
		templates_root: Dictionary,
		ability_definitions: Array,
		method_definitions: Array
) -> Array:
	var out := _sorted_rows(items_root)
	var existing_ids: Dictionary = {}
	var existing_ability_targets: Dictionary = {}
	var existing_method_targets: Dictionary = {}
	for row_v in out:
		var row := row_v as Dictionary
		existing_ids[str(row.get("id", ""))] = true
		var ability_id := str(row.get("learn_ability_id", "")).strip_edges()
		var method_id := str(row.get("learn_method_id", "")).strip_edges()
		if ability_id != "":
			existing_ability_targets[ability_id] = true
		if method_id != "":
			existing_method_targets[method_id] = true
	var templates_by_category: Dictionary = {}
	for template_v in _sorted_rows(templates_root):
		var template := template_v as Dictionary
		if bool(template.get("enabled", true)):
			templates_by_category[str(template.get("category", "")).strip_edges().to_lower()] = template
	_append_generated_rows(
		templates_by_category.get("ability", {}) as Dictionary,
		ability_definitions,
		"ability",
		out,
		existing_ids,
		existing_ability_targets
	)
	_append_generated_rows(
		templates_by_category.get("method", {}) as Dictionary,
		method_definitions,
		"method",
		out,
		existing_ids,
		existing_method_targets
	)
	return out


static func _append_generated_rows(
		template: Dictionary,
		source_definitions: Array,
		category: String,
		out: Array,
		existing_ids: Dictionary,
		existing_targets: Dictionary
) -> void:
	if template.is_empty():
		return
	for source_v in source_definitions:
		var source := source_v as Dictionary
		var target_id := str(source.get("id", "")).strip_edges()
		if target_id == "" or existing_targets.has(target_id):
			continue
		var item_id := _generated_learning_book_id(
			str(template.get("id_prefix", "book_skill_" if category == "ability" else "book_method_")),
			target_id,
			category
		)
		if item_id == "" or existing_ids.has(item_id):
			continue
		out.append(_build_generated_learning_book(template, source, category, item_id))
		existing_ids[item_id] = true
		existing_targets[target_id] = true


static func _build_generated_learning_book(
		template: Dictionary,
		source: Dictionary,
		category: String,
		item_id: String
) -> Dictionary:
	var source_name := str(source.get("name", item_id)).strip_edges()
	var values := {
		"name": source_name,
		"id": str(source.get("id", "")),
		"realm": str(source.get("realm", "")),
	}
	var out := {
		"id": item_id,
		"name": StringsZh.format_template(str(template.get("name_template", "{name}")), values),
		"type": str(template.get("secondary_type", template.get("type", "学习典籍"))),
		"primary_type": str(template.get("primary_type", "")),
		"secondary_type": str(template.get("secondary_type", "")),
		"quality": clampi(int(source.get("quality", template.get("quality", 1))), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME),
		"tier": EnumItemTier.clamp_tier(int(source.get("tier", template.get("tier", 1)))),
		"stackable": int(template.get("stackable", true)),
		"max_stack": maxi(1, int(template.get("max_stack", 9))),
		"desc": StringsZh.format_template(str(template.get("desc_template", "研读后习得{name}。")), values),
		"icon": str(template.get("icon", "")),
		"use_effect": [],
		"fight_effect": [],
	}
	if category == "ability":
		out["learn_ability_id"] = str(source.get("id", ""))
	else:
		out["learn_method_id"] = str(source.get("id", ""))
	return out


static func _generated_learning_book_id(prefix: String, target_id: String, category: String) -> String:
	var suffix := target_id.strip_edges()
	if category == "ability" and suffix.begins_with("ability.combat."):
		suffix = suffix.trim_prefix("ability.combat.")
	elif category == "ability" and suffix.begins_with("ability."):
		suffix = suffix.trim_prefix("ability.")
	elif category == "method" and suffix.begins_with("method."):
		suffix = suffix.trim_prefix("method.")
	suffix = suffix.replace(".", "_").replace("/", "_").replace("-", "_")
	return "%s%s" % [prefix.strip_edges(), suffix]


static func _validate_root(value: Variant, path: String, table: String, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append(_message("invalid_root", path, table, "root"))


static func _validate_item_rows(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	if rows.size() != EXPECTED_BASE_COUNT:
		errors.append(_message("base_count", path, "items", "root"))
	var item_ids: Dictionary = {}
	var fight_ids: Dictionary = {}
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, "items", key))
			continue
		var row := row_v as Dictionary
		if not row.get("id") is String or str(row.get("id")).strip_edges() != key:
			errors.append(_message("id_mismatch", path, "items", "%s.id" % key))
		var item_id := str(row.get("id", "")).strip_edges()
		if item_id != "":
			if item_ids.has(item_id):
				errors.append(_message("duplicate_item_id", path, "items", "%s.id" % key))
			item_ids[item_id] = true
		for field in ["name", "type", "primary_type", "secondary_type", "desc", "icon"]:
			_required_string(row, field, path, "items", "%s.%s" % [key, field], errors, field in ["desc", "icon"])
		for field in ["quality", "tier", "ling_shi", "stackable", "max_stack"]:
			if not _is_integer_number(row.get(field)):
				errors.append(_message("invalid_integer", path, "items", "%s.%s" % [key, field]))
		for field in ["use_effect", "fight_effect"]:
			if not row.get(field) is Array:
				errors.append(_message("invalid_array", path, "items", "%s.%s" % [key, field]))
		for field in ["fight_id", "fight_cd"]:
			if row.get(field) != null and not _is_numeric_cell(row.get(field)):
				errors.append(_message("invalid_numeric_cell", path, "items", "%s.%s" % [key, field]))
		var fight_id := int(row.get("fight_id", 0)) if row.get("fight_id") != null else 0
		if fight_id > 0:
			if fight_ids.has(fight_id):
				errors.append(_message("duplicate_fight_id", path, "items", "%s.fight_id" % key))
			fight_ids[fight_id] = true


static func _validate_template_rows(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	if rows.size() != EXPECTED_TEMPLATE_COUNT:
		errors.append(_message("template_count", path, "templates", "root"))
	var categories: Dictionary = {}
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, "templates", key))
			continue
		var row := row_v as Dictionary
		if not row.get("key") is String or str(row.get("key")).strip_edges() != key:
			errors.append(_message("key_mismatch", path, "templates", "%s.key" % key))
		var category := str(row.get("category", "")).strip_edges().to_lower()
		if not row.get("category") is String or category not in ["ability", "method"]:
			errors.append(_message("category_invalid", path, "templates", "%s.category" % key))
		elif categories.has(category):
			errors.append(_message("category_duplicate", path, "templates", "%s.category" % key))
		categories[category] = true
		if not row.get("enabled") is bool:
			errors.append(_message("enabled_type", path, "templates", "%s.enabled" % key))
		for field in ["id_prefix", "type", "primary_type", "secondary_type", "icon", "name_template", "desc_template"]:
			_required_string(row, field, path, "templates", "%s.%s" % [key, field], errors)
		if not row.get("stackable") is bool:
			errors.append(_message("stackable_type", path, "templates", "%s.stackable" % key))
		if not _is_integer_number(row.get("max_stack")) or int(row.get("max_stack", 0)) < 1:
			errors.append(_message("max_stack_invalid", path, "templates", "%s.max_stack" % key))
	for category in ["ability", "method"]:
		if not categories.has(category):
			errors.append(_message("category_missing", path, "templates", category))


static func _validate_alias_rows(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	if rows.size() != EXPECTED_ALIAS_COUNT:
		errors.append(_message("alias_count", path, "aliases", "root"))
	for key_v in rows.keys():
		var key := str(key_v).strip_edges()
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, "aliases", key))
			continue
		var row := row_v as Dictionary
		if not row.get("key") is String or str(row.get("key")).strip_edges() != key:
			errors.append(_message("key_mismatch", path, "aliases", "%s.key" % key))
		if not row.get("value") is String or str(row.get("value")).strip_edges() == "":
			errors.append(_message("alias_value_invalid", path, "aliases", "%s.value" % key))


static func _validate_source_definitions(
		ability_definitions: Array,
		method_definitions: Array,
		errors: PackedStringArray
) -> Dictionary:
	var source_ids: Dictionary = {"ability": {}, "method": {}}
	for spec in [["ability", ability_definitions, 39], ["method", method_definitions, 83]]:
		var category := str(spec[0])
		var rows := spec[1] as Array
		if rows.size() != int(spec[2]):
			errors.append(_message("source_count", "application://%s" % category, category, "root"))
		for index in rows.size():
			var row_v: Variant = rows[index]
			if not row_v is Dictionary:
				errors.append(_message("source_row_invalid", "application://%s" % category, category, str(index)))
				continue
			var row := row_v as Dictionary
			var source_id := str(row.get("id", "")).strip_edges()
			if source_id == "" or (source_ids[category] as Dictionary).has(source_id):
				errors.append(_message("source_id_invalid", "application://%s" % category, category, "%d.id" % index))
			(source_ids[category] as Dictionary)[source_id] = true
			for field in ["name", "quality", "tier"]:
				if not row.has(field):
					errors.append(_message("source_field_missing", "application://%s" % category, category, "%s.%s" % [source_id, field]))
	return source_ids


static func _validate_candidate_references(
		candidate_rows: Array,
		aliases_root: Dictionary,
		source_ids: Dictionary,
		paths: Dictionary,
		errors: PackedStringArray
) -> void:
	var item_ids: Dictionary = {}
	var ability_targets: Dictionary = {}
	var method_targets: Dictionary = {}
	for index in candidate_rows.size():
		var row := candidate_rows[index] as Dictionary
		var item_id := str(row.get("id", "")).strip_edges()
		if item_id == "" or item_ids.has(item_id):
			errors.append(_message("duplicate_item_id", str(paths.items), "items", "%d.id" % index))
		item_ids[item_id] = true
		var ability_id := str(row.get("learn_ability_id", "")).strip_edges()
		if ability_id != "":
			if ability_targets.has(ability_id):
				errors.append(_message("duplicate_generated_target", str(paths.templates), "templates", ability_id))
			if not (source_ids.ability as Dictionary).has(ability_id):
				errors.append(_message("generated_target_unknown", str(paths.templates), "templates", ability_id))
			ability_targets[ability_id] = true
		var method_id := str(row.get("learn_method_id", "")).strip_edges()
		if method_id != "":
			if method_targets.has(method_id):
				errors.append(_message("duplicate_generated_target", str(paths.templates), "templates", method_id))
			if not (source_ids.method as Dictionary).has(method_id):
				errors.append(_message("generated_target_unknown", str(paths.templates), "templates", method_id))
			method_targets[method_id] = true
	var aliases := _alias_map(aliases_root)
	for alias_v in aliases.keys():
		var alias := str(alias_v)
		var canonical := _resolve_alias(alias, aliases)
		if canonical == "":
			errors.append(_message("alias_cycle", str(paths.aliases), "aliases", alias))
		elif not item_ids.has(canonical):
			errors.append(_message("alias_target_unknown", str(paths.aliases), "aliases", alias))


static func _alias_map(rows: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row_v in rows.values():
		if row_v is Dictionary:
			var row := row_v as Dictionary
			out[str(row.get("key", "")).strip_edges()] = str(row.get("value", "")).strip_edges()
	return out


static func _resolve_alias(item_id: String, aliases: Dictionary) -> String:
	var current := item_id.strip_edges()
	var seen: Dictionary = {}
	while aliases.has(current):
		if seen.has(current):
			return ""
		seen[current] = true
		current = str(aliases[current]).strip_edges()
	return current


static func _sorted_rows(rows: Dictionary) -> Array:
	var keys: Array = rows.keys()
	keys.sort_custom(ExportTableReaderScript.compare_keys)
	var out: Array = []
	for key_v in keys:
		out.append((rows[key_v] as Dictionary).duplicate(true))
	return out


static func _required_string(
		row: Dictionary,
		field: String,
		path: String,
		table: String,
		qualified_field: String,
		errors: PackedStringArray,
		allow_empty: bool = false
) -> void:
	if not row.get(field) is String or (not allow_empty and str(row.get(field)).strip_edges() == ""):
		errors.append(_message("required_string", path, table, qualified_field))


static func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(float(value), roundf(float(value))))


static func _is_numeric_cell(value: Variant) -> bool:
	return value is int or value is float or (value is String and str(value).is_valid_float())


static func _resolved_fixture_paths(paths: Dictionary) -> Dictionary:
	return {
		"items": str(paths.get("items", "fixture://item_items.json")),
		"templates": str(paths.get("templates", "fixture://item_generated_learning_books.json")),
		"aliases": str(paths.get("aliases", "fixture://item_legacy_learning_book_ali.json")),
	}


static func _message(code: String, path: String, table: String, field: String) -> String:
	return "[item_catalog:%s] file=%s table=%s field=%s" % [code, path, table, field]
