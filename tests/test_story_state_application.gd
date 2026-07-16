extends SceneTree

const StoryStateScript := preload("res://scripts/features/story/domain/story_state.gd")
const StoryApplicationScript := preload("res://scripts/features/story/application/story_application.gd")
const DataStoreScript := preload("res://scripts/core/data_store.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var default_saved := StoryStateScript.default_savedata()
	var default_session := StoryStateScript.default_session()
	assert(StoryStateScript.collect_savedata_errors(default_saved).is_empty())
	assert(StoryStateScript.collect_session_errors(default_session).is_empty())
	assert(StoryStateScript.collect_savedata_errors([]) == PackedStringArray([
		"[story_state:saved_root_type] field=$",
	]))
	assert(StoryStateScript.collect_session_errors({"active_snapshot": []}) == PackedStringArray([
		"[story_state:session_missing_field] field=pending_event",
		"[story_state:active_type] field=session.active_snapshot",
	]))
	var missing_saved := default_saved.duplicate(true)
	missing_saved.erase("flags")
	assert(not StoryStateScript.collect_savedata_errors(missing_saved).is_empty())
	var bad_completed := default_saved.duplicate(true)
	bad_completed["completed"] = [1]
	assert(not StoryStateScript.collect_savedata_errors(bad_completed).is_empty())
	var active := _active("story.fixture", "node.a")
	var missing_active := active.duplicate(true)
	missing_active.erase("started")
	var saved_with_bad_active := default_saved.duplicate(true)
	saved_with_bad_active["active_snapshot"] = missing_active
	assert(not StoryStateScript.collect_savedata_errors(saved_with_bad_active).is_empty())
	var bad_active_type := active.duplicate(true)
	bad_active_type["history"] = "bad"
	saved_with_bad_active["active_snapshot"] = bad_active_type
	assert(not StoryStateScript.collect_savedata_errors(saved_with_bad_active).is_empty())

	var state := StoryStateScript.new()
	var saved := default_saved.duplicate(true)
	saved["active_snapshot"] = active
	var session := default_session.duplicate(true)
	session["active_snapshot"] = active
	session["pending_event"] = "event.fixture"
	assert(state.replace_candidate(saved, session).is_empty())
	var cloned := state.savedata_snapshot()
	(cloned["active_snapshot"] as Dictionary)["state"]["nested"] = "changed"
	assert(not (state.savedata_snapshot()["active_snapshot"] as Dictionary)["state"].has("nested"))
	var state_before := state.savedata_snapshot()
	assert(not state.replace_candidate(saved_with_bad_active, session).is_empty())
	assert(state.savedata_snapshot() == state_before)

	var store := DataStoreScript.new()
	root.add_child(store)
	store.reset_all()
	var application := StoryApplicationScript.new()
	application.bind_store(store)
	assert(application.initialize_missing())
	assert(application.savedata_snapshot() == default_saved)
	assert(application.session_snapshot() == default_session)
	assert(application.commit_active(active, "event.fixture"))
	assert(application.savedata_snapshot()["active_snapshot"] == active)
	active["current_node_id"] = "mutated"
	assert((application.savedata_snapshot()["active_snapshot"] as Dictionary)["current_node_id"] == "node.a")

	var store_before := store.savedata.duplicate(true)
	var runtime_before := store.rundata.duplicate(true)
	var invalid_session := application.session_snapshot()
	invalid_session["pending_event"] = 7
	Engine.print_error_messages = false
	assert(not application.restore_candidate(application.savedata_snapshot(), invalid_session))
	Engine.print_error_messages = true
	assert(store.savedata == store_before)
	assert(store.rundata == runtime_before)

	assert(application.finish("story.fixture", "completed", ["node.a", "node.b"]))
	var finished := application.savedata_snapshot()
	assert(finished["completed"] == ["story.fixture"])
	assert(finished["history"] == ["node.a", "node.b"])
	assert((finished["active_snapshot"] as Dictionary).is_empty())
	assert(application.session_snapshot() == default_session)
	assert(application.commit_active(_active("story.skip", "node.s")))
	assert(application.finish("story.skip", "skipped", ["node.s"]))
	assert(application.savedata_snapshot()["completed"] == ["story.fixture"])
	assert(application.commit_active(_active("story.clear", "node.c"), "event.clear"))
	assert(application.clear_active())
	assert((application.savedata_snapshot()["active_snapshot"] as Dictionary).is_empty())
	assert(application.session_snapshot() == default_session)

	var restored_saved := application.savedata_snapshot()
	var restored_active := _active("story.restore", "node.r")
	restored_saved["active_snapshot"] = restored_active
	store.savedata["story"] = restored_saved.duplicate(true)
	store.rundata.erase("story")
	assert(application.initialize_missing())
	assert(application.session_snapshot()["active_snapshot"] == restored_active)

	print("PASS: story state and application ownership")
	quit(0)


func _active(story_id: String, node_id: String) -> Dictionary:
	return {
		"story_file_id": story_id,
		"story_id": story_id,
		"current_node_id": node_id,
		"state": {},
		"history": [node_id],
		"started": true,
	}
