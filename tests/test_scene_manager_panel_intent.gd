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

	var normal := manager.go_zhandou_peizhi_mianban()
	assert(bool(normal.get("ok", false)))
	assert(not bool(normal.get("popup", false)))
	assert(store.runtime["current_id"] == SceneManagerScript.ZHANDOU_PEIZHI_MIANBAN)

	manager.free()
	host.free()
	store.free()
	if real_store != null:
		root.add_child(real_store)

	var overlay_manager := SceneManagerScript.new()
	root.add_child(overlay_manager)
	var overlay_host := Node.new()
	root.add_child(overlay_host)
	overlay_manager.bind_scene_host(overlay_host)
	var lilian_scene := (
		load(SceneManagerScript.SCENE_PATHS[SceneManagerScript.LILIAN_XUNHUAN]) as PackedScene
	).instantiate()
	overlay_manager.call("_set_active_scene", lilian_scene)
	var overlay := overlay_manager.go_zhandou_peizhi_mianban(true)
	assert(bool(overlay.get("ok", false)))
	assert(bool(overlay.get("popup", false)))

	overlay_manager.free()
	overlay_host.free()
	lilian_scene.free()
	print("PASS: panel navigation requires explicit overlay intent")
	quit(0)
