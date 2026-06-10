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
	_run("roll next event obeys depth", _test_roll_next_event_obey_depth)
	_run("decision event exposes options", _test_decision_event_exposes_options)
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
	_run("director is deterministic from event pool", _test_director_deterministic)
	_run("completed events change world state", _test_completed_events_world_change)
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


func _test_roll_next_event_obey_depth() -> void:
	var location := LocationServiceScript.by_id("qinglan_mountain")
	for _i in 20:
		var event := ExpeditionEventServiceScript.roll_next_event(location, 1, [], _rng(202 + _i))
		_expect_true(not event.is_empty(), "one rolled event at depth 1")
		_expect_true(str(event.get("id", "")) != "", "rolled event has id")
	var shallow := ExpeditionEventServiceScript.roll_next_event(location, 2, [], _rng(303))
	_expect_true(str(shallow.get("id", "")) != "qinglan_boss", "boss hidden at depth 2")
	_expect_true(str(shallow.get("id", "")) != "qinglan_serpent", "elite hidden at depth 2")


func _test_decision_event_exposes_options() -> void:
	var tracks := ExpeditionEventServiceScript.by_id("qinglan_wolf_tracks")
	_expect_true(ExpeditionEventServiceScript.is_decision_event(tracks), "wolf tracks is decision")
	var options := ExpeditionEventServiceScript.decision_options_as_choices(tracks)
	_expect_eq(options.size(), 2, "two decision options")
	_expect_true(str((options[0] as Dictionary).get("id", "")).contains("::"), "composite choice id")


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
	var inv_before := _inventory_total(game.inventory)
	expedition.runtime["hp"] = 0.0
	var finish: Dictionary = expedition.finish("defeated")
	var inv_after := _inventory_total(game.inventory)
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
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(3), 3, "3 steps -> 3 days")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(4), 4, "4 steps -> 4 days")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(6), 6, "6 steps -> 6 days")


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
	_expect_true(_inventory_total(game.inventory) >= inv_before - 2, "battle rewards offset consumed supplies")
	var slot_id := str(expedition.runtime.get("item_slots", [])[0])
	if slot_id != "":
		_expect_eq(int(game.inventory.get(slot_id, 0)), 2, "battle pill consumption synced to backpack")


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


func _test_director_deterministic() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 3333)
	var first: Dictionary = expedition.advance_step()
	_expect_true(bool(first.get("ok", false)), "first pool event resolves")
	_expect_true(not (first.get("event", {}) as Dictionary).is_empty(), "first pool event selected")
	expedition.reset()
	expedition.start("qinglan_mountain", game, 3333)
	var repeated: Dictionary = expedition.advance_step()
	_expect_eq(first.get("event", {}), repeated.get("event", {}), "same seed same director event")


func _test_completed_events_world_change() -> void:
	var game := _state()
	var before := int(game.world_state.get("wolf_threat", 0))
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 4444)
	expedition.completed_events = ["wolf_king_boss"]
	var finish: Dictionary = expedition.finish("journey_complete")
	game.settle_expedition(finish)
	_expect_eq(int(game.world_state.get("wolf_threat", 0)), maxi(0, before - 20), "perfect wolf hunt lowers threat")


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
