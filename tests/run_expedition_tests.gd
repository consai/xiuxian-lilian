extends SceneTree

const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionMapServiceScript := preload("res://scripts/expedition/expedition_map_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const ExpeditionRulesServiceScript := preload("res://scripts/expedition/expedition_rules_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("start creates isolated runtime", _test_start_creates_isolated_runtime)
	_run("expedition map is deterministic", _test_expedition_map_is_deterministic)
	_run("expedition map is reachable", _test_expedition_map_is_reachable)
	_run("expedition map is longer and ends with boss", _test_expedition_map_is_longer_and_ends_with_boss)
	_run("expedition map has three lanes and limited crosses", _test_expedition_map_has_three_lanes_and_limited_crosses)
	_run("map node choice is gated", _test_map_node_choice_is_gated)
	_run("event pick ignores configured difficulty", _test_event_pick_ignores_configured_difficulty)
	_run("common events use location generation", _test_common_events_use_location_generation)
	_run("location declares monsters and materials", _test_location_declares_monsters_and_materials)
	_run("difficulty rolls material grade variants", _test_difficulty_rolls_material_grade_variants)
	_run("monster drops materialize from map enemy", _test_monster_drops_materialize_from_map_enemy)
	_run("early common battles form small groups", _test_early_common_battles_form_small_groups)
	_run("group battles scale skill slots", _test_group_battles_scale_skill_slots)
	_run("expedition modes keep event pools separate", _test_expedition_modes_keep_event_pools_separate)
	_run("common event duration advances days", _test_common_event_duration_advances_days)
	_run("decision event exposes options", _test_decision_event_exposes_options)
	_run("common decision choice resolves", _test_common_decision_choice_resolves)
	_run("non battle events advance expedition", _test_non_battle_events_advance)
	_run("manual exit keeps all loot", _test_manual_exit_keeps_all_loot)
	_run("defeat exit drops inventory and injury", _test_defeat_exit_drops_inventory_and_injury)
	_run("defeat inventory drop is deterministic", _test_defeat_inventory_drop_deterministic)
	_run("defeat loot drop is deterministic", _test_defeat_loot_drop_deterministic)
	_run("elapsed days track expedition days", _test_elapsed_days_track_expedition_days)
	_run("quiet days advance time without logs", _test_quiet_days_advance_without_logs)
	_run("battle node builds unchanged battle init", _test_battle_node_builds_unchanged_battle_init)
	_run("elite and boss nodes always resolve battle", _test_elite_and_boss_nodes_always_resolve_battle)
	_run("high difficulty battle nodes generate map enemies", _test_high_difficulty_battle_nodes_generate_map_enemies)
	_run("battle win opens next map nodes", _test_battle_win_opens_next_map_nodes)
	_run("reward budget scales by days and difficulty", _test_reward_budget_scales_by_days_and_difficulty)
	_run("battle win returns to expedition", _test_battle_win_returns_to_expedition)
	_run("battle loss forces expedition result", _test_battle_loss_forces_expedition_result)
	_run("boss battle resolves at high difficulty", _test_boss_battle_resolves_at_high_difficulty)
	_run("game settlement occurs once", _test_game_settlement_occurs_once)
	_run("distinct expeditions do not collide on settlement", _test_distinct_expeditions_settlement_ids)
	_run("event pick is deterministic from event pool", _test_event_pick_deterministic)
	_run("result screen uses finish payload not settle return", _test_result_payload_from_finish)
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
	var starting_hp: float = game.hp
	game.hp = 1.0
	_expect_near(float(expedition.runtime.get("hp", 0.0)), starting_hp, "runtime isolated from game")
	_expect_true(starting_hp >= 130.0, "starter attributes are battle ready")
	_expect_true(not expedition.map_nodes.is_empty(), "start generates route map")
	_expect_true(not expedition.available_node_ids.is_empty(), "start exposes first route choices")


func _test_expedition_map_is_deterministic() -> void:
	var location := LocationServiceScript.by_id("qinglan_mountain")
	var first := ExpeditionMapServiceScript.generate(location, 9191)
	var second := ExpeditionMapServiceScript.generate(location, 9191)
	_expect_eq(first, second, "same seed generates same expedition map")


func _test_expedition_map_is_reachable() -> void:
	for location_v in LocationServiceScript.all_locations():
		var location := location_v as Dictionary
		var map_data := ExpeditionMapServiceScript.generate(location, 1234)
		_expect_true(ExpeditionMapServiceScript.is_reachable_to_exit(map_data), "map reaches exit for %s" % str(location.get("id", "")))


func _test_expedition_map_is_longer_and_ends_with_boss() -> void:
	var location := LocationServiceScript.by_id("qinglan_mountain")
	var map_data := ExpeditionMapServiceScript.generate(location, 5252)
	var exit_node := ExpeditionMapServiceScript.node_by_id(map_data.get("nodes", []) as Array, "exit")
	_expect_eq(str(exit_node.get("type", "")), "boss", "exit node is always boss")
	_expect_true(int(exit_node.get("layer", 0)) >= 9, "route has at least eight middle layers before boss")


func _test_expedition_map_has_three_lanes_and_limited_crosses() -> void:
	var location := LocationServiceScript.by_id("qinglan_mountain")
	for seed_value in [101, 202, 303, 404]:
		var map_data := ExpeditionMapServiceScript.generate(location, seed_value)
		var node_count_by_layer := {}
		var nodes_by_id := {}
		for node_v in map_data.get("nodes", []) as Array:
			var node := node_v as Dictionary
			nodes_by_id[str(node.get("id", ""))] = node
			var layer := int(node.get("layer", 0))
			if layer <= 0 or str(node.get("id", "")) == "exit":
				continue
			node_count_by_layer[layer] = int(node_count_by_layer.get(layer, 0)) + 1
		_expect_eq(node_count_by_layer.size(), 8, "route keeps eight middle layers")
		for count_v in node_count_by_layer.values():
			_expect_eq(int(count_v), 3, "each route layer has three lanes")
		var outgoing_count_by_node := {}
		for edge_v in map_data.get("edges", []) as Array:
			var edge := edge_v as Dictionary
			var from_id := str(edge.get("from", ""))
			outgoing_count_by_node[from_id] = int(outgoing_count_by_node.get(from_id, 0)) + 1
		var cross_layers := {}
		for from_id in outgoing_count_by_node.keys():
			if not nodes_by_id.has(from_id):
				continue
			var node := nodes_by_id[from_id] as Dictionary
			var layer := int(node.get("layer", 0))
			if layer <= 0:
				continue
			if int(outgoing_count_by_node.get(from_id, 0)) > 1:
				cross_layers[layer] = true
		_expect_true(cross_layers.size() >= 2 and cross_layers.size() <= 3, "route has two or three crossing opportunities")


func _test_map_node_choice_is_gated() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 8181)
	var locked_node_id := ""
	for node_v in expedition.map_nodes:
		var node := node_v as Dictionary
		var node_id := str(node.get("id", ""))
		if node_id != "start" and not expedition.available_node_ids.has(node_id):
			locked_node_id = node_id
			break
	_expect_true(locked_node_id != "", "found locked node")
	var blocked: Dictionary = expedition.choose_map_node(locked_node_id)
	_expect_true(not bool(blocked.get("ok", true)), "locked node cannot be chosen")
	var available_id := str(expedition.available_node_ids[0])
	var chosen: Dictionary = expedition.choose_map_node(available_id)
	_expect_true(bool(chosen.get("ok", false)), "available node can be chosen")
	var repeated: Dictionary = expedition.choose_map_node(available_id)
	_expect_true(not bool(repeated.get("ok", true)), "chosen node cannot be repeated while resolving")


func _test_event_pick_ignores_configured_difficulty() -> void:
	var location := LocationServiceScript.by_id("wild_wolf_valley")
	var capped := location.duplicate(true)
	capped["max_difficulty"] = 2
	var boss_node := {"id": "forced_boss", "type": "boss", "difficulty": 1}
	var candidates := ExpeditionEventServiceScript.candidates_for_node(capped, boss_node, [])
	var has_boss := false
	for event_v in candidates:
		var event := event_v as Dictionary
		if str(event.get("id", "")) == "qinglan_boss":
			has_boss = true
	_expect_true(has_boss, "boss event remains candidate even when current difficulty is low")
	var rolled := ExpeditionEventServiceScript.roll_event_for_node(capped, boss_node, [], _rng(303))
	_expect_true(not rolled.is_empty(), "rolled event materializes")
	_expect_eq(int(rolled.get("difficulty", 0)), 1, "rolled event uses node difficulty")


func _test_event_pick_deterministic() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 3333)
	var first := _first_event_from_advance_steps(expedition)
	_expect_true(not first.is_empty(), "first pool event selected")
	expedition.reset()
	expedition.start("qinglan_mountain", game, 3333)
	var repeated := _first_event_from_advance_steps(expedition)
	_expect_eq(first, repeated, "same seed same rolled event")


func _test_common_events_use_location_generation() -> void:
	var location := LocationServiceScript.by_id("blackwater_marsh")
	var pool := ExpeditionEventServiceScript.event_pool_for_location(location)
	var herbs := _find_event_by_template(pool, "gather_herbs")
	var beast := _find_event_by_template(pool, "local_beast")
	var traveler := _find_event_by_template(pool, "wandering_cultivator")
	_expect_eq(str(herbs.get("id", "")), "blackwater_marsh__gather_herbs", "common event gets stable generated id")
	_expect_eq(str(herbs.get("location_id", "")), "blackwater_marsh", "common event binds current location")
	_expect_eq(str(herbs.get("drop_pool", "")), "herbs", "gather references location drop pool")
	_expect_eq(int(beast.get("duration_days", 0)), 2, "common battle uses location duration")
	_expect_eq(ExpeditionEventServiceScript.by_id(str(beast.get("id", ""))), beast, "generated event can be restored by id")
	var materialized_beast := ExpeditionEventServiceScript.roll_event_for_node(
		location,
		{"id": "battle_1", "type": "battle", "difficulty": 2},
		[],
		_rng(161)
	)
	_expect_eq(str(ExpeditionEventServiceScript.build_battle_enemy(materialized_beast).get("name", "")), "毒沼蛇", "battle resolves location enemy pool at runtime")
	for template_id in ["gather_fruit", "hidden_cache", "harsh_terrain", "deep_rest", "wandering_cultivator", "local_elite"]:
		_expect_true(not _find_event_by_template(pool, template_id).is_empty(), "rich common template generated: %s" % template_id)
	var exchange := ExpeditionEventServiceScript.find_decision_option(traveler, "exchange")
	_expect_true(not (exchange.get("results", []) as Array).is_empty(), "decision option references location drop pool")


func _test_location_declares_monsters_and_materials() -> void:
	var monsters := LocationServiceScript.monsters_for_location("blackwater_marsh")
	var materials := LocationServiceScript.materials_for_location("blackwater_marsh")
	_expect_true(monsters.size() >= 2, "blackwater declares available monsters")
	_expect_true(materials.size() >= 3, "blackwater declares available materials")
	_expect_eq(str((monsters[0] as Dictionary).get("id", "")), "poison_marsh_serpent", "map monster id resolves global monster")
	_expect_eq(str((monsters[0] as Dictionary).get("species", "")), "beast", "resolved monster keeps species")
	_expect_true(not ((monsters[0] as Dictionary).get("drops", {}) as Dictionary).is_empty(), "resolved monster keeps drops")
	var found_superior_material := false
	for material_v in materials:
		var material := material_v as Dictionary
		if (material.get("item_ids", []) as Array).has("items_LingCao_Superior"):
			found_superior_material = true
	_expect_true(found_superior_material, "map material list includes quality variants")


func _test_difficulty_rolls_material_grade_variants() -> void:
	var event := ExpeditionEventServiceScript.by_id("qinglan_mountain__gather_herbs")
	event["difficulty"] = 6
	var found_high_grade := false
	for seed_value in range(50, 90):
		var rewards := ExpeditionRewardServiceScript.roll_event_rewards(event, _rng(seed_value))
		for reward_v in rewards:
			var reward := reward_v as Dictionary
			if int(reward.get("material_grade", 1)) >= 2:
				found_high_grade = true
	_expect_true(found_high_grade, "high difficulty can roll higher grade material")


func _test_monster_drops_materialize_from_map_enemy() -> void:
	var location := LocationServiceScript.by_id("blackwater_marsh")
	var node := {"id": "battle_1", "type": "battle", "difficulty": 5}
	var event := ExpeditionEventServiceScript.roll_event_for_node(location, node, [], _rng(515))
	_expect_eq(str(event.get("drop_pool", "")), "monster:poison_marsh_serpent", "battle event materializes exact monster drop pool")
	_expect_eq(int(event.get("difficulty", 0)), 5, "battle event keeps current node difficulty")
	var rewards := ExpeditionRewardServiceScript.roll_event_rewards(event, _rng(515))
	_expect_true(not rewards.is_empty(), "materialized monster drop rolls rewards")
	for reward_v in rewards:
		var reward := reward_v as Dictionary
		_expect_true(str(reward.get("id", "")) != "", "monster reward keeps reward id")


func _test_early_common_battles_form_small_groups() -> void:
	var event := ExpeditionEventServiceScript.roll_event_for_node(
		LocationServiceScript.by_id("qinglan_mountain"),
		{"id": "battle_1", "type": "battle", "difficulty": 2},
		[],
		_rng(7070)
	)
	var enemies := ExpeditionEventServiceScript.build_battle_enemies(event)
	_expect_eq(enemies.size(), 2, "qinglan starter beast should spawn a small group")
	var enemy := enemies[0] as Dictionary
	_expect_true(float(enemy.get("hp", 0.0)) >= 40.0, "starter group enemy keeps readable hp")
	_expect_true(str(enemy.get("name", "")).contains("·"), "starter group enemy gets numbered name")
	var slots := enemy.get("skills", []) as Array
	for slot_v in slots:
		var slot := slot_v as Dictionary
		if int(slot.get("id", -1)) > 0:
			_expect_true(
				float(slot.get("effect_value_scale", 1.0)) <= 0.42,
				"starter group skill fixed effects are toned down"
			)


func _test_group_battles_scale_skill_slots() -> void:
	var event := ExpeditionEventServiceScript.roll_event_for_node(
		LocationServiceScript.by_id("qinglan_mountain"),
		{"id": "battle_6", "type": "battle", "difficulty": 6},
		[],
		_rng(7071)
	)
	var enemies := ExpeditionEventServiceScript.build_battle_enemies(event)
	_expect_eq(enemies.size(), 4, "difficulty six common battle forms a larger group")
	for enemy_v in enemies:
		var enemy := enemy_v as Dictionary
		var slots := enemy.get("skills", []) as Array
		var found_scaled_skill := false
		for slot_v in slots:
			var slot := slot_v as Dictionary
			if int(slot.get("id", -1)) > 0:
				found_scaled_skill = true
				_expect_true(
					float(slot.get("effect_value_scale", 1.0)) <= 0.5,
					"group enemy skill fixed effects should scale down"
				)
		_expect_true(found_scaled_skill, "group enemy keeps active skill slot")


func _test_expedition_modes_keep_event_pools_separate() -> void:
	var resource_location := LocationServiceScript.by_id("qinglan_mountain")
	_expect_true((resource_location.get("tags", []) as Array).has("resource"), "qinglan is tagged resource")
	var blackwater_location := LocationServiceScript.by_id("blackwater_marsh")
	_expect_true((blackwater_location.get("tags", []) as Array).has("resource"), "blackwater is tagged resource")
	var resource_pool := ExpeditionEventServiceScript.event_pool_for_location(resource_location)
	_expect_true(not resource_pool.is_empty(), "resource pool has events")
	var has_material_event := false
	var has_battle_event := false
	var has_recover_event := false
	for event_v in resource_pool:
		var event := event_v as Dictionary
		_expect_true(str(event.get("id", "")).begins_with("qinglan_mountain__"), "resource map uses location-owned modular events")
		match str(event.get("type", "")):
			"gather":
				has_material_event = true
			"battle", "elite", "boss":
				has_battle_event = true
			"recover":
				has_recover_event = true
	_expect_true(has_material_event, "resource map can gather materials")
	_expect_true(has_battle_event, "resource map can roll common battle")
	_expect_true(has_recover_event, "resource map can roll common recover")
	var story_location := LocationServiceScript.by_id("wild_wolf_valley")
	_expect_true((story_location.get("tags", []) as Array).has("story"), "wild wolf valley is tagged story")
	var story_pool := ExpeditionEventServiceScript.event_pool_for_location(story_location)
	_expect_true(not story_pool.is_empty(), "story pool has events")
	var has_story_battle := false
	for event_v in story_pool:
		var event := event_v as Dictionary
		_expect_true(not str(event.get("id", "")).begins_with("wild_wolf_valley__"), "story map keeps authored events")
		if str(event.get("id", "")) == "qinglan_wolf":
			has_story_battle = true
	_expect_true(has_story_battle, "story map keeps configured map events")


func _test_common_event_duration_advances_days() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("blackwater_marsh", game, 3030)
	var event := ExpeditionEventServiceScript.by_id("blackwater_marsh__recover_hp")
	event["duration_days"] = 3
	expedition.runtime["hp"] = 10.0
	expedition.current_choices = [event]
	expedition.phase = "choosing"
	var result: Dictionary = expedition.choose_event(str(event.get("id", "")))
	_expect_true(bool(result.get("ok", false)), "generated duration event resolves")
	_expect_eq(expedition.days, 2, "event duration adds extra elapsed days")


func _test_decision_event_exposes_options() -> void:
	var traveler := ExpeditionEventServiceScript.by_id("blackwater_marsh__wandering_cultivator")
	_expect_true(ExpeditionEventServiceScript.is_decision_event(traveler), "wandering cultivator is decision")
	var options := ExpeditionEventServiceScript.decision_options_as_choices(traveler)
	_expect_eq(options.size(), 2, "two decision options")
	_expect_true(str((options[0] as Dictionary).get("id", "")).contains("::"), "composite choice id")


func _test_common_decision_choice_resolves() -> void:
	var traveler := ExpeditionEventServiceScript.by_id("blackwater_marsh__wandering_cultivator")
	var options := ExpeditionEventServiceScript.decision_options_as_choices(traveler)
	var choice_id := str((options[0] as Dictionary).get("id", ""))
	var parsed := ExpeditionEventServiceScript.parse_decision_choice_id(choice_id)
	_expect_eq(str(parsed.get("parent_id", "")), str(traveler.get("id", "")), "parses parent id from composite choice id")
	_expect_eq(str(parsed.get("option_id", "")), "exchange", "parses option id from composite choice id")
	var game := _state()
	var expedition := _expedition()
	expedition.start("blackwater_marsh", game, 505)
	expedition.pending_decision_event = traveler.duplicate(true)
	expedition.current_choices = options
	expedition.phase = "choosing"
	var result: Dictionary = expedition.choose_event(choice_id)
	_expect_true(bool(result.get("ok", false)), "common decision choice resolves")


func _test_non_battle_events_advance() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("blackwater_marsh", game, 404)
	var herbs := ExpeditionEventServiceScript.by_id("blackwater_marsh__gather_herbs")
	var before_steps: int = int(expedition.steps)
	var before_max_diff: int = int((expedition.stats as Dictionary).get("max_difficulty", 0))
	var before_loot: int = (expedition.loot as Array).size()
	expedition.current_choices = [herbs]
	expedition.phase = "choosing"
	var result: Dictionary = expedition.choose_event(str(herbs.get("id", "")))
	_expect_true(bool(result.get("ok", false)), "gather resolves")
	_expect_true(str(result.get("outcome", "")).contains("依照药性"), "gather uses event-specific outcome text")
	_expect_eq(expedition.steps, before_steps + 1, "steps increased")
	_expect_true(int((expedition.stats as Dictionary).get("max_difficulty", 0)) >= before_max_diff, "max difficulty tracked")
	_expect_true(expedition.loot.size() >= before_loot, "session loot tracked")
	var inv_before: int = int(game.inventory.get("items_LingCao", 0))
	var loot_total := 0
	for reward_v in expedition.loot:
		var reward := reward_v as Dictionary
		loot_total += int(reward.get("count", 0))
	_expect_true(loot_total > 0, "gather reward in session loot")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), inv_before, "game inventory unchanged during expedition")
	game.hp = 10.0
	expedition.runtime["hp"] = 10.0
	var shelter := ExpeditionEventServiceScript.by_id("blackwater_marsh__recover_hp")
	expedition.current_choices = [shelter]
	expedition.phase = "choosing"
	expedition.choose_event(str(shelter.get("id", "")))
	_expect_true(float(expedition.runtime.get("hp", 0.0)) > 10.0, "recover raises hp")
	var terrain := ExpeditionEventServiceScript.by_id("blackwater_marsh__harsh_terrain")
	expedition.current_choices = [terrain]
	expedition.phase = "choosing"
	var terrain_result: Dictionary = expedition.choose_event(str(terrain.get("id", "")))
	_expect_true(str(terrain_result.get("outcome", "")).contains("脱身"), "hazard uses location-specific feedback")


func _test_manual_exit_keeps_all_loot() -> void:
	var game := _state()
	var lingcao_before := int(game.inventory.get("items_LingCao", 0))
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 505)
	ExpeditionRewardServiceScript.merge_into_loot(
		expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 4}]
	)
	var finish: Dictionary = expedition.finish("manual")
	var settled: Dictionary = game.settle_expedition(finish)
	_expect_true(bool(settled.get("ok", false)), "settlement ok")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), lingcao_before + 4, "loot merged into inventory")
	_expect_eq(game.day, 31, "manual exit advances by expedition duration")


func _test_defeat_exit_drops_inventory_and_injury() -> void:
	var game := _state()
	game.inventory["items_LingCao"] = 3
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 606)
	ExpeditionRewardServiceScript.merge_into_loot(
		expedition.loot,
		[{"kind": "item", "id": "items_LingCao", "count": 5}],
	)
	var inv_before := _inventory_total(game.inventory)
	expedition.runtime["hp"] = 0.0
	var finish: Dictionary = expedition.finish("defeated")
	_expect_eq(_inventory_total(game.inventory), inv_before, "game inventory unchanged before settle")
	_expect_true(not (finish.get("loot_lost", []) as Array).is_empty(), "loot_lost recorded")
	var loot_arr := finish.get("loot", []) as Array
	var loot_total := 0
	for r in loot_arr:
		loot_total += int((r as Dictionary).get("count", 0))
	_expect_true(loot_total > 0, "defeat keeps partial session loot")
	_expect_true(loot_total < 5, "session loot reduced on defeat")
	game.settle_expedition(finish)
	_expect_eq(_inventory_total(game.inventory), inv_before + loot_total, "kept session loot merged on settle")
	_expect_near(game.hp, FightAttr.get_attr(game.attrs, FightAttr.HP_MAX) * 0.25, "defeat hp floor")
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


func _test_defeat_loot_drop_deterministic() -> void:
	var loot_a: Array = [{"kind": "item", "id": "items_LingCao", "count": 6}, {"kind": "item", "id": "items_HuiQiDan", "count": 4}]
	var loot_b: Array = [{"kind": "item", "id": "items_LingCao", "count": 6}, {"kind": "item", "id": "items_HuiQiDan", "count": 4}]
	var loss_a := ExpeditionRewardServiceScript.apply_loot_loss_on_defeat(loot_a, _rng(7777))
	var loss_b := ExpeditionRewardServiceScript.apply_loot_loss_on_defeat(loot_b, _rng(7777))
	_expect_eq(loss_a, loss_b, "same seed same loot loss result")
	_expect_true(not (loss_a.get("lost", []) as Array).is_empty(), "drops at least one loot stack")
	var remaining := 0
	for r in loot_a:
		remaining += int((r as Dictionary).get("count", 0))
	_expect_true(remaining < 10, "session loot count reduced")


func _test_elapsed_days_track_expedition_days() -> void:
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(0, "qi"), 30, "0 days -> qi expedition duration")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(1, "qi"), 30, "1 day -> qi expedition duration")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(31, "qi"), 31, "31 days -> actual elapsed")
	_expect_eq(ExpeditionRulesServiceScript.elapsed_days(0, "foundation"), 60, "foundation duration scales")


func _test_quiet_days_advance_without_logs() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 5151)
	var departure_logs: int = expedition.event_log.size()
	var days_before: int = int(expedition.days)
	var result: Dictionary = expedition.advance_day()
	_expect_true(bool(result.get("ok", false)), "advance day ok")
	_expect_true(int(expedition.days) > days_before, "days advanced")
	if str(result.get("mode", "")) == "resolving":
		var completed: Dictionary = expedition.complete_current_step()
		_expect_true(bool(completed.get("ok", false)), "node event completes")
	_expect_true(expedition.event_log.size() >= departure_logs, "route node keeps or extends log")


func _test_battle_node_builds_unchanged_battle_init() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 6161)
	var node := _first_available_node_by_type(expedition, "battle")
	if node.is_empty():
		node = _force_first_available_node_type(expedition, "battle")
	var result: Dictionary = expedition.choose_map_node(str(node.get("id", "")))
	_expect_true(bool(result.get("ok", false)), "battle route node starts")
	if str(result.get("mode", "")) != "battle":
		return
	var init_data: Dictionary = expedition.build_battle_init()
	_expect_true(BattleInitData.collect_errors(init_data).is_empty(), "battle node builds valid battle init")


func _test_elite_and_boss_nodes_always_resolve_battle() -> void:
	for forced_type in ["elite", "boss"]:
		var game := _state()
		var expedition := _expedition()
		expedition.start("qinglan_mountain", game, 6363)
		var node := _force_first_available_node_type(expedition, forced_type)
		var result: Dictionary = expedition.choose_map_node(str(node.get("id", "")))
		_expect_eq(str(result.get("mode", "")), "battle", "%s node falls back to battle candidate" % forced_type)
		var init_data: Dictionary = expedition.build_battle_init()
		_expect_true(BattleInitData.collect_errors(init_data).is_empty(), "%s fallback battle init is valid" % forced_type)


func _test_high_difficulty_battle_nodes_generate_map_enemies() -> void:
	for forced_type in ["battle", "elite"]:
		var game := _state()
		var expedition := _expedition()
		(root.get_node("DataStore").expedition_runtime() as Dictionary)["difficulty_override"] = {"min_difficulty": 5, "max_difficulty": 6}
		expedition.start("qinglan_mountain", game, 6464)
		var node := _force_first_available_node_type(expedition, forced_type, 6)
		var result: Dictionary = expedition.choose_map_node(str(node.get("id", "")))
		_expect_eq(str(result.get("mode", "")), "battle", "%s node enters battle at difficulty 5-6" % forced_type)
		var event := result.get("event", {}) as Dictionary
		_expect_true(not str(event.get("id", "")).begins_with("generated::"), "%s node uses materialized event template" % forced_type)
		_expect_eq(str(event.get("type", "")), forced_type, "%s generated event keeps node battle type" % forced_type)
		_expect_eq(int(event.get("difficulty", 0)), 6, "%s materialized event uses node difficulty" % forced_type)
		_expect_true(str(event.get("drop_pool", "")).begins_with("monster:"), "%s materialized event uses monster drop pool" % forced_type)
		_expect_true(float(event.get("enemy_difficulty_scale", 1.0)) > 1.0, "%s generated event scales enemy attrs" % forced_type)
		var init_data: Dictionary = expedition.build_battle_init()
		_expect_true(BattleInitData.collect_errors(init_data).is_empty(), "%s generated battle init valid" % forced_type)
		var enemies := init_data.get("enemies", []) as Array
		var formation := init_data.get("enemy_formation", {}) as Dictionary
		_expect_eq(str(formation.get("mode", "")), "columns", "%s generated battle uses column formation" % forced_type)
		_expect_eq(int(formation.get("columns", 0)), 3, "%s generated battle has three formation columns" % forced_type)
		_expect_eq(int(formation.get("rows", 0)), 5, "%s generated battle has five formation rows" % forced_type)
		_expect_eq(int(formation.get("active_columns", 0)), 1, "%s generated battle only activates front column" % forced_type)
		if forced_type == "battle":
			_expect_eq(enemies.size(), 4, "difficulty six normal battle generates group size from difficulty")
		else:
			_expect_eq(enemies.size(), 3, "difficulty six elite battle generates elite group size from difficulty")
		_expect_true(not enemies.is_empty(), "%s generated battle has enemies" % forced_type)
		if not enemies.is_empty():
			var enemy := enemies[0] as Dictionary
			_expect_true(str(enemy.get("name", "")).strip_edges() != "", "%s generated enemy has map monster name" % forced_type)


func _test_battle_win_opens_next_map_nodes() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 6262)
	var node := _force_first_available_node_type(expedition, "battle")
	var result: Dictionary = expedition.choose_map_node(str(node.get("id", "")))
	_expect_eq(str(result.get("mode", "")), "battle", "forced battle node enters battle")
	expedition.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {"hp": 55.0, "mp": 20.0, "items": []},
	})
	var settled: Dictionary = expedition.settle_pending_battle()
	_expect_true(bool(settled.get("ok", false)), "battle node win settles")
	_expect_true(expedition.available_node_ids.size() > 0 or str(expedition.current_node_id) == "exit", "battle win opens next route nodes")


func _test_reward_budget_scales_by_days_and_difficulty() -> void:
	var low_event := ExpeditionEventServiceScript.by_id("qinglan_mountain__gather_herbs")
	var high_event := low_event.duplicate(true)
	low_event["difficulty"] = 1
	low_event["duration_days"] = 1
	high_event["difficulty"] = 6
	high_event["duration_days"] = 3
	var low_budget := ExpeditionRewardServiceScript.reward_budget_value_for_event(low_event)
	var high_budget := ExpeditionRewardServiceScript.reward_budget_value_for_event(high_event)
	_expect_true(high_budget > low_budget, "high difficulty and longer duration increase reward budget")
	var raw_rewards: Array = [{"kind": "item", "id": "items_LingCao", "count": 1, "material_grade": 1}]
	var low_rewards := ExpeditionRewardServiceScript.apply_reward_budget(low_event, raw_rewards)
	var high_rewards := ExpeditionRewardServiceScript.apply_reward_budget(high_event, raw_rewards)
	_expect_true(
		ExpeditionRewardServiceScript.reward_value(high_rewards) > ExpeditionRewardServiceScript.reward_value(low_rewards),
		"reward budget scales concrete rewards"
	)


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
	_expect_eq(_inventory_total(game.inventory), inv_before, "game inventory unchanged during active expedition")
	var slot_id := str(expedition.runtime.get("item_slots", [])[0])
	if slot_id != "":
		var runtime_inv := expedition.runtime.get("inventory", {}) as Dictionary
		_expect_eq(int(runtime_inv.get(slot_id, 0)), 2, "runtime pill consumption updated")


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


func _test_boss_battle_resolves_at_high_difficulty() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 909)
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_boss")]
	expedition.choose_event("qinglan_boss")
	expedition.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {"hp": 40.0, "mp": 10.0, "items": []},
	})
	var settled: Dictionary = expedition.settle_pending_battle()
	_expect_true(bool(settled.get("ok", false)), "boss battle settled")
	_expect_true(expedition.active, "expedition continues after boss win")


func _test_game_settlement_occurs_once() -> void:
	var game := _state()
	var lingcao_before := int(game.inventory.get("items_LingCao", 0))
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 1001)
	ExpeditionRewardServiceScript.merge_into_loot(
		expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 2}]
	)
	var finish: Dictionary = expedition.finish("manual")
	_expect_true(str(finish.get("settlement_id", "")) != "", "finish includes settlement_id")
	var first: Dictionary = game.settle_expedition(finish)
	var second: Dictionary = game.settle_expedition(finish)
	_expect_true(bool(first.get("ok", false)), "first settlement ok")
	_expect_true(bool(second.get("duplicate", false)), "duplicate settlement rejected")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), lingcao_before + 2, "inventory not doubled at settlement")
	_expect_eq(game.day, 31, "day advanced by expedition duration")


func _test_distinct_expeditions_settlement_ids() -> void:
	var game := _state()
	var lingcao_before := int(game.inventory.get("items_LingCao", 0))
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 2001)
	ExpeditionRewardServiceScript.merge_into_loot(
		expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 1}]
	)
	var first_finish: Dictionary = expedition.finish("manual")
	game.settle_expedition(first_finish)
	expedition.start("qinglan_mountain", game, 2002)
	ExpeditionRewardServiceScript.merge_into_loot(
		expedition.loot, [{"kind": "item", "id": "items_LingCao", "count": 1}]
	)
	var second_finish: Dictionary = expedition.finish("manual")
	_expect_true(
		str(second_finish.get("settlement_id", "")) != str(first_finish.get("settlement_id", "")),
		"distinct expedition ids"
	)
	var second: Dictionary = game.settle_expedition(second_finish)
	_expect_true(bool(second.get("ok", false)), "second distinct settlement ok")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), lingcao_before + 2, "both loot applied")


func _inventory_total(inventory: Dictionary) -> int:
	var total := 0
	for count_v in inventory.values():
		total += int(count_v)
	return total


func _test_result_payload_from_finish() -> void:
	var game := _state()
	var expedition := _expedition()
	expedition.start("qinglan_mountain", game, 7777)
	_first_event_from_advance_steps(expedition)
	expedition.stats["battles"] = 3
	expedition.stats["wins"] = 2
	expedition.stats["steps"] = 5
	expedition.stats["max_difficulty"] = 4
	expedition.runtime["hp"] = 75.0
	expedition.runtime["mp"] = 42.0
	var finish: Dictionary = expedition.finish("manual")
	var settled: Dictionary = game.settle_expedition(finish)
	_expect_true(bool(settled.get("ok", false)), "settlement ok")
	_expect_true(not settled.has("stats"), "settle return is compact")
	_expect_true(settled.has("elapsed_days"), "settle return has elapsed_days")
	var stats := finish.get("stats", {}) as Dictionary
	_expect_eq(int(stats.get("battles", 0)), 3, "finish payload includes battles")
	_expect_eq(int(stats.get("steps", 0)), 5, "finish payload includes steps")
	_expect_eq(float(finish.get("hp", 0.0)), 75.0, "finish payload includes hp")
	_expect_eq(float(finish.get("mp", 0.0)), 42.0, "finish payload includes mp")
	var event_log := finish.get("event_log", []) as Array
	_expect_true(not event_log.is_empty(), "finish payload includes event log")


func _find_event_by_template(pool: Array, template_id: String) -> Dictionary:
	for event_v in pool:
		var event := event_v as Dictionary
		if str(event.get("template_id", "")) == template_id:
			return event
	return {}


func _first_event_from_advance_steps(expedition: Node) -> Dictionary:
	for _i in 30:
		var result: Dictionary = expedition.advance_step()
		_expect_true(bool(result.get("ok", false)), "advance step ok")
		if str(result.get("mode", "")) == "pass_day":
			continue
		return result.get("event", {}) as Dictionary
	return {}


func _first_available_node_by_type(expedition: Node, type_id: String) -> Dictionary:
	for node_id_v in expedition.available_node_ids:
		for node_v in expedition.map_nodes:
			var node := node_v as Dictionary
			if str(node.get("id", "")) == str(node_id_v) and str(node.get("type", "")) == type_id:
				return node
	return {}


func _force_first_available_node_type(expedition: Node, type_id: String, difficulty: int = -1) -> Dictionary:
	var node_id := str(expedition.available_node_ids[0])
	for i in expedition.map_nodes.size():
		var node := expedition.map_nodes[i] as Dictionary
		if str(node.get("id", "")) == node_id:
			node["type"] = type_id
			node["event_filter_tags"] = [type_id]
			if difficulty > 0:
				node["difficulty"] = difficulty
			expedition.map_nodes[i] = node
			return node
	return {}


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
