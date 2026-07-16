extends SceneTree

const TutorialStateScript := preload(
	"res://scripts/features/tutorial/domain/tutorial_state.gd"
)
const TutorialApplicationScript := preload(
	"res://scripts/features/tutorial/application/tutorial_application.gd"
)


class StoreFixture extends Node:
	signal state_replaced
	var savedata: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var active := TutorialStateScript.default_new_game()
	var inactive := TutorialStateScript.default_inactive()
	var production_store := root.get_node("DataStore")
	assert(production_store.export_savedata().get("tutorial") == inactive)
	assert(active["step"] == "T00" and not active["completed"])
	assert(inactive["step"] == "T10" and inactive["completed"])
	assert(TutorialStateScript.collect_errors(active).is_empty())
	assert(TutorialStateScript.collect_errors(null).size() == 1)
	_assert_invalid(_without(active, "chapter"))
	var unknown := active.duplicate(true)
	unknown["extra"] = true
	_assert_invalid(unknown)
	for field in ["chapter", "step", "completed", "skipped", "flags", "seen_context_tips"]:
		var bad := active.duplicate(true)
		bad[field] = 7
		_assert_invalid(bad)
	var bad_flag := active.duplicate(true)
	bad_flag["flags"] = {"loaded_test": 1}
	_assert_invalid(bad_flag)
	var bad_tip := active.duplicate(true)
	bad_tip["seen_context_tips"] = [1]
	_assert_invalid(bad_tip)
	var conflict := active.duplicate(true)
	conflict["completed"] = true
	conflict["skipped"] = true
	_assert_invalid(conflict)
	var legal_unknown_flag := active.duplicate(true)
	legal_unknown_flag["flags"] = {"loaded_test": true}
	assert(TutorialStateScript.collect_errors(legal_unknown_flag).is_empty())
	var prepared := TutorialStateScript.prepare(legal_unknown_flag)
	(prepared["flags"] as Dictionary)["loaded_test"] = false
	assert(bool((legal_unknown_flag["flags"] as Dictionary)["loaded_test"]))

	assert(TutorialStateScript.step_for_event("tutorial.xiulian_mianban_opened") == "T01")
	assert(TutorialStateScript.step_for_event("tutorial.first_battle_won") == "T05")
	assert(TutorialStateScript.step_for_event("missing") == "")

	var store := StoreFixture.new()
	root.add_child(store)
	var application := TutorialApplicationScript.new()
	application.bind_store(store)
	assert(application.initialize_missing())
	assert(application.snapshot() == inactive)
	assert(not application.is_active())
	assert(application.start_new_game())
	assert(application.is_active())
	assert(application.should_use_tutorial_lilian_map())
	assert(application.record_game_event("tutorial.xiulian_mianban_opened"))
	assert(application.snapshot()["step"] == "T01")
	assert(application.has_event_flag("tutorial.xiulian_mianban_opened"))
	assert(application.record_game_event("tutorial.first_battle_won"))
	assert(not application.should_use_tutorial_lilian_map())
	var snapshot := application.snapshot()
	(snapshot["flags"] as Dictionary)["mutated"] = true
	assert(not application.has_event_flag("mutated"))
	assert(application.finish(true, false))
	assert(not application.is_active())

	var before := application.snapshot()
	Engine.print_error_messages = false
	assert(application.prepare_import({}).is_empty())
	assert(application.snapshot() == before)
	Engine.print_error_messages = true
	var imported := TutorialStateScript.default_new_game()
	imported["step"] = "T09"
	imported["flags"] = {"loaded_test": true}
	var import_copy := application.prepare_import(imported)
	assert(import_copy == imported)
	(import_copy["flags"] as Dictionary)["loaded_test"] = false
	assert(bool((imported["flags"] as Dictionary)["loaded_test"]))

	print("PASS: tutorial state and application")
	quit(0)


func _assert_invalid(candidate: Variant) -> void:
	assert(not TutorialStateScript.collect_errors(candidate).is_empty())


func _without(source: Dictionary, field: String) -> Dictionary:
	var out := source.duplicate(true)
	out.erase(field)
	return out
