extends SceneTree

const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")
const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("new game and daily activities", _test_new_game_and_daily_activities)
	_run("foundations derive combat attributes", _test_foundations_derive_combat_attributes)
	_run("cultivation methods gate growth and apply effects", _test_cultivation_methods)
	_run("learning books unlock skills and methods", _test_learning_books)
	_run("player auto battle rules use configured preset", _test_player_auto_battle_rules)
	_run("inventory and battle item slots", _test_inventory_and_battle_item_slots)
	_run("battle runtime deducts inventory", _test_battle_runtime_deducts_inventory)
	_run("transfer item respects stack cap", _test_transfer_item_stack_cap)
	_run("expedition events build valid battle data", _test_expedition_events_build_valid_battle_data)
	_run("legacy enemies migrate to foundation scale", _test_legacy_enemies_migrate_to_foundation_scale)
	_run("reward pools produce legal rewards", _test_reward_pools)
	_run("expedition defeat settlement persists runtime state", _test_expedition_defeat_settlement)
	_run("three save slots round trip", _test_save_round_trip)
	_run("game state save and load via autoload", _test_game_state_save_load)
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
	_expect_near(float(state.foundations.get(CharacterStatsScript.BODY, 0.0)), 11.0, "breakthrough grows body")


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
	_expect_eq(state.cultivate(), 20, "starter main method enables cultivation")
	state.unlocked_methods.append("blazing_sun_art")
	var equipped: Dictionary = state.equip_method("main", "blazing_sun_art")
	_expect_true(bool(equipped.get("ok", false)), "advanced main method equips")
	_expect_eq(state.cultivate(), 27, "advanced main method speeds cultivation")
	_expect_near(
		FightAttr.get_attr(state.attrs, FightAttr.COMBAT_MP_RESTORE_2S),
		6.0,
		"main method grants combat mp recovery"
	)


func _test_learning_books() -> void:
	var state := _state()
	_expect_true(state.unlocked_skills.has(1), "fireball starts unlocked")
	_expect_eq(int(state.equipped_skills[0]), 1, "fireball auto equipped")
	state.inventory["book_skill_fireball"] = 1
	var duplicate: Dictionary = state.use_learning_book("book_skill_fireball")
	_expect_true(not bool(duplicate.get("ok", false)), "duplicate skill book rejected")
	_expect_eq(int(state.inventory.get("book_skill_fireball", 0)), 1, "duplicate skill book not consumed")
	state.inventory["book_method_iron_body"] = 1
	var method: Dictionary = state.use_learning_book("book_method_iron_body")
	_expect_true(bool(method.get("ok", false)), "method book learns method")
	_expect_true(state.unlocked_methods.has("iron_body_art"), "method unlocked")


func _test_player_auto_battle_rules() -> void:
	var state := _state()
	state.auto_battle_preset = "aggressive"
	var rules: Dictionary = state.resolved_auto_battle_rules()
	_expect_eq(str(rules.get("policy", "")), "rule_list", "player auto rules use rule list")
	_expect_true(not (rules.get("rules", []) as Array).is_empty(), "player auto rules are populated")
	var snapshot: Dictionary = state.build_player_battle_snapshot({
		"hp": state.hp, "mp": state.mp, "inventory": state.inventory, "item_slots": state.item_slots,
	})
	_expect_true(not (snapshot.get("ai", {}) as Dictionary).is_empty(), "battle snapshot carries player ai")


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


func _test_expedition_events_build_valid_battle_data() -> void:
	var state := _state()
	for event_id in ["qinglan_wolf", "qinglan_serpent", "qinglan_boss"]:
		var event := ExpeditionEventServiceScript.by_id(event_id)
		var errors := BattleInitData.collect_errors(state.build_battle_init(event))
		_expect_true(errors.is_empty(), "valid battle setup: %s" % str(errors))


func _test_legacy_enemies_migrate_to_foundation_scale() -> void:
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
	_expect_eq(int(info.get("day", 0)), 2, "auto save reflects settled day")
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
