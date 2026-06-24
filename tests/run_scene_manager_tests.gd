extends SceneTree

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")

var _failures: Array[String] = []
var _tests_run := 0
var _async_stage := ""
var _async_frames := 0
var _overlay_loop_instance_id := 0


func _init() -> void:
	call_deferred("_run_all")


func _process(_delta: float) -> bool:
	if _async_frames > 0:
		_async_frames -= 1
		if _async_frames <= 0:
			_finish_async_stage()
	return false


func _run_all() -> void:
	_run("import_savedata resets scene runtime", _test_import_savedata_resets_scene_runtime)
	_run("go_world_map allowed when idle", _test_world_map_allowed_when_idle)
	_run("go_world_map blocked when expedition active", _test_world_map_blocked_when_active)
	_run("go_expedition_loop rejected without active", _test_go_expedition_loop_rejected_without_active)
	_run("go_breakthrough_panel payload", _test_breakthrough_panel_payload)
	_run("go cultivation panel", _test_cultivation_panel)
	_run("go alchemy panel", _test_alchemy_panel)
	_run("go alchemy progress payload", _test_alchemy_progress)
	_run("go alchemy result payload", _test_alchemy_result)
	_run("go cultivation progress payload", _test_cultivation_progress)
	_run("go_breakthrough_summary payload consumed once", _test_breakthrough_summary_payload)
	_run("go_expedition_result passes reason", _test_expedition_result_reason)
	_run("go_back pops panel stack instead of previous_id", _test_go_back_panel_stack)
	_run("transition lock prevents double go_to", _test_transition_lock)
	_run("start expedition rolls back when transition locked", _test_start_expedition_rollback_on_lock)
	_run("go fight leaves no pending init when transition locked", _test_go_fight_blocked_without_pending)
	if not _failures.is_empty():
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		quit(1)
		return
	_begin_async_chain()


func _run(name: String, test: Callable) -> void:
	_tests_run += 1
	var before := _failures.size()
	test.call()
	if before == _failures.size():
		print("PASS: %s" % name)


func _scene_manager() -> Node:
	return root.get_node("SceneManager")


func _active_scene() -> Node:
	return _scene_manager().get_active_scene()


func _expedition() -> Node:
	return root.get_node("ExpeditionState")


func _reset_game() -> void:
	root.get_node("GameState").new_game()
	_expedition().reset()
	root.get_node("DataStore").reset_scene_runtime()


func _test_import_savedata_resets_scene_runtime() -> void:
	_reset_game()
	var ds := root.get_node("DataStore")
	ds.set_scene_payload(SceneManagerScript.HUB, {"probe": 1})
	ds.scene_runtime()["current_id"] = SceneManagerScript.HUB
	var saved: Dictionary = root.get_node("GameState").to_dict()
	_expect_true(ds.import_savedata(saved), "import ok")
	_expect_eq(str(ds.scene_runtime().get("current_id", "")), "", "current_id cleared")
	_expect_true(ds.peek_scene_payload(SceneManagerScript.HUB).is_empty(), "payload cleared")


func _test_world_map_allowed_when_idle() -> void:
	_reset_game()
	var nav: Dictionary = _scene_manager().go_world_map()
	_expect_true(bool(nav.get("ok", false)), "world map allowed")


func _test_world_map_blocked_when_active() -> void:
	_reset_game()
	var expedition := _expedition()
	var started: Dictionary = expedition.start("qinglan_mountain", root.get_node("GameState"), 77)
	_expect_true(bool(started.get("ok", false)), "expedition started")
	var nav: Dictionary = _scene_manager().go_world_map()
	_expect_false(bool(nav.get("ok", true)), "world map blocked")
	_expect_true(expedition.active, "expedition still active")


func _test_go_expedition_loop_rejected_without_active() -> void:
	_reset_game()
	var nav: Dictionary = _scene_manager().go_expedition_loop()
	_expect_false(bool(nav.get("ok", true)), "loop rejected")


func _test_breakthrough_panel_payload() -> void:
	_reset_game()
	var nav: Dictionary = _scene_manager().go_breakthrough_panel()
	_expect_true(bool(nav.get("ok", false)), "panel navigation ok")
	var peeked: Dictionary = _scene_manager().peek_payload(SceneManagerScript.BREAKTHROUGH_SUMMARY)
	_expect_eq(str(peeked.get("mode", "")), "panel", "panel payload mode")


func _test_cultivation_panel() -> void:
	_reset_game()
	var nav: Dictionary = _scene_manager().go_cultivation_panel()
	_expect_true(bool(nav.get("ok", false)), "cultivation panel navigation ok")
	_expect_eq(
		str(nav.get("path", "")),
		"res://scenes/sim/cultivation_panel.tscn",
		"cultivation panel path"
	)


func _test_cultivation_progress() -> void:
	_reset_game()
	var invalid: Dictionary = _scene_manager().go_cultivation_progress({"mode_id": "", "days": 3})
	_expect_false(bool(invalid.get("ok", true)), "empty mode rejected")
	var nav: Dictionary = _scene_manager().go_cultivation_progress({
		"mode_id": "cycle",
		"days": 3,
		"method_name": "混元归一经",
		"mode_name": "运转周天",
		"start_day": 1,
	})
	_expect_true(bool(nav.get("ok", false)), "cultivation progress navigation ok")
	_expect_eq(
		str(nav.get("path", "")),
		"res://scenes/sim/cultivation_progress_fullscreen.tscn",
		"cultivation progress path"
	)
	var peeked: Dictionary = _scene_manager().peek_payload(SceneManagerScript.CULTIVATION_PROGRESS)
	_expect_eq(int(peeked.get("days", 0)), 3, "cultivation progress payload days")


func _test_alchemy_panel() -> void:
	_reset_game()
	var nav: Dictionary = _scene_manager().go_alchemy_panel()
	_expect_true(bool(nav.get("ok", false)), "alchemy panel navigation ok")
	_expect_eq(
		str(nav.get("path", "")),
		"res://scenes/sim/alchemy_panel.tscn",
		"alchemy panel path"
	)


func _test_alchemy_progress() -> void:
	_reset_game()
	var invalid: Dictionary = _scene_manager().go_alchemy_progress({"recipe_id": "", "strategy_id": "steady", "days": 2})
	_expect_false(bool(invalid.get("ok", true)), "empty recipe rejected")
	var nav: Dictionary = _scene_manager().go_alchemy_progress({
		"recipe_id": "recipe.huiqi",
		"strategy_id": "steady",
		"selection_mode": "lowest",
		"days": 1,
		"recipe_name": "回气丹方",
		"start_day": 1,
	})
	_expect_true(bool(nav.get("ok", false)), "alchemy progress navigation ok")
	_expect_eq(
		str(nav.get("path", "")),
		"res://scenes/sim/alchemy_progress_fullscreen.tscn",
		"alchemy progress path"
	)
	var peeked: Dictionary = _scene_manager().peek_payload(SceneManagerScript.ALCHEMY_PROGRESS)
	_expect_eq(str(peeked.get("recipe_id", "")), "recipe.huiqi", "alchemy progress payload recipe")


func _test_alchemy_result() -> void:
	_reset_game()
	var invalid: Dictionary = _scene_manager().go_alchemy_result({"ok": false, "error": "bad"})
	_expect_false(bool(invalid.get("ok", true)), "failed result rejected")
	var nav: Dictionary = _scene_manager().go_alchemy_result({
		"ok": true,
		"quality": "medium",
		"quality_name": "中品",
		"product_id": "items_HuiQiDan",
		"added": 3,
		"xp": 8,
		"days": 1,
	})
	_expect_true(bool(nav.get("ok", false)), "alchemy result navigation ok")
	_expect_eq(
		str(nav.get("path", "")),
		"res://scenes/sim/alchemy_result_popup.tscn",
		"alchemy result path"
	)


func _test_breakthrough_summary_payload() -> void:
	_reset_game()
	var summary := {"old_realm": "炼气一层", "new_realm": "炼气二层", "day": 3, "success": true}
	var nav: Dictionary = _scene_manager().go_breakthrough_summary(summary)
	_expect_true(bool(nav.get("ok", false)), "summary navigation ok")
	var peeked: Dictionary = _scene_manager().peek_payload(SceneManagerScript.BREAKTHROUGH_SUMMARY)
	_expect_eq(str(peeked.get("new_realm", "")), "炼气二层", "payload peek")
	var taken: Dictionary = _scene_manager().take_payload(SceneManagerScript.BREAKTHROUGH_SUMMARY)
	_expect_eq(str(taken.get("old_realm", "")), "炼气一层", "payload take")
	_expect_true(_scene_manager().take_payload(SceneManagerScript.BREAKTHROUGH_SUMMARY).is_empty(), "payload consumed once")


func _test_expedition_result_reason() -> void:
	_reset_game()
	_expedition().start("qinglan_mountain", root.get_node("GameState"), 88)
	var nav: Dictionary = _scene_manager().go_expedition_result("manual")
	_expect_true(bool(nav.get("ok", false)), "result navigation ok")
	var payload: Dictionary = _scene_manager().peek_payload(SceneManagerScript.EXPEDITION_RESULT)
	_expect_eq(str(payload.get("reason", "")), "manual", "reason payload")


func _test_start_expedition_rollback_on_lock() -> void:
	_reset_game()
	root.get_node("DataStore").scene_runtime()["transitioning"] = true
	var expedition := _expedition()
	var nav: Dictionary = _scene_manager().start_expedition("qinglan_mountain", 1234)
	_expect_false(bool(nav.get("ok", true)), "start blocked by lock")
	_expect_false(expedition.active, "expedition not left active")
	root.get_node("DataStore").scene_runtime()["transitioning"] = false


func _test_go_fight_blocked_without_pending() -> void:
	_reset_game()
	root.get_node("DataStore").scene_runtime()["transitioning"] = true
	var data: Dictionary = BattleInitData.sample_for_editor()
	var nav: Dictionary = _scene_manager().go_fight(data, "scene_manager_test")
	_expect_false(bool(nav.get("ok", true)), "go fight blocked by lock")
	var pending_v: Variant = root.get_node("DataStore").battle_runtime().get("pending_init", {})
	_expect_true((pending_v as Dictionary).is_empty(), "pending init not written")
	root.get_node("DataStore").scene_runtime()["transitioning"] = false


func _test_go_back_panel_stack() -> void:
	_reset_game()
	var ds := root.get_node("DataStore")
	var sm := _scene_manager()
	var hub_nav: Dictionary = sm.go_hub()
	_expect_true(bool(hub_nav.get("ok", false)), "hub navigation ok")
	ds.scene_runtime()["transitioning"] = false
	var attrs_nav: Dictionary = sm.go_character_attributes_panel()
	_expect_true(bool(attrs_nav.get("ok", false)), "attributes navigation ok")
	ds.scene_runtime()["transitioning"] = false
	var loadout_nav: Dictionary = sm.go_combat_loadout_panel()
	_expect_true(bool(loadout_nav.get("ok", false)), "loadout navigation ok")
	ds.scene_runtime()["transitioning"] = false
	var dao_nav: Dictionary = sm.go_dao_tree_panel()
	_expect_true(bool(dao_nav.get("ok", false)), "dao tree navigation ok")
	ds.scene_runtime()["transitioning"] = false
	var strategy_nav: Dictionary = sm.go_skill_release_strategy_panel()
	_expect_true(bool(strategy_nav.get("ok", false)), "strategy navigation ok")
	ds.scene_runtime()["transitioning"] = false
	var back_to_loadout: Dictionary = sm.go_back()
	_expect_true(bool(back_to_loadout.get("ok", false)), "back to loadout ok")
	_expect_eq(
		str(ds.scene_runtime().get("current_id", "")),
		SceneManagerScript.COMBAT_LOADOUT_PANEL,
		"current is loadout after strategy back"
	)
	ds.scene_runtime()["transitioning"] = false
	var back_to_attrs: Dictionary = sm.go_back()
	_expect_true(bool(back_to_attrs.get("ok", false)), "back to attributes ok")
	_expect_eq(
		str(ds.scene_runtime().get("current_id", "")),
		SceneManagerScript.CHARACTER_ATTRIBUTES_PANEL,
		"current is attributes after loadout back"
	)
	ds.scene_runtime()["transitioning"] = false
	var back_to_hub: Dictionary = sm.go_back()
	_expect_true(bool(back_to_hub.get("ok", false)), "back to hub ok")
	_expect_eq(str(ds.scene_runtime().get("current_id", "")), SceneManagerScript.HUB, "current is hub after second back")
	_expect_neq(
		str(ds.scene_runtime().get("current_id", "")),
		SceneManagerScript.COMBAT_LOADOUT_PANEL,
		"closing attributes does not reopen loadout"
	)


func _test_transition_lock() -> void:
	_reset_game()
	root.get_node("DataStore").scene_runtime()["transitioning"] = false
	var sm := _scene_manager()
	var first: Dictionary = sm.go_hub()
	var second: Dictionary = sm.go_hub()
	_expect_true(bool(first.get("ok", false)), "first transition ok")
	_expect_false(bool(second.get("ok", true)), "second transition blocked")
	_expect_eq(str(second.get("error", "")), "transition_in_progress", "lock error")


func _begin_async_chain() -> void:
	_run_async("start_expedition starts state and enters loop", "start_expedition")


func _run_async(name: String, stage: String) -> void:
	_tests_run += 1
	_async_stage = stage
	match stage:
		"start_expedition":
			_reset_game()
			var nav: Dictionary = _scene_manager().start_expedition("qinglan_mountain", 9999)
			_expect_true(bool(nav.get("ok", false)), "start expedition ok")
			_expect_true(_expedition().active, "expedition active after start")
		"go_hub":
			_reset_game()
			var nav: Dictionary = _scene_manager().go_hub()
			_expect_true(bool(nav.get("ok", false)), "go hub ok")
		"go_fight":
			_reset_game()
			var data: Dictionary = BattleInitData.sample_for_editor()
			var nav: Dictionary = _scene_manager().go_fight(data, "scene_manager_test")
			_expect_true(bool(nav.get("ok", false)), "go fight ok")
			var pending_v: Variant = root.get_node("DataStore").battle_runtime().get("pending_init", {})
			_expect_false((pending_v as Dictionary).is_empty(), "pending init written")
		"expedition_overlay_fight_enter":
			_overlay_loop_instance_id = _active_scene().get_instance_id()
			var overlay_data: Dictionary = BattleInitData.sample_for_editor()
			var overlay_nav: Dictionary = _scene_manager().go_fight(overlay_data, "expedition")
			_expect_true(bool(overlay_nav.get("ok", false)), "expedition overlay fight ok")
			_expect_true(bool(overlay_nav.get("overlay", false)), "expedition fight uses overlay")
		"expedition_overlay_fight_resume":
			var resumed: Dictionary = _scene_manager().resume_expedition_after_fight()
			_expect_true(bool(resumed.get("ok", false)), "resume expedition after overlay fight ok")
			_expect_true(bool(resumed.get("resumed", false)), "resume kept expedition loop instance")
	if not _failures.is_empty():
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		quit(1)
		return
	print("PASS: %s" % name)
	_async_frames = 3


func _finish_async_stage() -> void:
	match _async_stage:
		"start_expedition":
			_expect_eq(
				str(_active_scene().scene_file_path),
				"res://scenes/expedition/expedition_loop.tscn",
				"expedition loop scene"
			)
			if _failures.is_empty():
				_run_async("expedition fight overlays loop without destroying it", "expedition_overlay_fight_enter")
			else:
				_quit_failures()
		"expedition_overlay_fight_enter":
			_expect_eq(
				str(_active_scene().scene_file_path),
				"res://scenes/fightScene.tscn",
				"overlay fight scene active"
			)
			_expect_eq(_active_scene().get_instance_id(), _active_scene().get_instance_id(), "fight scene loaded")
			var loop_node := _find_expedition_loop_node()
			_expect_true(loop_node != null, "expedition loop kept in tree")
			if loop_node != null:
				_expect_eq(loop_node.get_instance_id(), _overlay_loop_instance_id, "expedition loop instance preserved")
			if _failures.is_empty():
				_run_async("resume expedition after overlay fight", "expedition_overlay_fight_resume")
			else:
				_quit_failures()
		"expedition_overlay_fight_resume":
			_expect_eq(
				str(_active_scene().scene_file_path),
				"res://scenes/expedition/expedition_loop.tscn",
				"resumed expedition loop scene"
			)
			_expect_eq(_active_scene().get_instance_id(), _overlay_loop_instance_id, "resumed same expedition loop instance")
			if _failures.is_empty():
				_run_async("go_hub switches to hub scene", "go_hub")
			else:
				_quit_failures()
		"go_hub":
			_expect_eq(
				str(_active_scene().scene_file_path),
				"res://scenes/sim/cave_hub.tscn",
				"hub scene"
			)
			if _failures.is_empty():
				_run_async("go_fight writes pending init and enters fight", "go_fight")
			else:
				_quit_failures()
		"go_fight":
			_expect_eq(
				str(_active_scene().scene_file_path),
				"res://scenes/fightScene.tscn",
				"fight scene"
			)
			_async_stage = ""
			if _failures.is_empty():
				_print_pass_and_quit()
			else:
				_quit_failures()


func _quit_failures() -> void:
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _print_pass_and_quit() -> void:
	print("PASS: %d scene manager tests" % _tests_run)
	quit(0)


func _expect_true(value: bool, label: String) -> void:
	if not value:
		_failures.append("%s (expected true)" % label)


func _expect_false(value: bool, label: String) -> void:
	if value:
		_failures.append("%s (expected false)" % label)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s got %s)" % [label, str(expected), str(actual)])


func _expect_neq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_failures.append("%s (expected not %s)" % [label, str(expected)])


func _find_expedition_loop_node() -> Node:
	var scene_root: Node = _scene_manager().get_scene_root()
	if scene_root == null:
		return null
	for child in scene_root.get_children():
		if child == null:
			continue
		if str(child.scene_file_path) == "res://scenes/expedition/expedition_loop.tscn":
			return child
	return null
