class_name WorldMapCatalog
extends RefCounted

const META_PATH := "res://data/exportjson/shijie_map.json"
const CITIES_PATH := "res://data/exportjson/shijie_map_cities.json"
const ROUTES_PATH := "res://data/exportjson/shijie_map_routes.json"
const REGIONS_PATH := "res://data/exportjson/shijie_map_wilderness_regions.json"
const LOCATIONS_PATH := "res://data/exportjson/shijie_map_wilderness_locatio.json"

const VALID_ROUTE_STATES := ["open", "blocked"]

var _paths: Dictionary
var _load_attempted := false
var _valid := false
var _meta: Dictionary = {}
var _cities: Dictionary = {}
var _routes: Array = []
var _regions: Dictionary = {}
var _locations: Dictionary = {}


func _init(paths: Dictionary = {}) -> void:
	_paths = {
		"meta": META_PATH,
		"cities": CITIES_PATH,
		"routes": ROUTES_PATH,
		"regions": REGIONS_PATH,
		"locations": LOCATIONS_PATH,
	}
	for key_v in paths.keys():
		if _paths.has(key_v):
			_paths[key_v] = str(paths[key_v])


func meta() -> Dictionary:
	_ensure_loaded()
	return _meta.duplicate(true) if _valid else {}


func city_by_id(city_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var id := city_id.strip_edges()
	var row_v: Variant = _cities.get(id)
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


func all_city_ids() -> Array:
	_ensure_loaded()
	return _sorted_ids(_cities) if _valid else []


func all_routes() -> Array:
	_ensure_loaded()
	return _routes.duplicate(true) if _valid else []


func wilderness_region_by_id(region_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var id := region_id.strip_edges()
	var row_v: Variant = _regions.get(id)
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


func all_wilderness_region_ids() -> Array:
	_ensure_loaded()
	return _sorted_ids(_regions) if _valid else []


func wilderness_location_by_id(location_id: String) -> Dictionary:
	_ensure_loaded()
	if not _valid:
		return {}
	var id := location_id.strip_edges()
	var row_v: Variant = _locations.get(id)
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


func all_wilderness_location_ids() -> Array:
	_ensure_loaded()
	return _sorted_ids(_locations) if _valid else []


static func validate_tables(
	meta_table: Dictionary,
	cities: Dictionary,
	routes: Array,
	regions: Dictionary,
	locations: Dictionary,
	paths: Dictionary = {}
) -> PackedStringArray:
	var resolved_paths := {
		"meta": str(paths.get("meta", META_PATH)),
		"cities": str(paths.get("cities", CITIES_PATH)),
		"routes": str(paths.get("routes", ROUTES_PATH)),
		"regions": str(paths.get("regions", REGIONS_PATH)),
		"locations": str(paths.get("locations", LOCATIONS_PATH)),
	}
	var errors := PackedStringArray()
	_validate_meta(meta_table, resolved_paths["meta"], errors)
	_validate_cities(cities, resolved_paths["cities"], errors)
	_validate_routes(routes, cities, resolved_paths["routes"], errors)
	_validate_regions(regions, cities, locations, resolved_paths["regions"], errors)
	_validate_locations(locations, regions, resolved_paths["locations"], errors)
	var starter_id := str(meta_table.get("starter_city_id", "")).strip_edges()
	if starter_id != "" and not cities.has(starter_id):
		errors.append(_message("unknown_reference", resolved_paths["meta"], "starter_city_id"))
	return errors


func _ensure_loaded() -> void:
	if _load_attempted:
		return
	_load_attempted = true
	for key in ["meta", "cities", "routes", "regions", "locations"]:
		var path := str(_paths[key])
		if not FileAccess.file_exists(path):
			_fail("missing_file", path, "root")
			return
		var root_v: Variant = JsonReader.read_variant(path)
		if root_v == null:
			_fail("invalid_json", path, "root")
			return
		if not root_v is Dictionary:
			_fail("invalid_root", path, "root")
			return
		for row_key_v in (root_v as Dictionary).keys():
			if not (root_v as Dictionary)[row_key_v] is Dictionary:
				_fail("invalid_row", path, str(row_key_v))
				return
	var meta_table := ExportTableReader.read_settings(str(_paths["meta"]))
	var cities := ExportTableReader.read_keyed_rows(str(_paths["cities"]))
	var routes := ExportTableReader.read_row_array(str(_paths["routes"]))
	var regions := ExportTableReader.read_keyed_rows(str(_paths["regions"]))
	var locations := ExportTableReader.read_keyed_rows(str(_paths["locations"]))
	var errors := validate_tables(meta_table, cities, routes, regions, locations, _paths)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		_clear_bundle()
		return
	_meta = meta_table.duplicate(true)
	_cities = cities.duplicate(true)
	_routes = routes.duplicate(true)
	_regions = regions.duplicate(true)
	_locations = locations.duplicate(true)
	_valid = true


func _fail(code: String, file_path: String, field: String) -> void:
	push_error(_message(code, file_path, field))
	_clear_bundle()


func _clear_bundle() -> void:
	_valid = false
	_meta.clear()
	_cities.clear()
	_routes.clear()
	_regions.clear()
	_locations.clear()


static func _validate_meta(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	if typeof(table.get("schema_version")) != TYPE_INT or int(table.get("schema_version", 0)) < 1:
		errors.append(_message("invalid_type", path, "schema_version"))
	if typeof(table.get("starter_city_id")) != TYPE_STRING \
			or str(table.get("starter_city_id", "")).strip_edges() == "":
		errors.append(_message("required_string", path, "starter_city_id"))


static func _validate_cities(table: Dictionary, path: String, errors: PackedStringArray) -> void:
	for key_v in table.keys():
		var id := str(key_v)
		var row_v: Variant = table[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, id))
			continue
		var row := row_v as Dictionary
		_validate_key_and_name(id, row, path, errors)
		_validate_position(row.get("position"), path, "%s.position" % id, errors)
		_validate_string(row.get("type"), path, "%s.type" % id, errors)
		_validate_string(row.get("desc"), path, "%s.desc" % id, errors)
		_validate_string_array(row.get("services"), path, "%s.services" % id, errors)


static func _validate_routes(
	routes: Array,
	cities: Dictionary,
	path: String,
	errors: PackedStringArray
) -> void:
	var seen_pairs := {}
	for index in routes.size():
		var row_v: Variant = routes[index]
		var field := "routes[%d]" % index
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, field))
			continue
		var row := row_v as Dictionary
		var from_id := str(row.get("from", "")).strip_edges()
		var to_id := str(row.get("to", "")).strip_edges()
		if from_id == "" or not cities.has(from_id):
			errors.append(_message("unknown_reference", path, "%s.from" % field))
		if to_id == "" or not cities.has(to_id):
			errors.append(_message("unknown_reference", path, "%s.to" % field))
		if from_id != "" and from_id == to_id:
			errors.append(_message("self_route", path, field))
		if not _is_integer_number(row.get("days")) or int(row.get("days", 0)) < 1:
			errors.append(_message("invalid_range", path, "%s.days" % field))
		var state := str(row.get("default_state", "")).strip_edges()
		if typeof(row.get("default_state")) != TYPE_STRING or state not in VALID_ROUTE_STATES:
			errors.append(_message("invalid_route_state", path, "%s.default_state" % field))
		if from_id != "" and to_id != "":
			var ids := [from_id, to_id]
			ids.sort()
			var pair := "%s|%s" % ids
			if seen_pairs.has(pair):
				errors.append(_message("duplicate_route", path, field))
			seen_pairs[pair] = true


static func _validate_regions(
	regions: Dictionary,
	cities: Dictionary,
	locations: Dictionary,
	path: String,
	errors: PackedStringArray
) -> void:
	for key_v in regions.keys():
		var id := str(key_v)
		var row_v: Variant = regions[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, id))
			continue
		var row := row_v as Dictionary
		_validate_key_and_name(id, row, path, errors)
		for field_name in ["danger", "min_difficulty", "max_difficulty"]:
			if not _is_integer_number(row.get(field_name)):
				errors.append(_message("invalid_type", path, "%s.%s" % [id, field_name]))
		var min_value := int(row.get("min_difficulty", 0))
		var max_value := int(row.get("max_difficulty", 0))
		if min_value < 1 or max_value < min_value:
			errors.append(_message("invalid_range", path, "%s.difficulty" % id))
		_validate_string_array(row.get("near_city"), path, "%s.near_city" % id, errors)
		for city_v in row.get("near_city", []) if row.get("near_city") is Array else []:
			if not cities.has(str(city_v)):
				errors.append(_message("unknown_reference", path, "%s.near_city" % id))
		_validate_string_array(row.get("sub_locations"), path, "%s.sub_locations" % id, errors)
		for location_v in row.get("sub_locations", []) if row.get("sub_locations") is Array else []:
			var location_id := str(location_v)
			if not locations.has(location_id):
				errors.append(_message("unknown_reference", path, "%s.sub_locations" % id))
			elif str((locations[location_id] as Dictionary).get("parent_region", "")) != id:
				errors.append(_message("parent_mismatch", path, "%s.sub_locations" % id))
		_validate_point_array(row.get("polygon"), path, "%s.polygon" % id, errors)
		_validate_string_array(row.get("environment_tags"), path, "%s.environment_tags" % id, errors)
		_validate_string_array(row.get("preview_rewards"), path, "%s.preview_rewards" % id, errors)
		_validate_string(row.get("recommended_realm"), path, "%s.recommended_realm" % id, errors)
		_validate_string(row.get("lilian_location_id"), path, "%s.lilian_location_id" % id, errors)


static func _validate_locations(
	locations: Dictionary,
	regions: Dictionary,
	path: String,
	errors: PackedStringArray
) -> void:
	for key_v in locations.keys():
		var id := str(key_v)
		var row_v: Variant = locations[key_v]
		if not row_v is Dictionary:
			errors.append(_message("invalid_row", path, id))
			continue
		var row := row_v as Dictionary
		_validate_key_and_name(id, row, path, errors)
		var parent_id := str(row.get("parent_region", "")).strip_edges()
		if parent_id == "" or not regions.has(parent_id):
			errors.append(_message("unknown_reference", path, "%s.parent_region" % id))
		_validate_position(row.get("position"), path, "%s.position" % id, errors)
		if typeof(row.get("reveal_radius")) not in [TYPE_INT, TYPE_FLOAT] \
				or float(row.get("reveal_radius", 0.0)) <= 0.0:
			errors.append(_message("invalid_range", path, "%s.reveal_radius" % id))
		if not _is_integer_number(row.get("danger")) or int(row.get("danger", -1)) < 0:
			errors.append(_message("invalid_range", path, "%s.danger" % id))
		if row.has("default_discovered") and typeof(row["default_discovered"]) != TYPE_BOOL:
			errors.append(_message("invalid_type", path, "%s.default_discovered" % id))
		_validate_string_array(row.get("environment_tags"), path, "%s.environment_tags" % id, errors)
		_validate_string_array(row.get("preview_rewards"), path, "%s.preview_rewards" % id, errors)
		_validate_string_array(row.get("services"), path, "%s.services" % id, errors)
		_validate_string(row.get("recommended_realm"), path, "%s.recommended_realm" % id, errors)
		_validate_string(row.get("lilian_location_id"), path, "%s.lilian_location_id" % id, errors)


static func _validate_key_and_name(
	id: String,
	row: Dictionary,
	path: String,
	errors: PackedStringArray
) -> void:
	if id.strip_edges() == "" or str(row.get("key", "")).strip_edges() != id:
		errors.append(_message("key_mismatch", path, "%s.key" % id))
	_validate_string(row.get("name"), path, "%s.name" % id, errors)


static func _validate_position(value: Variant, path: String, field: String, errors: PackedStringArray) -> void:
	if not value is Array or (value as Array).size() != 2:
		errors.append(_message("invalid_position", path, field))
		return
	for cell_v in value as Array:
		if typeof(cell_v) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append(_message("invalid_position", path, field))
			return


static func _validate_point_array(value: Variant, path: String, field: String, errors: PackedStringArray) -> void:
	if not value is Array or (value as Array).size() < 3:
		errors.append(_message("invalid_polygon", path, field))
		return
	for point_v in value as Array:
		if not point_v is Array or (point_v as Array).size() != 2:
			errors.append(_message("invalid_polygon", path, field))
			return
		for cell_v in point_v as Array:
			if typeof(cell_v) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append(_message("invalid_polygon", path, field))
				return


static func _validate_string(value: Variant, path: String, field: String, errors: PackedStringArray) -> void:
	if typeof(value) != TYPE_STRING or str(value).strip_edges() == "":
		errors.append(_message("required_string", path, field))


static func _validate_string_array(value: Variant, path: String, field: String, errors: PackedStringArray) -> void:
	if not value is Array:
		errors.append(_message("invalid_type", path, field))
		return
	for cell_v in value as Array:
		if typeof(cell_v) != TYPE_STRING or str(cell_v).strip_edges() == "":
			errors.append(_message("invalid_type", path, field))
			return


static func _sorted_ids(table: Dictionary) -> Array:
	var ids: Array = table.keys()
	ids.sort_custom(ExportTableReader.compare_keys)
	return ids


static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	return is_equal_approx(float(value), floor(float(value)))


static func _message(code: String, file_path: String, field: String) -> String:
	return "[world_map_catalog:%s] file=%s field=%s" % [code, file_path, field]
