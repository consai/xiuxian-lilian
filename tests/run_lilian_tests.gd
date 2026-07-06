extends SceneTree

const LilianEventServiceScript := preload("res://scripts/lilian/lilian_event_service.gd")
const LilianMapServiceScript := preload("res://scripts/lilian/lilian_map_service.gd")
const LilianRewardServiceScript := preload("res://scripts/lilian/lilian_reward_service.gd")
const LilianRulesServiceScript := preload("res://scripts/lilian/lilian_rules_service.gd")
const DidianServiceScript := preload("res://scripts/lilian/didian_service.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("start creates isolated runtime", _test_start_creates_isolated_runtime)
	_run("lilian map is deterministic", _test_expedition_map_is_deterministic)
	_run("tutorial lilian map is single path", _test_tutorial_expedition_map_is_single_path)
	_run("lilian map is reachable", _test_expedition_map_is_reachable)
	_run("lilian map is longer and ends with boss", _test_expedition_map_is_longer_and_ends_with_boss)
	_run("lilian map has three lanes and limited crosses", _test_expedition_map_has_three_lanes_and_limited_crosses)
	_run("map node choice is gated", _test_map_node_choice_is_gated)
	_run("event pick ignores configured difficulty", _test_event_pick_ignores_configured_difficulty)
	_run("common events use location generation", _test_common_events_use_location_generation)
	_run("location declares monsters and materials", _test_location_declares_monsters_and_materials)
	_run("lianqi lilian combat bands are readable", _test_qi_expedition_combat_bands_are_readable)
	_run("difficulty rolls material grade variants", _test_difficulty_rolls_material_grade_variants)
	_run("monster drops materialize from map enemy", _test_monster_drops_materialize_from_map_enemy)
	_run("early common battles form small groups", _test_early_common_battles_form_small_groups)
	_run("group battles keep full monster attrs", _test_group_battles_keep_full_monster_attrs)
	_run("lilian modes keep event pools separate", _test_lilian_modes_keep_event_pools_separate)
	_run("common event duration advances days", _test_common_event_duration_advances_days)
	_run("decision event exposes options", _test_decision_event_exposes_options)
	_run("common decision choice resolves", _test_common_decision_choice_resolves)
	_run("p3 mist valley chain exposes next goals", _test_p3_mist_valley_chain)
	_run("non battle events advance lilian", _test_non_battle_events_advance)
	_run("manual exit keeps all loot", _test_manual_exit_keeps_all_loot)
	_run("defeat exit drops session loot and injury", _test_defeat_exit_drops_session_loot_and_injury)
	_run("defeat loot drops fixed twenty percent", _test_defeat_loot_drops_fixed_twenty_percent)
	_run("elapsed days track lilian days", _test_elapsed_days_track_expedition_days)
	_run("quiet days advance time without logs", _test_quiet_days_advance_without_logs)
	_run("battle node builds unchanged battle init", _test_battle_node_builds_unchanged_battle_init)
	_run("elite and boss nodes always resolve battle", _test_elite_and_boss_nodes_always_resolve_battle)
	_run("high difficulty battle nodes generate map enemies", _test_high_difficulty_battle_nodes_generate_map_enemies)
	_run("battle win opens next map nodes", _test_battle_win_opens_next_map_nodes)
	_run("reward budget scales by days and difficulty", _test_reward_budget_scales_by_days_and_difficulty)
	_run("battle win returns to lilian", _test_battle_win_returns_to_lilian)
	_run("runtime potion slot can be used manually", _test_runtime_potion_slot_can_be_used_manually)
	_run("battle loss forces lilian result", _test_battle_loss_forces_lilian_jiesuan)
	_run("boss battle resolves at high difficulty", _test_boss_battle_resolves_at_high_difficulty)
	_run("game settlement occurs once", _test_game_settlement_occurs_once)
	_run("distinct expeditions do not collide on settlement", _test_distinct_expeditions_settlement_ids)
	_run("event pick is deterministic from event pool", _test_event_pick_deterministic)
	_run("result screen uses finish payload not settle return", _test_result_payload_from_finish)
	if _failures.is_empty():
		print("PASS: %d lilian tests" % _tests_run)
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


func _lilian() -> Node:
	return root.get_node("LilianState")


func _test_start_creates_isolated_runtime() -> void:
	var game := _state()
	var lilian := _lilian()
	var started: Dictionary = lilian.start("qinglan_mountain", game, 101)
	_expect_true(bool(started.get("ok", false)), "start ok")
	_expect_true(lilian.active, "lilian active")
	_expect_near(float(lilian.runtime.get("hp", 0.0)), game.hp, "runtime hp copied")
	var starting_hp: float = game.hp
	game.hp = 1.0
	_expect_near(float(lilian.runtime.get("hp", 0.0)), starting_hp, "runtime isolated from game")
	_expect_true(starting_hp >= 130.0, "starter attributes are battle ready")
	_expect_true(not lilian.map_nodes.is_empty(), "start generates route map")
	_expect_true(not lilian.available_node_ids.is_empty(), "start exposes first route choices")


func _test_expedition_map_is_deterministic() -> void:
	var location := DidianServiceScript.by_id("qinglan_mountain")
	var first := LilianMapServiceScript.generate(location, 9191)
	var second := LilianMapServiceScript.generate(location, 9191)
	_expect_eq(first, second, "same seed generates same lilian map")


func _test_tutorial_expedition_map_is_single_path() -> void:
	var location := DidianServiceScript.by_id("wild_wolf_valley")
	var map_data := LilianMapServiceScript.generate_tutorial(location)
	var nodes := map_data.get("nodes", []) as Array
	var edges := map_data.get("edges", []) as Array
	_expect_eq(nodes.size(), 3, "tutorial map has three nodes")
	_expect_eq(edges.size(), 2, "tutorial map has one path edge per step")
	var gather := LilianMapServiceScript.node_by_id(nodes, "tutorial_gather")
	var battle := LilianMapServiceScript.node_by_id(nodes, "tutorial_battle")
	_expect_eq(str(gather.get("type", "")), "gather", "middle node is gather")
	_expect_eq(str(battle.get("type", "")), "battle", "last node is battle")
	_expect_eq(str(battle.get("label", "")), "怪物", "battle node shows monster label")
	_expect_eq(str(gather.get("fixed_event_id", "")), "tutorial_valley_herbs", "gather binds tutorial herb event")
	_expect_eq(str(battle.get("fixed_event_id", "")), "qinglan_wolf", "battle binds wolf event")
	var game := _state()
	var lilian := _lilian()
	var store := root.get_node("DataStore")
	store.reset_savedata()
	game.new_game()
	var tutorial := store.savedata.get("tutorial", {}) as Dictionary
	tutorial["completed"] = false
	tutorial["skipped"] = false
	store.savedata["tutorial"] = tutorial
	var started: Dictionary = lilian.start("wild_wolf_valley", game, 777)
	_expect_true(bool(started.get("ok", false)), "tutorial lilian starts")
	_expect_eq(lilian.map_nodes.size(), 3, "active tutorial lilian uses short map")
	_expect_eq(lilian.available_node_ids.size(), 1, "only one next node from start")
	_expect_eq(str(lilian.available_node_ids[0]), "tutorial_gather", "first step is gather")
	_expect_true(LilianMapServiceScript.is_compact_map(nodes), "tutorial map uses compact layout")


func _test_expedition_map_is_reachable() -> void:
	for location_v in DidianServiceScript.all_locations():
		var location := location_v as Dictionary
		var map_data := LilianMapServiceScript.generate(location, 1234)
		_expect_true(LilianMapServiceScript.is_reachable_to_exit(map_data), "map reaches exit for %s" % str(location.get("id", "")))


func _test_expedition_map_is_longer_and_ends_with_boss() -> void:
	var location := DidianServiceScript.by_id("qinglan_mountain")
	var map_data := LilianMapServiceScript.generate(location, 5252)
	var exit_node := LilianMapServiceScript.node_by_id(map_data.get("nodes", []) as Array, "exit")
	_expect_eq(str(exit_node.get("type", "")), "boss", "exit node is always boss")
	_expect_true(int(exit_node.get("layer", 0)) >= 9, "route has at least eight middle layers before boss")
	for node_v in map_data.get("nodes", []) as Array:
		var node := node_v as Dictionary
		if str(node.get("id", "")) == "exit":
			continue
		_expect_true(
			str(node.get("type", "")) != "boss",
			"middle route node %s is not boss" % str(node.get("id", ""))
		)


func _test_expedition_map_has_three_lanes_and_limited_crosses() -> void:
	var location := DidianServiceScript.by_id("qinglan_mountain")
	for seed_value in [101, 202, 303, 404]:
		var map_data := LilianMapServiceScript.generate(location, seed_value)
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
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 8181)
	var locked_node_id := ""
	for node_v in lilian.map_nodes:
		var node := node_v as Dictionary
		var node_id := str(node.get("id", ""))
		if node_id != "start" and not lilian.available_node_ids.has(node_id):
			locked_node_id = node_id
			break
	_expect_true(locked_node_id != "", "found locked node")
	var blocked: Dictionary = lilian.choose_map_node(locked_node_id)
	_expect_true(not bool(blocked.get("ok", true)), "locked node cannot be chosen")
	var available_id := str(lilian.available_node_ids[0])
	var chosen: Dictionary = lilian.choose_map_node(available_id)
	_expect_true(bool(chosen.get("ok", false)), "available node can be chosen")
	var repeated: Dictionary = lilian.choose_map_node(available_id)
	_expect_true(not bool(repeated.get("ok", true)), "chosen node cannot be repeated while resolving")


func _test_event_pick_ignores_configured_difficulty() -> void:
	var location := DidianServiceScript.by_id("wild_wolf_valley")
	var capped := location.duplicate(true)
	capped["max_difficulty"] = 2
	var boss_node := {"id": "forced_boss", "type": "boss", "difficulty": 1}
	var candidates := LilianEventServiceScript.candidates_for_node(capped, boss_node, [])
	var has_boss := false
	for event_v in candidates:
		var event := event_v as Dictionary
		if str(event.get("id", "")) == "qinglan_boss":
			has_boss = true
	_expect_true(not has_boss, "boss event is gated before checkpoint difficulty")
	boss_node["difficulty"] = 5
	candidates = LilianEventServiceScript.candidates_for_node(capped, boss_node, [])
	has_boss = false
	for event_v in candidates:
		var event := event_v as Dictionary
		if str(event.get("id", "")) == "qinglan_boss":
			has_boss = true
	_expect_true(has_boss, "boss event unlocks at checkpoint difficulty")
	var rolled := LilianEventServiceScript.roll_event_for_node(capped, boss_node, [], _rng(303))
	_expect_true(not rolled.is_empty(), "rolled event materializes")
	_expect_eq(int(rolled.get("difficulty", 0)), 5, "rolled event uses node difficulty")


func _test_event_pick_deterministic() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 3333)
	var first := _first_event_from_advance_steps(lilian)
	_expect_true(not first.is_empty(), "first pool event selected")
	lilian.reset()
	lilian.start("qinglan_mountain", game, 3333)
	var repeated := _first_event_from_advance_steps(lilian)
	_expect_eq(first, repeated, "same seed same rolled event")


func _test_common_events_use_location_generation() -> void:
	var location := DidianServiceScript.by_id("blackwater_marsh")
	var pool := LilianEventServiceScript.event_pool_for_location(location)
	var herbs := _find_event_by_template(pool, "gather_herbs")
	var beast := _find_event_by_template(pool, "local_beast")
	var traveler := _find_event_by_template(pool, "wandering_cultivator")
	_expect_eq(str(herbs.get("id", "")), "blackwater_marsh__gather_herbs", "common event gets stable generated id")
	_expect_eq(str(herbs.get("location_id", "")), "blackwater_marsh", "common event binds current location")
	_expect_eq(str(herbs.get("drop_pool", "")), "herbs", "gather references location drop pool")
	_expect_eq(int(beast.get("duration_days", 0)), 2, "common battle uses location duration")
	_expect_eq(LilianEventServiceScript.by_id(str(beast.get("id", ""))), beast, "generated event can be restored by id")
	var materialized_beast := LilianEventServiceScript.roll_event_for_node(
		location,
		{"id": "battle_1", "type": "battle", "difficulty": 2},
		[],
		_rng(161)
	)
	_expect_eq(str(LilianEventServiceScript.build_battle_enemy(materialized_beast).get("name", "")), "毒沼蛇", "battle resolves location enemy pool at runtime")
	for template_id in ["gather_fruit", "hidden_cache", "harsh_terrain", "deep_rest", "wandering_cultivator", "local_elite"]:
		_expect_true(not _find_event_by_template(pool, template_id).is_empty(), "rich common template generated: %s" % template_id)
	var exchange := LilianEventServiceScript.find_decision_option(traveler, "exchange")
	_expect_true(not (exchange.get("results", []) as Array).is_empty(), "decision option references location drop pool")


func _test_location_declares_monsters_and_materials() -> void:
	var monsters := DidianServiceScript.monsters_for_location("blackwater_marsh")
	var materials := DidianServiceScript.materials_for_location("blackwater_marsh")
	_expect_true(monsters.size() >= 2, "blackwater declares available monsters")
	_expect_true(materials.size() >= 3, "blackwater declares available materials")
	_expect_eq(str((monsters[0] as Dictionary).get("id", "")), "poison_marsh_serpent", "map monster id resolves global monster")
	_expect_eq(str((monsters[0] as Dictionary).get("species", "")), "beast", "resolved monster keeps species")
	var config_manager := root.get_node("ConfigManager")
	_expect_true(not config_manager.monster_drop_entries(monsters[0] as Dictionary).is_empty(), "resolved monster keeps drops")
	var found_superior_material := false
	for material_v in materials:
		var material := material_v as Dictionary
		if (material.get("item_ids", []) as Array).has("items_LingCao_Superior"):
			found_superior_material = true
	_expect_true(found_superior_material, "map material list includes quality variants")


func _test_qi_expedition_combat_bands_are_readable() -> void:
	var specs: Array = [
		{
			"location": "qinglan_mountain",
			"normal": "qinglan_wolf",
			"elite": "ironback_bear",
			"boss": "qinglan_boss",
			"max_difficulty": 6,
		},
		{
			"location": "wild_wolf_valley",
			"normal": "qinglan_wolf",
			"elite": "qinglan_serpent",
			"boss": "qinglan_boss",
			"max_difficulty": 6,
		},
		{
			"location": "blackwater_marsh",
			"normal": "poison_marsh_serpent",
			"elite": "rot_armor_crocodile",
			"boss": "blackwater_boss",
			"max_difficulty": 5,
		},
		{
			"location": "mist_hidden_valley",
			"normal": "mist_marten",
			"elite": "vine_armor_guard",
			"boss": "sealed_creek_boss",
			"max_difficulty": 8,
		},
	]
	for spec_v in specs:
		var spec := spec_v as Dictionary
		var location := DidianServiceScript.by_id(str(spec["location"]))
		var monster_ids := location.get("monsters", []) as Array
		for key in ["normal", "elite", "boss"]:
			_expect_true(monster_ids.has(str(spec[key])), "%s declares %s monster" % [spec["location"], key])
		_expect_combat_band_event(location, "battle", int(location.get("min_difficulty", 1)), str(spec["normal"]))
		_expect_combat_band_event(location, "elite", int(spec["max_difficulty"]), str(spec["elite"]))
		var boss := _expect_combat_band_event(location, "boss", int(spec["max_difficulty"]), str(spec["boss"]))
		_expect_true(bool(boss.get("once_per_lilian", false)), "%s boss is a checkpoint" % spec["location"])
		_expect_true(
			ConditionService.all_met(boss.get("conditions", []) as Array, {"difficulty": int(spec["max_difficulty"])}),
			"%s boss unlocks at max difficulty" % spec["location"]
		)


func _expect_combat_band_event(location: Dictionary, node_type: String, difficulty: int, monster_id: String) -> Dictionary:
	var event := LilianEventServiceScript.roll_event_for_node(
		location,
		{"id": "pm202_%s_%s" % [str(location.get("id", "")), node_type], "type": node_type, "difficulty": difficulty},
		[],
		_rng(20202 + difficulty)
	)
	_expect_eq(str(event.get("type", "")), node_type, "%s rolls %s event" % [location.get("id", ""), node_type])
	_expect_eq(str(event.get("enemy_pool", "")), monster_id, "%s %s uses expected monster" % [location.get("id", ""), node_type])
	var enemies := LilianEventServiceScript.build_battle_enemies(event)
	_expect_true(not enemies.is_empty(), "%s %s builds enemies" % [location.get("id", ""), node_type])
	var formation := LilianEventServiceScript.build_enemy_formation(event, enemies)
	if node_type == "boss":
		_expect_eq(enemies.size(), 1, "%s boss stays single target" % location.get("id", ""))
		_expect_eq(int(formation.get("rank_size", 0)), 1, "%s boss uses checkpoint formation" % location.get("id", ""))
	elif node_type == "elite":
		_expect_true(enemies.size() >= 2, "%s elite can pressure prepared players" % location.get("id", ""))
	else:
		_expect_true(enemies.size() <= 2, "%s starter normal battle stays farmable" % location.get("id", ""))
	return event


func _test_difficulty_rolls_material_grade_variants() -> void:
	var event := LilianEventServiceScript.by_id("qinglan_mountain__gather_herbs")
	event["difficulty"] = 6
	var found_high_grade := false
	for seed_value in range(50, 90):
		var rewards := LilianRewardServiceScript.roll_event_rewards(event, _rng(seed_value))
		for reward_v in rewards:
			var reward := reward_v as Dictionary
			if int(reward.get("material_grade", 1)) >= 2:
				found_high_grade = true
	_expect_true(found_high_grade, "high difficulty can roll higher grade material")


func _test_monster_drops_materialize_from_map_enemy() -> void:
	var location := DidianServiceScript.by_id("blackwater_marsh")
	var node := {"id": "battle_1", "type": "battle", "difficulty": 5}
	var event := LilianEventServiceScript.roll_event_for_node(location, node, [], _rng(515))
	_expect_eq(str(event.get("drop_pool", "")), "monster:poison_marsh_serpent", "battle event materializes exact monster drop pool")
	_expect_eq(int(event.get("difficulty", 0)), 5, "battle event keeps current node difficulty")
	var rewards := LilianRewardServiceScript.roll_event_rewards(event, _rng(515))
	_expect_true(not rewards.is_empty(), "materialized monster drop rolls rewards")
	for reward_v in rewards:
		var reward := reward_v as Dictionary
		_expect_true(str(reward.get("id", "")) != "", "monster reward keeps reward id")


func _test_early_common_battles_form_small_groups() -> void:
	var event := LilianEventServiceScript.roll_event_for_node(
		DidianServiceScript.by_id("qinglan_mountain"),
		{"id": "battle_1", "type": "battle", "difficulty": 2},
		[],
		_rng(7070)
	)
	var enemies := LilianEventServiceScript.build_battle_enemies(event)
	_expect_eq(enemies.size(), 2, "qinglan starter beast should spawn a small group")
	var enemy := enemies[0] as Dictionary
	_expect_true(float(enemy.get("hp", 0.0)) >= 75.0, "starter group enemy keeps full hp")
	var attrs := enemy.get("attrs", {}) as Dictionary
	_expect_true(float(attrs.get("physical_atk", 0.0)) >= 21.0, "starter group enemy keeps full attack")
	_expect_true(str(enemy.get("name", "")).contains("·"), "starter group enemy gets numbered name")
	var slots := enemy.get("skills", []) as Array
	var found_active_skill := false
	for slot_v in slots:
		var slot := slot_v as Dictionary
		if int(slot.get("id", -1)) > 0:
			found_active_skill = true
	_expect_true(found_active_skill, "starter group keeps active skill slot")


func _test_group_battles_keep_full_monster_attrs() -> void:
	var event := LilianEventServiceScript.roll_event_for_node(
		DidianServiceScript.by_id("qinglan_mountain"),
		{"id": "battle_6", "type": "battle", "difficulty": 6},
		[],
		_rng(7071)
	)
	var enemies := LilianEventServiceScript.build_battle_enemies(event)
	_expect_eq(enemies.size(), 4, "difficulty six common battle forms a larger group")
	var single_event := event.duplicate(true)
	single_event["enemy_count"] = 1
	var single_enemy := LilianEventServiceScript.build_battle_enemies(single_event)[0] as Dictionary
	var single_attrs := single_enemy.get("attrs", {}) as Dictionary
	var single_atk := float(single_attrs.get(ZhandouAttr.PHYSICAL_ATK, 0.0))
	var single_hp := float(single_enemy.get("hp", 0.0))
	for enemy_v in enemies:
		var enemy := enemy_v as Dictionary
		_expect_near(float(enemy.get("hp", 0.0)), single_hp, "group count does not reduce per-enemy hp")
		var attrs := enemy.get("attrs", {}) as Dictionary
		_expect_near(float(attrs.get(ZhandouAttr.PHYSICAL_ATK, 0.0)), single_atk, "group count does not reduce per-enemy atk")
		var slots := enemy.get("skills", []) as Array
		var found_active_skill := false
		for slot_v in slots:
			var slot := slot_v as Dictionary
			if int(slot.get("id", -1)) > 0:
				found_active_skill = true
		_expect_true(found_active_skill, "group enemy keeps active skill slot")


func _test_lilian_modes_keep_event_pools_separate() -> void:
	var resource_location := DidianServiceScript.by_id("qinglan_mountain")
	_expect_true((resource_location.get("tags", []) as Array).has("resource"), "qinglan is tagged resource")
	var blackwater_location := DidianServiceScript.by_id("blackwater_marsh")
	_expect_true((blackwater_location.get("tags", []) as Array).has("resource"), "blackwater is tagged resource")
	var resource_pool := LilianEventServiceScript.event_pool_for_location(resource_location)
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
	var story_location := DidianServiceScript.by_id("wild_wolf_valley")
	_expect_true((story_location.get("tags", []) as Array).has("story"), "wild wolf valley is tagged story")
	var story_pool := LilianEventServiceScript.event_pool_for_location(story_location)
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
	var lilian := _lilian()
	lilian.start("blackwater_marsh", game, 3030)
	var event := LilianEventServiceScript.by_id("blackwater_marsh__recover_hp")
	event["duration_days"] = 3
	lilian.runtime["hp"] = 10.0
	lilian.current_choices = [event]
	lilian.phase = "choosing"
	var result: Dictionary = lilian.choose_event(str(event.get("id", "")))
	_expect_true(bool(result.get("ok", false)), "generated duration event resolves")
	_expect_eq(lilian.days, 2, "event duration adds extra elapsed days")


func _test_decision_event_exposes_options() -> void:
	var traveler := LilianEventServiceScript.by_id("blackwater_marsh__wandering_cultivator")
	_expect_true(LilianEventServiceScript.is_decision_event(traveler), "wandering cultivator is decision")
	var options := LilianEventServiceScript.decision_options_as_choices(traveler)
	_expect_eq(options.size(), 2, "two decision options")
	_expect_true(str((options[0] as Dictionary).get("id", "")).contains("::"), "composite choice id")


func _test_common_decision_choice_resolves() -> void:
	var traveler := LilianEventServiceScript.by_id("blackwater_marsh__wandering_cultivator")
	var options := LilianEventServiceScript.decision_options_as_choices(traveler)
	var choice_id := str((options[0] as Dictionary).get("id", ""))
	var parsed := LilianEventServiceScript.parse_decision_choice_id(choice_id)
	_expect_eq(str(parsed.get("parent_id", "")), str(traveler.get("id", "")), "parses parent id from composite choice id")
	_expect_eq(str(parsed.get("option_id", "")), "exchange", "parses option id from composite choice id")
	var game := _state()
	var lilian := _lilian()
	lilian.start("blackwater_marsh", game, 505)
	lilian.pending_decision_event = traveler.duplicate(true)
	lilian.current_choices = options
	lilian.phase = "choosing"
	var result: Dictionary = lilian.choose_event(choice_id)
	_expect_true(bool(result.get("ok", false)), "common decision choice resolves")


func _test_p3_mist_valley_chain() -> void:
	var location := DidianServiceScript.by_id("mist_hidden_valley")
	_expect_true(not location.is_empty(), "p3 location exists")
	var pool := location.get("event_pool", []) as Array
	for event_id in [
		"mist_creek_chain_tracks",
		"mist_creek_chain_choice",
		"mist_creek_chain_seal_core",
	]:
		_expect_true(pool.has(event_id), "p3 chain includes %s" % event_id)
	var tracks := LilianEventServiceScript.by_id("mist_creek_chain_tracks")
	_expect_true(LilianEventServiceScript.is_decision_event(tracks), "p3 chain starts with decision")
	var trace := LilianEventServiceScript.find_decision_option(tracks, "trace")
	_expect_eq(str(trace.get("trigger_event", "")), "mist_creek_chain_fog_test", "trace option triggers fog test")
	var seal := LilianEventServiceScript.by_id("mist_creek_chain_seal_core")
	_expect_eq(str(seal.get("enemy_pool", "")), "sealed_creek_boss", "p3 chain boss uses sealed creek boss")
	var rewards := (seal.get("results", []) as Array)[1] as Dictionary
	var reward := (rewards.get("rewards", []) as Array)[0] as Dictionary
	_expect_eq(str(reward.get("id", "")), "book_method_hunyuan_2", "p3 chain points to zhuji method")


func _test_non_battle_events_advance() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("blackwater_marsh", game, 404)
	var herbs := LilianEventServiceScript.by_id("blackwater_marsh__gather_herbs")
	var before_steps: int = int(lilian.steps)
	var before_max_diff: int = int((lilian.stats as Dictionary).get("max_difficulty", 0))
	var before_loot: int = (lilian.loot as Array).size()
	lilian.current_choices = [herbs]
	lilian.phase = "choosing"
	var result: Dictionary = lilian.choose_event(str(herbs.get("id", "")))
	_expect_true(bool(result.get("ok", false)), "gather resolves")
	_expect_true(str(result.get("outcome", "")).contains("依照药性"), "gather uses event-specific outcome text")
	_expect_eq(lilian.steps, before_steps + 1, "steps increased")
	_expect_true(int((lilian.stats as Dictionary).get("max_difficulty", 0)) >= before_max_diff, "max difficulty tracked")
	_expect_true(lilian.loot.size() >= before_loot, "session loot tracked")
	var inv_before: int = int(game.inventory.get("items_LingCao", 0))
	var loot_total := 0
	for reward_v in lilian.loot:
		var reward := reward_v as Dictionary
		loot_total += int(reward.get("count", 0))
	_expect_true(loot_total > 0, "gather reward in session loot")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), inv_before, "game inventory unchanged during lilian")
	game.hp = 10.0
	lilian.runtime["hp"] = 10.0
	var shelter := LilianEventServiceScript.by_id("blackwater_marsh__recover_hp")
	lilian.current_choices = [shelter]
	lilian.phase = "choosing"
	lilian.choose_event(str(shelter.get("id", "")))
	_expect_true(float(lilian.runtime.get("hp", 0.0)) > 10.0, "recover raises hp")
	var terrain := LilianEventServiceScript.by_id("blackwater_marsh__harsh_terrain")
	lilian.current_choices = [terrain]
	lilian.phase = "choosing"
	var terrain_result: Dictionary = lilian.choose_event(str(terrain.get("id", "")))
	_expect_true(str(terrain_result.get("outcome", "")).contains("脱身"), "hazard uses location-specific feedback")


func _test_manual_exit_keeps_all_loot() -> void:
	var game := _state()
	var lingcao_before := int(game.inventory.get("items_LingCao", 0))
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 505)
	LilianRewardServiceScript.merge_into_loot(
		lilian.loot, [{"kind": "item", "id": "items_LingCao", "count": 4}]
	)
	var finish: Dictionary = lilian.finish("manual")
	var settled: Dictionary = game.settle_lilian(finish)
	_expect_true(bool(settled.get("ok", false)), "settlement ok")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), lingcao_before + 4, "loot merged into inventory")
	_expect_eq(game.day, 31, "manual exit advances by lilian duration")


func _test_defeat_exit_drops_session_loot_and_injury() -> void:
	var game := _state()
	game.inventory["items_LingCao"] = 3
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 606)
	LilianRewardServiceScript.merge_into_loot(
		lilian.loot,
		[{"kind": "item", "id": "items_LingCao", "count": 5}],
	)
	var inv_before := _inventory_total(game.inventory)
	lilian.runtime["hp"] = 0.0
	var finish: Dictionary = lilian.finish("defeated")
	_expect_eq(_inventory_total(game.inventory), inv_before, "game inventory unchanged before settle")
	_expect_true(not (finish.get("loot_lost", []) as Array).is_empty(), "loot_lost recorded")
	var loot_arr := finish.get("loot", []) as Array
	var loot_total := 0
	for r in loot_arr:
		loot_total += int((r as Dictionary).get("count", 0))
	_expect_eq(loot_total, 4, "defeat keeps eighty percent of rounded session loot")
	var lost_total := 0
	for r in finish.get("loot_lost", []) as Array:
		lost_total += int((r as Dictionary).get("count", 0))
	_expect_eq(lost_total, 1, "defeat drops twenty percent of rounded session loot")
	game.settle_lilian(finish)
	_expect_eq(_inventory_total(game.inventory), inv_before + loot_total, "kept session loot merged on settle")
	_expect_near(game.hp, ZhandouAttr.get_attr(game.attrs, ZhandouAttr.HP_MAX) * 0.4, "defeat hp floor")
	_expect_eq(game.injury_days, 2, "defeat injury applied after elapsed reduction")


func _test_defeat_loot_drops_fixed_twenty_percent() -> void:
	var loot_a: Array = [
		{"kind": "item", "id": "items_LingCao", "count": 6},
		{"kind": "item", "id": "items_HuiQiDan", "count": 4},
	]
	var loss_a := LilianRewardServiceScript.apply_loot_loss_on_defeat(loot_a)
	_expect_eq(
		loss_a.get("lost", []),
		[
			{"kind": "item", "id": "items_LingCao", "count": 1, "source": "session_loot"},
			{"kind": "item", "id": "items_HuiQiDan", "count": 1, "source": "session_loot"},
		],
		"defeat drops fixed twenty percent across loot stacks"
	)
	var remaining := 0
	for r in loot_a:
		remaining += int((r as Dictionary).get("count", 0))
	_expect_eq(remaining, 8, "session loot keeps eighty percent")


func _test_elapsed_days_track_expedition_days() -> void:
	_expect_eq(LilianRulesServiceScript.elapsed_days(0, "lianqi"), 30, "0 days -> lianqi lilian duration")
	_expect_eq(LilianRulesServiceScript.elapsed_days(1, "lianqi"), 30, "1 day -> lianqi lilian duration")
	_expect_eq(LilianRulesServiceScript.elapsed_days(31, "lianqi"), 31, "31 days -> actual elapsed")
	_expect_eq(LilianRulesServiceScript.elapsed_days(0, "zhuji"), 60, "zhuji duration scales")


func _test_quiet_days_advance_without_logs() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 5151)
	var departure_logs: int = lilian.event_log.size()
	var days_before: int = int(lilian.days)
	var result: Dictionary = lilian.advance_day()
	_expect_true(bool(result.get("ok", false)), "advance day ok")
	_expect_true(int(lilian.days) > days_before, "days advanced")
	if str(result.get("mode", "")) == "resolving":
		var completed: Dictionary = lilian.complete_current_step()
		_expect_true(bool(completed.get("ok", false)), "node event completes")
	_expect_true(lilian.event_log.size() >= departure_logs, "route node keeps or extends log")


func _test_battle_node_builds_unchanged_battle_init() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 6161)
	var node := _first_available_node_by_type(lilian, "battle")
	if node.is_empty():
		node = _force_first_available_node_type(lilian, "battle")
	var result: Dictionary = lilian.choose_map_node(str(node.get("id", "")))
	_expect_true(bool(result.get("ok", false)), "battle route node starts")
	if str(result.get("mode", "")) != "battle":
		return
	var init_data: Dictionary = lilian.build_battle_init()
	_expect_true(ZhandouInitData.collect_errors(init_data).is_empty(), "battle node builds valid battle init")


func _test_elite_and_boss_nodes_always_resolve_battle() -> void:
	for forced_type in ["elite", "boss"]:
		var game := _state()
		var lilian := _lilian()
		lilian.start("qinglan_mountain", game, 6363)
		var node := _force_first_available_node_type(lilian, forced_type)
		var result: Dictionary = lilian.choose_map_node(str(node.get("id", "")))
		_expect_eq(str(result.get("mode", "")), "battle", "%s node falls back to battle candidate" % forced_type)
		var init_data: Dictionary = lilian.build_battle_init()
		_expect_true(ZhandouInitData.collect_errors(init_data).is_empty(), "%s fallback battle init is valid" % forced_type)
		var formation := init_data.get("enemy_formation", {}) as Dictionary
		if forced_type == "boss":
			_expect_eq(int(formation.get("rank_size", 0)), 1, "boss battle places one enemy per rank")
		else:
			_expect_eq(int(formation.get("rank_size", 0)), 2, "elite battle places two enemies per rank")


func _test_high_difficulty_battle_nodes_generate_map_enemies() -> void:
	for forced_type in ["battle", "elite"]:
		var game := _state()
		var lilian := _lilian()
		(root.get_node("DataStore").lilian_runtime() as Dictionary)["difficulty_override"] = {"min_difficulty": 5, "max_difficulty": 6}
		lilian.start("qinglan_mountain", game, 6464)
		var node := _force_first_available_node_type(lilian, forced_type, 6)
		var result: Dictionary = lilian.choose_map_node(str(node.get("id", "")))
		_expect_eq(str(result.get("mode", "")), "battle", "%s node enters battle at difficulty 5-6" % forced_type)
		var event := result.get("event", {}) as Dictionary
		_expect_true(not str(event.get("id", "")).begins_with("generated::"), "%s node uses materialized event template" % forced_type)
		_expect_eq(str(event.get("type", "")), forced_type, "%s generated event keeps node battle type" % forced_type)
		_expect_eq(int(event.get("difficulty", 0)), 6, "%s materialized event uses node difficulty" % forced_type)
		_expect_true(str(event.get("drop_pool", "")).begins_with("monster:"), "%s materialized event uses monster drop pool" % forced_type)
		_expect_true(float(event.get("enemy_difficulty_scale", 1.0)) > 1.0, "%s generated event scales enemy attrs" % forced_type)
		var init_data: Dictionary = lilian.build_battle_init()
		_expect_true(ZhandouInitData.collect_errors(init_data).is_empty(), "%s generated battle init valid" % forced_type)
		var enemies := init_data.get("enemies", []) as Array
		var formation := init_data.get("enemy_formation", {}) as Dictionary
		_expect_eq(str(formation.get("mode", "")), EnumBattleFormationMode.LABEL_COLUMNS, "%s generated battle uses column formation" % forced_type)
		_expect_eq(int(formation.get("columns", 0)), 3, "%s generated battle has three formation columns" % forced_type)
		_expect_eq(int(formation.get("rows", 0)), 5, "%s generated battle has five formation rows" % forced_type)
		_expect_eq(int(formation.get("active_columns", 0)), 1, "%s generated battle only activates front column" % forced_type)
		if forced_type == "battle":
			_expect_eq(enemies.size(), 4, "difficulty six normal battle generates group size from difficulty")
			_expect_eq(int(formation.get("rank_size", 0)), 0, "normal battle fills a full front rank")
		else:
			_expect_eq(enemies.size(), 3, "difficulty six elite battle generates elite group size from difficulty")
			_expect_eq(int(formation.get("rank_size", 0)), 2, "elite battle places two enemies per rank")
		_expect_true(not enemies.is_empty(), "%s generated battle has enemies" % forced_type)
		if not enemies.is_empty():
			var enemy := enemies[0] as Dictionary
			_expect_true(str(enemy.get("name", "")).strip_edges() != "", "%s generated enemy has map monster name" % forced_type)


func _test_battle_win_opens_next_map_nodes() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 6262)
	var node := _force_first_available_node_type(lilian, "battle")
	var result: Dictionary = lilian.choose_map_node(str(node.get("id", "")))
	_expect_eq(str(result.get("mode", "")), "battle", "forced battle node enters battle")
	lilian.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {"hp": 55.0, "mp": 20.0, "items": []},
	})
	var settled: Dictionary = lilian.settle_pending_battle()
	_expect_true(bool(settled.get("ok", false)), "battle node win settles")
	_expect_true(lilian.available_node_ids.size() > 0 or str(lilian.current_node_id) == "exit", "battle win opens next route nodes")


func _test_reward_budget_scales_by_days_and_difficulty() -> void:
	var low_event := LilianEventServiceScript.by_id("qinglan_mountain__gather_herbs")
	var high_event := low_event.duplicate(true)
	low_event["difficulty"] = 1
	low_event["duration_days"] = 1
	high_event["difficulty"] = 6
	high_event["duration_days"] = 3
	var low_budget := LilianRewardServiceScript.reward_budget_value_for_event(low_event)
	var high_budget := LilianRewardServiceScript.reward_budget_value_for_event(high_event)
	_expect_true(high_budget > low_budget, "high difficulty and longer duration increase reward budget")
	var raw_rewards: Array = [{"kind": "item", "id": "items_LingCao", "count": 1, "material_grade": 1}]
	var low_rewards := LilianRewardServiceScript.apply_reward_budget(low_event, raw_rewards)
	var high_rewards := LilianRewardServiceScript.apply_reward_budget(high_event, raw_rewards)
	_expect_true(
		LilianRewardServiceScript.reward_value(high_rewards) > LilianRewardServiceScript.reward_value(low_rewards),
		"reward budget scales concrete rewards"
	)


func _test_battle_win_returns_to_lilian() -> void:
	var game := _state()
	var day_before: int = int(game.day)
	var inv_before := _inventory_total(game.inventory)
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 707)
	lilian.current_choices = [LilianEventServiceScript.by_id("qinglan_wolf")]
	lilian.choose_event("qinglan_wolf")
	lilian.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {
			"hp": 55.0,
			"mp": 20.0,
			"items": [{"id": 9001, "count": 2}, {"id": 9003, "count": 1}],
		},
	})
	var settled: Dictionary = lilian.settle_pending_battle()
	_expect_true(bool(settled.get("ok", false)), "battle settled")
	_expect_true(lilian.active, "lilian still active")
	_expect_eq(game.day, day_before, "game day unchanged")
	_expect_near(float(lilian.runtime.get("hp", 0.0)), 55.0, "runtime hp updated")
	_expect_true(not lilian.loot.is_empty(), "battle loot tracked in session")
	_expect_eq(_inventory_total(game.inventory), inv_before, "game inventory unchanged during active lilian")
	var slot_id := str(lilian.runtime.get("item_slots", [])[0])
	if slot_id != "":
		var runtime_inv := lilian.runtime.get("inventory", {}) as Dictionary
		_expect_eq(int(runtime_inv.get(slot_id, 0)), 2, "runtime pill consumption updated")


func _test_runtime_potion_slot_can_be_used_manually() -> void:
	var game := _state()
	game.item_slots = ["items_HuiQiDan", "", ""]
	game.inventory["items_HuiQiDan"] = 2
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 1313)
	lilian.runtime["hp"] = 10.0
	var hp_before := float(lilian.runtime.get("hp", 0.0))
	var inv_before := int((lilian.runtime.get("inventory", {}) as Dictionary).get("items_HuiQiDan", 0))
	var used: Dictionary = lilian.use_runtime_item_slot(0)
	_expect_true(bool(used.get("ok", false)), "manual potion use ok")
	_expect_true(float(lilian.runtime.get("hp", 0.0)) > hp_before, "hp increased after potion")
	_expect_eq(
		int((lilian.runtime.get("inventory", {}) as Dictionary).get("items_HuiQiDan", 0)),
		inv_before - 1,
		"inventory decremented"
	)
	lilian.phase = "battle"
	var in_battle: Dictionary = lilian.use_runtime_item_slot(0)
	_expect_true(bool(in_battle.get("ok", false)), "can use potion before fight overlay starts")


func _test_battle_loss_forces_lilian_jiesuan() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 808)
	lilian.current_choices = [LilianEventServiceScript.by_id("qinglan_wolf")]
	lilian.choose_event("qinglan_wolf")
	lilian.receive_battle_summary({
		"outcome": "loss",
		"player_runtime": {"hp": 0.0, "mp": 5.0, "items": []},
	})
	var settled: Dictionary = lilian.settle_pending_battle()
	_expect_true(bool(settled.get("forced_exit", false)), "loss forces exit")
	_expect_true(lilian.should_go_to_result(), "result scene required")
	_expect_true(lilian.current_choices.is_empty(), "no more choices after defeat")


func _test_boss_battle_resolves_at_high_difficulty() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 909)
	lilian.current_choices = [LilianEventServiceScript.by_id("qinglan_boss")]
	lilian.choose_event("qinglan_boss")
	lilian.receive_battle_summary({
		"outcome": "win",
		"player_runtime": {"hp": 40.0, "mp": 10.0, "items": []},
	})
	var settled: Dictionary = lilian.settle_pending_battle()
	_expect_true(bool(settled.get("ok", false)), "boss battle settled")
	_expect_true(lilian.active, "lilian continues after boss win")


func _test_game_settlement_occurs_once() -> void:
	var game := _state()
	var lingcao_before := int(game.inventory.get("items_LingCao", 0))
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 1001)
	LilianRewardServiceScript.merge_into_loot(
		lilian.loot, [{"kind": "item", "id": "items_LingCao", "count": 2}]
	)
	var finish: Dictionary = lilian.finish("manual")
	_expect_true(str(finish.get("settlement_id", "")) != "", "finish includes settlement_id")
	var first: Dictionary = game.settle_lilian(finish)
	var second: Dictionary = game.settle_lilian(finish)
	_expect_true(bool(first.get("ok", false)), "first settlement ok")
	_expect_true(bool(second.get("duplicate", false)), "duplicate settlement rejected")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), lingcao_before + 2, "inventory not doubled at settlement")
	_expect_eq(game.day, 31, "day advanced by lilian duration")


func _test_distinct_expeditions_settlement_ids() -> void:
	var game := _state()
	var lingcao_before := int(game.inventory.get("items_LingCao", 0))
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 2001)
	LilianRewardServiceScript.merge_into_loot(
		lilian.loot, [{"kind": "item", "id": "items_LingCao", "count": 1}]
	)
	var first_finish: Dictionary = lilian.finish("manual")
	game.settle_lilian(first_finish)
	lilian.start("qinglan_mountain", game, 2002)
	LilianRewardServiceScript.merge_into_loot(
		lilian.loot, [{"kind": "item", "id": "items_LingCao", "count": 1}]
	)
	var second_finish: Dictionary = lilian.finish("manual")
	_expect_true(
		str(second_finish.get("settlement_id", "")) != str(first_finish.get("settlement_id", "")),
		"distinct lilian ids"
	)
	var second: Dictionary = game.settle_lilian(second_finish)
	_expect_true(bool(second.get("ok", false)), "second distinct settlement ok")
	_expect_eq(int(game.inventory.get("items_LingCao", 0)), lingcao_before + 2, "both loot applied")


func _inventory_total(inventory: Dictionary) -> int:
	var total := 0
	for count_v in inventory.values():
		total += int(count_v)
	return total


func _test_result_payload_from_finish() -> void:
	var game := _state()
	var lilian := _lilian()
	lilian.start("qinglan_mountain", game, 7777)
	_first_event_from_advance_steps(lilian)
	lilian.stats["battles"] = 3
	lilian.stats["wins"] = 2
	lilian.stats["steps"] = 5
	lilian.stats["max_difficulty"] = 4
	lilian.runtime["hp"] = 75.0
	lilian.runtime["mp"] = 42.0
	var finish: Dictionary = lilian.finish("manual")
	var settled: Dictionary = game.settle_lilian(finish)
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


func _first_event_from_advance_steps(lilian: Node) -> Dictionary:
	for _i in 30:
		var result: Dictionary = lilian.advance_step()
		_expect_true(bool(result.get("ok", false)), "advance step ok")
		if str(result.get("mode", "")) == "pass_day":
			continue
		return result.get("event", {}) as Dictionary
	return {}


func _first_available_node_by_type(lilian: Node, type_id: String) -> Dictionary:
	for node_id_v in lilian.available_node_ids:
		for node_v in lilian.map_nodes:
			var node := node_v as Dictionary
			if str(node.get("id", "")) == str(node_id_v) and str(node.get("type", "")) == type_id:
				return node
	return {}


func _force_first_available_node_type(lilian: Node, type_id: String, difficulty: int = -1) -> Dictionary:
	var node_id := str(lilian.available_node_ids[0])
	var nodes: Array = lilian.map_nodes
	for i in nodes.size():
		var node := nodes[i] as Dictionary
		if str(node.get("id", "")) == node_id:
			node["type"] = type_id
			node["event_filter_tags"] = [type_id]
			match type_id:
				"battle":
					node["fixed_event_id"] = "qinglan_mountain__local_beast"
				"elite":
					node["fixed_event_id"] = "qinglan_mountain__local_elite"
				"boss":
					node["fixed_event_id"] = "qinglan_mountain__local_boss"
			if difficulty > 0:
				node["difficulty"] = difficulty
			nodes[i] = node
			lilian.map_nodes = nodes
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
