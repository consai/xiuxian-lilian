extends SceneTree


class FakeLilianState:
	extends Node

	var active := false
	var result_pending := false

	func should_go_to_result() -> bool:
		return result_pending


class FakeSceneManager:
	extends Node

	var open_calls := 0
	var back_calls := 0
	var back_target := "hub"
	var open_result := {"ok": true}

	func go_lilian_xunhuan() -> Dictionary:
		open_calls += 1
		return open_result.duplicate(true)

	func peek_back_scene_id(_fallback: String = "hub") -> String:
		return back_target

	func go_back(_fallback: String = "hub") -> Dictionary:
		back_calls += 1
		return {"ok": true}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow_script := load("res://scripts/lilian/lilian_flow_service.gd")
	var lilian := FakeLilianState.new()
	var scene_manager := FakeSceneManager.new()

	var inactive: Dictionary = flow_script.call("open_active_lilian", lilian, scene_manager)
	assert(inactive == {"ok": false, "error": "没有进行中的历练"})
	assert(scene_manager.open_calls == 0)

	lilian.active = true
	lilian.result_pending = true
	var result_pending: Dictionary = flow_script.call("open_active_lilian", lilian, scene_manager)
	assert(result_pending == {"ok": false, "error": "历练已进入结算流程"})
	assert(scene_manager.open_calls == 0)

	lilian.result_pending = false
	var opened: Dictionary = flow_script.call("open_active_lilian", lilian, scene_manager)
	assert(bool(opened.get("ok", false)))
	assert(scene_manager.open_calls == 1)

	scene_manager.open_result = {"ok": false, "error": "navigation_failed"}
	var failed: Dictionary = flow_script.call("open_active_lilian", lilian, scene_manager)
	assert(failed == {"ok": false, "error": "navigation_failed"})

	scene_manager.back_target = "lilian_xunhuan"
	lilian.active = false
	var blocked_back: Dictionary = flow_script.call("go_back", lilian, scene_manager, "hub")
	assert(not bool(blocked_back.get("ok", false)))
	assert(scene_manager.back_calls == 0)

	lilian.active = true
	var allowed_back: Dictionary = flow_script.call("go_back", lilian, scene_manager, "hub")
	assert(bool(allowed_back.get("ok", false)))
	assert(scene_manager.back_calls == 1)

	scene_manager.back_target = "character_attributes_panel"
	lilian.active = false
	var unrelated_back: Dictionary = flow_script.call("go_back", lilian, scene_manager, "hub")
	assert(bool(unrelated_back.get("ok", false)))
	assert(scene_manager.back_calls == 2)

	lilian.free()
	scene_manager.free()
	print("PASS: active lilian navigation admission")
	quit(0)
