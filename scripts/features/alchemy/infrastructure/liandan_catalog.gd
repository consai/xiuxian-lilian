class_name LiandanCatalog
extends RefCounted

const SETTINGS_PATH := "res://data/exportjson/liandan.json"
const FURNACES_PATH := "res://data/exportjson/liandan_furnaces.json"
const RECIPES_PATH := "res://data/exportjson/liandan_recipes.json"
const STRATEGIES_PATH := "res://data/exportjson/liandan_strategies.json"

const EXPECTED_FURNACE_COUNT := 2
const EXPECTED_RECIPE_COUNT := 6
const EXPECTED_STRATEGY_COUNT := 2
const PRODUCT_QUALITIES := ["low", "medium", "high", "supreme"]

const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _errors: PackedStringArray = []
var _root: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = {
		"settings": str(paths.get("settings", SETTINGS_PATH)),
		"furnaces": str(paths.get("furnaces", FURNACES_PATH)),
		"recipes": str(paths.get("recipes", RECIPES_PATH)),
		"strategies": str(paths.get("strategies", STRATEGIES_PATH)),
	}


func reload(known_item_ids: Dictionary) -> bool:
	_load_attempted = true
	var roots: Dictionary = {}
	var errors: PackedStringArray = []
	for table in ["settings", "furnaces", "recipes", "strategies"]:
		var path := str(_paths[table])
		var value: Variant = JsonReaderScript.read_variant(path)
		if value == null:
			errors.append(_message("unreadable_file", path, table, "root"))
		elif not value is Dictionary:
			errors.append(_message("invalid_root", path, table, "root"))
		else:
			roots[table] = value
	if not errors.is_empty():
		return _reject(errors)
	return reload_from_roots(roots.settings, roots.furnaces, roots.recipes, roots.strategies, known_item_ids, _paths)


func reload_from_roots(
		settings_root: Variant,
		furnaces_root: Variant,
		recipes_root: Variant,
		strategies_root: Variant,
		known_item_ids: Dictionary,
		paths: Dictionary = {}
) -> bool:
	_load_attempted = true
	var resolved_paths := _resolved_fixture_paths(paths)
	var errors := validate_roots(settings_root, furnaces_root, recipes_root, strategies_root, known_item_ids, resolved_paths)
	if not errors.is_empty():
		return _reject(errors)
	var candidate := {
		"schema_version": int(((settings_root as Dictionary).get("schema_version", {}) as Dictionary).get("value", 0)),
		"furnaces": _decode_rows(furnaces_root as Dictionary),
		"recipes": _decode_rows(recipes_root as Dictionary),
		"strategies": _decode_rows(strategies_root as Dictionary),
	}
	_root = candidate
	_errors.clear()
	_valid = true
	return true


func all_recipes(known_item_ids: Dictionary) -> Array:
	_ensure_loaded(known_item_ids)
	return (_root.get("recipes", []) as Array).duplicate(true) if _valid else []


func all_strategies(known_item_ids: Dictionary) -> Array:
	_ensure_loaded(known_item_ids)
	return (_root.get("strategies", []) as Array).duplicate(true) if _valid else []


func recipe_by_id(recipe_id: String, known_item_ids: Dictionary) -> Dictionary:
	return _row_by_id(all_recipes(known_item_ids), recipe_id)


func strategy_by_id(strategy_id: String, known_item_ids: Dictionary) -> Dictionary:
	return _row_by_id(all_strategies(known_item_ids), strategy_id)


func furnace_by_id(furnace_id: String, known_item_ids: Dictionary) -> Dictionary:
	_ensure_loaded(known_item_ids)
	return _row_by_id(_root.get("furnaces", []) as Array, furnace_id) if _valid else {}


func snapshot(known_item_ids: Dictionary) -> Dictionary:
	_ensure_loaded(known_item_ids)
	return _root.duplicate(true) if _valid else {}


func collect_errors() -> PackedStringArray:
	return _errors.duplicate()


static func validate_roots(
		settings_root: Variant,
		furnaces_root: Variant,
		recipes_root: Variant,
		strategies_root: Variant,
		known_item_ids: Dictionary,
		paths: Dictionary = {}
) -> PackedStringArray:
	var resolved_paths := _resolved_fixture_paths(paths)
	var errors: PackedStringArray = []
	for spec in [
		[settings_root, "settings"], [furnaces_root, "furnaces"],
		[recipes_root, "recipes"], [strategies_root, "strategies"],
	]:
		if not spec[0] is Dictionary:
			errors.append(_message("invalid_root", str(resolved_paths[spec[1]]), str(spec[1]), "root"))
	if not errors.is_empty():
		return errors
	_validate_settings(settings_root as Dictionary, str(resolved_paths.settings), errors)
	_validate_furnaces(furnaces_root as Dictionary, str(resolved_paths.furnaces), errors)
	_validate_recipes(recipes_root as Dictionary, known_item_ids, str(resolved_paths.recipes), errors)
	_validate_strategies(strategies_root as Dictionary, str(resolved_paths.strategies), errors)
	return errors


func _ensure_loaded(known_item_ids: Dictionary) -> void:
	if not _load_attempted:
		reload(known_item_ids)


func _reject(errors: PackedStringArray) -> bool:
	_errors = errors.duplicate()
	for message in _errors:
		push_error(message)
	return false


static func _validate_settings(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	var schema_v: Variant = rows.get("schema_version")
	if not schema_v is Dictionary or not _is_int((schema_v as Dictionary).get("value")) \
			or int((schema_v as Dictionary).get("value", 0)) != 1:
		errors.append(_message("schema_version_invalid", path, "settings", "schema_version.value"))


static func _validate_furnaces(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	_validate_keyed_count(rows, EXPECTED_FURNACE_COUNT, path, "furnaces", errors)
	for key_v in rows.keys():
		var key := str(key_v)
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, "furnaces", key))
			continue
		var row := row_v as Dictionary
		_validate_key_id(row, key, path, "furnaces", errors)
		_required_string(row, "name", path, "furnaces", key, errors)
		for field in ["control", "refinement", "safety", "max_durability"]:
			if not _is_number(row.get(field)):
				errors.append(_message("invalid_number", path, "furnaces", "%s.%s" % [key, field]))
		if int(row.get("max_durability", 0)) < 1:
			errors.append(_message("out_of_range", path, "furnaces", "%s.max_durability" % key))


static func _validate_recipes(rows: Dictionary, known_item_ids: Dictionary, path: String, errors: PackedStringArray) -> void:
	_validate_keyed_count(rows, EXPECTED_RECIPE_COUNT, path, "recipes", errors)
	for key_v in rows.keys():
		var key := str(key_v)
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, "recipes", key))
			continue
		var row := _decode_value(row_v) as Dictionary
		_validate_key_id(row, key, path, "recipes", errors)
		for field in ["name", "pill_name"]:
			_required_string(row, field, path, "recipes", key, errors)
		for field in ["difficulty", "base_yield", "minimum_level"]:
			if not _is_int(row.get(field)) or int(row.get(field, 0)) < 1:
				errors.append(_message("invalid_integer", path, "recipes", "%s.%s" % [key, field]))
		var ingredients_v: Variant = row.get("ingredients")
		if not ingredients_v is Array or (ingredients_v as Array).is_empty():
			errors.append(_message("ingredients_invalid", path, "recipes", "%s.ingredients" % key))
		else:
			_validate_ingredients(ingredients_v as Array, known_item_ids, path, key, errors)
		var products_v: Variant = row.get("products")
		if not products_v is Dictionary:
			errors.append(_message("products_invalid", path, "recipes", "%s.products" % key))
		else:
			for quality in PRODUCT_QUALITIES:
				if not (products_v as Dictionary).get(quality) is String or str((products_v as Dictionary).get(quality)).strip_edges() == "":
					errors.append(_message("product_reference_invalid", path, "recipes", "%s.products.%s" % [key, quality]))
				elif not known_item_ids.has(str((products_v as Dictionary).get(quality))):
					errors.append(_message("product_reference_unknown", path, "recipes", "%s.products.%s" % [key, quality]))


static func _validate_ingredients(ingredients: Array, known_item_ids: Dictionary, path: String, recipe_id: String, errors: PackedStringArray) -> void:
	for index in ingredients.size():
		var ingredient_v: Variant = ingredients[index]
		var field := "%s.ingredients[%d]" % [recipe_id, index]
		if not ingredient_v is Dictionary:
			errors.append(_message("ingredient_invalid", path, "recipes", field))
			continue
		var ingredient := ingredient_v as Dictionary
		if not ingredient.get("family") is String or str(ingredient.get("family")).strip_edges() == "":
			errors.append(_message("ingredient_family_invalid", path, "recipes", field + ".family"))
		if not _is_int(ingredient.get("count")) or int(ingredient.get("count", 0)) < 1:
			errors.append(_message("ingredient_count_invalid", path, "recipes", field + ".count"))
		if not _is_number(ingredient.get("weight")) or float(ingredient.get("weight", 0.0)) <= 0.0:
			errors.append(_message("ingredient_weight_invalid", path, "recipes", field + ".weight"))
		var options_v: Variant = ingredient.get("options")
		if not options_v is Array or (options_v as Array).is_empty():
			errors.append(_message("ingredient_options_invalid", path, "recipes", field + ".options"))
			continue
		for option_index in (options_v as Array).size():
			var option_v: Variant = (options_v as Array)[option_index]
			var option_field := "%s.options[%d]" % [field, option_index]
			if not option_v is Dictionary or not (option_v as Dictionary).get("id") is String \
					or str((option_v as Dictionary).get("id")).strip_edges() == "" \
					or not _is_int((option_v as Dictionary).get("quality")):
				errors.append(_message("ingredient_reference_invalid", path, "recipes", option_field))
			elif not known_item_ids.has(str((option_v as Dictionary).get("id"))):
				errors.append(_message("ingredient_reference_unknown", path, "recipes", option_field + ".id"))


static func _validate_strategies(rows: Dictionary, path: String, errors: PackedStringArray) -> void:
	_validate_keyed_count(rows, EXPECTED_STRATEGY_COUNT, path, "strategies", errors)
	for key_v in rows.keys():
		var key := str(key_v)
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, "strategies", key))
			continue
		var row := row_v as Dictionary
		_validate_key_id(row, key, path, "strategies", errors)
		for field in ["name", "description"]:
			_required_string(row, field, path, "strategies", key, errors)
		for field in ["score", "spread", "days", "yield", "safety"]:
			if not _is_number(row.get(field)):
				errors.append(_message("invalid_number", path, "strategies", "%s.%s" % [key, field]))
		for field in ["spread_down", "spread_up"]:
			if row.get(field) != null and not _is_int(row.get(field)):
				errors.append(_message("invalid_integer", path, "strategies", "%s.%s" % [key, field]))


static func _validate_keyed_count(rows: Dictionary, expected_count: int, path: String, table: String, errors: PackedStringArray) -> void:
	if rows.size() != expected_count:
		errors.append(_message("row_count", path, table, "root"))


static func _validate_key_id(row: Dictionary, key: String, path: String, table: String, errors: PackedStringArray) -> void:
	if not row.get("id") is String or str(row.get("id")).strip_edges() != key:
		errors.append(_message("id_mismatch", path, table, "%s.id" % key))


static func _required_string(row: Dictionary, field: String, path: String, table: String, key: String, errors: PackedStringArray) -> void:
	if not row.get(field) is String or str(row.get(field)).strip_edges() == "":
		errors.append(_message("required_string", path, table, "%s.%s" % [key, field]))


static func _decode_rows(rows: Dictionary) -> Array:
	var keys: Array = rows.keys()
	keys.sort_custom(ExportTableReaderScript.compare_keys)
	var out: Array = []
	for key_v in keys:
		out.append(_decode_value(rows[key_v]))
	return out


static func _decode_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key_v in (value as Dictionary).keys():
			var cell: Variant = (value as Dictionary)[key_v]
			if cell != null:
				out[key_v] = _decode_value(cell)
		return out
	if value is Array:
		var out: Array = []
		for cell in value as Array:
			out.append(_decode_value(cell))
		return out
	if value is String:
		var text := str(value).strip_edges()
		if text.begins_with("{") or text.begins_with("["):
			var parser := JSON.new()
			if parser.parse(text) == OK and (parser.data is Dictionary or parser.data is Array):
				return _decode_value(parser.data)
	return value


static func _row_by_id(rows: Array, target_id: String) -> Dictionary:
	for row_v in rows:
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == target_id:
			return (row_v as Dictionary).duplicate(true)
	return {}


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_int(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(float(value), floorf(float(value))))


static func _resolved_fixture_paths(paths: Dictionary) -> Dictionary:
	return {
		"settings": str(paths.get("settings", SETTINGS_PATH)),
		"furnaces": str(paths.get("furnaces", FURNACES_PATH)),
		"recipes": str(paths.get("recipes", RECIPES_PATH)),
		"strategies": str(paths.get("strategies", STRATEGIES_PATH)),
	}


static func _message(code: String, path: String, table: String, field: String) -> String:
	return "[liandan_catalog:%s] path=%s table=%s field=%s" % [code, path, table, field]
