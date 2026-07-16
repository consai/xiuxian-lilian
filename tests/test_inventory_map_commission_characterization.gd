extends SceneTree

const InventoryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_application.gd"
)
const WeituoServiceScript := preload("res://scripts/sim/weituo_service.gd")
const WeituoStateScript := preload(
	"res://scripts/features/commission/domain/weituo_state.gd"
)
const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)

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
	_test_commission_lifecycle(errors)
	_test_map(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: inventory, commission, and map characterization")
	quit(0)


func _test_inventory(errors: PackedStringArray) -> void:
	var alias_def: ItemDef = InventoryQueryApplicationScript.definition_by_id("book_method_hunyuan")
	var canonical_def: ItemDef = InventoryQueryApplicationScript.definition_by_id("book_method_hunyuan_1")
	_expect(
		errors,
		alias_def != null and canonical_def != null \
				and alias_def.id == canonical_def.id \
				and alias_def.name == canonical_def.name \
				and alias_def.quality == canonical_def.quality \
				and alias_def.tier == canonical_def.tier,
		"item alias resolves to an equivalent canonical definition"
	)
	var inventory: Dictionary = {}
	_expect(errors, InventoryApplicationScript.add_item(inventory, "items_LingCao", 2) == 2, "inventory add count")
	_expect(errors, inventory == {"items_LingCao": 2}, "inventory add state")
	_expect(errors, InventoryApplicationScript.remove_item(inventory, "items_LingCao", 1) == 1, "inventory remove count")
	_expect(errors, inventory == {"items_LingCao": 1}, "inventory remove state")
	var before_failed_remove := inventory.duplicate(true)
	_expect(errors, InventoryApplicationScript.remove_item(inventory, "missing_item", 1) == 0, "missing inventory removal fails")
	_expect(errors, inventory == before_failed_remove, "failed inventory removal leaves state unchanged")


func _test_recovery_item(errors: PackedStringArray) -> void:
	var result := InventoryApplicationScript.recovery_result(90.0, 40.0, 100.0, 50.0, 20.0, 5.0)
	_expect(errors, result == {
		"hp": 100.0,
		"mp": 45.0,
		"hp_gained": 10.0,
		"mp_gained": 5.0,
	}, "recovery item amounts must clamp to current maxima")


func _test_commission_submit(errors: PackedStringArray) -> void:
	var game_state := FakeGameState.new()
	game_state.inventory = {"items_LingCao": 2, "items_LingGuo": 2}
	var weituo := WeituoStateScript.default_state()
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

	var invalid_savedata := savedata.duplicate(true)
	invalid_savedata["weituo"] = WeituoStateScript.default_state()
	(invalid_savedata["weituo"]["active"] as Dictionary)[INSTANCE_ID] = {
		"weituo_id": "missing.commission",
		"accepted_day": 42,
		"progress": {},
	}
	var invalid_before := invalid_savedata.duplicate(true)
	Engine.print_error_messages = false
	var invalid_submit := WeituoServiceScript.submit(INSTANCE_ID, invalid_savedata, game_state)
	Engine.print_error_messages = true
	_expect(errors, not bool(invalid_submit.get("ok", false)), "unknown commission reference is rejected")
	_expect(errors, invalid_savedata == invalid_before, "unknown commission reference does not commit state")
	game_state.free()


func _test_commission_lifecycle(errors: PackedStringArray) -> void:
	var savedata := {
		"day": 7,
		"inventory": {},
		"map": {"discovered_cities": ["qingshi_market"]},
		"weituo": WeituoStateScript.default_state(),
	}
	var refresh := WeituoServiceScript.refresh_board_if_needed(savedata)
	_expect(errors, bool(refresh.get("ok", false)), "commission board refresh succeeds")
	_expect(errors, (savedata["weituo"]["board"]["offer_ids"] as Array).size() == 3, "commission board keeps configured offer count")

	var accepted := WeituoServiceScript.accept(COMMISSION_ID, savedata)
	_expect(errors, bool(accepted.get("ok", false)), "commission accept succeeds")
	var accepted_instance_id := str(accepted.get("instance_id", ""))
	_expect(errors, accepted_instance_id != "", "commission accept returns instance id")
	var abandoned := WeituoServiceScript.abandon(accepted_instance_id, savedata)
	_expect(errors, bool(abandoned.get("ok", false)), "commission abandon succeeds")
	_expect(errors, (savedata["weituo"]["active"] as Dictionary).is_empty(), "commission abandon removes active record")

	var patrol_instance := "fixed_patrol_instance"
	(savedata["weituo"]["active"] as Dictionary)[patrol_instance] = {
		"weituo_id": "qinglan_patrol_001",
		"accepted_day": 7,
		"progress": {},
	}
	var recorded := WeituoServiceScript.record_lilian_result({
		"settlement_id": "settlement.fixed",
		"location_id": "qinglan_mountain",
		"exit_reason": "manual",
		"stats": {"steps": 4},
	}, savedata)
	_expect(errors, bool(recorded.get("ok", false)), "commission lilian progress records")
	var progress := savedata["weituo"]["active"][patrol_instance]["progress"] as Dictionary
	_expect(errors, int(progress.get("lilian_steps", 0)) == 4, "commission lilian steps are preserved")
	_expect(errors, progress.get("settlement_ids") == ["settlement.fixed"], "commission settlement id prevents duplicate progress")
	var before_duplicate := savedata.duplicate(true)
	var duplicate_record := WeituoServiceScript.record_lilian_result({
		"settlement_id": "settlement.fixed",
		"location_id": "qinglan_mountain",
		"exit_reason": "manual",
		"stats": {"steps": 9},
	}, savedata)
	_expect(errors, bool(duplicate_record.get("ok", false)), "duplicate settlement is an idempotent success")
	_expect(errors, savedata == before_duplicate, "duplicate settlement leaves commission state unchanged")


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
