extends SceneTree

const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const ExpeditionRewardServiceScript := preload("res://scripts/expedition/expedition_reward_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const BreakthroughServiceScript := preload("res://scripts/sim/breakthrough_service.gd")
const AlchemyServiceScript := preload("res://scripts/sim/alchemy_service.gd")
const PlayerAutoBattleServiceScript := preload("res://scripts/sim/player_auto_battle_service.gd")
const EnemyAiPolicyPlayerAutoScript := preload("res://scripts/fight/ai/enemy_ai_policy_player_auto.gd")
const EnemyAiContextScript := preload("res://scripts/fight/ai/enemy_ai_context.gd")
var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("new game and daily activities", _test_new_game_and_daily_activities)
	_run("breakthrough preview survives knowledge gate", _test_breakthrough_preview_with_knowledge_gate)
	_run("foundations derive combat attributes", _test_foundations_derive_combat_attributes)
	_run("cultivation methods gate growth and apply effects", _test_cultivation_methods)
	_run("cultivation sessions support focus and duration", _test_cultivation_sessions)
	_run("pill cultivation preview reports missing and selected pills", _test_pill_cultivation_preview)
	_run("pill cultivation accelerates growth and combat presses instability", _test_pill_cultivation_and_instability)
	_run("learning books unlock skills and methods", _test_learning_books)
	_run("player auto battle rules use player_auto policy", _test_player_auto_battle_rules)
	_run("player auto policy prefers strategies then default", _test_player_auto_policy_order)
	_run("inventory and battle item slots", _test_inventory_and_battle_item_slots)
	_run("alchemy preview and brew preserve resources", _test_alchemy_preview_and_brew)
	_run("alchemy recipe mastery improves outcomes and rewards failure", _test_alchemy_recipe_mastery)
	_run("alchemy steady strategy beats supreme on success rate", _test_alchemy_steady_strategy_ordering)
	_run("alchemy batch count respects inventory and furnace", _test_alchemy_batch_count)
	_run("battle runtime deducts inventory", _test_battle_runtime_deducts_inventory)
	_run("transfer item respects stack cap", _test_transfer_item_stack_cap)
	_run("expedition events build valid battle data", _test_expedition_events_build_valid_battle_data)
	_run("enemies preserve explicit combat attributes", _test_enemies_preserve_explicit_combat_attrs)
	_run("reward pools produce legal rewards", _test_reward_pools)
	_run("expedition defeat settlement persists runtime state", _test_expedition_defeat_settlement)
	_run("three save slots round trip", _test_save_round_trip)
	_run("game state save and load via autoload", _test_game_state_save_load)
	_run("find latest save slot", _test_find_latest_slot)
	_run("bootstrap does not auto load save on startup", _test_bootstrap_savedata)
	_run("auto save slot restrictions", _test_auto_save_slot_restrictions)
	_run("expedition settlement auto saves", _test_expedition_settlement_auto_saves)
	_run("save blocked during expedition", _test_save_blocked_during_expedition)
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
	var state := root.get_node("GameState")
	state.new_game()
	return state


func _expedition() -> Node:
	return root.get_node("ExpeditionState")


func _save_service() -> Node:
	return root.get_node("SaveService")


func _test_new_game_and_daily_activities() -> void:
	var state := _state()
	_expect_eq(state.day, 1, "new game day")
	_expect_eq(state.cultivate(), 140, "healthy cultivate gain")
	_expect_eq(state.day, 8, "cultivate advances by rule duration")
	state.injury_days = 3
	_expect_eq(state.cultivate(), 110, "injured cultivate gain")
	_expect_eq(state.injury_days, 0, "cultivation duration clears injury")
	state.hp = 1.0
	state.rest()
	_expect_near(state.hp, FightAttr.get_attr(state.attrs, FightAttr.HP_MAX), "rest hp")
	_expect_eq(state.injury_days, 0, "rest injury reduction")
	state.new_game()
	var base_hp_max: float = FightAttr.get_attr(state.attrs, FightAttr.HP_MAX)
	var base_body := float(state.foundations.get(CharacterStatsScript.BODY, 0.0))
	state.cultivation = state.breakthrough_at
	_expect_true(not state.can_breakthrough(), "same major realm does not need breakthrough")
	_expect_eq(state._auto_advance_layers(), 1, "layer auto advance to qi 2")
	_expect_eq(state.realm_name, "炼气二层", "auto advanced to qi layer 2")
	_expect_near(FightAttr.get_attr(state.attrs, FightAttr.HP_MAX), base_hp_max + 6.0, "layer advance raises hp max")
	state.cultivation = state.breakthrough_at
	_expect_eq(state._auto_advance_layers(), 1, "layer auto advance to qi 3")
	_expect_eq(state.realm_name, "炼气三层", "auto advanced to qi layer 3")
	_expect_near(FightAttr.get_attr(state.attrs, FightAttr.HP_MAX), base_hp_max + 12.0, "second layer advance raises hp max")
	state.realm_index = 8
	state._sync_realm()
	state.cultivation = state.breakthrough_at
	_grant_foundation_knowledge_gate(state)
	_expect_true(state.can_breakthrough(), "major realm breakthrough available")
	var result: Dictionary = state.breakthrough()
	_expect_true(bool(result.get("ok", false)), "breakthrough succeeds")
	_expect_eq(state.realm_name, "筑基初期", "breakthrough to foundation")
	_expect_near(float(state.foundations.get(CharacterStatsScript.BODY, 0.0)), base_body + 1.0, "breakthrough grows body")
	_expect_near(FightAttr.get_attr(state.attrs, FightAttr.HP_MAX), base_hp_max + 59.0, "major breakthrough raises hp max")


func _grant_foundation_knowledge_gate(state: Node) -> void:
	state.grant_knowledge("cultivation.cycle", 5)
	state.grant_knowledge("body.tempering", 5)
	state.grant_knowledge("spell.escape", 5)
	state.grant_knowledge("foundation.breathing", 5)


func _test_breakthrough_preview_with_knowledge_gate() -> void:
	var state := _state()
	state.realm_index = 8
	state._sync_realm()
	state.cultivation = state.breakthrough_at
	var preview: Dictionary = state.preview_breakthrough()
	_expect_true(bool(preview.get("ok", false)), "preview still returns breakdown")
	_expect_eq(str(preview.get("current_realm_name", "")), "炼气九层", "preview uses current realm")
	_expect_eq(str(preview.get("target_realm_name", "")), "筑基初期", "preview uses target realm")
	_expect_true(not bool(preview.get("can_attempt", true)), "knowledge gate blocks attempt")
	_expect_true(str(preview.get("knowledge_error", "")).contains("知识点不足"), "knowledge error surfaced")
	_grant_foundation_knowledge_gate(state)
	var ready: Dictionary = state.preview_breakthrough()
	_expect_true(str(ready.get("knowledge_error", "")) == "", "knowledge gate clears after grant")
	_expect_true(not bool(ready.get("can_attempt", true)), "still blocked when breakthrough value is low")


func _test_foundations_derive_combat_attributes() -> void:
	var attrs: Dictionary = CharacterStatsScript.build_combat_attrs({
		CharacterStatsScript.BODY: 10,
		CharacterStatsScript.SPIRIT: 10,
		CharacterStatsScript.SENSE: 10,
		CharacterStatsScript.AGILITY: 10,
	})
	_expect_near(FightAttr.get_attr(attrs, FightAttr.HP_MAX), 100.0, "derived hp")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.MP_MAX), 100.0, "derived mp")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.PHYSICAL_ATK), 30.0, "derived physical attack")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.MAGIC_ATK), 32.0, "derived magic attack")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.PHYSICAL_DEF), 20.0, "derived physical defense")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.MAGIC_DEF), 24.0, "derived magic defense")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.SPD), 100.0, "derived action speed")


func _test_cultivation_methods() -> void:
	var state := _state()
	_expect_eq(state.cultivate(), 140, "starter main method enables cultivation")
	var before_mp := FightAttr.get_attr(state.attrs, FightAttr.MP_MAX)
	state.cultivate()
	_expect_gt(
		KnowledgeServiceScript.effective_level(state.to_dict(), "foundation.breathing"),
		0.0,
		"cultivation grants knowledge xp"
	)
	_expect_gt(FightAttr.get_attr(state.attrs, FightAttr.MP_MAX), 0.0, "method modifiers apply")
	_expect_gt(before_mp, 0.0, "starter attrs initialized")


func _test_cultivation_sessions() -> void:
	var state := _state()
	var balanced_preview: Dictionary = state.preview_cultivation_session("cycle", 3)
	var breathing_preview: Dictionary = state.preview_cultivation_session("breathing", 3)
	var insight_preview: Dictionary = state.preview_cultivation_session("insight", 3)
	_expect_true(bool(balanced_preview.get("ok", false)), "balanced cultivation preview")
	_expect_gt(
		int(breathing_preview.get("estimated_cultivation", 0)),
		int(balanced_preview.get("estimated_cultivation", 0)),
		"breathing estimates more cultivation"
	)
	_expect_gt(
		int(balanced_preview.get("estimated_cultivation", 0)),
		int(insight_preview.get("estimated_cultivation", 0)),
		"insight estimates less cultivation"
	)
	var result: Dictionary = state.cultivate_session("insight", 3)
	_expect_true(bool(result.get("ok", false)), "insight session succeeds")
	_expect_eq(state.day, 4, "three day session advances three days")
	_expect_eq(int(result.get("cultivation_gained", 0)), 36, "insight session cultivation")
	_expect_gt(float(result.get("mastery_gained", 0.0)), 0.06, "insight gains extra mastery")
	_expect_true(not (result.get("knowledge_gains", []) as Array).is_empty(), "session reports knowledge gains")


func _test_pill_cultivation_preview() -> void:
	var state := _state()
	state.inventory.erase("items_JuQiDan")
	var missing: Dictionary = state.preview_cultivation_session("pill", 1)
	_expect_true(not bool(missing.get("ok", true)), "pill preview blocked without cultivation pill")
	_expect_true(
		str(missing.get("error", "")).contains("丹药"),
		"pill preview explains missing cultivation pill"
	)
	state.inventory["items_JuQiDan"] = 3
	var selected: Dictionary = state.preview_cultivation_session("pill", 3, "items_JuQiDan")
	_expect_true(bool(selected.get("ok", false)), "pill preview accepts selected pill")
	_expect_eq(str(selected.get("pill_id", "")), "items_JuQiDan", "pill preview preserves selected pill")
	_expect_eq((selected.get("pill_ids", []) as Array).size(), 3, "pill preview plans one pill per day")


func _test_pill_cultivation_and_instability() -> void:
	var state := _state()
	var normal: Dictionary = state.preview_cultivation_session("cycle", 1)
	var pill: Dictionary = state.preview_cultivation_session("pill", 1)
	_expect_true(bool(pill.get("ok", false)), "starter pill enables pill cultivation")
	_expect_gt(
		int(pill.get("estimated_cultivation", 0)),
		int(normal.get("estimated_cultivation", 0)) * 8,
		"pill cultivation is roughly an order faster"
	)
	var pills_before := int(state.inventory.get("items_JuQiDan", 0))
	var result: Dictionary = state.cultivate_session("pill", 1)
	_expect_eq(int(state.inventory.get("items_JuQiDan", 0)), pills_before - 1, "pill cultivation consumes pill")
	_expect_eq(int(result.get("instability_gained", 0)), 12, "pill cultivation adds instability")
	var settlement := {
		"settlement_id": "test-pill-instability",
		"elapsed_days": 1,
		"start_day": state.day,
		"exit_reason": "manual",
		"hp": state.hp,
		"mp": state.mp,
		"items": [],
		"loot": [],
		"loot_lost": [],
		"stats": {"steps": 1, "battles": 1, "wins": 1, "losses": 0, "max_difficulty": 1},
		"location_name": "测试山林",
	}
	var settled: Dictionary = state.settle_expedition(settlement)
	_expect_true(bool(settled.get("ok", false)), "expedition settlement succeeds")
	_expect_eq(state.cultivation_instability, 2, "battle win presses instability")


func _test_learning_books() -> void:
	var state := _state()
	_expect_true(state.unlocked_abilities.has("ability.combat.qi_bolt"), "starter ability unlocked")
	_expect_true(
		(state.equipped_abilities as Array).has("ability.combat.qi_bolt"),
		"starter ability equipped"
	)
	state.inventory["book_skill_qi_bolt"] = 1
	var duplicate: Dictionary = state.use_learning_book("book_skill_qi_bolt")
	_expect_true(not bool(duplicate.get("ok", false)), "duplicate skill book rejected")
	_expect_eq(int(state.inventory.get("book_skill_qi_bolt", 0)), 1, "duplicate skill book not consumed")
	state.grant_knowledge("spell.escape", 1)
	state.grant_knowledge("cultivation.cycle", 1)
	state.inventory["book_skill_wind_step"] = 1
	var skill: Dictionary = state.use_learning_book("book_skill_wind_step")
	_expect_true(bool(skill.get("ok", false)), "skill book learns wind step")
	_expect_true(state.unlocked_abilities.has("ability.combat.wind_step"), "wind step unlocked")
	_expect_eq(int(state.inventory.get("book_skill_wind_step", 0)), 0, "skill book consumed")
	state.grant_knowledge("body.tempering", 1)
	state.inventory["book_method_iron_body"] = 1
	var method: Dictionary = state.use_learning_book("book_method_iron_body")
	_expect_true(bool(method.get("ok", false)), "method book learns iron skin")
	_expect_true(state.unlocked_methods.has("method.iron_skin.1"), "iron skin unlocked")
	state.grant_knowledge("sword.qi", 1)
	state.grant_knowledge("sword.weapon", 2)
	state.inventory["book_skill_sword_qi"] = 1
	var generated_skill: Dictionary = state.use_learning_book("book_skill_sword_qi")
	_expect_true(bool(generated_skill.get("ok", false)), "generated skill book learns sword qi")
	_expect_true(state.unlocked_abilities.has("ability.combat.sword_qi"), "generated skill unlocked")
	state.grant_knowledge("foundation.breathing", 1)
	state.inventory["book_method_basic_breathing_1"] = 1
	var generated_method: Dictionary = state.use_learning_book("book_method_basic_breathing_1")
	_expect_true(bool(generated_method.get("ok", false)), "generated method book learns breathing method")
	_expect_true(state.unlocked_methods.has("method.basic_breathing.1"), "generated method unlocked")


func _test_player_auto_battle_rules() -> void:
	var state := _state()
	var rules: Dictionary = state.resolved_auto_battle_rules()
	_expect_eq(str(rules.get("policy", "")), "player_auto", "player auto rules use player_auto policy")
	_expect_eq((rules.get("strategies", []) as Array).size(), 0, "default player auto has no custom strategies")
	state.auto_battle_rules = PlayerAutoBattleServiceScript.with_strategies([
		{
			"when": {"self_hp_ratio_lte": 0.5},
			"action": {"type": "item", "slot_index": 0},
		},
	])
	rules = state.resolved_auto_battle_rules()
	_expect_eq((rules.get("strategies", []) as Array).size(), 1, "custom strategies persist")
	var snapshot: Dictionary = state.build_player_battle_snapshot({
		"hp": state.hp, "mp": state.mp, "inventory": state.inventory, "item_slots": state.item_slots,
	})
	_expect_eq(
		str((snapshot.get("ai", {}) as Dictionary).get("policy", "")),
		"player_auto",
		"battle snapshot carries player ai"
	)


func _test_player_auto_policy_order() -> void:
	var player := FightObj.new()
	player.hp = 100.0
	player.mp = 100.0
	player.skills = [
		{"id": 1, "cd": 5.0},
		{"id": 2, "cd": 0.0},
		{"id": 0, "cd": 0.0},
	]
	var enemy := FightObj.new()
	enemy.hp = 100.0
	enemy.mp = 100.0
	var skill_cfg := {
		"1": {"mp_cost": 10.0},
		"2": {"mp_cost": 10.0},
	}
	var ctx := EnemyAiContextScript.from_units(player, enemy, skill_cfg, {}, {}, {})
	var ai_cfg := PlayerAutoBattleServiceScript.with_strategies([
		{"when": {"skill_ready": 1}, "action": {"type": "skill", "skill_id": 1}},
	])
	var blocked := EnemyAiPolicyPlayerAutoScript.decide(ctx, ai_cfg)
	_expect_eq(int(blocked.get("skill_id", -1)), 2, "default uses first castable slot when strategy cannot fire")
	_expect_true(bool(blocked.get("ok", false)), "player auto still finds an action")
	var basic_cfg := PlayerAutoBattleServiceScript.default_rules()
	player.skills = [{"id": 1, "cd": 5.0}, {"id": -1, "cd": 0.0}, {"id": 0, "cd": 0.0}]
	ctx = EnemyAiContextScript.from_units(player, enemy, skill_cfg, {}, {}, {})
	var basic := EnemyAiPolicyPlayerAutoScript.decide(ctx, basic_cfg)
	_expect_eq(str(basic.get("action_type", "")), "basic", "falls back to basic attack")


func _test_transfer_item_stack_cap() -> void:
	var from := {"items_HuiQiDan": 10}
	var dest_full := {"items_HuiQiDan": 99}
	var dest_partial := {"items_HuiQiDan": 95}
	var dest_empty := {}
	var moved_full := InventoryServiceScript.transfer_item(from, dest_full, "items_HuiQiDan", 5)
	_expect_eq(moved_full, 0, "full destination blocks transfer")
	_expect_eq(int(from.get("items_HuiQiDan", 0)), 10, "source unchanged when blocked")
	_expect_eq(int(dest_full.get("items_HuiQiDan", 0)), 99, "destination unchanged when blocked")
	var moved_partial := InventoryServiceScript.transfer_item(from, dest_partial, "items_HuiQiDan", 8)
	_expect_eq(moved_partial, 4, "partial capacity transfer")
	_expect_eq(int(from.get("items_HuiQiDan", 0)), 6, "source reduced by partial transfer")
	_expect_eq(int(dest_partial.get("items_HuiQiDan", 0)), 99, "destination filled to cap")
	var moved_all := InventoryServiceScript.transfer_item(from, dest_empty, "items_HuiQiDan", 6)
	_expect_eq(moved_all, 6, "full transfer when room available")
	_expect_true(not from.has("items_HuiQiDan"), "source emptied")
	_expect_eq(int(dest_empty.get("items_HuiQiDan", 0)), 6, "destination received all")


func _test_inventory_and_battle_item_slots() -> void:
	var state := _state()
	state.inventory["items_FightTestDan"] = 3
	state.item_slots = ["items_FightTestDan", ""]
	var slot_id := str(state.item_slots[0])
	var before := int(state.inventory.get(slot_id, 0))
	var slots := InventoryServiceScript.build_battle_item_slots(state.inventory, state.item_slots)
	_expect_eq(slots.size(), 2, "battle item slot count")
	(slots[0] as Dictionary)["count"] = maxi(0, before - 1)
	InventoryServiceScript.sync_battle_item_counts(state.inventory, state.item_slots, slots)
	_expect_eq(int(state.inventory.get(slot_id, 0)), before - 1, "sync consumed items")
	(slots[0] as Dictionary)["count"] = 0
	InventoryServiceScript.sync_battle_item_counts(state.inventory, state.item_slots, slots)
	_expect_true(not state.inventory.has(slot_id), "depleted item removed")
	_expect_eq(str(state.item_slots[0]), "", "depleted slot cleared")


func _test_battle_runtime_deducts_inventory() -> void:
	var state := _state()
	state.inventory["items_FightTestDan"] = 3
	state.item_slots = ["items_FightTestDan", ""]
	var slot_id := str(state.item_slots[0])
	_expect_true(slot_id != "", "battle slot configured")
	var before := int(state.inventory.get(slot_id, 0))
	var battle_items := InventoryServiceScript.build_battle_item_slots(state.inventory, state.item_slots)
	(battle_items[0] as Dictionary)["count"] = maxi(0, before - 1)
	state.apply_battle_player_runtime({
		"player_runtime": {
			"hp": 80.0,
			"mp": 60.0,
			"items": battle_items,
		},
	})
	_expect_eq(int(state.inventory.get(slot_id, 0)), before - 1, "battle consumption persisted")


func _test_alchemy_preview_and_brew() -> void:
	var state := _state()
	state.inventory["items_LingCao"] = 4
	var preview: Dictionary = state.preview_alchemy("recipe.huiqi", "standard", "lowest")
	_expect_true(bool(preview.get("ok", false)), "alchemy preview succeeds")
	var total_probability := 0.0
	for value_v in (preview.get("probabilities", {}) as Dictionary).values():
		total_probability += float(value_v)
	_expect_near(total_probability, 1.0, "alchemy probabilities sum to one")
	_expect_eq(str(((preview.get("ingredients", []) as Array)[0] as Dictionary).get("id", "")), "items_LingCao", "lowest quality selected")
	var grass_before := int(state.inventory.get("items_LingCao", 0))
	var day_before: int = int(state.day)
	var result: Dictionary = state.brew_alchemy("recipe.huiqi", "standard", "lowest", 42)
	_expect_true(bool(result.get("ok", false)), "alchemy brew succeeds")
	_expect_eq(int(state.inventory.get("items_LingCao", 0)), grass_before - 2, "alchemy consumes exact ingredients")
	_expect_eq(state.day, day_before + int(preview.get("days", 1)), "alchemy advances configured days")
	_expect_eq(int(state.alchemy.get("total_batches", 0)), 1, "alchemy batch count increments")
	_expect_gt(int(state.alchemy.get("xp", 0)), 0, "alchemy grants xp")
	_expect_gt(int(result.get("mastery_gain", 0)), 0, "alchemy grants recipe mastery")
	_expect_eq(
		int(result.get("recipe_mastery", 0)),
		int(result.get("mastery_gain", 0)),
		"recipe mastery persisted"
	)


func _test_alchemy_batch_count() -> void:
	var state := _state()
	state.inventory["items_LingCao"] = 6
	var preview: Dictionary = state.preview_alchemy("recipe.huiqi", "standard", "lowest")
	_expect_true(bool(preview.get("ok", false)), "batch preview succeeds")
	_expect_eq(state.max_alchemy_batch_count(preview), 3, "batch count limited by herb stock")
	var grass_before := int(state.inventory.get("items_LingCao", 0))
	var day_before: int = int(state.day)
	var batches_before := int(state.alchemy.get("total_batches", 0))
	var result: Dictionary = state.brew_alchemy_batches("recipe.huiqi", "standard", "lowest", 2, 42)
	_expect_true(bool(result.get("ok", false)), "batch brew succeeds")
	_expect_eq(int(result.get("batch_count", 0)), 2, "batch brew reports count")
	_expect_eq(int(state.inventory.get("items_LingCao", 0)), grass_before - 4, "batch brew consumes ingredients per batch")
	_expect_eq(
		int(state.day),
		day_before + int(preview.get("days", 1)) * 2,
		"batch brew advances total days"
	)
	_expect_eq(int(state.alchemy.get("total_batches", 0)), batches_before + 2, "batch brew increments total batches")


func _test_alchemy_steady_strategy_ordering() -> void:
	var state := _state()
	state.inventory["items_LingCao"] = 4
	state.inventory["items_LingGuo"] = 2
	state.inventory["items_YaoDan"] = 1
	var steady: Dictionary = state.preview_alchemy("recipe.juqi", "steady", "lowest")
	var supreme: Dictionary = state.preview_alchemy("recipe.juqi", "supreme", "lowest")
	_expect_true(bool(steady.get("ok", false)), "steady preview succeeds")
	_expect_true(bool(supreme.get("ok", false)), "supreme preview succeeds")
	_expect_gt(
		float(steady.get("base_score", 0.0)),
		float(supreme.get("base_score", 0.0)),
		"steady raises base score above supreme"
	)
	_expect_gt(
		float(steady.get("success_probability", 0.0)),
		float(supreme.get("success_probability", 0.0)),
		"higher base score strategy should not have lower success rate"
	)


func _test_alchemy_recipe_mastery() -> void:
	var state := _state()
	state.inventory["items_LingCao"] = 20
	var novice: Dictionary = state.preview_alchemy("recipe.huiqi", "standard", "lowest")
	var alchemy_state: Dictionary = state.alchemy.duplicate(true)
	alchemy_state["recipe_mastery"] = {"recipe.huiqi": 1000}
	state.alchemy = alchemy_state
	var mastered: Dictionary = state.preview_alchemy("recipe.huiqi", "standard", "lowest")
	_expect_gt(
		float(mastered.get("base_score", 0.0)),
		float(novice.get("base_score", 0.0)),
		"recipe mastery raises outcome score"
	)
	_expect_near(
		float(mastered.get("base_score", 0.0)) - float(novice.get("base_score", 0.0)),
		20.0,
		"maximum recipe mastery grants twenty outcome score"
	)
	_expect_gt(
		float(mastered.get("success_probability", 0.0)),
		float(novice.get("success_probability", 0.0)),
		"recipe mastery raises success probability"
	)
	var novice_probabilities := novice.get("probabilities", {}) as Dictionary
	var mastered_probabilities := mastered.get("probabilities", {}) as Dictionary
	var novice_high_quality := (
		float(novice_probabilities.get("high", 0.0))
		+ float(novice_probabilities.get("supreme", 0.0))
	)
	var mastered_high_quality := (
		float(mastered_probabilities.get("high", 0.0))
		+ float(mastered_probabilities.get("supreme", 0.0))
	)
	_expect_gt(mastered_high_quality, novice_high_quality, "recipe mastery raises high-or-better probability")
	_expect_near(float(mastered.get("extra_pill_chance", 0.0)), 0.75, "maximum mastery grants multi-pill chance")
	_expect_eq(int(mastered.get("max_extra_pills", 0)), 2, "maximum mastery can add two pills")
	_expect_near(float(mastered.get("cost_save_chance", 0.0)), 0.35, "maximum mastery reduces material cost")
	var guaranteed_mastery_benefits := mastered.duplicate(true)
	guaranteed_mastery_benefits["base_score"] = 55.0
	guaranteed_mastery_benefits["extra_pill_chance"] = 1.0
	guaranteed_mastery_benefits["second_extra_pill_chance"] = 1.0
	guaranteed_mastery_benefits["cost_save_chance"] = 1.0
	(guaranteed_mastery_benefits.get("strategy", {}) as Dictionary)["spread"] = 0
	var mastery_benefit_result := AlchemyServiceScript.roll(
		guaranteed_mastery_benefits,
		RandomNumberGenerator.new()
	)
	_expect_eq(int(mastery_benefit_result.get("extra_pills", 0)), 2, "mastery can produce multiple extra pills")
	_expect_eq(int(mastery_benefit_result.get("saved_material_count", 0)), 2, "mastery can save selected materials")
	_expect_eq(
		int(((mastery_benefit_result.get("ingredients", []) as Array)[0] as Dictionary).get("count", -1)),
		0,
		"saved materials are not consumed"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var forced_failure := novice.duplicate(true)
	forced_failure["base_score"] = 0.0
	(forced_failure.get("strategy", {}) as Dictionary)["spread"] = 0
	var failed: Dictionary = AlchemyServiceScript.roll(forced_failure, rng)
	_expect_true(not bool(failed.get("succeeded", true)), "none result counts as failure")
	_expect_eq(str(failed.get("outcome_name", "")), "炼制失败", "failure outcome label")
	var forced_success := novice.duplicate(true)
	forced_success["base_score"] = 55.0
	(forced_success.get("strategy", {}) as Dictionary)["spread"] = 0
	var succeeded: Dictionary = AlchemyServiceScript.roll(forced_success, rng)
	_expect_true(bool(succeeded.get("succeeded", false)), "low or better counts as success")
	_expect_eq(str(succeeded.get("outcome_name", "")), "炼制成功", "success outcome label")
	_expect_gt(
		int(failed.get("mastery_gain", 0)),
		int(succeeded.get("mastery_gain", 0)),
		"failure grants more recipe mastery"
	)


func _test_expedition_events_build_valid_battle_data() -> void:
	var state := _state()
	for event_id in ["qinglan_wolf", "qinglan_serpent", "qinglan_boss"]:
		var event := ExpeditionEventServiceScript.by_id(event_id)
		var errors := BattleInitData.collect_errors(state.build_battle_init(event))
		_expect_true(errors.is_empty(), "valid battle setup: %s" % str(errors))


func _test_enemies_preserve_explicit_combat_attrs() -> void:
	var enemy := ExpeditionEventServiceScript.build_battle_enemy(
		ExpeditionEventServiceScript.by_id("qinglan_wolf")
	)
	var attrs := enemy.get("attrs", {}) as Dictionary
	_expect_near(FightAttr.get_attr(attrs, FightAttr.PHYSICAL_ATK), 21.0, "wolf physical attack")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.MAGIC_ATK), 22.4, "wolf magic attack")
	_expect_near(FightAttr.get_attr(attrs, FightAttr.PHYSICAL_DEF), 16.0, "wolf physical defense")


func _test_reward_pools() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for event_id in ["qinglan_wolf", "qinglan_serpent", "qinglan_boss"]:
		var event := ExpeditionEventServiceScript.by_id(event_id)
		var rewards := ExpeditionRewardServiceScript.roll_event_rewards(event, rng)
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
	_expect_eq(state.day, 31, "expedition consumes rule duration")
	_expect_near(state.hp, FightAttr.get_attr(state.attrs, FightAttr.HP_MAX) * 0.25, "loss hp floor")
	_expect_near(state.mp, 12.0, "mp persisted")
	_expect_eq(state.injury_days, 3, "loss applies three injury days")


func _test_save_round_trip() -> void:
	var state := _state()
	state.day = 9
	state.cultivation = 77
	var saved: Dictionary = _save_service().save_slot(3, state.to_dict())
	_expect_true(bool(saved.get("ok", false)), "save slot")
	var loaded: Dictionary = _save_service().load_slot(3)
	_expect_true(bool(loaded.get("ok", false)), "load slot")
	var restored := _state()
	_expect_true(restored.apply_dict(loaded.get("game", {})), "apply saved state")
	_expect_eq(restored.day, 9, "restored day")
	_expect_eq(restored.cultivation, 77, "restored cultivation")


func _test_game_state_save_load() -> void:
	var state := _state()
	state.new_game()
	state.day = 5
	state.cultivation = 42
	var saved: Dictionary = state.save_game(2)
	_expect_true(bool(saved.get("ok", false)), "game save ok")
	_expect_eq(state.active_save_slot, 2, "active slot tracked")
	state.day = 1
	state.cultivation = 0
	var loaded: Dictionary = state.load_game(2)
	_expect_true(bool(loaded.get("ok", false)), "game load ok")
	_expect_eq(state.day, 5, "loaded day")
	_expect_eq(state.cultivation, 42, "loaded cultivation")
	_expect_eq(state.active_save_slot, 2, "active slot restored")


func _test_find_latest_slot() -> void:
	var state := _state()
	state.day = 2
	_save_service().save_slot(2, state.to_dict())
	state.day = 9
	_save_service().save_slot(3, state.to_dict())
	_expect_eq(_save_service().find_latest_slot(), 3, "latest slot by timestamp")


func _test_bootstrap_savedata() -> void:
	var state := _state()
	state.day = 7
	_save_service().save_slot(3, state.to_dict())
	root.get_node("DataStore").reset_all()
	state._bootstrap_savedata()
	_expect_eq(state.day, 1, "bootstrap does not auto load save")


func _test_auto_save_slot_restrictions() -> void:
	var state := _state()
	state.new_game()
	state.day = 3
	var blocked: Dictionary = state.save_game(SaveService.AUTO_SAVE_SLOT)
	_expect_true(not bool(blocked.get("ok", false)), "manual save blocked on auto slot")
	var auto_saved: Dictionary = state.auto_save()
	_expect_true(bool(auto_saved.get("ok", false)), "auto save ok")
	_expect_eq(state.active_save_slot, SaveService.AUTO_SAVE_SLOT, "auto slot tracked")
	var info: Dictionary = _save_service().slot_info(SaveService.AUTO_SAVE_SLOT)
	_expect_true(bool(info.get("ok", false)), "auto slot has data")
	_expect_eq(int(info.get("day", 0)), 3, "auto slot day")


func _test_expedition_settlement_auto_saves() -> void:
	var state := _state()
	var expedition := _expedition()
	state.new_game()
	expedition.start("qinglan_mountain", state, 9092)
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_wolf")]
	expedition.choose_event("qinglan_wolf")
	expedition.receive_battle_summary({
		"outcome": "loss",
		"player_runtime": {"hp": 0.0, "mp": 12.0, "items": [{"id": 9001, "count": 1}, {"id": 9003, "count": 0}]},
	})
	expedition.settle_pending_battle()
	var finish: Dictionary = expedition.finish("defeated")
	state.settle_expedition(finish)
	var info: Dictionary = _save_service().slot_info(SaveService.AUTO_SAVE_SLOT)
	_expect_true(bool(info.get("ok", false)), "expedition settlement auto-saves")
	_expect_eq(int(info.get("day", 0)), 31, "auto save reflects settled day")
	_expect_eq(state.active_save_slot, SaveService.AUTO_SAVE_SLOT, "active slot is auto save")


func _test_save_blocked_during_expedition() -> void:
	var state := _state()
	var expedition := _expedition()
	state.new_game()
	var started: Dictionary = expedition.start("qinglan_mountain", state, 99)
	_expect_true(bool(started.get("ok", false)), "expedition started")
	var blocked: Dictionary = state.save_game(2)
	_expect_true(not bool(blocked.get("ok", false)), "save blocked")
	expedition.reset()


func _test_corrupt_save() -> void:
	var file := FileAccess.open("user://save_slot_2.json", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var loaded: Dictionary = _save_service().load_slot(2)
	_expect_true(not bool(loaded.get("ok", false)), "corrupt save rejected")


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s: expected %.2f, got %.2f" % [message, expected, actual])


func _expect_gt(actual: float, expected: float, message: String) -> void:
	if actual <= expected:
		_failures.append("%s: expected %.2f > %.2f" % [message, actual, expected])
