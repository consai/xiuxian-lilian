extends SceneTree

const MoniCatalogScript := preload("res://scripts/sim/moni_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var initial := MoniCatalogScript.load_bundle().get("initial_player", {}) as Dictionary
	assert(initial.get("jineng") == [
		"factive_lq_001", "factive_lq_002", "factive_lq_003",
	])
	assert(initial.get("gongfa") == ["method.hunyuan.1"])
	assert(initial.get("item_slots") == ["", "", ""])
	assert(initial.get("equip_slots") == [-1, -1, -1])

	var store := root.get_node("DataStore")
	var game_state := root.get_node("GameState")
	var lilian_state := root.get_node("LilianState")
	store.lilian_runtime()["active"] = true
	store.savedata["tutorial"] = {"completed": true, "step": "T10"}
	game_state.new_game({"player_name": "新局测试"})

	assert(not lilian_state.active)
	assert(str(game_state.player_name) == "新局测试")
	assert(game_state.unlocked_abilities == initial["jineng"])
	assert(game_state.unlocked_methods == initial["gongfa"])
	var new_tutorial := store.export_savedata().get("tutorial", {}) as Dictionary
	assert(not bool(new_tutorial.get("completed", true)))

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

	print("PASS: game entry config and current session reset protocol")
	quit(0)
