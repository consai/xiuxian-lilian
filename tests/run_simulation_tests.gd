extends SceneTree

const GameStateScript := preload("res://scripts/sim/game_state.gd")
const ExpeditionStateScript := preload("res://scripts/expedition/expedition_state.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const SaveServiceScript := preload("res://scripts/sim/save_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	_run("new game and daily activities", _test_new_game_and_daily_activities)
	_run("inventory and battle item slots", _test_inventory_and_battle_item_slots)
	_run("expedition events build valid battle data", _test_expedition_events_build_valid_battle_data)
	_run("reward pools produce legal rewards", _test_reward_pools)
	_run("expedition defeat settlement persists runtime state", _test_expedition_defeat_settlement)
	_run("three save slots round trip", _test_save_round_trip)
	_run("save service rejects corrupt data", _test_corrupt_save)
	if _failures.is_empty():
		print("PASS: %d simulation tests" % _tests_run)
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


func _state() -> Node:
	var state := GameStateScript.new()
	state.new_game()
	return state


func _expedition() -> Node:
	return ExpeditionStateScript.new()


func _test_new_game_and_daily_activities() -> void:
	var state := _state()
	_expect_eq(state.day, 1, "new game day")
	_expect_eq(state.cultivate(), 20, "healthy cultivate gain")
	_expect_eq(state.day, 2, "cultivate day advance")
	state.injury_days = 3
	_expect_eq(state.cultivate(), 10, "injured cultivate gain")
	_expect_eq(state.injury_days, 2, "non-rest injury reduction")
	state.hp = 1.0
	state.rest()
	_expect_near(state.hp, 100.0, "rest hp")
	_expect_eq(state.injury_days, 0, "rest injury reduction")
	state.cultivation = state.breakthrough_at
	_expect_true(state.can_breakthrough(), "breakthrough available")
	var result: Dictionary = state.breakthrough()
	_expect_true(bool(result.get("ok", false)), "breakthrough succeeds")
	state.free()


func _test_inventory_and_battle_item_slots() -> void:
	var state := _state()
	var before := int(state.inventory.get("items_HuiQiDan", 0))
	_expect_eq(InventoryServiceScript.add_item(state.inventory, "items_HuiQiDan", 2), 2, "add stack")
	_expect_eq(int(state.inventory["items_HuiQiDan"]), before + 2, "stack result")
	var slots := InventoryServiceScript.build_battle_item_slots(state.inventory, state.item_slots)
	_expect_eq(slots.size(), 2, "battle item slot count")
	(slots[0] as Dictionary)["count"] = 1
	InventoryServiceScript.sync_battle_item_counts(state.inventory, state.item_slots, slots)
	_expect_eq(int(state.inventory[state.item_slots[0]]), 1, "sync consumed items")
	state.free()


func _test_expedition_events_build_valid_battle_data() -> void:
	var state := _state()
	for event_id in ["qinglan_wolf", "qinglan_serpent", "qinglan_boss"]:
		var event := ExpeditionEventServiceScript.by_id(event_id)
		var errors := BattleInitData.collect_errors(state.build_battle_init(event))
		_expect_true(errors.is_empty(), "valid battle setup: %s" % str(errors))
	state.free()


func _test_reward_pools() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for event_id in ["qinglan_wolf", "qinglan_serpent", "qinglan_boss"]:
		var event := ExpeditionEventServiceScript.by_id(event_id)
		var rewards := RewardServiceScript.roll_rewards(event, rng)
		_expect_true(not rewards.is_empty(), "rewards should not be empty")
		for reward_v in rewards:
			var reward := reward_v as Dictionary
			_expect_true(str(reward.get("kind", "")) in ["item", "equip"], "legal reward kind")
			_expect_true(int(reward.get("count", 0)) > 0, "positive reward count")


func _test_expedition_defeat_settlement() -> void:
	var state := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", state, 9091)
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_wolf")]
	expedition.choose_event("qinglan_wolf")
	expedition.receive_battle_summary({
		"outcome": "loss",
		"player_runtime": {"hp": 0.0, "mp": 12.0, "items": [{"id": 9001, "count": 1}, {"id": 9003, "count": 0}]},
	})
	expedition.settle_pending_battle()
	var finish: Dictionary = expedition.finish("defeated")
	var result: Dictionary = state.settle_expedition(finish)
	_expect_true(bool(result.get("ok", false)), "settlement ok")
	_expect_eq(state.day, 2, "expedition consumes day")
	_expect_near(state.hp, 25.0, "loss hp floor")
	_expect_near(state.mp, 12.0, "mp persisted")
	_expect_eq(state.injury_days, 3, "loss applies three injury days")
	state.free()
	expedition.free()


func _test_save_round_trip() -> void:
	var state := _state()
	state.day = 9
	state.cultivation = 77
	var service := SaveServiceScript.new()
	var saved: Dictionary = service.save_slot(3, state.to_dict())
	_expect_true(bool(saved.get("ok", false)), "save slot")
	var loaded: Dictionary = service.load_slot(3)
	_expect_true(bool(loaded.get("ok", false)), "load slot")
	var restored := _state()
	_expect_true(restored.apply_dict(loaded.get("game", {})), "apply saved state")
	_expect_eq(restored.day, 9, "restored day")
	_expect_eq(restored.cultivation, 77, "restored cultivation")
	state.free()
	restored.free()
	service.free()


func _test_corrupt_save() -> void:
	var file := FileAccess.open("user://save_slot_2.json", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var service := SaveServiceScript.new()
	var loaded: Dictionary = service.load_slot(2)
	_expect_true(not bool(loaded.get("ok", false)), "corrupt save rejected")
	service.free()


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.2f, got %.2f" % [message, expected, actual])
