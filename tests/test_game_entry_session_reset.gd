extends SceneTree

const MoniCatalogScript := preload("res://scripts/sim/moni_catalog.gd")
const LiandanStateScript := preload("res://scripts/features/alchemy/domain/liandan_state.gd")
const WeituoStateScript := preload(
	"res://scripts/features/commission/domain/weituo_state.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var initial := MoniCatalogScript.initial_player()
	assert(initial.get("jineng") == [
		"factive_lq_001", "factive_lq_002", "factive_lq_003",
	])
	assert(initial.get("gongfa") == ["method.hunyuan.1"])
	assert(initial.get("item_slots") == ["", "", ""])
	assert(initial.get("equip_slots") == [-1, -1, -1])

	var store := root.get_node("DataStore")
	var game_state := root.get_node("GameState")
	var lilian_state := root.get_node("LilianState")
	var coalesced: Dictionary = store.coalesce_savedata({"knowledge": {}})
	assert((coalesced.get("knowledge", {}) as Dictionary).is_empty())
	store.lilian_runtime()["active"] = true
	store.savedata["tutorial"] = {"completed": true, "step": "T10"}
	game_state.new_game({"player_name": "新局测试"})

	assert(not lilian_state.active)
	assert(str(game_state.player_name) == "新局测试")
	assert(game_state.unlocked_abilities == initial["jineng"])
	assert(game_state.unlocked_methods == initial["gongfa"])
	assert(game_state.liandan == LiandanStateScript.default_state())
	assert(store.export_savedata().get("weituo") == WeituoStateScript.default_state())
	var new_tutorial := store.export_savedata().get("tutorial", {}) as Dictionary
	assert(not bool(new_tutorial.get("completed", true)))
	var new_knowledge := store.export_savedata().get("knowledge", {}) as Dictionary
	# 当前 starter knowledge ID 未被配置解析；本批保持既有行为且不允许 DataStore 隐式授予。
	assert(new_knowledge.is_empty())

	# 当前 schema v2 槽位只导入 savedata；未来可恢复 session 的路由不在此规定。
	var savedata: Dictionary = store.export_savedata()
	savedata["tutorial"] = {
		"chapter": "prologue_morning_practice",
		"step": "T09",
		"completed": true,
		"skipped": false,
		"flags": {"loaded_test": true},
		"seen_context_tips": [],
	}
	store.lilian_runtime()["active"] = true
	var scene_runtime: Dictionary = store.scene_runtime()
	scene_runtime["current_id"] = "dirty_scene"
	scene_runtime["history"] = ["dirty_scene"]
	scene_runtime["payloads"] = {"dirty_scene": {"value": 1}}
	assert(game_state.apply_dict(savedata))

	assert(not lilian_state.active)
	assert(store.scene_runtime() == {
		"current_id": "",
		"previous_id": "",
		"transitioning": false,
		"payloads": {},
		"history": [],
	})
	var loaded_tutorial := store.export_savedata().get("tutorial", {}) as Dictionary
	assert(bool(loaded_tutorial.get("completed", false)))
	assert(str(loaded_tutorial.get("step", "")) == "T09")
	assert((loaded_tutorial.get("flags", {}) as Dictionary).get("loaded_test", false))

	var before_failed_load: Dictionary = store.export_savedata()
	store.game_runtime()["last_settled_lilian_id"] = "atomic_guard"
	var runtime_before_failed_load: Dictionary = store.rundata.duplicate(true)
	Engine.print_error_messages = false
	var missing_liandan := savedata.duplicate(true)
	missing_liandan.erase("liandan")
	assert(not game_state.apply_dict(missing_liandan))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	var invalid_liandan := savedata.duplicate(true)
	invalid_liandan["liandan"] = (savedata["liandan"] as Dictionary).duplicate(true)
	invalid_liandan["liandan"]["last_strategy"] = "standard"
	assert(not game_state.apply_dict(invalid_liandan))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	var missing_weituo := savedata.duplicate(true)
	missing_weituo.erase("weituo")
	assert(not game_state.apply_dict(missing_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	var invalid_weituo := savedata.duplicate(true)
	invalid_weituo["weituo"] = WeituoStateScript.default_state()
	invalid_weituo["weituo"]["board"]["refresh_day"] = 0
	assert(not game_state.apply_dict(invalid_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	var unknown_active_weituo := savedata.duplicate(true)
	unknown_active_weituo["weituo"] = WeituoStateScript.default_state()
	unknown_active_weituo["weituo"]["active"]["unknown_instance"] = {
		"weituo_id": "missing.commission",
		"accepted_day": 1,
		"progress": {},
	}
	assert(not game_state.apply_dict(unknown_active_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	var unknown_board_weituo := savedata.duplicate(true)
	unknown_board_weituo["weituo"] = WeituoStateScript.default_state()
	unknown_board_weituo["weituo"]["board"]["offer_ids"] = ["missing.commission"]
	assert(not game_state.apply_dict(unknown_board_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	Engine.print_error_messages = true

	print("PASS: game entry config and current session reset protocol")
	quit(0)
