class_name StoryApplication
extends RefCounted

const StoryStateScript := preload("res://scripts/features/story/domain/story_state.gd")

var _store = null


func bind_store(store: Node) -> void:
	_store = store


func initialize_missing() -> bool:
	if not _require_store():
		return false
	var saved_candidate: Variant = _store.savedata.get(
		"story", StoryStateScript.default_savedata()
	)
	var session_candidate: Variant = _store.rundata.get(
		"story", StoryStateScript.default_session()
	)
	var session_active: Variant = (
		(session_candidate as Dictionary).get("active_snapshot", {})
		if session_candidate is Dictionary else null
	)
	if session_active is Dictionary and (session_active as Dictionary).is_empty():
		if saved_candidate is Dictionary:
			var saved_active: Variant = (saved_candidate as Dictionary).get("active_snapshot", {})
			if saved_active is Dictionary and not (saved_active as Dictionary).is_empty():
				session_candidate = StoryStateScript.default_session()
				session_candidate["active_snapshot"] = (saved_active as Dictionary).duplicate(true)
	return restore_candidate(saved_candidate, session_candidate)


func validate_savedata(candidate: Variant) -> bool:
	var errors := StoryStateScript.collect_savedata_errors(candidate)
	if errors.is_empty():
		return true
	for message in errors:
		push_error(message)
	return false


func savedata_snapshot() -> Dictionary:
	if not _require_store() or not _store.savedata.has("story"):
		push_error("[story_application:missing_state_slice] field=story")
		return {}
	return StoryStateScript.prepare_savedata(_store.savedata.get("story"))


func session_snapshot() -> Dictionary:
	if not _require_store() or not _store.rundata.has("story"):
		push_error("[story_application:missing_session_slice] field=story")
		return {}
	return StoryStateScript.prepare_session(_store.rundata.get("story"))


func restore_candidate(saved_candidate: Variant, session_candidate: Variant) -> bool:
	if not _require_store():
		return false
	var state := StoryStateScript.new()
	var errors := state.replace_candidate(saved_candidate, session_candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return false
	_commit_state(state)
	return true


func commit_active(active_snapshot: Variant, pending_event: String = "") -> bool:
	var saved := savedata_snapshot()
	var session := session_snapshot()
	if saved.is_empty() or session.is_empty():
		return false
	saved["active_snapshot"] = active_snapshot
	session["active_snapshot"] = active_snapshot
	session["pending_event"] = pending_event
	return restore_candidate(saved, session)


func finish(story_id: String, result: String, history: Array) -> bool:
	var saved := savedata_snapshot()
	var session := session_snapshot()
	if saved.is_empty() or session.is_empty():
		return false
	var completed := (saved.get("completed", []) as Array).duplicate()
	if result == "completed" and not completed.has(story_id):
		completed.append(story_id)
	saved["completed"] = completed
	saved["history"] = history.duplicate(true)
	saved["active_snapshot"] = {}
	session = StoryStateScript.default_session()
	return restore_candidate(saved, session)


func clear_active() -> bool:
	var saved := savedata_snapshot()
	if saved.is_empty():
		return false
	saved["active_snapshot"] = {}
	return restore_candidate(saved, StoryStateScript.default_session())


func _commit_state(state: RefCounted) -> void:
	_store.savedata["story"] = state.savedata_snapshot()
	_store.rundata["story"] = state.session_snapshot()


func _require_store() -> bool:
	if _store != null:
		return true
	push_error("[story_application:store_not_bound]")
	return false
