class_name LilianFlowService
extends RefCounted

## 历练结算编排：finish → settle，避免场景与 autoload 散落重复调用。

const _BLOCKED_LILIAN_ACTIVE := "当前仍在历练中，请先完成或结算后再操作。"


static func start_lilian(
		location_id: String,
		seed_override: int,
		lilian_state: Node,
		game_state: Node,
		scene_manager: Node,
		tutorial_service: Node
) -> Dictionary:
	if lilian_state == null or game_state == null:
		return {"ok": false, "error": "缺少 GameState 或 LilianState"}
	var preflight: Dictionary = scene_manager.preflight_transition()
	if not bool(preflight.get("ok", false)):
		return preflight
	var use_tutorial_map: bool = (
		tutorial_service != null
		and tutorial_service.should_use_tutorial_lilian_map()
	)
	var started: Dictionary = lilian_state.start(
		location_id,
		game_state,
		seed_override,
		use_tutorial_map
	)
	if not bool(started.get("ok", false)):
		return started
	if tutorial_service != null:
		tutorial_service.game_event("tutorial.lilian_started")
	var nav: Dictionary = open_active_lilian(lilian_state, scene_manager)
	if not bool(nav.get("ok", false)):
		lilian_state.reset()
	return nav


static func open_active_lilian(lilian_state: Node, scene_manager: Node) -> Dictionary:
	var admission := _active_lilian_admission(lilian_state)
	if not bool(admission.get("ok", false)):
		return admission
	return scene_manager.go_lilian_xunhuan()


static func go_back(
		lilian_state: Node,
		scene_manager: Node,
		fallback_scene_id: String = "hub"
) -> Dictionary:
	if scene_manager.peek_back_scene_id(fallback_scene_id) == "lilian_xunhuan":
		var admission := _active_lilian_admission(lilian_state)
		if not bool(admission.get("ok", false)):
			return admission
	return scene_manager.go_back(fallback_scene_id)


static func open_settlement(
		reason: String,
		lilian_state: Node,
		game_state: Node,
		scene_manager: Node
) -> Dictionary:
	if lilian_state == null:
		return {"ok": false, "error": "缺少 LilianState"}
	var has_summary := (
		game_state != null
		and not (game_state.last_lilian_summary as Dictionary).is_empty()
	)
	if not lilian_state.active and not has_summary:
		return {"ok": false, "error": "没有可结算的历练"}
	var payload := ScenePayload.lilian_jiesuan(reason)
	if payload.is_empty():
		return {"ok": false, "error": "invalid_lilian_jiesuan_payload"}
	return scene_manager.open_lilian_jiesuan(payload)


static func open_world_map(lilian_state: Node, scene_manager: Node) -> Dictionary:
	if lilian_state != null and lilian_state.active:
		return {"ok": false, "error": _BLOCKED_LILIAN_ACTIVE}
	return scene_manager.go_world_map()


static func open_hub(
		lilian_state: Node,
		scene_manager: Node,
		payload: Dictionary = {},
		options: Dictionary = {},
		allow_active: bool = false
) -> Dictionary:
	if lilian_state != null and lilian_state.active and not allow_active:
		return {
			"ok": false,
			"error": _BLOCKED_LILIAN_ACTIVE,
			"blocked": true,
		}
	var nav_options := options.duplicate(true)
	if allow_active:
		nav_options["allow_active_lilian"] = true
	return scene_manager.go_hub(payload.duplicate(true), nav_options)


static func close_settlement(
		lilian_state: Node,
		scene_manager: Node,
		tutorial_service: Node
) -> Dictionary:
	if lilian_state == null or scene_manager == null or tutorial_service == null:
		return {"ok": false, "error": "缺少 LilianState、SceneManager 或 TutorialService"}
	tutorial_service.game_event("tutorial.result_closed")
	scene_manager.take_payload(scene_manager.LILIAN_JIESUAN)
	return open_hub(lilian_state, scene_manager)


static func _active_lilian_admission(lilian_state: Node) -> Dictionary:
	if lilian_state == null or not lilian_state.active:
		return {"ok": false, "error": "没有进行中的历练"}
	if lilian_state.should_go_to_result():
		return {"ok": false, "error": "历练已进入结算流程"}
	return {"ok": true}


static func settle_active_lilian(
		reason: String,
		lilian_state: Node,
		game_state: Node,
		tutorial_service: Node
) -> Dictionary:
	if lilian_state == null or game_state == null or tutorial_service == null:
		return {"ok": false, "error": "缺少 LilianState、GameState 或 TutorialService"}
	if not lilian_state.active:
		return {"ok": false, "error": "没有可结算的历练"}
	var result: Dictionary = lilian_state.finish(reason)
	if not bool(result.get("ok", false)):
		return result
	var settled: Dictionary = game_state.settle_lilian(result, tutorial_service)
	if not bool(settled.get("ok", false)):
		return settled
	return result
