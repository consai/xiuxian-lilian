extends SceneTree

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")


class FakeDataStore:
	extends Node

	var runtime := {"transitioning": false, "current_id": "", "previous_id": "", "history": []}
	var payloads: Dictionary = {}

	func scene_runtime() -> Dictionary:
		return runtime

	func set_scene_payload(scene_id: String, payload: Dictionary) -> void:
		payloads[scene_id] = payload.duplicate(true)

	func take_scene_payload(scene_id: String) -> Dictionary:
		var payload := peek_scene_payload(scene_id)
		payloads.erase(scene_id)
		return payload

	func peek_scene_payload(scene_id: String) -> Dictionary:
		return (payloads.get(scene_id, {}) as Dictionary).duplicate(true)

	func reset_scene_runtime() -> void:
		runtime = {"transitioning": false, "current_id": "", "previous_id": "", "history": []}

	func scene_payloads() -> Dictionary:
		return payloads


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_store := root.get_node_or_null("DataStore")
	if real_store != null:
		root.remove_child(real_store)
	var store := FakeDataStore.new()
	store.name = "DataStore"
	root.add_child(store)
	var manager := SceneManagerScript.new()
	root.add_child(manager)
	var host := Node.new()
	root.add_child(host)
	manager.bind_scene_host(host)

	var failed := manager.go_to("missing", {}, {"reset_history": true})
	assert(not bool(failed.get("ok", false)))
	assert(store.runtime == {"transitioning": false, "current_id": "", "previous_id": "", "history": []})
	assert(store.payloads.is_empty())

	var entered := manager.go_to(SceneManagerScript.MAIN_MENU, {"test": true}, {"reset_history": true})
	assert(bool(entered.get("ok", false)))
	assert(host.get_child_count() == 1)
	assert(store.runtime["current_id"] == SceneManagerScript.MAIN_MENU)
	assert(store.runtime["history"] == [SceneManagerScript.MAIN_MENU])

	var before_runtime := store.runtime.duplicate(true)
	var before_payloads := store.payloads.duplicate(true)
	failed = manager.go_to("missing", {}, {"reset_history": true})
	assert(not bool(failed.get("ok", false)))
	assert(store.runtime == before_runtime)
	assert(store.payloads == before_payloads)
	assert(host.get_child_count() == 1)

	manager.free()
	host.free()
	store.free()
	if real_store != null:
		root.add_child(real_store)
	print("PASS: SceneManager atomic navigation")
	quit(0)
