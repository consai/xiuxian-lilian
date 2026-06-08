extends SceneTree

const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("start creates isolated runtime", _test_start_creates_isolated_runtime)
	_run("choices obey depth and battle cap", _test_choices_obey_depth_and_battle_cap)
	_run("non battle events advance expedition", _test_non_battle_events_advance)
	_run("manual exit keeps all loot", _test_manual_exit_keeps_all_loot)
	_run("defeat exit drops inventory and injury", _test_defeat_exit_drops_inventory_and_injury)
	_run("defeat inventory drop is deterministic", _test_defeat_inventory_drop_deterministic)
	_run("elapsed days use step ceiling", _test_elapsed_days_use_step_ceiling)
	_run("battle win returns to expedition", _test_battle_win_returns_to_expedition)
	_run("battle loss forces expedition result", _test_battle_loss_forces_expedition_result)
	_run("boss requires depth and marks completion", _test_boss_requires_depth_and_marks_completion)
	_run("game settlement occurs once", _test_game_settlement_occurs_once)
	_run("distinct expeditions do not collide on settlement", _test_distinct_expeditions_settlement_ids)
	if _failures.is_empty():
		print("PASS: %d expedition tests" % _tests_run)
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
	var state := root.get_node("GameState")
	state.new_game()
	return state


func _expedition() -> Node:
	return root.get_node("ExpeditionState")


func _test_start_creates_isolated_runtime() -> void:
	var game := _state()
	var expedition := _expedition()
	var started: Dictionary = expedition.start("qinglan_mountain", game, 101)
	_expect_true(bool(started.get("ok", false)), "start ok")
	_expect_true(expedition.active, "expedition active")
	_expect_near(float(expedition.runtime.get("hp", 0.0)), game.hp, "runtime hp copied")
	game.hp = 1.0
	_expect_near(float(expedition.runtime.get("hp", 0.0)), 100.0, "runtime isolated from game")


func _test_choices_obey_depth_and_battle_cap() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 202)
	var location := LocationServiceScript.by_id("qinglan_mountain")
	for _i in 20:
		var choices := ExpeditionEventServiceScript.generate_choices(location, 1, [], _rng(202 + _i))
		_expect_eq(choices.size(), 3, "three choices at depth 1")
		var ids := {}
		var battle_count := 0
		for choice_v in choices:
			var choice := choice_v as Dictionary
			var eid := str(choice.get("id", ""))
			_expect_true(not ids.has(eid), "unique event ids")
			ids[eid] = true
			if ExpeditionRulesServiceScript.is_battle_type(str(choice.get("type", ""))):
				battle_count += 1
		_expect_true(battle_count <= 1, "max one battle card")
	var shallow := ExpeditionEventServiceScript.generate_choices(location, 2, [], _rng(303))
	for choice_v in shallow:
		var choice := choice_v as Dictionary
		_expect_true(str(choice.get("id", "")) != "qinglan_boss", "boss hidden at depth 2")
		_expect_true(str(choice.get("id", "")) != "qinglan_serpent", "elite hidden at depth 2")


func _test_non_battle_events_advance() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 404)
	var herbs := ExpeditionEventServiceScript.by_id("qinglan_herbs")
	var before_steps: int = int(expedition.steps)
	var before_depth: int = int(expedition.depth)
	var before_loot: int = (expedition.loot as Array).size()
	expedition.current_choices = [herbs]
	expedition.phase = "choosing"
	var result: Dictionary = expedition.choose_event("qinglan_herbs")
	_expect_true(bool(result.get("ok", false)), "gather resolves")
	_expect_eq(expedition.steps, before_steps + 1, "steps increased")
	_expect_eq(expedition.depth, before_depth + 1, "depth increased")
	_expect_true(expedition.loot.size() >= before_loot, "session loot tracked")
	_expect_true(int(game.inventory.get("items_LingCao", 0)) > 3, "gather reward entered inventory")
	game.hp = 10.0
	expedition.runtime["hp"] = 10.0
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_shelter")]
	expedition.phase = "choosing"
	expedition.choose_event("qinglan_shelter")
	_expect_true(float(expedition.runtime.get("hp", 0.0)) > 10.0, "recover raises hp")


func _test_manual_exit_keeps_all_loot() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 505)
	ExpeditionRewardServiceScript.grant_to_player(
		game, expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 4}]
	)
	var finish: Dictionary = expedition.finish("manual")
	var settled: Dictionary = game.settle_expedition(finish)
	_expect_true(bool(settled.get("ok", false)), "settlement ok")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), 7, "loot merged into inventory")
	_expect_eq(game.day, 2, "manual exit advances at least one day")


func _test_defeat_exit_drops_inventory_and_injury() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 606)
	ExpeditionRewardServiceScript.grant_to_player(
		game,
		expedition.loot,
		[{"kind": "item", "id": "items_LingCao", "count": 5}],
	)
	var inv_before := int(game.inventory.get("items_LingCao", 0))
	expedition.runtime["hp"] = 0.0
	var finish: Dictionary = expedition.finish("defeated")
	var inv_after := int(game.inventory.get("items_LingCao", 0))
	_expect_true(inv_after < inv_before, "defeat removes inventory items")
	_expect_true(not (finish.get("loot_lost", []) as Array).is_empty(), "loot_lost recorded")
	game.settle_expedition(finish)
	_expect_near(game.hp, 25.0, "defeat hp floor")
	_expect_eq(game.injury_days, 3, "defeat injury applied after elapsed reduction")


func _test_defeat_inventory_drop_deterministic() -> void:
	var inventory_a := {"items_LingCao": 8, "items_HuiQiDan": 4}
	var inventory_b := {"items_LingCao": 8, "items_HuiQiDan": 4}
	var loss_a := ExpeditionRewardServiceScript.apply_inventory_loss_on_defeat(inventory_a, _rng(4242))
	var loss_b := ExpeditionRewardServiceScript.apply_inventory_loss_on_defeat(inventory_b, _rng(4242))
	_expect_eq(inventory_a, inventory_b, "same seed same inventory result")
	_expect_eq(loss_a, loss_b, "same seed same loss result")
	_expect_true(not (loss_a.get("lost", []) as Array).is_empty(), "drops at least one stack")
	_expect_true(_inventory_total(inventory_a) < 12, "inventory count reduced")


func _test_elapsed_days_use_step_ceiling() -> void:
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(0), 1, "0 steps -> 1 day")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(1), 1, "1 step -> 1 day")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(3), 1, "3 steps -> 1 day")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(4), 2, "4 steps -> 2 days")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(6), 2, "6 steps -> 2 days")


func _test_battle_win_returns_to_expedition() -> void:
	var game := _state()
	var day_before: int = int(game.day)
	var inv_before := _inventory_total(game.inventory)
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 707)
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_wolf")]
	expedition.choose_event("qinglan_wolf")
	expedition.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {
			"hp": 55.0,
			"mp": 20.0,
			"items": [{"id": 9001, "count": 2}, {"id": 9003, "count": 1}],
		},
	})
	var settled: Dictionary = expedition.settle_pending_battle()
	_expect_true(bool(settled.get("ok", false)), "battle settled")
	_expect_true(expedition.active, "expedition still active")
	_expect_eq(game.day, day_before, "game day unchanged")
	_expect_near(float(expedition.runtime.get("hp", 0.0)), 55.0, "runtime hp updated")
	_expect_true(not expedition.loot.is_empty(), "battle loot tracked in session")
	_expect_true(_inventory_total(game.inventory) > inv_before, "battle loot entered inventory")


func _test_battle_loss_forces_expedition_result() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 808)
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_wolf")]
	expedition.choose_event("qinglan_wolf")
	expedition.receive_battle_summary({
		"outcome": "loss",
		"player_runtime": {"hp": 0.0, "mp": 5.0, "items": []},
	})
	var settled: Dictionary = expedition.settle_pending_battle()
	_expect_true(bool(settled.get("forced_exit", false)), "loss forces exit")
	_expect_true(expedition.should_go_to_result(), "result scene required")
	_expect_true(expedition.current_choices.is_empty(), "no more choices after defeat")


func _test_boss_requires_depth_and_marks_completion() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 909)
	expedition.depth = 6
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_boss")]
	expedition.choose_event("qinglan_boss")
	expedition.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {"hp": 40.0, "mp": 10.0, "items": []},
	})
	expedition.settle_pending_battle()
	_expect_true(bool(expedition.stats.get("boss_defeated", false)), "boss completion marked")


func _test_game_settlement_occurs_once() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 1001)
	ExpeditionRewardServiceScript.grant_to_player(
		game, expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 2}]
	)
	var finish: Dictionary = expedition.finish("manual")
	_expect_true(str(finish.get("settlement_id", "")) != "", "finish includes settlement_id")
	var first: Dictionary = game.settle_expedition(finish)
	var second: Dictionary = game.settle_expedition(finish)
	_expect_true(bool(first.get("ok", false)), "first settlement ok")
	_expect_true(bool(second.get("duplicate", false)), "duplicate settlement rejected")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), 5, "inventory not doubled at settlement")
	_expect_eq(game.day, 2, "day advanced once")


func _test_distinct_expeditions_settlement_ids() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 2001)
	ExpeditionRewardServiceScript.grant_to_player(
		game, expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 1}]
	)
	var first_finish: Dictionary = expedition.finish("manual")
	game.settle_expedition(first_finish)
	expedition.start("qinglan_mountain", game, 2002)
	ExpeditionRewardServiceScript.grant_to_player(
		game, expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 1}]
	)
	var second_finish: Dictionary = expedition.finish("manual")
	_expect_true(
		str(second_finish.get("settlement_id", "")) != str(first_finish.get("settlement_id", "")),
		"distinct expedition ids"
	)
	var second: Dictionary = game.settle_expedition(second_finish)
	_expect_true(bool(second.get("ok", false)), "second distinct settlement ok")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), 5, "both loot applied")


func _inventory_total(inventory: Dictionary) -> int:
	var total := 0
	for count_v in inventory.values():
		total += int(count_v)
	return total


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


func _expect_near(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.2f, got %.2f" % [message, expected, actual])
