extends SceneTree

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := SceneManagerScript.new()
	root.add_child(manager)
	var host := Node.new()
	root.add_child(host)
	manager.bind_scene_host(host)

	var empty_snapshot := {
		"current_id": "",
		"previous_id": "",
		"transitioning": false,
		"overlay_id": "",
		"history": [],
	}
	assert(manager.navigation_snapshot() == empty_snapshot)
	manager.set("_payloads", {
		SceneManagerScript.ZHANDOU_CHANGJING: {"old": {"value": 1}},
	})
	assert(manager.open_zhandou(false, {}) == {
		"ok": false,
		"error": "battle_payload_required",
	})
	assert(manager.navigation_snapshot() == empty_snapshot)
	assert(manager.peek_payload(SceneManagerScript.ZHANDOU_CHANGJING) == {
		"old": {"value": 1},
	})
	manager.reset_navigation_runtime()

	var source_payload := {"nested": {"value": 1}, "rows": [{"id": "original"}]}
	var entered := manager.go_to(
		SceneManagerScript.MAIN_MENU,
		source_payload,
		{"reset_history": true}
	)
	assert(bool(entered.get("ok", false)))
	assert(host.get_child_count() == 1)
	assert(manager.navigation_snapshot()["current_id"] == SceneManagerScript.MAIN_MENU)
	assert(manager.navigation_snapshot()["history"] == [SceneManagerScript.MAIN_MENU])

	(source_payload["nested"] as Dictionary)["value"] = 99
	(source_payload["rows"] as Array)[0]["id"] = "mutated_source"
	var peeked := manager.peek_payload(SceneManagerScript.MAIN_MENU)
	assert((peeked["nested"] as Dictionary)["value"] == 1)
	assert((peeked["rows"] as Array)[0]["id"] == "original")
	(peeked["nested"] as Dictionary)["value"] = 77
	assert((manager.peek_payload(SceneManagerScript.MAIN_MENU)["nested"] as Dictionary)["value"] == 1)
	var taken := manager.take_payload(SceneManagerScript.MAIN_MENU)
	assert((taken["nested"] as Dictionary)["value"] == 1)
	(taken["nested"] as Dictionary)["value"] = 55
	assert(manager.take_payload(SceneManagerScript.MAIN_MENU).is_empty())

	entered = manager.go_to(
		SceneManagerScript.CHARACTER_CREATION,
		{"guard": {"value": 2}}
	)
	assert(bool(entered.get("ok", false)))
	assert(manager.navigation_snapshot()["history"] == [
		SceneManagerScript.MAIN_MENU,
		SceneManagerScript.CHARACTER_CREATION,
	])
	assert(manager.peek_back_scene_id() == SceneManagerScript.MAIN_MENU)

	var before_failed_snapshot := manager.navigation_snapshot()
	var before_failed_payload := manager.peek_payload(SceneManagerScript.CHARACTER_CREATION)
	var active_before_failed := manager.get_active_scene()
	var failed := manager.go_to("missing", {"guard": {"value": 999}}, {"reset_history": true})
	assert(not bool(failed.get("ok", false)))
	assert(manager.navigation_snapshot() == before_failed_snapshot)
	assert(manager.peek_payload(SceneManagerScript.CHARACTER_CREATION) == before_failed_payload)
	assert(manager.get_active_scene() == active_before_failed)

	var backed := manager.go_back()
	assert(bool(backed.get("ok", false)))
	assert(manager.navigation_snapshot()["current_id"] == SceneManagerScript.MAIN_MENU)
	assert(manager.navigation_snapshot()["previous_id"] == SceneManagerScript.CHARACTER_CREATION)
	assert(manager.navigation_snapshot()["history"] == [SceneManagerScript.MAIN_MENU])

	manager.set("_transitioning", true)
	var locked_snapshot := manager.navigation_snapshot()
	failed = manager.go_to(SceneManagerScript.HUB)
	assert(failed == {"ok": false, "error": "transition_in_progress"})
	assert(manager.navigation_snapshot() == locked_snapshot)
	manager.set("_transitioning", false)

	entered = manager.go_to(SceneManagerScript.CHARACTER_CREATION, {"reset": {"value": 3}})
	assert(bool(entered.get("ok", false)))
	var active_before_reset := manager.get_active_scene()
	manager.reset_navigation_runtime()
	assert(manager.navigation_snapshot() == empty_snapshot)
	assert(manager.peek_payload(SceneManagerScript.CHARACTER_CREATION).is_empty())
	assert(manager.get_active_scene() == active_before_reset)

	manager.free()
	host.free()
	print("PASS: SceneManager atomic navigation")
	quit(0)
