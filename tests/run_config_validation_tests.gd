extends SceneTree

const ConfigValidatorScript := preload("res://scripts/core/config_validator.gd")
const ExpeditionDataValidatorScript := preload("res://scripts/expedition/expedition_data_validator.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")
const TagServiceScript := preload("res://scripts/sim/tag_service.gd")
const DropPoolServiceScript := preload("res://scripts/sim/drop_pool_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("config validator reports no errors on boot data", _test_config_has_no_errors)
	_run("realm balance covers simulation realms", _test_realm_balance_covers_simulation_realms)
	_run("location service reads cached config", _test_location_service_cached)
	_run("modular location validator rejects legacy fields", _test_modular_location_validator_rejects_legacy_fields)
	_run("tag service aggregates modular tags", _test_tag_service_aggregates_tags)
	_run("drop pool service rolls deterministic rewards", _test_drop_pool_service_deterministic)
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


func _test_modular_location_validator_rejects_legacy_fields() -> void:
	var legacy := {
		"recommended_realm": "炼气一层",
		"tags": [],
		"event_pool": ["qinglan_wolf"],
		"enemy_pools": {},
		"drop_pools": {},
		"expedition_mode": "resource",
		"common_event_generation": {},
		"common_event_pool": [],
		"map_event_pool": [],
	}
	var errors: PackedStringArray = ExpeditionDataValidatorScript._validate_location(legacy, "legacy_location")
	_expect_true(_has_error_containing(errors, "旧字段 expedition_mode"), "rejects expedition_mode")
	_expect_true(_has_error_containing(errors, "旧字段 common_event_generation"), "rejects generation")
	_expect_true(_has_error_containing(errors, "旧字段 common_event_pool"), "rejects common pool")
	_expect_true(_has_error_containing(errors, "旧字段 map_event_pool"), "rejects map pool")


func _test_tag_service_aggregates_tags() -> void:
	var stats := TagServiceScript.collect_tag_stats([
		{"tags": ["fire", "spell"]},
		{"tags": ["fire", "shield"]},
		{"tags": ["spell"]},
	])
	_expect_eq(int(stats.get("fire", 0)), 2, "fire tag count")
	_expect_eq(int(stats.get("spell", 0)), 2, "spell tag count")
	_expect_eq(int(stats.get("shield", 0)), 1, "shield tag count")


func _test_drop_pool_service_deterministic() -> void:
	var event := ExpeditionEventServiceScript.by_id("blackwater_marsh__gather_herbs")
	var rewards_a := DropPoolServiceScript.roll_event_rewards(event, _rng(9090))
	var rewards_b := DropPoolServiceScript.roll_event_rewards(event, _rng(9090))
	_expect_eq(rewards_a, rewards_b, "same seed same modular drop")
	_expect_true(not rewards_a.is_empty(), "drop pool produces reward")


func _has_error_containing(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if str(error).contains(needle):
			return true
	return false


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %.3f, got %.3f" % [message, expected, actual])
