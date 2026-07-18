extends SceneTree

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")
const GameSessionHostScript := preload("res://scripts/app/game_session_host.gd")
const LilianSessionScript := preload("res://scripts/lilian/lilian_state.gd")
const LilianSessionHostScript := preload("res://scripts/app/lilian_session_host.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := SceneManagerScript.new()
	root.add_child(manager)
	var host := Node.new()
	root.add_child(host)
	manager.bind_scene_host(host)
	var game_session := GameSessionScript.new()
	root.add_child(game_session)
	game_session.bind_store(root.get_node("DataStore"))
	game_session.bind_scene_manager(manager)
	var game_host := GameSessionHostScript.new()
	game_host.bind_session(game_session)
	var lilian_session := LilianSessionScript.new()
	root.add_child(lilian_session)
	lilian_session.active = true
	var lilian_host := LilianSessionHostScript.new()
	lilian_host.bind_session(lilian_session)
	var tutorial_coordinator := Node.new()
	manager.bind_page_dependencies(game_host, lilian_host, null, tutorial_coordinator)

	var normal := manager.go_zhandou_peizhi_mianban()
	assert(bool(normal.get("ok", false)))
	assert(not bool(normal.get("popup", false)))
	assert(manager.navigation_snapshot()["current_id"] == SceneManagerScript.ZHANDOU_PEIZHI_MIANBAN)
	assert(manager.navigation_snapshot()["overlay_id"] == "")

	manager.free()
	host.free()

	var overlay_manager := SceneManagerScript.new()
	root.add_child(overlay_manager)
	var overlay_host := Node.new()
	root.add_child(overlay_host)
	overlay_manager.bind_scene_host(overlay_host)
	overlay_manager.bind_page_dependencies(game_host, lilian_host, null, tutorial_coordinator)
	var lilian_scene := (
		load(SceneManagerScript.SCENE_PATHS[SceneManagerScript.LILIAN_XUNHUAN]) as PackedScene
	).instantiate()
	overlay_manager.call("_inject_page_dependencies", lilian_scene)
	overlay_host.add_child(lilian_scene)
	overlay_manager.call("_set_active_scene", lilian_scene)
	var overlay := overlay_manager.go_zhandou_peizhi_mianban(true)
	assert(bool(overlay.get("ok", false)))
	assert(bool(overlay.get("popup", false)))
	assert(overlay_manager.navigation_snapshot()["overlay_id"] == SceneManagerScript.ZHANDOU_PEIZHI_MIANBAN)
	assert(not lilian_scene.visible)
	var dismissed_routes: Array[String] = []
	overlay_manager.overlay_dismissed.connect(func(route_id: String) -> void:
		dismissed_routes.append(route_id)
	)
	var dismissed_panel := overlay_manager.dismiss_panel_popup()
	assert(bool(dismissed_panel.get("ok", false)))
	assert(dismissed_routes == [SceneManagerScript.ZHANDOU_PEIZHI_MIANBAN])
	assert(lilian_scene.visible)
	assert(overlay_manager.navigation_snapshot()["overlay_id"] == "")

	var no_battle_overlay := overlay_manager.dismiss_zhandou_overlay()
	assert(no_battle_overlay == {"ok": false, "error": "no_zhandou_overlay"})
	assert(overlay_manager.get_active_scene() == lilian_scene)

	var battle_underlay := Control.new()
	overlay_host.add_child(battle_underlay)
	battle_underlay.visible = false
	battle_underlay.process_mode = Node.PROCESS_MODE_DISABLED
	var battle_overlay := Node.new()
	overlay_host.add_child(battle_overlay)
	overlay_manager.set("_scene_underlay", battle_underlay)
	overlay_manager.set("_zhandou_overlay", battle_overlay)
	assert(overlay_manager.navigation_snapshot()["overlay_id"] == SceneManagerScript.ZHANDOU_CHANGJING)
	var dismissed_battle := overlay_manager.dismiss_zhandou_overlay()
	assert(bool(dismissed_battle.get("ok", false)))
	assert(dismissed_routes == [
		SceneManagerScript.ZHANDOU_PEIZHI_MIANBAN,
		SceneManagerScript.ZHANDOU_CHANGJING,
	])
	assert(battle_underlay.visible)
	assert(battle_underlay.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(overlay_manager.navigation_snapshot()["overlay_id"] == "")

	# Overlay 只把通用 payload 深拷贝交给 route；SceneManager 不读取战斗字段。
	await process_frame
	await process_frame
	var generic_payload := {"opaque": {"value": 1}}
	var pushed_battle: Dictionary = overlay_manager.call(
		"_push_zhandou_overlay", generic_payload
	)
	assert(bool(pushed_battle.get("ok", false)), str(pushed_battle))
	(generic_payload["opaque"] as Dictionary)["value"] = 9
	assert(overlay_manager.peek_payload(SceneManagerScript.ZHANDOU_CHANGJING) == {
		"opaque": {"value": 1},
	})
	assert(bool(overlay_manager.dismiss_zhandou_overlay().get("ok", false)))
	overlay_manager.reset_navigation_runtime()

	overlay_manager.free()
	overlay_host.free()
	game_host.free()
	lilian_host.free()
	tutorial_coordinator.free()
	game_session.free()
	lilian_session.free()
	print("PASS: panel navigation requires explicit overlay intent")
	quit(0)
