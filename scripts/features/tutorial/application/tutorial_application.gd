class_name TutorialApplication
extends RefCounted

const TutorialStateScript := preload(
	"res://scripts/features/tutorial/domain/tutorial_state.gd"
)

var _store: Node


func bind_store(store: Node) -> void:
	_store = store


func initialize_missing() -> bool:
	if not _require_store():
		return false
	if _store.savedata.has("tutorial"):
		return not prepare_import(_store.savedata.get("tutorial")).is_empty()
	_store.savedata["tutorial"] = TutorialStateScript.default_inactive()
	return true


func start_new_game() -> bool:
	return _commit(TutorialStateScript.default_new_game())


func prepare_import(candidate: Variant) -> Dictionary:
	return TutorialStateScript.prepare(candidate)


func snapshot() -> Dictionary:
	if not _require_store() or not _store.savedata.has("tutorial"):
		push_error("[tutorial_application:missing_state_slice] field=tutorial")
		return {}
	return TutorialStateScript.prepare(_store.savedata.get("tutorial"))


func is_active() -> bool:
	var state := snapshot()
	return not state.is_empty() and not bool(state["completed"]) and not bool(state["skipped"])


func has_event_flag(event_id: String) -> bool:
	var state := snapshot()
	return not state.is_empty() and bool((state["flags"] as Dictionary).get(event_id, false))


func record_game_event(event_id: String) -> bool:
	var state := snapshot()
	if state.is_empty():
		return false
	var step := TutorialStateScript.step_for_event(event_id)
	if step == "":
		return true
	state["step"] = step
	var flags := (state["flags"] as Dictionary).duplicate(true)
	flags[event_id] = true
	state["flags"] = flags
	return _commit(state)


func finish(completed: bool, skipped: bool) -> bool:
	var state := snapshot()
	if state.is_empty():
		return false
	state["step"] = "T10"
	state["completed"] = completed
	state["skipped"] = skipped
	return _commit(state)


func should_use_tutorial_lilian_map() -> bool:
	return is_active() and not has_event_flag("tutorial.first_battle_won")


func _commit(candidate: Variant) -> bool:
	if not _require_store():
		return false
	var prepared := TutorialStateScript.prepare(candidate)
	if prepared.is_empty():
		return false
	_store.savedata["tutorial"] = prepared
	return true


func _require_store() -> bool:
	if _store != null:
		return true
	push_error("[tutorial_application:store_not_bound]")
	return false
