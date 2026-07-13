extends SceneTree


class FakeLilianState:
	extends Node

	var active := false


class FakeGameState:
	extends Node

	var last_lilian_summary: Dictionary = {}


class FakeSceneManager:
	extends Node

	const LILIAN_JIESUAN := "lilian_jiesuan"

	var calls := 0
	var payload: Dictionary = {}
	var log: Array[String] = []
	var navigation_result := {"ok": true}

	func open_lilian_jiesuan(value: Dictionary) -> Dictionary:
		calls += 1
		payload = value.duplicate(true)
		return {"ok": true}

	func take_payload(_scene_id: String) -> Dictionary:
		log.append("take_payload")
		return {}

	func go_hub(_payload: Dictionary = {}, _options: Dictionary = {}) -> Dictionary:
		log.append("go_hub")
		return navigation_result


class FakeTutorialService:
	extends Node

	var log: Array[String]

	func _init(call_log: Array[String]) -> void:
		log = call_log

	func game_event(event_id: String) -> void:
		assert(event_id == "tutorial.result_closed")
		log.append("game_event")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow_script := load("res://scripts/lilian/lilian_flow_service.gd")
	var lilian := FakeLilianState.new()
	var game_state := FakeGameState.new()
	var scene_manager := FakeSceneManager.new()
	var tutorial := FakeTutorialService.new(scene_manager.log)

	var blocked: Dictionary = flow_script.call(
		"open_settlement", "manual", lilian, game_state, scene_manager
	)
	assert(not bool(blocked.get("ok", false)))
	assert(str(blocked.get("error", "")) == "没有可结算的历练")
	assert(scene_manager.calls == 0)

	lilian.active = true
	var invalid: Dictionary = flow_script.call(
		"open_settlement", "invalid_reason", lilian, game_state, scene_manager
	)
	assert(not bool(invalid.get("ok", false)))
	assert(str(invalid.get("error", "")) == "invalid_lilian_jiesuan_payload")
	assert(scene_manager.calls == 0)

	var opened: Dictionary = flow_script.call(
		"open_settlement", "manual", lilian, game_state, scene_manager
	)
	assert(bool(opened.get("ok", false)))
	assert(scene_manager.calls == 1)
	assert(scene_manager.payload == {"reason": "manual"})
	lilian.active = false

	var missing: Dictionary = flow_script.call(
		"close_settlement", lilian, scene_manager, null
	)
	assert(not bool(missing.get("ok", false)))
	assert(scene_manager.log.is_empty())

	var closed: Dictionary = flow_script.call(
		"close_settlement", lilian, scene_manager, tutorial
	)
	assert(bool(closed.get("ok", false)))
	assert(scene_manager.log == ["game_event", "take_payload", "go_hub"])

	scene_manager.log.clear()
	scene_manager.navigation_result = {"ok": false, "error": "blocked"}
	closed = flow_script.call("close_settlement", lilian, scene_manager, tutorial)
	assert(not bool(closed.get("ok", false)))
	assert(scene_manager.log == ["game_event", "take_payload", "go_hub"])

	var manager_script := load("res://scripts/core/scene_manager.gd")
	var manager: Node = manager_script.new()
	var rejected: Dictionary = manager.open_lilian_jiesuan({"reason": "invalid_reason"})
	assert(not bool(rejected.get("ok", false)))

	manager.free()
	lilian.free()
	game_state.free()
	scene_manager.free()
	tutorial.free()
	print("PASS: lilian settlement admission and payload")
	quit(0)
