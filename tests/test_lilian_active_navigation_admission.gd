extends SceneTree


class FakeLilianState:
	extends Node

	var active := false
	var result_pending := false
	var peizhi_sync_calls := 0

	func should_go_to_result() -> bool:
		return result_pending

	func sync_runtime_peizhi_from_game() -> void:
		peizhi_sync_calls += 1


class FakeSceneManager:
	extends Node

	var open_calls := 0
	var back_calls := 0
	var back_target := "hub"
	var panel_active := false
	var open_result := {"ok": true}
	var dismiss_calls := 0

	func go_lilian_xunhuan() -> Dictionary:
		open_calls += 1
		return open_result.duplicate(true)

	func peek_back_scene_id(_fallback: String = "hub") -> String:
		return back_target

	func is_panel_popup_active() -> bool:
		return panel_active

	func go_back(_fallback: String = "hub") -> Dictionary:
		back_calls += 1
		return {"ok": true}

	func dismiss_panel_popup() -> Dictionary:
		dismiss_calls += 1
		return {"ok": true, "resumed": true}


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

	scene_manager.back_target = "hub"
	lilian.active = true
	var blocked_hub_back: Dictionary = flow_script.call("go_back", lilian, scene_manager, "hub")
	assert(blocked_hub_back == {
		"ok": false,
		"error": "当前仍在历练中，请先完成或结算后再操作。",
		"blocked": true,
	})
	assert(scene_manager.back_calls == 2)

	lilian.active = false
	var allowed_hub_back: Dictionary = flow_script.call("go_back", lilian, scene_manager, "hub")
	assert(bool(allowed_hub_back.get("ok", false)))
	assert(scene_manager.back_calls == 3)

	scene_manager.panel_active = true
	lilian.active = true
	var dismissed_panel: Dictionary = flow_script.call("go_back", lilian, scene_manager, "hub")
	assert(bool(dismissed_panel.get("ok", false)))
	assert(scene_manager.back_calls == 4)

	var dongfu_bag_close: Dictionary = flow_script.call(
		"close_lilian_utility_panel", false, lilian, scene_manager, "hub"
	)
	assert(bool(dongfu_bag_close.get("ok", false)))
	assert(lilian.peizhi_sync_calls == 0)
	assert(scene_manager.dismiss_calls == 1)

	var lilian_bag_close: Dictionary = flow_script.call(
		"close_lilian_utility_panel", true, lilian, scene_manager, "hub"
	)
	assert(bool(lilian_bag_close.get("ok", false)))
	assert(lilian.peizhi_sync_calls == 1)
	assert(scene_manager.dismiss_calls == 2)

	var popup_configuration_close: Dictionary = flow_script.call(
		"close_lilian_utility_panel", true, lilian, scene_manager, "hub"
	)
	assert(bool(popup_configuration_close.get("ok", false)))
	assert(lilian.peizhi_sync_calls == 2)
	assert(scene_manager.dismiss_calls == 3)

	scene_manager.panel_active = false
	lilian.active = false
	var route_configuration_close: Dictionary = flow_script.call(
		"close_lilian_utility_panel", false, lilian, scene_manager, "hub"
	)
	assert(bool(route_configuration_close.get("ok", false)))
	assert(lilian.peizhi_sync_calls == 2)
	assert(scene_manager.dismiss_calls == 3)
	assert(scene_manager.back_calls == 5)

	lilian.free()
	scene_manager.free()
	print("PASS: active lilian navigation admission")
	quit(0)
