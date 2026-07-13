extends SceneTree

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")
const WeituoServiceScript := preload("res://scripts/sim/weituo_service.gd")
const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")
const ItemAliasCatalogScript := preload("res://scripts/sim/item_alias_catalog.gd")

const COMMISSION_ID := "qingxin_herb_delivery_001"
const INSTANCE_ID := "fixed_commission_instance"


class FakeGameState:
	extends Node

	var inventory: Dictionary = {}
	var owned_equips: Array = []
	var ling_stones := 0
	var activity_log: Array = []
	var day := 42
	var autosave_calls := 0

	func auto_save() -> Dictionary:
		autosave_calls += 1
		return {"ok": true}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_test_inventory(errors)
	_test_recovery_item(errors)
	_test_commission_submit(errors)
	_test_map(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: inventory, commission, and map characterization")
	quit(0)


func _test_inventory(errors: PackedStringArray) -> void:
	var aliases := ItemAliasCatalogScript.load_all()
	_expect(errors, aliases.size() == 3, "item alias count")
	_expect(errors, aliases.get("book_method_hunyuan") == "book_method_hunyuan_1", "known item alias")
	var config := root.get_node("ConfigManager")
	var alias_def: ItemDef = config.item_def_by_id("book_method_hunyuan")
	var canonical_def: ItemDef = config.item_def_by_id("book_method_hunyuan_1")
	_expect(errors, alias_def != null and alias_def == canonical_def, "item alias resolves to canonical definition")
	var inventory: Dictionary = {}
	_expect(errors, InventoryServiceScript.add_item(inventory, "items_LingCao", 2) == 2, "inventory add count")
	_expect(errors, inventory == {"items_LingCao": 2}, "inventory add state")
	_expect(errors, InventoryServiceScript.remove_item(inventory, "items_LingCao", 1) == 1, "inventory remove count")
	_expect(errors, inventory == {"items_LingCao": 1}, "inventory remove state")
	var before_failed_remove := inventory.duplicate(true)
	_expect(errors, InventoryServiceScript.remove_item(inventory, "missing_item", 1) == 0, "missing inventory removal fails")
	_expect(errors, inventory == before_failed_remove, "failed inventory removal leaves state unchanged")


func _test_recovery_item(errors: PackedStringArray) -> void:
	var result := InventoryServiceScript.recovery_result(90.0, 40.0, 100.0, 50.0, 20.0, 5.0)
	_expect(errors, result == {
		"hp": 100.0,
		"mp": 45.0,
		"hp_gained": 10.0,
		"mp_gained": 5.0,
	}, "recovery item amounts must clamp to current maxima")


func _test_commission_submit(errors: PackedStringArray) -> void:
	var game_state := FakeGameState.new()
	game_state.inventory = {"items_LingCao": 2, "items_LingGuo": 2}
	var weituo := WeituoServiceScript.default_savedata()
	(weituo["active"] as Dictionary)[INSTANCE_ID] = {
		"weituo_id": COMMISSION_ID,
		"accepted_day": 42,
		"progress": {},
	}
	var savedata := {
		"day": 42,
		"inventory": game_state.inventory,
		"weituo": weituo,
	}
	var before_failed_submit := savedata.duplicate(true)
	var failed := WeituoServiceScript.submit(INSTANCE_ID, savedata, game_state)
	_expect(errors, not bool(failed.get("ok", false)), "commission rejects insufficient inventory")
	_expect(errors, savedata == before_failed_submit, "failed commission submit leaves savedata unchanged")
	_expect(errors, game_state.inventory == {"items_LingCao": 2, "items_LingGuo": 2}, "failed commission submit consumes nothing")

	game_state.inventory["items_LingCao"] = 3
	savedata["inventory"] = game_state.inventory
	var submitted := WeituoServiceScript.submit(INSTANCE_ID, savedata, game_state)
	var completed := savedata["weituo"] as Dictionary
	_expect(errors, bool(submitted.get("ok", false)), "commission submits when requirements are met")
	_expect(errors, not (completed["active"] as Dictionary).has(INSTANCE_ID), "submitted commission leaves active state")
	_expect(errors, COMMISSION_ID in (completed["completed_once"] as Array), "non-repeatable commission is completed once")
	_expect(errors, int((completed["completed_count"] as Dictionary).get(COMMISSION_ID, 0)) == 1, "commission completion count increments")
	_expect(errors, game_state.inventory == {"items_LingCao": 10, "items_XuanJin": 20}, "commission consumes requirements and applies item rewards")
	_expect(errors, game_state.ling_stones == 500, "commission applies currency reward")
	_expect(errors, game_state.autosave_calls == 1, "successful commission requests one autosave")
	game_state.free()


func _test_map(errors: PackedStringArray) -> void:
	var same_city := WorldMapServiceScript.build_travel_preview("qingshi_market", "qingshi_market", {})
	_expect(errors, bool(same_city.get("ok", false)), "same-city travel preview succeeds")
	_expect(errors, same_city.get("path", []) == ["qingshi_market"], "same-city travel keeps location")
	_expect(errors, int(same_city.get("total_days", -1)) == 0, "same-city travel consumes no time")

	var original := {"discovered_cities": ["qingshi_market"]}
	var discovered := WorldMapServiceScript.discover_map_node(original, "yunlan_city", "city")
	var repeated := WorldMapServiceScript.discover_map_node(discovered, "yunlan_city", "city")
	_expect(errors, original == {"discovered_cities": ["qingshi_market"]}, "map discovery does not mutate input")
	_expect(errors, (discovered["discovered_cities"] as Array) == ["qingshi_market", "yunlan_city"], "map discovery commits destination")
	_expect(errors, repeated == discovered, "map discovery is idempotent")
	_expect(errors, WorldMapServiceScript.route_key("yunlan_city", "qingshi_market") == "qingshi_market|yunlan_city", "map route key is direction independent")


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
