extends SceneTree

const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")


class FakeDataStore:
	extends Node

	var pending: Dictionary = {}

	func set_zhandou_pending_init(envelope: Dictionary) -> void:
		pending = envelope.duplicate(true)

	func take_zhandou_pending_init() -> Dictionary:
		var result := pending.duplicate(true)
		pending = {}
		return result


class FakeSceneManager:
	extends Node

	var open_calls := 0
	var last_prefer_overlay := false
	var navigation_result := {"ok": true}

	func preflight_transition() -> Dictionary:
		return {"ok": true}

	func open_zhandou(prefer_overlay: bool) -> Dictionary:
		open_calls += 1
		last_prefer_overlay = prefer_overlay
		return navigation_result.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_store := root.get_node_or_null("DataStore")
	if real_store != null:
		root.remove_child(real_store)
	var store := FakeDataStore.new()
	store.name = "DataStore"
	root.add_child(store)
	var manager := FakeSceneManager.new()

	var invalid := ZhandouInitDataScript.start_battle(self, {}, "test", manager, false)
	assert(not bool(invalid.get("ok", false)))
	assert(manager.open_calls == 0)
	assert(store.pending.is_empty())

	var valid := ZhandouInitDataScript.sample_for_editor()
	manager.navigation_result = {"ok": false, "error": "navigation_failed"}
	var failed := ZhandouInitDataScript.start_battle(self, valid, "lilian", manager, true)
	assert(not bool(failed.get("ok", false)))
	assert(manager.open_calls == 1)
	assert(manager.last_prefer_overlay)
	assert(store.pending.is_empty())

	manager.navigation_result = {"ok": true}
	var opened := ZhandouInitDataScript.start_battle(self, valid, "gm_panel", manager, false)
	assert(bool(opened.get("ok", false)))
	assert(manager.open_calls == 2)
	assert(not manager.last_prefer_overlay)
	assert(not store.pending.is_empty())

	manager.free()
	store.free()
	if real_store != null:
		root.add_child(real_store)
	print("PASS: battle start validation, cleanup, and navigation mode")
	quit(0)
