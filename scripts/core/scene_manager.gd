extends Node

const HUB := "hub"
const LOCATION_SELECT := "location_select"
const EXPEDITION_LOOP := "expedition_loop"
const EXPEDITION_RESULT := "expedition_result"
const FIGHT := "fight"
const BREAKTHROUGH_SUMMARY := "breakthrough_summary"

const SCENE_PATHS := {
	HUB: "res://scenes/sim/cave_hub.tscn",
	LOCATION_SELECT: "res://scenes/expedition/location_select.tscn",
	EXPEDITION_LOOP: "res://scenes/expedition/expedition_loop.tscn",
	EXPEDITION_RESULT: "res://scenes/expedition/expedition_result.tscn",
	FIGHT: "res://scenes/fightScene.tscn",
	BREAKTHROUGH_SUMMARY: "res://scenes/sim/breakthrough_summary.tscn",
}

const _BLOCKED_EXPEDITION_ACTIVE := "当前仍在历练中，请先完成或结算后再操作。"


func _ds() -> Node:
	return _autoload("DataStore")


func _game_state() -> Node:
	return _autoload("GameState")


func _expedition_state() -> Node:
	return _autoload("ExpeditionState")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func go_to(scene_id: String, payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var guard := _guard_enter(scene_id, options)
	if not bool(guard.get("ok", false)):
		return guard
	return _perform_transition(scene_id, payload)


func go_hub(payload: Dictionary = {}) -> Dictionary:
	return go_to(HUB, payload)


func go_location_select() -> Dictionary:
	return go_to(LOCATION_SELECT)


func start_expedition(location_id: String, seed_override: int = -1) -> Dictionary:
	var expedition := _expedition_state()
	var game_state := _game_state()
	if expedition == null or game_state == null:
		return {"ok": false, "error": "缺少 GameState 或 ExpeditionState"}
	var started: Dictionary = expedition.start(location_id, game_state, seed_override)
	if not bool(started.get("ok", false)):
		return started
	return go_expedition_loop()


func go_expedition_loop() -> Dictionary:
	return go_to(EXPEDITION_LOOP)


func go_expedition_result(reason: String = "manual") -> Dictionary:
	return go_to(EXPEDITION_RESULT, {"reason": reason})


func go_breakthrough_summary(summary: Dictionary) -> Dictionary:
	return go_to(BREAKTHROUGH_SUMMARY, summary)


func go_fight(battle_data: Dictionary, source: String = "scene_manager") -> Dictionary:
	var merged := BattleInitData.merge_skill_cfg_from_tables(battle_data)
	var errors := BattleInitData.collect_errors(merged)
	if not errors.is_empty():
		return {"ok": false, "error": errors[0]}
	BattleInitData.set_pending(get_tree(), merged, source)
	return _perform_transition(FIGHT, {})


func take_payload(scene_id: String) -> Dictionary:
	return _ds().take_scene_payload(scene_id)


func peek_payload(scene_id: String) -> Dictionary:
	return _ds().peek_scene_payload(scene_id)


func _guard_enter(scene_id: String, options: Dictionary) -> Dictionary:
	if not SCENE_PATHS.has(scene_id):
		return {"ok": false, "error": "unknown_scene_id:%s" % scene_id}
	var expedition := _expedition_state()
	match scene_id:
		EXPEDITION_LOOP:
			if expedition == null or not expedition.active:
				return {"ok": false, "error": "没有进行中的历练"}
			if expedition.should_go_to_result():
				return {"ok": false, "error": "历练已进入结算流程"}
		EXPEDITION_RESULT:
			if expedition == null:
				return {"ok": false, "error": "缺少 ExpeditionState"}
			if not expedition.active and expedition.last_finish_result.is_empty():
				return {"ok": false, "error": "没有可结算的历练"}
		LOCATION_SELECT:
			if expedition != null and expedition.active:
				return {"ok": false, "error": _BLOCKED_EXPEDITION_ACTIVE}
		FIGHT:
			return {"ok": false, "error": "战斗场景必须通过 go_fight() 进入"}
		HUB:
			if expedition != null and expedition.active and not bool(options.get("allow_active_expedition", false)):
				return {"ok": false, "error": _BLOCKED_EXPEDITION_ACTIVE, "blocked": true}
	return {"ok": true}


func _perform_transition(scene_id: String, payload: Dictionary) -> Dictionary:
	var scene_rt: Dictionary = _ds().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	var path := str(SCENE_PATHS.get(scene_id, ""))
	if path == "":
		return {"ok": false, "error": "unknown_scene_id:%s" % scene_id}
	scene_rt["transitioning"] = true
	if not payload.is_empty():
		_ds().set_scene_payload(scene_id, payload)
	scene_rt["previous_id"] = str(scene_rt.get("current_id", ""))
	scene_rt["current_id"] = scene_id
	var history_v: Variant = scene_rt.get("history", [])
	var history: Array = history_v as Array if history_v is Array else []
	history.append(scene_id)
	scene_rt["history"] = history
	get_tree().call_deferred("change_scene_to_file", path)
	call_deferred("_release_transition_lock")
	return {"ok": true, "scene_id": scene_id, "path": path}


func _release_transition_lock() -> void:
	await get_tree().process_frame
	_ds().scene_runtime()["transitioning"] = false
