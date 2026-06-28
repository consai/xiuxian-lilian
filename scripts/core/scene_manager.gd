extends Node

signal active_scene_changed(scene: Node)

const MAIN_MENU := "main_menu"
const HUB := "hub"
const WORLD_MAP := "world_map"
const LILIAN_XUNHUAN := "lilian_xunhuan"
const LILIAN_JIESUAN := "lilian_jiesuan"
const ZHANDOU_CHANGJING := "zhandou_changjing"
const TUPO_ZONGJIE := "tupo_zongjie"
const XIULIAN_MIANBAN := "xiulian_mianban"
const XIULIAN_JINDU_QUANPING := "xiulian_jindu_quanping"
const KNOWLEDGE_STUDY_PANEL := "knowledge_study_panel"
const LIANDAN_MIANBAN := "liandan_mianban"
const LIANDAN_JINDU_QUANPING := "liandan_jindu_quanping"
const LIANDAN_JIEGUO_TANCHUANG := "liandan_jieguo_tanchuang"
const CHARACTER_ATTRIBUTES_PANEL := "character_attributes_panel"
const MASTERED_ARTS_PANEL := "mastered_arts_panel"
const ZHANDOU_PEIZHI_MIANBAN := "zhandou_peizhi_mianban"
const SKILL_RELEASE_STRATEGY_PANEL := "skill_release_strategy_panel"
const BEIBAO_PANEL := "beibao_panel"
const DAO_TREE_PANEL := "dao_tree_panel"

const SCENE_PATHS := {
	MAIN_MENU: "res://scenes/ui/main_menu.tscn",
	HUB: "res://scenes/sim/dongfu.tscn",
	WORLD_MAP: "res://scenes/map/map.tscn",
	LILIAN_XUNHUAN: "res://scenes/lilian/lilian_xunhuan.tscn",
	LILIAN_JIESUAN: "res://scenes/lilian/lilian_jiesuan.tscn",
	ZHANDOU_CHANGJING: "res://scenes/zhandou/zhandou_changjing.tscn",
	TUPO_ZONGJIE: "res://scenes/sim/tupo_zongjie.tscn",
	XIULIAN_MIANBAN: "res://scenes/sim/xiulian_mianban.tscn",
	XIULIAN_JINDU_QUANPING: "res://scenes/sim/xiulian_jindu_quanping.tscn",
	KNOWLEDGE_STUDY_PANEL: "res://scenes/ui/knowledge_study_panel.tscn",
	LIANDAN_MIANBAN: "res://scenes/sim/liandan_mianban.tscn",
	LIANDAN_JINDU_QUANPING: "res://scenes/sim/liandan_jindu_quanping.tscn",
	LIANDAN_JIEGUO_TANCHUANG: "res://scenes/sim/liandan_jieguo_tanchuang.tscn",
	CHARACTER_ATTRIBUTES_PANEL: "res://scenes/ui/character_attributes_panel.tscn",
	MASTERED_ARTS_PANEL: "res://scenes/ui/mastered_arts_panel.tscn",
	ZHANDOU_PEIZHI_MIANBAN: "res://scenes/ui/zhandou_peizhi_mianban.tscn",
	SKILL_RELEASE_STRATEGY_PANEL: "res://scenes/ui/skill_release_strategy_panel.tscn",
	BEIBAO_PANEL: "res://scenes/ui/beibao_panel.tscn",
	DAO_TREE_PANEL: "res://scenes/ui/dao_tree_panel.tscn",
}

const _BLOCKED_LILIAN_ACTIVE := "当前仍在历练中，请先完成或结算后再操作。"

## 叠在当前场景上的战斗/面板浮层，避免切场景销毁底层界面。
var _zhandou_overlay: Node = null
var _panel_overlay: Node = null
var _scene_underlay: Node = null
## 无专属 Host 的可导航场景与浮层统一挂在此节点下，不直接挂 root。
var _scene_root: Node = null
## ponytail: Godot 要求 current_scene 必须是 root 子节点；改由本字段追踪可导航场景。
var _active_scene: Node = null


func _ready() -> void:
	_ensure_scene_root()
	call_deferred("_adopt_boot_scene")


func _game_state() -> Node:
	return _autoload("GameState")


func _lilian_state() -> Node:
	return _autoload("LilianState")


func _data_store() -> Node:
	return _autoload("DataStore")


func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(node_name)
	return null


## 返回 SceneManager 下的场景容器，供剧情引导等跨层查找节点。
func get_scene_root() -> Node:
	_ensure_scene_root()
	return _scene_root


func _ensure_scene_root() -> void:
	if _scene_root != null and is_instance_valid(_scene_root):
		return
	_scene_root = Node.new()
	_scene_root.name = "SceneRoot"
	add_child(_scene_root)


## 返回当前可交互的主场景或浮层（战斗/全屏面板）；背包弹窗时仍返回底层场景。
func get_active_scene() -> Node:
	if _zhandou_overlay != null and is_instance_valid(_zhandou_overlay):
		return _zhandou_overlay
	if _panel_overlay != null and is_instance_valid(_panel_overlay):
		if _scene_underlay != null and is_instance_valid(_scene_underlay) and _scene_underlay.visible:
			return _scene_underlay
		return _panel_overlay
	if _active_scene != null and is_instance_valid(_active_scene):
		return _active_scene
	return get_tree().current_scene


func _set_active_scene(scene: Node) -> void:
	_active_scene = scene
	active_scene_changed.emit(scene)


## 启动时把 project.godot 配置的 main_scene 从 root 收编到 SceneRoot。
func _adopt_boot_scene() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	if current.get_parent() == get_tree().root:
		current.get_parent().remove_child(current)
		_scene_root.add_child(current)
	_set_active_scene(current)


func _load_main_scene(path: String) -> void:
	_ensure_scene_root()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneManager: failed to load %s" % path)
		_data_store().scene_runtime()["transitioning"] = false
		return
	var new_scene: Node = packed.instantiate()
	if new_scene == null:
		push_error("SceneManager: failed to instantiate %s" % path)
		_data_store().scene_runtime()["transitioning"] = false
		return
	var old_scene := get_active_scene()
	if old_scene != null and is_instance_valid(old_scene) and old_scene.get_parent() == _scene_root:
		old_scene.queue_free()
	_scene_root.add_child(new_scene)
	_set_active_scene(new_scene)


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


func start_lilian(location_id: String, seed_override: int = -1) -> Dictionary:
	var lilian := _lilian_state()
	var game_state := _game_state()
	if lilian == null or game_state == null:
		return {"ok": false, "error": "缺少 GameState 或 LilianState"}
	var preflight := _preflight_transition()
	if not bool(preflight.get("ok", false)):
		return preflight
	var started: Dictionary = lilian.start(location_id, game_state, seed_override)
	if not bool(started.get("ok", false)):
		return started
	var tutorial := _autoload("TutorialService")
	if tutorial != null and tutorial.has_method("game_event"):
		tutorial.call("game_event", "tutorial.lilian_started")
	var nav := go_lilian_xunhuan()
	if not bool(nav.get("ok", false)):
		lilian.reset()
	return nav


func go_lilian_xunhuan() -> Dictionary:
	return go_to(LILIAN_XUNHUAN)


func go_lilian_jiesuan(reason: String = "manual") -> Dictionary:
	_discard_lilian_zhandou_stack()
	var payload := ScenePayload.lilian_jiesuan(reason)
	if payload.is_empty():
		return {"ok": false, "error": "invalid_lilian_jiesuan_payload"}
	return go_to(LILIAN_JIESUAN, payload)


func go_tupo_mianban() -> Dictionary:
	return go_to(TUPO_ZONGJIE, {"mode": "panel"})


func go_xiulian_mianban() -> Dictionary:
	return go_to(XIULIAN_MIANBAN)


func go_knowledge_study_panel() -> Dictionary:
	return go_to(KNOWLEDGE_STUDY_PANEL)


func go_liandan_mianban() -> Dictionary:
	return go_to(LIANDAN_MIANBAN)


func go_liandan_jindu_quanping(session: Dictionary) -> Dictionary:
	var payload := session.duplicate(true)
	if str(payload.get("recipe_id", "")).strip_edges() == "":
		return {"ok": false, "error": "缺少丹方"}
	if str(payload.get("strategy_id", "")).strip_edges() == "":
		return {"ok": false, "error": "缺少炼制策略"}
	if int(payload.get("days", 0)) <= 0:
		return {"ok": false, "error": "炼制天数无效"}
	return go_to(LIANDAN_JINDU_QUANPING, payload)


func go_liandan_jieguo_tanchuang(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return {"ok": false, "error": str(result.get("error", "炼丹结果无效"))}
	return go_to(LIANDAN_JIEGUO_TANCHUANG, result.duplicate(true))


func go_xiulian_jindu_quanping(session: Dictionary) -> Dictionary:
	var payload := session.duplicate(true)
	if str(payload.get("mode_id", "")).strip_edges() == "":
		return {"ok": false, "error": "缺少修炼方式"}
	if int(payload.get("days", 0)) <= 0:
		return {"ok": false, "error": "闭关天数无效"}
	return go_to(XIULIAN_JINDU_QUANPING, payload)


func go_tupo_zongjie(summary: Dictionary) -> Dictionary:
	var payload := summary.duplicate(true)
	payload["mode"] = "result"
	var validated := ScenePayload.tupo_zongjie(payload)
	if validated.is_empty():
		return {"ok": false, "error": "invalid_tupo_zongjie_payload"}
	return go_to(TUPO_ZONGJIE, validated)


func go_character_attributes_panel() -> Dictionary:
	return go_to(CHARACTER_ATTRIBUTES_PANEL)


func go_mastered_arts_panel() -> Dictionary:
	return go_to(MASTERED_ARTS_PANEL)


func go_zhandou_peizhi_mianban() -> Dictionary:
	if _can_overlay_panel_on_lilian_xunhuan():
		return _push_panel_popup(ZHANDOU_PEIZHI_MIANBAN, {})
	return go_to(ZHANDOU_PEIZHI_MIANBAN)


func go_skill_release_strategy_panel() -> Dictionary:
	if _can_overlay_panel_on_lilian_xunhuan():
		return _push_panel_popup(SKILL_RELEASE_STRATEGY_PANEL, {})
	return go_to(SKILL_RELEASE_STRATEGY_PANEL)


## 背包统一以弹窗叠在当前场景上打开，不切场景、不压栈。
func go_beibao_panel(payload: Dictionary = {}) -> Dictionary:
	var merged := payload.duplicate(true)
	if _should_use_lilian_bag_context():
		merged["context"] = "lilian"
	var preflight := _preflight_panel_popup()
	if not bool(preflight.get("ok", false)):
		return preflight
	return _push_panel_popup(BEIBAO_PANEL, merged)


func go_dao_tree_panel() -> Dictionary:
	var guard := _guard_enter(DAO_TREE_PANEL, {})
	if not bool(guard.get("ok", false)):
		return guard
	# 大道树是人物配置中的同级视图，不额外占用返回栈层级。
	return _perform_transition(DAO_TREE_PANEL, {}, false)


func go_back(fallback_scene_id: String = HUB, options: Dictionary = {}) -> Dictionary:
	if _panel_overlay != null:
		return dismiss_panel_popup()
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


func go_zhandou(battle_data: Dictionary, source: String = "scene_manager") -> Dictionary:
	var merged := ZhandouInitData.merge_skill_cfg_from_tables(battle_data)
	var errors := ZhandouInitData.collect_errors(merged)
	if not errors.is_empty():
		return {"ok": false, "error": errors[0]}
	var preflight := _preflight_transition()
	if not bool(preflight.get("ok", false)):
		return preflight
	ZhandouInitData.set_pending(get_tree(), merged, source)
	var nav: Dictionary
	if _can_overlay_zhandou_on_lilian_xunhuan(source):
		nav = _push_zhandou_overlay()
	else:
		nav = _perform_transition(ZHANDOU_CHANGJING, {}, true)
	if not bool(nav.get("ok", false)):
		_data_store().zhandou_runtime()["pending_init"] = {}
	return nav


## 历练战斗胜利后：移除战斗叠层并恢复历练界面（不重新加载场景）。
func resume_lilian_after_zhandou() -> Dictionary:
	if _zhandou_overlay == null or _scene_underlay == null:
		return go_lilian_xunhuan()
	_remove_zhandou_overlay()
	_restore_scene_underlay()
	if _scene_underlay.has_method("resume_after_battle"):
		_scene_underlay.call("resume_after_battle")
	return {"ok": true, "scene_id": LILIAN_XUNHUAN, "resumed": true}


## 历练战斗战败/撤退结算：清掉叠层与历练界面后进入结算场景。
func end_lilian_zhandou_and_go_jiesuan(reason: String = "defeated") -> Dictionary:
	_discard_lilian_zhandou_stack()
	return go_lilian_jiesuan(reason)


## 关闭面板弹窗并恢复底层场景。
func dismiss_panel_popup() -> Dictionary:
	if _panel_overlay == null:
		return {"ok": false, "error": "no_panel_overlay"}
	var underlay := _scene_underlay
	_remove_panel_overlay()
	if underlay != null and is_instance_valid(underlay):
		if not underlay.visible:
			underlay.visible = true
			underlay.process_mode = Node.PROCESS_MODE_INHERIT
		if underlay.has_method("resume_after_panel"):
			underlay.call("resume_after_panel")
	if _zhandou_overlay == null:
		_scene_underlay = null
	return {"ok": true, "resumed": true}


func is_panel_popup_active() -> bool:
	return _panel_overlay != null and is_instance_valid(_panel_overlay)


func is_lilian_zhandou_overlay_active() -> bool:
	return _zhandou_overlay != null and is_instance_valid(_zhandou_overlay)


func take_payload(scene_id: String) -> Dictionary:
	return _data_store().take_scene_payload(scene_id)


func peek_payload(scene_id: String) -> Dictionary:
	return _data_store().peek_scene_payload(scene_id)


func _guard_enter(scene_id: String, options: Dictionary) -> Dictionary:
	if not SCENE_PATHS.has(scene_id):
		return {"ok": false, "error": "unknown_scene_id:%s" % scene_id}
	var lilian := _lilian_state()
	match scene_id:
		LILIAN_XUNHUAN:
			if lilian == null or not lilian.active:
				return {"ok": false, "error": "没有进行中的历练"}
			if lilian.should_go_to_result():
				return {"ok": false, "error": "历练已进入结算流程"}
		LILIAN_JIESUAN:
			if lilian == null:
				return {"ok": false, "error": "缺少 LilianState"}
			var game_state := _game_state()
			var has_summary := game_state != null and not (game_state.last_lilian_summary as Dictionary).is_empty()
			if not lilian.active and not has_summary:
				return {"ok": false, "error": "没有可结算的历练"}
		WORLD_MAP:
			if lilian != null and lilian.active:
				return {"ok": false, "error": _BLOCKED_LILIAN_ACTIVE}
		ZHANDOU_CHANGJING:
			return {"ok": false, "error": "战斗场景必须通过 go_zhandou() 进入"}
		HUB:
			if lilian != null and lilian.active and not bool(options.get("allow_active_lilian", false)):
				return {"ok": false, "error": _BLOCKED_LILIAN_ACTIVE, "blocked": true}
	return {"ok": true}


func _preflight_transition() -> Dictionary:
	var scene_rt: Dictionary = _data_store().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	return {"ok": true}


func _perform_transition(scene_id: String, payload: Dictionary, record_history: bool) -> Dictionary:
	_discard_lilian_zhandou_stack()
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
	call_deferred("_load_main_scene", path)
	call_deferred("_release_transition_lock")
	return {"ok": true, "scene_id": scene_id, "path": path}


func _release_transition_lock() -> void:
	await get_tree().process_frame
	_data_store().scene_runtime()["transitioning"] = false


func _can_overlay_zhandou_on_lilian_xunhuan(source: String) -> bool:
	if not _is_lilian_zhandou_source(source):
		return false
	if _zhandou_overlay != null or _panel_overlay != null:
		return false
	var underlay := get_active_scene()
	if underlay == null:
		return false
	return str(underlay.scene_file_path) == str(SCENE_PATHS.get(LILIAN_XUNHUAN, ""))


## 与 LilianBattleFlow.is_lilian_source 保持一致，避免 SceneManager 与战斗出口脚本循环依赖。
func _is_lilian_zhandou_source(source: String) -> bool:
	var trimmed := source.strip_edges()
	return trimmed == "lilian" or trimmed.begins_with("lilian_")


func _push_zhandou_overlay() -> Dictionary:
	var scene_rt: Dictionary = _data_store().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	var path := str(SCENE_PATHS.get(ZHANDOU_CHANGJING, ""))
	if path == "":
		return {"ok": false, "error": "unknown_scene_id:%s" % ZHANDOU_CHANGJING}
	var underlay := get_active_scene()
	if underlay == null:
		return {"ok": false, "error": "no_current_scene"}
	var packed := load(path)
	if packed == null:
		return {"ok": false, "error": "zhandou_changjing_load_failed"}
	var overlay: Node = packed.instantiate()
	if overlay == null:
		return {"ok": false, "error": "zhandou_changjing_instantiate_failed"}
	scene_rt["transitioning"] = true
	scene_rt["overlay_id"] = ZHANDOU_CHANGJING
	_scene_underlay = underlay
	_scene_underlay.visible = false
	_scene_underlay.process_mode = Node.PROCESS_MODE_DISABLED
	_zhandou_overlay = overlay
	_scene_root.add_child(_zhandou_overlay)
	call_deferred("_release_transition_lock")
	return {"ok": true, "scene_id": ZHANDOU_CHANGJING, "path": path, "overlay": true}


func _remove_zhandou_overlay() -> void:
	if _zhandou_overlay != null and is_instance_valid(_zhandou_overlay):
		_zhandou_overlay.queue_free()
	_zhandou_overlay = null
	_data_store().scene_runtime()["overlay_id"] = ""


func _restore_scene_underlay() -> void:
	if _scene_underlay == null or not is_instance_valid(_scene_underlay):
		_scene_underlay = null
		return
	_scene_underlay.visible = true
	_scene_underlay.process_mode = Node.PROCESS_MODE_INHERIT


func _discard_scene_underlay() -> void:
	if _scene_underlay != null and is_instance_valid(_scene_underlay):
		_scene_underlay.queue_free()
	_scene_underlay = null


func _should_use_lilian_bag_context() -> bool:
	var lilian := _lilian_state()
	return lilian != null and lilian.active


func _preflight_panel_popup() -> Dictionary:
	if _zhandou_overlay != null or _panel_overlay != null:
		return {"ok": false, "error": "panel_popup_already_open"}
	return _preflight_transition()


func _can_overlay_panel_on_lilian_xunhuan() -> bool:
	if not _preflight_panel_popup().get("ok", false):
		return false
	var lilian := _lilian_state()
	if lilian == null or not lilian.active:
		return false
	var underlay := get_active_scene()
	if underlay == null:
		return false
	return str(underlay.scene_file_path) == str(SCENE_PATHS.get(LILIAN_XUNHUAN, ""))


func _push_panel_popup(scene_id: String, payload: Dictionary) -> Dictionary:
	var scene_rt: Dictionary = _data_store().scene_runtime()
	if bool(scene_rt.get("transitioning", false)):
		return {"ok": false, "error": "transition_in_progress"}
	var path := str(SCENE_PATHS.get(scene_id, ""))
	if path == "":
		return {"ok": false, "error": "unknown_scene_id:%s" % scene_id}
	var underlay := get_active_scene()
	if underlay == null:
		return {"ok": false, "error": "no_current_scene"}
	var packed := load(path)
	if packed == null:
		return {"ok": false, "error": "panel_scene_load_failed"}
	var overlay: Node = packed.instantiate()
	if overlay == null:
		return {"ok": false, "error": "panel_scene_instantiate_failed"}
	scene_rt["transitioning"] = true
	if not payload.is_empty():
		_data_store().set_scene_payload(scene_id, payload)
	scene_rt["overlay_id"] = scene_id
	_scene_underlay = underlay
	var keep_underlay_visible := scene_id == BEIBAO_PANEL
	if not keep_underlay_visible:
		_scene_underlay.visible = false
		_scene_underlay.process_mode = Node.PROCESS_MODE_DISABLED
	_panel_overlay = overlay
	if keep_underlay_visible:
		# 背包弹窗：底层场景保持可见，仅在上层叠半透明遮罩与背包面板。
		_panel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
		_scene_underlay.add_child(_panel_overlay)
	else:
		_scene_root.add_child(_panel_overlay)
	call_deferred("_release_transition_lock")
	return {"ok": true, "scene_id": scene_id, "path": path, "popup": true}


func _remove_panel_overlay() -> void:
	if _panel_overlay != null and is_instance_valid(_panel_overlay):
		_panel_overlay.queue_free()
	_panel_overlay = null
	if _zhandou_overlay == null:
		_data_store().scene_runtime()["overlay_id"] = ""


func _discard_lilian_zhandou_stack() -> void:
	_remove_zhandou_overlay()
	_remove_panel_overlay()
	_discard_scene_underlay()
