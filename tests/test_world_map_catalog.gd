extends SceneTree

const WorldMapCatalogScript := preload("res://scripts/map/world_map_catalog.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	_test_production_bundle()
	_test_deep_copy_and_sorting()
	_test_validation_contract()
	_test_atomic_failure()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: world map catalog")
	quit(0)


func _test_production_bundle() -> void:
	var catalog := WorldMapCatalogScript.new()
	var expected_meta := ExportTableReaderScript.read_settings(WorldMapCatalogScript.META_PATH)
	var expected_cities := ExportTableReaderScript.read_keyed_rows(WorldMapCatalogScript.CITIES_PATH)
	var expected_routes := ExportTableReaderScript.read_row_array(WorldMapCatalogScript.ROUTES_PATH)
	var expected_regions := ExportTableReaderScript.read_keyed_rows(WorldMapCatalogScript.REGIONS_PATH)
	var expected_locations := ExportTableReaderScript.read_keyed_rows(WorldMapCatalogScript.LOCATIONS_PATH)
	_check(catalog.meta() == expected_meta, "meta remains in exported shape")
	_check(catalog.all_city_ids().size() == 4, "catalog loads four cities")
	_check(catalog.all_routes().size() == 6, "catalog loads six routes")
	_check(catalog.all_wilderness_region_ids().size() == 3, "catalog loads three regions")
	_check(catalog.all_wilderness_location_ids().size() == 5, "catalog loads five wilderness locations")
	for id_v in expected_cities.keys():
		_check(catalog.city_by_id(str(id_v)) == expected_cities[id_v], "city row %s changed" % id_v)
	_check(catalog.all_routes() == expected_routes, "route rows remain in deterministic exported order")
	for id_v in expected_regions.keys():
		_check(catalog.wilderness_region_by_id(str(id_v)) == expected_regions[id_v], "region row %s changed" % id_v)
	for id_v in expected_locations.keys():
		_check(catalog.wilderness_location_by_id(str(id_v)) == expected_locations[id_v], "location row %s changed" % id_v)
	_check(str(catalog.meta().get("starter_city_id", "")) == "qingshi_market", "known starter city changed")
	_check(str(catalog.city_by_id("yunlan_city").get("name", "")) == "云岚仙城", "known city changed")


func _test_deep_copy_and_sorting() -> void:
	var catalog := WorldMapCatalogScript.new()
	var city_ids := catalog.all_city_ids()
	_check(city_ids == _sorted_copy(city_ids), "city ids are sorted")
	var region_ids := catalog.all_wilderness_region_ids()
	_check(region_ids == _sorted_copy(region_ids), "region ids are sorted")
	var location_ids := catalog.all_wilderness_location_ids()
	_check(location_ids == _sorted_copy(location_ids), "location ids are sorted")
	var city := catalog.city_by_id("qingshi_market")
	(city["position"] as Array)[0] = -1
	(city["services"] as Array).append("mutated")
	var fresh_city := catalog.city_by_id("qingshi_market")
	_check(int((fresh_city["position"] as Array)[0]) == 146, "city position query is a deep copy")
	_check(not (fresh_city["services"] as Array).has("mutated"), "city nested array is a deep copy")
	var routes := catalog.all_routes()
	(routes[0] as Dictionary)["days"] = 999
	_check(int((catalog.all_routes()[0] as Dictionary)["days"]) == 2, "route query is a deep copy")


func _test_validation_contract() -> void:
	var meta := ExportTableReaderScript.read_settings(WorldMapCatalogScript.META_PATH)
	var cities := ExportTableReaderScript.read_keyed_rows(WorldMapCatalogScript.CITIES_PATH)
	var routes := ExportTableReaderScript.read_row_array(WorldMapCatalogScript.ROUTES_PATH)
	var regions := ExportTableReaderScript.read_keyed_rows(WorldMapCatalogScript.REGIONS_PATH)
	var locations := ExportTableReaderScript.read_keyed_rows(WorldMapCatalogScript.LOCATIONS_PATH)
	var paths := {
		"meta": "fixture://meta.json",
		"cities": "fixture://cities.json",
		"routes": "fixture://routes.json",
		"regions": "fixture://regions.json",
		"locations": "fixture://locations.json",
	}
	var bad_meta := meta.duplicate(true)
	bad_meta["schema_version"] = "1"
	var errors := WorldMapCatalogScript.validate_tables(bad_meta, cities, routes, regions, locations, paths)
	_expect_code(errors, "invalid_type", "fixture://meta.json", "schema_version")
	bad_meta = meta.duplicate(true)
	bad_meta["starter_city_id"] = "missing_city"
	errors = WorldMapCatalogScript.validate_tables(bad_meta, cities, routes, regions, locations, paths)
	_expect_code(errors, "unknown_reference", "fixture://meta.json", "starter_city_id")
	var bad_cities := cities.duplicate(true)
	(bad_cities["qingshi_market"] as Dictionary)["position"] = [146]
	errors = WorldMapCatalogScript.validate_tables(meta, bad_cities, routes, regions, locations, paths)
	_expect_code(errors, "invalid_position", "fixture://cities.json", "qingshi_market.position")
	var bad_routes := routes.duplicate(true)
	(bad_routes[0] as Dictionary)["to"] = "missing_city"
	errors = WorldMapCatalogScript.validate_tables(meta, cities, bad_routes, regions, locations, paths)
	_expect_code(errors, "unknown_reference", "fixture://routes.json", "routes[0].to")
	var bad_regions := regions.duplicate(true)
	(bad_regions["qinglan_mountain"] as Dictionary)["sub_locations"] = ["missing_location"]
	errors = WorldMapCatalogScript.validate_tables(meta, cities, routes, bad_regions, locations, paths)
	_expect_code(errors, "unknown_reference", "fixture://regions.json", "qinglan_mountain.sub_locations")
	var bad_locations := locations.duplicate(true)
	(bad_locations["wild_wolf_valley"] as Dictionary)["reveal_radius"] = "120"
	errors = WorldMapCatalogScript.validate_tables(meta, cities, routes, regions, bad_locations, paths)
	_expect_code(errors, "invalid_range", "fixture://locations.json", "wild_wolf_valley.reveal_radius")


func _test_atomic_failure() -> void:
	var missing_path := "res:/" + "/missing_world_map_routes.json"
	var catalog := WorldMapCatalogScript.new({"routes": missing_path})
	Engine.print_error_messages = false
	var routes := catalog.all_routes()
	var cities := catalog.all_city_ids()
	var meta := catalog.meta()
	Engine.print_error_messages = true
	_check(routes.is_empty(), "missing file returns no routes")
	_check(cities.is_empty(), "one failed file clears the entire bundle")
	_check(meta.is_empty(), "one failed file returns no partial metadata")


func _expect_code(errors: PackedStringArray, code: String, file_path: String, field: String) -> void:
	var expected := "[world_map_catalog:%s] file=%s field=%s" % [code, file_path, field]
	_check(expected in errors, "expected precise error %s, got %s" % [expected, str(errors)])


func _sorted_copy(values: Array) -> Array:
	var out := values.duplicate()
	out.sort_custom(ExportTableReaderScript.compare_keys)
	return out


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
