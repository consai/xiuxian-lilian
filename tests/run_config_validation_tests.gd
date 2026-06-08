extends SceneTree

const ConfigValidatorScript := preload("res://scripts/core/config_validator.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("config validator reports no errors on boot data", _test_config_has_no_errors)
	_run("location service reads cached config", _test_location_service_cached)
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


func _test_location_service_cached() -> void:
	var location: Dictionary = LocationServiceScript.by_id("qinglan_mountain")
	_expect_true(not location.is_empty(), "location loaded from cache")
	_expect_eq(str(location.get("name", "")), "青岚山脉", "location name")


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
