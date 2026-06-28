extends SceneTree

const UiDragMoveScript := preload("res://scripts/ui/components/ui_drag_move.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("expedition result rejects missing settlement_id", _test_lilian_jiesuan_missing_id)
	_run("expedition result accepts valid payload", _test_lilian_jiesuan_valid)
	_run("battle summary rejects invalid outcome", _test_battle_summary_invalid_outcome)
	_run("reward entry rejects empty item id", _test_reward_entry_invalid)
	_run("tip intent accepts reward channels", _test_tip_intent_reward_channels)
	_run("reward tip builder separates resource and growth", _test_reward_tip_builder_channels)
	_run("scene payload rejects invalid reason", _test_scene_payload_invalid_reason)
	_run("ui drag move clamps center inside viewport", _test_ui_drag_move_clamp_center)
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


func _test_lilian_jiesuan_missing_id() -> void:
	var errors := LilianResult.collect_errors({
		"exit_reason": LilianResult.EXIT_MANUAL,
		"elapsed_days": 1,
		"stats": {},
		"loot": [],
		"items": [],
	})
	_expect_true(not errors.is_empty(), "missing settlement_id rejected")


func _test_lilian_jiesuan_valid() -> void:
	var errors := LilianResult.collect_errors({
		"settlement_id": "expedition_test_1",
		"exit_reason": LilianResult.EXIT_MANUAL,
		"elapsed_days": 1,
		"stats": {"steps": 0},
		"loot": [{"kind": "item", "id": "items_LingCao", "count": 1}],
		"items": [],
	})
	_expect_true(errors.is_empty(), "valid expedition result: %s" % str(errors))


func _test_battle_summary_invalid_outcome() -> void:
	var errors := ZhandouSummary.collect_errors({"outcome": "unknown"})
	_expect_true(not errors.is_empty(), "invalid outcome rejected")


func _test_reward_entry_invalid() -> void:
	var errors := RewardEntry.collect_errors({"kind": "item", "id": "", "count": 1})
	_expect_true(not errors.is_empty(), "empty item id rejected")


func _test_tip_intent_reward_channels() -> void:
	var intent := TipIntent.make({
		"text": "获得：清心草 x1",
		"channel": TipIntent.CHANNEL_REWARD_ITEM,
	})
	_expect_eq(str(intent.get("channel", "")), TipIntent.CHANNEL_REWARD_ITEM, "reward item channel accepted")


func _test_reward_tip_builder_channels() -> void:
	var resource := RewardTipBuilder.resource("灵石", 20, "test", "ling_stones")
	_expect_eq(str(resource.get("channel", "")), TipIntent.CHANNEL_REWARD_RESOURCE, "small resource uses resource lane")
	var growth := RewardTipBuilder.growth("修为", 20, "test", "cultivation")
	_expect_eq(str(growth.get("channel", "")), TipIntent.CHANNEL_REWARD_GROWTH, "growth uses growth lane")
	var large_resource := RewardTipBuilder.resource("灵石", 500, "test", "ling_stones")
	_expect_eq(str(large_resource.get("channel", "")), TipIntent.CHANNEL_REWARD_ITEM, "large resource escalates to item lane")


func _test_scene_payload_invalid_reason() -> void:
	var payload := ScenePayload.lilian_jiesuan("invalid_reason")
	_expect_true(payload.is_empty(), "invalid reason payload rejected")


func _test_ui_drag_move_clamp_center() -> void:
	var viewport := Rect2(0, 0, 200, 100)
	var panel_size := Vector2(40, 40)
	var left: Vector2 = UiDragMoveScript.clamp_center_to_viewport(Vector2(-10, 50), panel_size, viewport)
	_expect_eq(left, Vector2(20, 50), "left overflow clamps center x")
	var right: Vector2 = UiDragMoveScript.clamp_center_to_viewport(Vector2(250, 50), panel_size, viewport)
	_expect_eq(right, Vector2(180, 50), "right overflow clamps center x")
	var oversized: Vector2 = UiDragMoveScript.clamp_center_to_viewport(Vector2(999, -5), Vector2(300, 80), viewport)
	_expect_eq(oversized, Vector2(100, 40), "oversized panel clamps each axis independently")


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (actual=%s expected=%s)" % [message, str(actual), str(expected)])


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)
