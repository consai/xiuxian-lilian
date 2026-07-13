extends SceneTree

class FailingLilianState:
	extends Node

	var reset_calls := 0
	var use_tutorial_map := false

	func start(
			_location_id: String,
			_game_state: Node,
			_seed: int,
			use_tutorial: bool
	) -> Dictionary:
		use_tutorial_map = use_tutorial
		return {"ok": false, "error": "start_failed"}

	func reset() -> void:
		reset_calls += 1


class FakeSceneManager:
	extends Node

	var navigation_calls := 0

	func preflight_transition() -> Dictionary:
		return {"ok": true}

	func go_lilian_xunhuan() -> Dictionary:
		navigation_calls += 1
		return {"ok": true}


class FakeTutorialService:
	extends Node

	func should_use_tutorial_lilian_map() -> bool:
		return true

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow_script := load("res://scripts/lilian/lilian_flow_service.gd")
	var lilian := FailingLilianState.new()
	var scene_manager := FakeSceneManager.new()
	var game_state := Node.new()
	var result: Dictionary = flow_script.call(
		"start_lilian", "location", 1, lilian, game_state, scene_manager, null
	)
	assert(not bool(result.get("ok", false)))
	assert(str(result.get("error", "")) == "start_failed")
	assert(scene_manager.navigation_calls == 0)
	assert(lilian.reset_calls == 0)
	assert(not lilian.use_tutorial_map)
	var tutorial := FakeTutorialService.new()
	result = flow_script.call(
		"start_lilian", "location", 1, lilian, game_state, scene_manager, tutorial
	)
	assert(not bool(result.get("ok", false)))
	assert(lilian.use_tutorial_map)
	lilian.free()
	scene_manager.free()
	game_state.free()
	tutorial.free()
	print("PASS: Lilian start failure does not navigate")
	quit(0)
