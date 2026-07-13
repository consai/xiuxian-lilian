extends SceneTree


class FakeLilianState:
	extends Node

	var active := false


class FakeSceneManager:
	extends Node

	var calls := 0
	var result := {"ok": true}

	func go_world_map() -> Dictionary:
		calls += 1
		return result.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow_script := load("res://scripts/lilian/lilian_flow_service.gd")
	var lilian := FakeLilianState.new()
	var scene_manager := FakeSceneManager.new()

	lilian.active = true
	var blocked: Dictionary = flow_script.call("open_world_map", lilian, scene_manager)
	assert(not bool(blocked.get("ok", false)))
	assert(str(blocked.get("error", "")) == "当前仍在历练中，请先完成或结算后再操作。")
	assert(scene_manager.calls == 0)

	lilian.active = false
	var opened: Dictionary = flow_script.call("open_world_map", lilian, scene_manager)
	assert(bool(opened.get("ok", false)))
	assert(scene_manager.calls == 1)

	scene_manager.result = {"ok": false, "error": "navigation_failed"}
	var failed: Dictionary = flow_script.call("open_world_map", lilian, scene_manager)
	assert(failed == {"ok": false, "error": "navigation_failed"})
	assert(scene_manager.calls == 2)

	lilian.free()
	scene_manager.free()
	print("PASS: world map navigation admission")
	quit(0)
