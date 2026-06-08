extends SceneTree

const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")

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
		printerr("FAIL: expedition smoke test timed out at stage %s" % _stage)
		quit(1)
		return true
	return false


func _start() -> void:
	var game_state := root.get_node_or_null("GameState")
	var expedition := root.get_node_or_null("ExpeditionState")
	if game_state == null or expedition == null:
		printerr("FAIL: required autoload missing")
		quit(1)
		return
	game_state.new_game()
	var day_before: int = int(game_state.day)
	_stage = "start expedition"
	var started: Dictionary = expedition.start("qinglan_mountain", game_state, 4242)
	if not bool(started.get("ok", false)):
		printerr("FAIL: could not start expedition")
		quit(1)
		return
	expedition.current_choices = [ExpeditionEventServiceScript.by_id("qinglan_wolf")]
	_stage = "enter battle"
	var choose: Dictionary = expedition.choose_event("qinglan_wolf")
	if not bool(choose.get("ok", false)):
		printerr("FAIL: could not choose wolf battle")
		quit(1)
		return
	var data: Dictionary = expedition.build_battle_init()
	(data["player"] as Dictionary)["attrs"]["atk"] = 500.0
	data["auto_battle"] = {"player": true, "enemy": true}
	BattleInitData.set_pending(self, data, "expedition_smoke")
	change_scene_to_file("res://scenes/fightScene.tscn")
	await process_frame
	await process_frame
	if current_scene == null or not current_scene.has_signal("battle_finished"):
		printerr("FAIL: fight scene did not load")
		quit(1)
		return
	current_scene.battle_finished.connect(_on_battle_finished.bind(game_state, expedition, day_before))


func _on_battle_finished(summary: Dictionary, game_state: Node, expedition: Node, day_before: int) -> void:
	if str(summary.get("outcome", "")) != "win":
		printerr("FAIL: expected battle win")
		quit(1)
		return
	await process_frame
	await process_frame
	if expedition.phase != "battle":
		printerr("FAIL: expedition not waiting for battle settlement")
		quit(1)
		return
	_stage = "close battle"
	if current_scene.has_method("_on_battle_result_close_requested"):
		current_scene.call("_on_battle_result_close_requested")
	else:
		printerr("FAIL: fight scene missing close handler")
		quit(1)
		return
	for _i in 120:
		await process_frame
		if current_scene != null and current_scene.name == "ExpeditionLoop":
			break
	if current_scene == null or current_scene.name != "ExpeditionLoop":
		printerr("FAIL: did not return to expedition loop")
		quit(1)
		return
	if not expedition.active:
		printerr("FAIL: expedition inactive after battle win")
		quit(1)
		return
	if int(game_state.day) != day_before:
		printerr("FAIL: game day advanced before expedition exit")
		quit(1)
		return
	_stage = "exit expedition"
	root.set_meta("smoke_auto_exit", true)
	change_scene_to_file(ExpeditionState.RESULT_SCENE)
	for _i in 120:
		await process_frame
		if current_scene != null and current_scene.name == "ExpeditionResult":
			break
	if current_scene == null or current_scene.name != "ExpeditionResult":
		printerr("FAIL: did not reach expedition result")
		quit(1)
		return
	if expedition.active:
		printerr("FAIL: expedition still active after settlement")
		quit(1)
		return
	if int(game_state.day) <= day_before:
		printerr("FAIL: expedition exit did not advance day")
		quit(1)
		return
	_stage = "return hub"
	if current_scene.has_method("_on_return_pressed"):
		current_scene.call("_on_return_pressed")
	for _i in 120:
		await process_frame
		if current_scene != null and str(current_scene.scene_file_path).ends_with("cave_hub.tscn"):
			break
	_finished = true
	print("PASS: expedition smoke test completed full loop")
	quit(0)
