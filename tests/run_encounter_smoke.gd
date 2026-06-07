extends SceneTree

const EncounterServiceScript := preload("res://scripts/sim/encounter_service.gd")

var _finished := false
var _frames := 0


func _init() -> void:
	call_deferred("_start")


func _process(_delta: float) -> bool:
	_frames += 1
	if _finished:
		return true
	if _frames > 1800:
		printerr("FAIL: encounter smoke test timed out")
		quit(1)
		return true
	return false


func _start() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		printerr("FAIL: GameState autoload missing")
		quit(1)
		return
	game_state.new_game()
	var encounter := EncounterServiceScript.by_id("normal")
	var data: Dictionary = game_state.build_battle_init(encounter)
	(data["player"] as Dictionary)["attrs"]["atk"] = 500.0
	data["auto_battle"] = {"player": true, "enemy": true}
	BattleInitData.set_pending(self, data, "encounter_smoke")
	change_scene_to_file("res://scenes/fightScene.tscn")
	await process_frame
	await process_frame
	if current_scene == null or not current_scene.has_signal("battle_finished"):
		printerr("FAIL: fight scene did not load")
		quit(1)
		return
	current_scene.battle_finished.connect(_on_battle_finished.bind(game_state))


func _on_battle_finished(summary: Dictionary, game_state: Node) -> void:
	if not summary.has("player_runtime"):
		printerr("FAIL: battle summary missing player runtime")
		quit(1)
		return
	game_state.pending_encounter_id = "normal"
	game_state.receive_battle_summary(summary)
	var settled: Dictionary = game_state.settle_pending_battle()
	if not bool(settled.get("ok", false)) or game_state.day != 2:
		printerr("FAIL: battle did not settle into simulation state")
		quit(1)
		return
	_finished = true
	print("PASS: encounter battle returns runtime state and settles one day")
	quit(0)
