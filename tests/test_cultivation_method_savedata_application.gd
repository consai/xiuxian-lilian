extends SceneTree

const StateScript := preload("res://scripts/features/cultivation/domain/cultivation_method_savedata_state.gd")
const ApplicationScript := preload("res://scripts/features/cultivation/application/cultivation_method_savedata_application.gd")
var _failures := PackedStringArray()

func _init() -> void: call_deferred("_run")
func _run() -> void:
	var store := {}
	Engine.print_error_messages = false
	var missing := ApplicationScript.snapshot(store)
	Engine.print_error_messages = true
	_check(not bool(missing.get("ok", true)) and store.is_empty(), "missing starter method state is rejected without mutation")
	var candidate := {"method_mastery": {"method.a": 0.2}, "unlocked_methods": ["method.a", "method.b"], "current_cultivation_method_id": "method.a", "cultivation_method_slots": {"main": "method.a", "support_1": "method.b", "support_2": "", "support_3": ""}}
	_check(bool(ApplicationScript.commit(store, candidate).get("ok", false)), "valid state commits")
	candidate["method_mastery"]["method.a"] = 0.9
	_check(float((store["method_mastery"] as Dictionary)["method.a"]) == 0.2, "commit deep clones")
	var before := store.duplicate(true)
	_check_invalid(store, {"method_mastery": {}, "unlocked_methods": ["method.a"], "current_cultivation_method_id": "", "cultivation_method_slots": {"main": "method.a", "support_1": "", "support_2": "", "support_3": ""}}, "empty current rejected")
	_check_invalid(store, {"method_mastery": {}, "unlocked_methods": ["method.a", "method.b"], "current_cultivation_method_id": "method.a", "cultivation_method_slots": {"main": "method.a", "support_1": "method.a", "support_2": "", "support_3": ""}}, "duplicate slots rejected")
	_check_invalid(store, {"method_mastery": {}, "unlocked_methods": ["method.a"], "current_cultivation_method_id": "method.a", "cultivation_method_slots": {"main": "method.a", "support_1": "method.b", "support_2": "", "support_3": ""}}, "locked support rejected")
	_check_invalid(store, {"method_mastery": {"method.a": 1.1}, "unlocked_methods": ["method.a"], "current_cultivation_method_id": "method.a", "cultivation_method_slots": {"main": "method.a", "support_1": "", "support_2": "", "support_3": ""}}, "invalid mastery rejected")
	_check(store == before, "invalid commits are atomic")
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("PASS: cultivation method savedata application ownership")
	quit(0)
func _check_invalid(store: Dictionary, candidate: Dictionary, message: String) -> void:
	Engine.print_error_messages = false
	var result := ApplicationScript.commit(store, candidate)
	Engine.print_error_messages = true
	_check(not bool(result.get("ok", true)), message)
func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
