extends SceneTree

const ConfigValidatorScript := preload("res://scripts/core/config_validator.gd")
const ExpeditionDataValidatorScript := preload("res://scripts/expedition/expedition_data_validator.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("config validator reports no errors on boot data", _test_config_has_no_errors)
	_run("realm balance covers simulation realms", _test_realm_balance_covers_simulation_realms)
	_run("location service reads cached config", _test_location_service_cached)
	_run("expedition mode validator reports pool mistakes", _test_expedition_mode_validator_reports_pool_mistakes)
	if _failures.is_empty():
		print("PASS: %d config validation tests" % _tests_run)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _run(name: String, test: Callable) -> void:
	_tests_run += 1
	var before := _failures.size()
	test.call()
	if before == _failures.size():
		print("PASS: %s" % name)


func _config_manager() -> Node:
	return root.get_node("ConfigManager")


func _test_config_has_no_errors() -> void:
	var cm := _config_manager()
	var game := root.get_node("GameState")
	var errors: PackedStringArray = ConfigValidatorScript.collect_all_errors(cm, game)
	_expect_true(errors.is_empty(), "config errors: %s" % str(errors))


func _test_realm_balance_covers_simulation_realms() -> void:
	var simulation := JsonLoader._read_json_root_object("res://data/simulation.json")
	var errors := RealmBalanceServiceScript.collect_config_errors(simulation.get("realms", []) as Array)
	_expect_true(errors.is_empty(), "realm balance errors: %s" % str(errors))
	var qi := RealmBalanceServiceScript.major_realm_by_id("qi")
	_expect_eq(str(qi.get("name", "")), "炼气", "qi realm configured")
	var mods := RealmBalanceServiceScript.realm_flat_modifiers(2)
	_expect_near(float(mods.get(FightAttr.HP_MAX, 0.0)), 12.0, "realm layer hp modifier")


func _test_location_service_cached() -> void:
	var location: Dictionary = LocationServiceScript.by_id("qinglan_mountain")
	_expect_true(not location.is_empty(), "location loaded from cache")
	_expect_eq(str(location.get("name", "")), "青岚山脉", "location name")


func _test_expedition_mode_validator_reports_pool_mistakes() -> void:
	var resource_with_map := {
		"expedition_mode": "resource",
		"common_event_generation": {"duration_days": {"gather": 1}, "reward_pools": {"herbs": []}, "enemy_pools": {"beast": {}}},
	}
	var errors := ExpeditionDataValidatorScript._validate_location_expedition_mode(
		resource_with_map, "bad_resource", ["gather_herbs"], ["qinglan_wolf"]
	)
	_expect_true(_has_error_containing(errors, "不能配置 map_event_pool"), "resource mode rejects map pool")
	var story_with_common := {"expedition_mode": "story"}
	errors = ExpeditionDataValidatorScript._validate_location_expedition_mode(
		story_with_common, "bad_story", ["gather_herbs"], ["qinglan_wolf"]
	)
	_expect_true(_has_error_containing(errors, "不能配置 common_event_pool"), "story mode rejects common pool")
	var resource_without_generation := {"expedition_mode": "resource"}
	errors = ExpeditionDataValidatorScript._validate_location_expedition_mode(
		resource_without_generation, "no_generation", ["gather_herbs"], []
	)
	_expect_true(_has_error_containing(errors, "缺少 common_event_generation"), "resource mode requires generation")
	var story_without_map := {"expedition_mode": "story"}
	errors = ExpeditionDataValidatorScript._validate_location_expedition_mode(
		story_without_map, "no_story_events", [], []
	)
	_expect_true(_has_error_containing(errors, "必须配置 map_event_pool"), "story mode requires map pool")


func _has_error_containing(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if str(error).contains(needle):
			return true
	return false


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %.3f, got %.3f" % [message, expected, actual])
