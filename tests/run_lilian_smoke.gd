extends SceneTree

var _finished := false
var _frames := 0
var _stage := "init"


func _init() -> void:
	call_deferred("_start")


func _process(_delta: float) -> bool:
	_frames += 1
	if _finished:
		return true
	if _frames > 2400:
		printerr("FAIL: lilian smoke test timed out at stage %s" % _stage)
		quit(1)
		return true
	return false


func _start() -> void:
	var game_state := root.get_node_or_null("GameState")
	var lilian := root.get_node_or_null("LilianState")
	if game_state == null or lilian == null:
		printerr("FAIL: required autoload missing")
		quit(1)
		return
	game_state.new_game()
	var day_before: int = int(game_state.day)
	_stage = "start lilian"
	var started: Dictionary = lilian.start("qinglan_mountain", game_state, 4242)
	if not bool(started.get("ok", false)):
		printerr("FAIL: could not start lilian")
		quit(1)
		return
	lilian.current_choices = [LilianEventService.by_id("qinglan_wolf")]
	_stage = "enter battle"
	var choose: Dictionary = lilian.choose_event("qinglan_wolf")
	if not bool(choose.get("ok", false)):
		printerr("FAIL: could not choose wolf battle")
		quit(1)
		return
	var data: Dictionary = lilian.build_battle_init()
	(data["player"] as Dictionary)["attrs"]["atk"] = 500.0
	data["auto_battle"] = {"player": true, "enemy": true}
	var scene_manager := root.get_node_or_null("SceneManager")
	if scene_manager == null:
		printerr("FAIL: SceneManager autoload missing")
		quit(1)
		return
	var nav: Dictionary = scene_manager.go_zhandou(data, "lilian_smoke")
	if not bool(nav.get("ok", false)):
		printerr("FAIL: go_zhandou failed: %s" % str(nav.get("error", "unknown")))
		quit(1)
		return
	await process_frame
	await process_frame
	var fight_scene: Node = scene_manager.get_active_scene()
	if fight_scene == null or not fight_scene.has_signal("battle_finished"):
		printerr("FAIL: fight scene did not load")
		quit(1)
		return
	fight_scene.battle_finished.connect(_on_battle_finished.bind(game_state, lilian, day_before, scene_manager))


func _on_battle_finished(summary: Dictionary, game_state: Node, lilian: Node, day_before: int, scene_manager: Node) -> void:
	if str(summary.get("outcome", "")) != "win":
		printerr("FAIL: expected battle win")
		quit(1)
		return
	await process_frame
	await process_frame
	if lilian.phase != "battle":
		printerr("FAIL: lilian not waiting for battle settlement")
		quit(1)
		return
	_stage = "close battle"
	var fight_scene: Node = scene_manager.get_active_scene()
	if fight_scene.has_method("_on_battle_result_close_requested"):
		fight_scene.call("_on_battle_result_close_requested")
	else:
		printerr("FAIL: fight scene missing close handler")
		quit(1)
		return
	for _i in 120:
		await process_frame
		var active: Node = scene_manager.get_active_scene()
		if active != null and active.name == "LilianXunhuan":
			break
	var loop_scene: Node = scene_manager.get_active_scene()
	if loop_scene == null or loop_scene.name != "LilianXunhuan":
		printerr("FAIL: did not return to lilian loop")
		quit(1)
		return
	if not lilian.active:
		printerr("FAIL: lilian inactive after battle win")
		quit(1)
		return
	if int(game_state.day) != day_before:
		printerr("FAIL: game day advanced before lilian exit")
		quit(1)
		return
	_stage = "exit lilian"
	root.set_meta("smoke_auto_exit", true)
	var result_nav: Dictionary = scene_manager.go_lilian_jiesuan("manual")
	if not bool(result_nav.get("ok", false)):
		printerr("FAIL: go_lilian_jiesuan failed")
		quit(1)
		return
	for _i in 120:
		await process_frame
		var active: Node = scene_manager.get_active_scene()
		if active != null and active.name == "LilianResult":
			break
	var result_scene: Node = scene_manager.get_active_scene()
	if result_scene == null or result_scene.name != "LilianResult":
		printerr("FAIL: did not reach lilian result")
		quit(1)
		return
	if lilian.active:
		printerr("FAIL: lilian still active after settlement")
		quit(1)
		return
	if int(game_state.day) <= day_before:
		printerr("FAIL: lilian exit did not advance day")
		quit(1)
		return
	_stage = "return hub"
	if result_scene.has_method("_on_return_pressed"):
		result_scene.call("_on_return_pressed")
	for _i in 120:
		await process_frame
		var active: Node = scene_manager.get_active_scene()
		if active != null and str(active.scene_file_path).ends_with("dongfu.tscn"):
			break
	_finished = true
	print("PASS: lilian smoke test completed full loop")
	quit(0)
