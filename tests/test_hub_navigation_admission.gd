extends SceneTree


class FakeLilianState:
	extends Node

	var active := false


class FakeSceneManager:
	extends Node

	var calls := 0
	var payload: Dictionary = {}
	var options: Dictionary = {}
	var result := {"ok": true}

	func go_hub(value: Dictionary = {}, nav_options: Dictionary = {}) -> Dictionary:
		calls += 1
		payload = value.duplicate(true)
		options = nav_options.duplicate(true)
		return result.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow_script := load("res://scripts/lilian/lilian_flow_service.gd")
	var lilian := FakeLilianState.new()
	var scene_manager := FakeSceneManager.new()

	lilian.active = true
	var blocked: Dictionary = flow_script.call("open_hub", lilian, scene_manager)
	assert(blocked == {
		"ok": false,
		"error": "当前仍在历练中，请先完成或结算后再操作。",
		"blocked": true,
	})
	assert(scene_manager.calls == 0)

	lilian.active = false
	var opened: Dictionary = flow_script.call(
		"open_hub", lilian, scene_manager, {"source": "test"}, {"reset_history": true}
	)
	assert(bool(opened.get("ok", false)))
	assert(scene_manager.calls == 1)
	assert(scene_manager.payload == {"source": "test"})
	assert(scene_manager.options == {"reset_history": true})

	lilian.active = true
	var allowed: Dictionary = flow_script.call(
		"open_hub", lilian, scene_manager, {}, {}, true
	)
	assert(bool(allowed.get("ok", false)))
	assert(scene_manager.calls == 2)
	assert(scene_manager.options == {"allow_active_lilian": true})

	lilian.active = false
	scene_manager.result = {"ok": false, "error": "navigation_failed"}
	var failed: Dictionary = flow_script.call("open_hub", lilian, scene_manager)
	assert(failed == {"ok": false, "error": "navigation_failed"})

	lilian.free()
	scene_manager.free()
	print("PASS: hub navigation admission")
	quit(0)
