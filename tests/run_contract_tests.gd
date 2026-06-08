extends SceneTree

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("expedition result rejects missing settlement_id", _test_expedition_result_missing_id)
	_run("expedition result accepts valid payload", _test_expedition_result_valid)
	_run("battle summary rejects invalid outcome", _test_battle_summary_invalid_outcome)
	_run("reward entry rejects empty item id", _test_reward_entry_invalid)
	_run("scene payload rejects invalid reason", _test_scene_payload_invalid_reason)
	if _failures.is_empty():
		print("PASS: %d contract tests" % _tests_run)
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


func _test_expedition_result_missing_id() -> void:
	var errors := ExpeditionResult.collect_errors({
		"exit_reason": ExpeditionResult.EXIT_MANUAL,
		"elapsed_days": 1,
		"stats": {},
		"loot": [],
		"items": [],
	})
	_expect_true(not errors.is_empty(), "missing settlement_id rejected")


func _test_expedition_result_valid() -> void:
	var errors := ExpeditionResult.collect_errors({
		"settlement_id": "expedition_test_1",
		"exit_reason": ExpeditionResult.EXIT_MANUAL,
		"elapsed_days": 1,
		"stats": {"steps": 0},
		"loot": [{"kind": "item", "id": "items_LingCao", "count": 1}],
		"items": [],
	})
	_expect_true(errors.is_empty(), "valid expedition result: %s" % str(errors))


func _test_battle_summary_invalid_outcome() -> void:
	var errors := BattleSummary.collect_errors({"outcome": "unknown"})
	_expect_true(not errors.is_empty(), "invalid outcome rejected")


func _test_reward_entry_invalid() -> void:
	var errors := RewardEntry.collect_errors({"kind": "item", "id": "", "count": 1})
	_expect_true(not errors.is_empty(), "empty item id rejected")


func _test_scene_payload_invalid_reason() -> void:
	var payload := ScenePayload.expedition_result("invalid_reason")
	_expect_true(payload.is_empty(), "invalid reason payload rejected")


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)
