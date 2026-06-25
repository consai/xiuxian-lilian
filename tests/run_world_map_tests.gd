extends SceneTree

const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")
const WorldMapDataValidatorScript := preload("res://scripts/map/world_map_data_validator.gd")
const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("world map validator passes", _test_validator_passes)
	_run("shortest path uses minimum days", _test_shortest_path)
	_run("same city travel is zero days", _test_same_city_travel)
	_run("blocked route detours or marks blocked", _test_blocked_route)
	_run("coalesce adds map defaults", _test_coalesce_map_defaults)
	_run("go_world_map allowed when idle", _test_go_world_map_allowed)
	_run("go_world_map blocked when expedition active", _test_go_world_map_blocked)
	_run("travel discovers nearby wilderness regions", _test_travel_discovers_nearby_regions)
	_run("wilderness entry requires nearby city", _test_wilderness_entry_requires_nearby_city)
	if not _failures.is_empty():
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("All %d world map tests passed." % 9)
	quit(0)


func _run(name: String, test: Callable) -> void:
	var before := _failures.size()
	test.call()
	if before == _failures.size():
		print("PASS: %s" % name)


func _reset_game() -> void:
	root.get_node("GameState").new_game()
	root.get_node("ExpeditionState").reset()
	root.get_node("DataStore").reset_scene_runtime()


func _test_validator_passes() -> void:
	for msg in WorldMapDataValidatorScript.collect_errors():
		_failures.append("validator error: %s" % msg)


func _game_state() -> Node:
	return root.get_node("GameState")


func _test_shortest_path() -> void:
	_reset_game()
	var map_data: Dictionary = _game_state().map_data()
	var preview := WorldMapServiceScript.build_travel_preview("qingshi_market", "yunlan_city", map_data)
	_expect_true(bool(preview.get("ok", false)), "preview ok")
	_expect_eq(int(preview.get("total_days", -1)), 2, "yunlan travel days")


func _test_same_city_travel() -> void:
	_reset_game()
	var map_data: Dictionary = _game_state().map_data()
	var preview := WorldMapServiceScript.build_travel_preview("qingshi_market", "qingshi_market", map_data)
	_expect_true(bool(preview.get("ok", false)), "same city preview ok")
	_expect_eq(int(preview.get("total_days", -1)), 0, "same city zero days")


func _test_blocked_route() -> void:
	_reset_game()
	var map_data: Dictionary = _game_state().map_data()
	map_data = WorldMapServiceScript.discover_route(map_data, "qingshi_market", "yunlan_city")
	var route_states: Dictionary = map_data.get("route_states", {}) as Dictionary
	var key := WorldMapServiceScript.route_key("qingshi_market", "yunlan_city")
	route_states[key] = "blocked"
	map_data["route_states"] = route_states
	var visual := WorldMapServiceScript.route_visual_state(key, map_data, "qingshi_market")
	_expect_eq(visual, "blocked", "blocked route visual")
	var preview := WorldMapServiceScript.build_travel_preview("qingshi_market", "yunlan_city", map_data)
	_expect_true(bool(preview.get("ok", false)), "alternate route still reachable")
	_expect_eq(int(preview.get("total_days", -1)), 4, "detour via tianhe ferry")


func _test_coalesce_map_defaults() -> void:
	var ds := root.get_node("DataStore")
	var merged: Dictionary = ds.coalesce_savedata({"day": 5, "realm_index": 0, "cultivation": 0, "attrs": {}, "inventory": {}})
	_expect_true(merged.has("map"), "map key exists")
	_expect_eq(str((merged.get("map", {}) as Dictionary).get("current_city_id", "")), "qingshi_market", "starter city")


func _test_go_world_map_allowed() -> void:
	_reset_game()
	var nav: Dictionary = root.get_node("SceneManager").go_world_map()
	_expect_true(bool(nav.get("ok", false)), "world map allowed")


func _test_go_world_map_blocked() -> void:
	_reset_game()
	var expedition := root.get_node("ExpeditionState")
	var started: Dictionary = expedition.start("qinglan_mountain", root.get_node("GameState"), 88)
	_expect_true(bool(started.get("ok", false)), "expedition started")
	var nav: Dictionary = root.get_node("SceneManager").go_world_map()
	_expect_false(bool(nav.get("ok", true)), "world map blocked")
	_expect_true(expedition.active, "expedition still active")


func _test_travel_discovers_nearby_regions() -> void:
	_reset_game()
	var map_data: Dictionary = _game_state().map_data()
	_expect_false(
		"blackwater_marsh" in (map_data.get("discovered_regions", []) as Array),
		"blackwater not discovered at starter city"
	)
	var preview := WorldMapServiceScript.build_travel_preview("qingshi_market", "yunlan_city", map_data)
	_expect_true(bool(preview.get("ok", false)), "travel preview ok")
	map_data = WorldMapServiceScript.discover_along_path(map_data, preview.get("path", []) as Array)
	map_data["current_city_id"] = "yunlan_city"
	_expect_true(
		"blackwater_marsh" in (map_data.get("discovered_regions", []) as Array),
		"blackwater discovered after arriving at yunlan"
	)
	_expect_true(
		"mist_hidden_valley" in (map_data.get("discovered_regions", []) as Array),
		"mist hidden valley discovered after arriving at yunlan"
	)


func _test_wilderness_entry_requires_nearby_city() -> void:
	_reset_game()
	var map_data: Dictionary = _game_state().map_data()
	map_data["current_city_id"] = "yunlan_city"
	var qinglan := WorldMapServiceScript.can_enter_wilderness("qinglan_mountain", map_data)
	_expect_false(bool(qinglan.get("ok", true)), "qinglan blocked from yunlan")
	_expect_true(str(qinglan.get("error", "")).contains("青石坊市"), "qinglan hints entry city")
	map_data["current_city_id"] = "qingshi_market"
	var qinglan_ok := WorldMapServiceScript.can_enter_wilderness("qinglan_mountain", map_data)
	_expect_true(bool(qinglan_ok.get("ok", false)), "qinglan enterable from qingshi")
	map_data = WorldMapServiceScript.discover_regions_near_city(map_data, "yunlan_city")
	map_data["current_city_id"] = "yunlan_city"
	var marsh := WorldMapServiceScript.can_enter_wilderness("blackwater_marsh", map_data)
	_expect_true(bool(marsh.get("ok", false)), "blackwater enterable from yunlan")
	var mist := WorldMapServiceScript.can_enter_wilderness("mist_hidden_valley", map_data)
	_expect_true(bool(mist.get("ok", false)), "mist valley enterable from yunlan")
	_expect_eq(str(mist.get("location_id", "")), "mist_hidden_valley", "mist valley maps to expedition location")


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_false(value: bool, message: String) -> void:
	if value:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s got %s)" % [message, str(expected), str(actual)])
