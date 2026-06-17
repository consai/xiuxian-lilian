extends Node

const MAIN_MENU := "main_menu"
const HUB := "hub"
const WORLD_MAP := "world_map"
const EXPEDITION_LOOP := "expedition_loop"
const EXPEDITION_RESULT := "expedition_result"
const FIGHT := "fight"
const BREAKTHROUGH_SUMMARY := "breakthrough_summary"
const CULTIVATION_PANEL := "cultivation_panel"
const CULTIVATION_PROGRESS := "cultivation_progress"
const ALCHEMY_PANEL := "alchemy_panel"
const ALCHEMY_PROGRESS := "alchemy_progress"
const ALCHEMY_RESULT := "alchemy_result"
const CHARACTER_ATTRIBUTES_PANEL := "character_attributes_panel"
const COMBAT_LOADOUT_PANEL := "combat_loadout_panel"
const SKILL_RELEASE_STRATEGY_PANEL := "skill_release_strategy_panel"
const BACKPACK_PANEL := "backpack_panel"
const DAO_TREE_PANEL := "dao_tree_panel"

const SCENE_PATHS := {
	MAIN_MENU: "res://scenes/ui/main_menu.tscn",
	HUB: "res://scenes/sim/cave_hub.tscn",
	WORLD_MAP: "res://scenes/map/map.tscn",
	EXPEDITION_LOOP: "res://scenes/expedition/expedition_loop.tscn",
	EXPEDITION_RESULT: "res://scenes/expedition/expedition_result.tscn",
	FIGHT: "res://scenes/fightScene.tscn",
	BREAKTHROUGH_SUMMARY: "res://scenes/sim/breakthrough_summary.tscn",
	CULTIVATION_PANEL: "res://scenes/sim/cultivation_panel.tscn",
	CULTIVATION_PROGRESS: "res://scenes/sim/cultivation_progress_fullscreen.tscn",
	ALCHEMY_PANEL: "res://scenes/sim/alchemy_panel.tscn",
	ALCHEMY_PROGRESS: "res://scenes/sim/alchemy_progress_fullscreen.tscn",
	ALCHEMY_RESULT: "res://scenes/sim/alchemy_result_popup.tscn",
	CHARACTER_ATTRIBUTES_PANEL: "res://scenes/ui/character_attributes_panel.tscn",
	COMBAT_LOADOUT_PANEL: "res://scenes/ui/combat_loadout_panel.tscn",
	SKILL_RELEASE_STRATEGY_PANEL: "res://scenes/ui/skill_release_strategy_panel.tscn",
	BACKPACK_PANEL: "res://scenes/ui/backpack_panel.tscn",
	DAO_TREE_PANEL: "res://scenes/ui/dao_tree_panel.tscn",
}

const _BLOCKED_EXPEDITION_ACTIVE := "当前仍在历练中，请先完成或结算后再操作。"


func _game_state() -> Node:
	return _autoload("GameState")


func _expedition_state() -> Node:
	return _autoload("ExpeditionState")


func _data_store() -> Node:
	return _autoload("DataStore")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


func go_to(scene_id: String, payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	if bool(options.get("reset_history", false)):
		_data_store().reset_scene_runtime()
	var guard := _guard_enter(scene_id, options)
	if not bool(guard.get("ok", false)):
		return guard
	return _perform_transition(scene_id, payload, true)


func go_hub(payload: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	return go_to(HUB, payload, options)


func go_world_map() -> Dictionary:
	return go_to(WORLD_MAP)


func start_expedition(location_id: String, seed_override: int = -1) -> Dictionary:
	var expedition := _expedition_state()
	var game_state := _game_state()
	if expedition == null or game_state == null:
		return {"ok": false, "error": "缺少 GameState 或 ExpeditionState"}
	var preflight := _preflight_transition()
	if not bool(preflight.get("ok", false)):
		return preflight
	var started: Dictionary = expedition.start(location_id, game_state, seed_override)
	if not bool(started.get("ok", false)):
		return started
	var tutorial := _autoload("TutorialService")
	if tutorial != null and tutorial.has_method("game_event"):
		tutorial.call("game_event", "tutorial.expedition_started")
	var nav := go_expedition_loop()
	if not bool(nav.get("ok", false)):
		expedition.reset()
	return nav


func go_expedition_loop() -> Dictionary:
	return go_to(EXPEDITION_LOOP)


func go_expedition_result(reason: String = "manual") -> Dictionary:
	var payload := ScenePayload.expedition_result(reason)
	if payload.is_empty():
		return {"ok": false, "error": "invalid_expedition_result_payload"}
	return go_to(EXPEDITION_RESULT, payload)


func go_breakthrough_panel() -> Dictionary:
	return go_to(BREAKTHROUGH_SUMMARY, {"mode": "panel"})


func go_cultivation_panel() -> Dictionary:
	return go_to(CULTIVATION_PANEL)


func go_alchemy_panel() -> Dictionary:
	return go_to(ALCHEMY_PANEL)


func go_alchemy_progress(session: Dictionary) -> Dictionary:
	var payload := session.duplicate(true)
	if str(payload.get("recipe_id", "")).strip_edges() == "":
		return {"ok": false, "error": "缺少丹方"}
	if str(payload.get("strategy_id", "")).strip_edges() == "":
		return {"ok": false, "error": "缺少炼制策略"}
	if int(payload.get("days", 0)) <= 0:
		return {"ok": false, "error": "炼制天数无效"}
	return go_to(ALCHEMY_PROGRESS, payload)


func go_alchemy_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": str(result.get("error", "炼丹结果无效"))}
	return go_to(ALCHEMY_RESULT, result.duplicate(true))


func go_cultivation_progress(session: Dictionary) -> Dictionary:
	var payload := session.duplicate(true)
	if str(payload.get("mode_id", "")).strip_edges() == "":
		return {"ok": false, "error": "缺少修炼方式"}
	if int(payload.get("days", 0)) <= 0:
		return {"ok": false, "error": "闭关天数无效"}
	return go_to(CULTIVATION_PROGRESS, payload)


func go_breakthrough_summary(summary: Dictionary) -> Dictionary:
	var payload := summary.duplicate(true)
	payload["mode"] = "result"
	var validated := ScenePayload.breakthrough_summary(payload)
	if validated.is_empty():
		return {"ok": false, "error": "invalid_breakthrough_summary_payload"}
	return go_to(BREAKTHROUGH_SUMMARY, validated)


func go_character_attributes_panel() -> Dictionary:
	return go_to(CHARACTER_ATTRIBUTES_PANEL)


func go_combat_loadout_panel() -> Dictionary:
	return go_to(COMBAT_LOADOUT_PANEL)


func go_skill_release_strategy_panel() -> Dictionary:
	return go_to(SKILL_RELEASE_STRATEGY_PANEL)


func go_backpack_panel() -> Dictionary:
	return go_to(BACKPACK_PANEL)


func go_dao_tree_panel() -> Dictionary:
	var guard := _guard_enter(DAO_TREE_PANEL, {})
	if not bool(guard.get("ok", false)):
		return guard
	# 大道树是人物配置中的同级视图，不额外占用返回栈层级。
	return _perform_transition(DAO_TREE_PANEL, {}, false)


func go_back(fallback_scene_id: String = HUB, options: Dictionary = {}) -> Dictionary:
	var scene_rt: Dictionary = _data_store().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	var history_v: Variant = scene_rt.get("history", [])
	var history: Array = history_v as Array if history_v is Array else []
	var current_id := str(scene_rt.get("current_id", ""))
	if not history.is_empty() and str(history.back()) == current_id:
		history.pop_back()
	var target_id := fallback_scene_id
	if not history.is_empty():
		target_id = str(history.back())
	scene_rt["history"] = history
	if not SCENE_PATHS.has(target_id):
		return {"ok": false, "error": "unknown_scene_id:%s" % target_id}
	var guard := _guard_enter(target_id, options)
	if not bool(guard.get("ok", false)):
		return guard
	return _perform_transition(target_id, {}, false)


func go_fight(battle_data: Dictionary, source: String = "scene_manager") -> Dictionary:
	var merged := BattleInitData.merge_skill_cfg_from_tables(battle_data)
	var errors := BattleInitData.collect_errors(merged)
	if not errors.is_empty():
		return {"ok": false, "error": errors[0]}
	var preflight := _preflight_transition()
	if not bool(preflight.get("ok", false)):
		return preflight
	BattleInitData.set_pending(get_tree(), merged, source)
	var nav := _perform_transition(FIGHT, {}, true)
	if not bool(nav.get("ok", false)):
		_data_store().battle_runtime()["pending_init"] = {}
	return nav


func take_payload(scene_id: String) -> Dictionary:
	return _data_store().take_scene_payload(scene_id)


func peek_payload(scene_id: String) -> Dictionary:
	return _data_store().peek_scene_payload(scene_id)


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
			var game_state := _game_state()
			var has_summary := game_state != null and not (game_state.last_expedition_summary as Dictionary).is_empty()
			if not expedition.active and not has_summary:
				return {"ok": false, "error": "没有可结算的历练"}
		WORLD_MAP:
			if expedition != null and expedition.active:
				return {"ok": false, "error": _BLOCKED_EXPEDITION_ACTIVE}
		FIGHT:
			return {"ok": false, "error": "战斗场景必须通过 go_fight() 进入"}
		HUB:
			if expedition != null and expedition.active and not bool(options.get("allow_active_expedition", false)):
				return {"ok": false, "error": _BLOCKED_EXPEDITION_ACTIVE, "blocked": true}
	return {"ok": true}


func _preflight_transition() -> Dictionary:
	var scene_rt: Dictionary = _data_store().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	return {"ok": true}


func _perform_transition(scene_id: String, payload: Dictionary, record_history: bool) -> Dictionary:
	var scene_rt: Dictionary = _data_store().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	var path := str(SCENE_PATHS.get(scene_id, ""))
	if path == "":
		return {"ok": false, "error": "unknown_scene_id:%s" % scene_id}
	scene_rt["transitioning"] = true
	if not payload.is_empty():
		_data_store().set_scene_payload(scene_id, payload)
	scene_rt["previous_id"] = str(scene_rt.get("current_id", ""))
	scene_rt["current_id"] = scene_id
	if record_history:
		var history_v: Variant = scene_rt.get("history", [])
		var history: Array = history_v as Array if history_v is Array else []
		history.append(scene_id)
		scene_rt["history"] = history
	get_tree().call_deferred("change_scene_to_file", path)
	call_deferred("_release_transition_lock")
	return {"ok": true, "scene_id": scene_id, "path": path}


func _release_transition_lock() -> void:
	await get_tree().process_frame
	_data_store().scene_runtime()["transitioning"] = false
