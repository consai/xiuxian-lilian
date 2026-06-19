extends SceneTree

const GameTimeServiceScript := preload("res://scripts/sim/game_time_service.gd")
const EnumActivityTimeScript := preload("res://scripts/enum/enum_activity_time.gd")
var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("calendar formats abstract dates", _test_calendar_formats)
	_run("realm multipliers scale suggested days", _test_realm_multiplier)
	_run("activity days use time rules", _test_activity_days)
	if _failures.is_empty():
		print("PASS: %d game time tests" % _tests_run)
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


func _test_calendar_formats() -> void:
	_expect_eq(GameTimeServiceScript.date_label(1), "第1年1月1日", "day 1 date")
	_expect_eq(GameTimeServiceScript.date_label(31), "第1年2月1日", "day 31 date")
	_expect_eq(GameTimeServiceScript.date_label(361), "第2年1月1日", "day 361 date")
	_expect_eq(GameTimeServiceScript.duration_label(390), "1年1月", "duration label")


func _test_realm_multiplier() -> void:
	_expect_eq(
		GameTimeServiceScript.suggested_activity_days(EnumActivityTimeScript.LABEL_CULTIVATE, "qi"),
		7,
		"qi cultivate suggestion"
	)
	_expect_eq(
		GameTimeServiceScript.suggested_activity_days(EnumActivityTimeScript.LABEL_CULTIVATE, "core"),
		28,
		"core cultivate suggestion"
	)
	_expect_eq(
		GameTimeServiceScript.suggested_activity_days(EnumActivityTimeScript.LABEL_INSIGHT, "nascent"),
		800,
		"nascent insight suggestion"
	)


func _test_activity_days() -> void:
	_expect_eq(
		GameTimeServiceScript.days_for_activity(EnumActivityTimeScript.LABEL_ALCHEMY, "qi"),
		7,
		"qi alchemy days"
	)
	_expect_eq(
		GameTimeServiceScript.days_for_activity(EnumActivityTimeScript.LABEL_ALCHEMY, "foundation"),
		14,
		"foundation alchemy days"
	)
	_expect_eq(
		GameTimeServiceScript.days_for_activity(EnumActivityTimeScript.LABEL_EXPEDITION, "qi"),
		30,
		"qi expedition days"
	)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [label, str(expected), str(actual)])
