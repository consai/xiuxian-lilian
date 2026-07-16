extends SceneTree

const WEITUO_APPLICATION_PATH := (
	"res://scripts/features/commission/application/weituo_application.gd"
)
const WeituoServiceScript := preload("res://scripts/sim/weituo_service.gd")
const WeituoStateScript := preload(
	"res://scripts/features/commission/domain/weituo_state.gd"
)

const COMMISSION_ID := "qingxin_herb_delivery_001"
const INSTANCE_ID := "application_submit_instance"

var _application_script: GDScript


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


class StoreFixture:
	extends Node

	var savedata: Variant = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_application_script = load(WEITUO_APPLICATION_PATH) as GDScript
	if _application_script == null:
		push_error("commission application failed to load after Autoload initialization")
		quit(1)
		return
	_test_refresh_and_override(errors)
	_test_store_replacement_uses_latest_savedata(errors)
	_test_invalid_store_rejected(errors)
	_test_accept_and_abandon_save_contract(errors)
	_test_submit_save_contract(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: commission application snapshot and save contract")
	quit(0)


func _test_refresh_and_override(errors: PackedStringArray) -> void:
	var no_refresh_savedata := _savedata(7)
	var no_refresh_before := no_refresh_savedata.duplicate(true)
	var direct_entries := WeituoServiceScript.visible_entries(no_refresh_savedata)
	_expect(errors, direct_entries.is_empty(), "visible_entries does not synthesize an empty board")
	_expect(errors, no_refresh_savedata == no_refresh_before, "visible_entries does not refresh or mutate board state")

	var game_state := FakeGameState.new()
	var savedata := _savedata(7)
	var store := _store(savedata)
	var application: Variant = _application_script.new(store, game_state)
	var snapshot: Dictionary = application.refresh_board_snapshot()
	_expect(errors, bool(snapshot.get("ok", false)), "application board refresh succeeds")
	_expect(errors, (savedata["weituo"]["board"]["offer_ids"] as Array).size() == 3, "application refreshes the board once before querying")
	_expect(errors, (snapshot.get("entries", []) as Array).size() == 3, "application returns refreshed visible entries")
	_expect(errors, not (snapshot.get("header", {}) as Dictionary).is_empty(), "application returns board header")

	var override := [{"key": "override", "nested": {"value": 1}}]
	var override_snapshot: Dictionary = application.refresh_board_snapshot(override)
	_expect(errors, override_snapshot.get("entries") == override, "non-empty override replaces computed entries")
	(override[0]["nested"] as Dictionary)["value"] = 9
	_expect(errors, int(override_snapshot["entries"][0]["nested"]["value"]) == 1, "override snapshot is deeply copied")
	game_state.free()
	store.free()


func _test_store_replacement_uses_latest_savedata(errors: PackedStringArray) -> void:
	var game_state := FakeGameState.new()
	var old_savedata := _savedata(7)
	var old_before := old_savedata.duplicate(true)
	var store := _store(old_savedata)
	var application: Variant = _application_script.new(store, game_state)
	var current_savedata := _savedata(8)
	store.savedata = current_savedata
	var snapshot: Dictionary = application.refresh_board_snapshot()
	_expect(errors, bool(snapshot.get("ok", false)), "refresh uses replacement store savedata")
	_expect(errors, old_savedata == old_before, "refresh leaves replaced old savedata unchanged")
	_expect(errors, (current_savedata["weituo"]["board"]["offer_ids"] as Array).size() == 3, "refresh mutates only current savedata")
	var accepted: Dictionary = application.accept(COMMISSION_ID)
	_expect(errors, bool(accepted.get("ok", false)), "accept uses replacement store savedata")
	_expect(errors, old_savedata == old_before, "accept leaves replaced old savedata unchanged")
	_expect(errors, (current_savedata["weituo"]["active"] as Dictionary).size() == 1, "accept commits only current savedata")
	_expect(errors, game_state.autosave_calls == 1, "replacement savedata accept saves once")
	game_state.free()
	store.free()


func _test_invalid_store_rejected(errors: PackedStringArray) -> void:
	var game_state := FakeGameState.new()
	Engine.print_error_messages = false
	var missing_application: Variant = _application_script.new(null, game_state)
	var missing_result: Dictionary = missing_application.accept(COMMISSION_ID)
	var bad_store := _store([])
	var bad_application: Variant = _application_script.new(bad_store, game_state)
	var bad_result: Dictionary = bad_application.abandon("missing")
	Engine.print_error_messages = true
	_expect(errors, missing_result == {"ok": false, "error": "委托状态存储无效"}, "missing store returns stable error")
	_expect(errors, bad_result == {"ok": false, "error": "委托状态存储无效"}, "invalid savedata type returns stable error")
	_expect(errors, game_state.autosave_calls == 0, "invalid stores have no save side effect")
	game_state.free()
	bad_store.free()


func _test_accept_and_abandon_save_contract(errors: PackedStringArray) -> void:
	var game_state := FakeGameState.new()
	var savedata := _savedata(7)
	var store := _store(savedata)
	var application: Variant = _application_script.new(store, game_state)
	var accepted: Dictionary = application.accept(COMMISSION_ID)
	_expect(errors, bool(accepted.get("ok", false)), "accept succeeds through application")
	_expect(errors, game_state.autosave_calls == 1, "successful accept saves exactly once")

	var before_failed_accept := savedata.duplicate(true)
	var failed_accept: Dictionary = application.accept(COMMISSION_ID)
	_expect(errors, not bool(failed_accept.get("ok", false)), "duplicate accept fails")
	_expect(errors, game_state.autosave_calls == 1, "failed accept does not save")
	_expect(errors, savedata == before_failed_accept, "failed accept leaves state unchanged")

	var instance_id := str(accepted.get("instance_id", ""))
	var abandoned: Dictionary = application.abandon(instance_id)
	_expect(errors, bool(abandoned.get("ok", false)), "abandon succeeds through application")
	_expect(errors, game_state.autosave_calls == 2, "successful abandon saves exactly once")
	var before_failed_abandon := savedata.duplicate(true)
	var failed_abandon: Dictionary = application.abandon(instance_id)
	_expect(errors, not bool(failed_abandon.get("ok", false)), "missing active commission cannot be abandoned")
	_expect(errors, game_state.autosave_calls == 2, "failed abandon does not save")
	_expect(errors, savedata == before_failed_abandon, "failed abandon leaves state unchanged")
	game_state.free()
	store.free()


func _test_submit_save_contract(errors: PackedStringArray) -> void:
	var game_state := FakeGameState.new()
	game_state.inventory = {"items_LingCao": 3, "items_LingGuo": 2}
	var savedata := _savedata(42)
	savedata["inventory"] = game_state.inventory
	(savedata["weituo"]["active"] as Dictionary)[INSTANCE_ID] = {
		"weituo_id": COMMISSION_ID,
		"accepted_day": 42,
		"progress": {},
	}
	var store := _store(savedata)
	var application: Variant = _application_script.new(store, game_state)
	var submitted: Dictionary = application.submit(INSTANCE_ID)
	_expect(errors, bool(submitted.get("ok", false)), "submit succeeds through application")
	_expect(errors, game_state.autosave_calls == 1, "submit keeps service-owned single autosave")

	var failed_game_state := FakeGameState.new()
	failed_game_state.inventory = {"items_LingCao": 2, "items_LingGuo": 2}
	var failed_savedata := _savedata(42)
	failed_savedata["inventory"] = failed_game_state.inventory
	(failed_savedata["weituo"]["active"] as Dictionary)[INSTANCE_ID] = {
		"weituo_id": COMMISSION_ID,
		"accepted_day": 42,
		"progress": {},
	}
	var before_failed_submit := failed_savedata.duplicate(true)
	var failed_store := _store(failed_savedata)
	var failed_application: Variant = _application_script.new(failed_store, failed_game_state)
	var failed_submit: Dictionary = failed_application.submit(INSTANCE_ID)
	_expect(errors, not bool(failed_submit.get("ok", false)), "submit rejects insufficient inventory")
	_expect(errors, failed_game_state.autosave_calls == 0, "failed submit does not save")
	_expect(errors, failed_savedata == before_failed_submit, "failed submit leaves state unchanged")
	game_state.free()
	failed_game_state.free()
	store.free()
	failed_store.free()


func _savedata(day: int) -> Dictionary:
	return {
		"day": day,
		"realm_index": 0,
		"inventory": {},
		"map": {"discovered_cities": ["qingshi_market"]},
		"weituo": WeituoStateScript.default_state(),
	}


func _store(savedata: Variant) -> StoreFixture:
	var store := StoreFixture.new()
	store.savedata = savedata
	return store


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
