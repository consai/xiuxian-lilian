extends SceneTree

const MoniCatalogScript := preload("res://scripts/sim/moni_catalog.gd")
const LiandanStateScript := preload("res://scripts/features/alchemy/domain/liandan_state.gd")
const WeituoStateScript := preload(
	"res://scripts/features/commission/domain/weituo_state.gd"
)
const WorldMapStateScript := preload(
	"res://scripts/features/map/domain/world_map_state.gd"
)
const LilianSessionScript := preload("res://scripts/lilian/lilian_state.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")


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
	var navigation_manager := root.get_node("SceneManager")
	var game_state := GameSessionScript.new()
	root.add_child(game_state)
	game_state.bind_store(store)
	game_state.bind_scene_manager(navigation_manager)
	var lilian_state := LilianSessionScript.new()
	root.add_child(lilian_state)
	game_state.bind_lilian_session(lilian_state)
	navigation_manager.reset_navigation_runtime()
	var coalesced: Dictionary = store.coalesce_savedata({"knowledge": {}})
	assert((coalesced.get("knowledge", {}) as Dictionary).is_empty())
	lilian_state.active = true
	lilian_state.remember_generated_event({"id": "generated.new_game", "name": "fixture"})
	lilian_state.set_difficulty_override(2, 3)
	store.savedata["tutorial"] = {"completed": true, "step": "T10"}
	assert(bool(navigation_manager.go_to(
		SceneManager.MAIN_MENU,
		{"entry": {"value": 1}},
		{"reset_history": true}
	).get("ok", false)))
	game_state.new_game({"player_name": "新局测试"})

	assert(not store.rundata.has("zhandou"))
	assert(not store.rundata.has("battle"))
	assert(not lilian_state.active)
	assert(lilian_state.generated_events_snapshot().is_empty())
	assert(lilian_state.difficulty_override_snapshot().is_empty())
	assert(navigation_manager.navigation_snapshot() == {
		"current_id": "",
		"previous_id": "",
		"transitioning": false,
		"overlay_id": "",
		"history": [],
	})
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU).is_empty())
	assert(str(game_state.player_name) == "新局测试")
	assert(game_state.unlocked_abilities == initial["jineng"])
	assert(game_state.equipped_abilities == [
		"factive_lq_001", "factive_lq_002", "factive_lq_003", "", "",
	])
	assert(game_state.unlocked_methods == initial["gongfa"])
	assert(game_state.liandan == LiandanStateScript.default_state())
	assert(store.export_savedata().get("weituo") == WeituoStateScript.default_state())
	var new_map: Dictionary = game_state.map_data()
	assert(WorldMapStateScript.validate(new_map))
	assert(str(new_map.get("current_city_id", "")) == "qingshi_market")
	assert((new_map.get("discovered_cities", []) as Array).has("qingshi_market"))
	var new_tutorial := store.export_savedata().get("tutorial", {}) as Dictionary
	assert(not bool(new_tutorial.get("completed", true)))
	assert(store.export_savedata().get("story") == {
		"completed": [], "flags": {}, "history": [], "active_snapshot": {},
	})
	assert(store.rundata.get("story") == {"active_snapshot": {}, "pending_event": ""})
	var new_knowledge := store.export_savedata().get("knowledge", {}) as Dictionary
	# 当前 starter knowledge ID 未被配置解析；本批保持既有行为且不允许 DataStore 隐式授予。
	assert(new_knowledge.is_empty())

	# 当前 schema v2 槽位只导入 savedata；未来可恢复 session 的路由不在此规定。
	var savedata: Dictionary = store.export_savedata()
	var saved_knowledge := {
		"fixture.knowledge": {
			"level": 2,
			"xp": 4.5,
			"marked": true,
			"growth_source": "fixture",
			"extension": {"source": "roundtrip"},
		},
	}
	savedata["knowledge"] = saved_knowledge.duplicate(true)
	var saved_map: Dictionary = WorldMapStateScript.default_state()
	saved_map["current_city_id"] = "yunlan_city"
	saved_map["discovered_cities"] = ["yunlan_city", "qingshi_market"]
	saved_map["region_exploration"] = {"qinglan_mountain": 2}
	savedata["map"] = saved_map
	savedata["tutorial"] = {
		"chapter": "prologue_morning_practice",
		"step": "T09",
		"completed": true,
		"skipped": false,
		"flags": {"loaded_test": true},
		"seen_context_tips": [],
	}
	lilian_state.active = true
	lilian_state.remember_generated_event({"id": "generated.apply", "name": "fixture"})
	lilian_state.set_difficulty_override(3, 4)
	assert(bool(navigation_manager.go_to(
		SceneManager.MAIN_MENU,
		{"apply": {"value": 2}},
		{"reset_history": true}
	).get("ok", false)))
	assert(game_state.apply_dict(savedata))

	assert(not store.rundata.has("zhandou"))
	assert(not store.rundata.has("battle"))
	assert(not lilian_state.active)
	assert(lilian_state.generated_events_snapshot().is_empty())
	assert(lilian_state.difficulty_override_snapshot().is_empty())
	assert(navigation_manager.navigation_snapshot() == {
		"current_id": "",
		"previous_id": "",
		"transitioning": false,
		"overlay_id": "",
		"history": [],
	})
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU).is_empty())
	var loaded_tutorial := store.export_savedata().get("tutorial", {}) as Dictionary
	assert(bool(loaded_tutorial.get("completed", false)))
	assert(str(loaded_tutorial.get("step", "")) == "T09")
	assert((loaded_tutorial.get("flags", {}) as Dictionary).get("loaded_test", false))
	assert(game_state.map_data() == saved_map)
	assert(store.export_savedata().get("knowledge") == saved_knowledge)

	var before_failed_load: Dictionary = store.export_savedata()
	store.game_runtime()["last_settled_lilian_id"] = "atomic_guard"
	var runtime_before_failed_load: Dictionary = store.rundata.duplicate(true)
	lilian_state.active = true
	lilian_state.remember_generated_event({"id": "generated.atomic_guard", "name": "fixture"})
	lilian_state.set_difficulty_override(4, 5)
	var lilian_before_failed_load: Dictionary = lilian_state.session_snapshot()
	assert(bool(navigation_manager.go_to(
		SceneManager.MAIN_MENU,
		{"atomic_guard": {"value": 3}},
		{"reset_history": true}
	).get("ok", false)))
	var navigation_before_failed_load: Dictionary = navigation_manager.navigation_snapshot()
	var payload_before_failed_load: Dictionary = navigation_manager.peek_payload(SceneManager.MAIN_MENU)
	Engine.print_error_messages = false
	var missing_knowledge := savedata.duplicate(true)
	var missing_abilities := savedata.duplicate(true)
	missing_abilities.erase("equipped_abilities")
	assert(not game_state.apply_dict(missing_abilities))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(lilian_state.session_snapshot() == lilian_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_abilities := savedata.duplicate(true)
	invalid_abilities["equipped_abilities"] = ["factive_lq_001", "factive_lq_001", "", "", ""]
	assert(not game_state.apply_dict(invalid_abilities))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(lilian_state.session_snapshot() == lilian_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	missing_knowledge.erase("knowledge")
	assert(not game_state.apply_dict(missing_knowledge))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(lilian_state.session_snapshot() == lilian_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_knowledge := savedata.duplicate(true)
	invalid_knowledge["knowledge"] = {"fixture.knowledge": {"level": 6}}
	assert(not game_state.apply_dict(invalid_knowledge))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(lilian_state.session_snapshot() == lilian_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var missing_story := savedata.duplicate(true)
	missing_story.erase("story")
	assert(not game_state.apply_dict(missing_story))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	var missing_tutorial := savedata.duplicate(true)
	missing_tutorial.erase("tutorial")
	assert(not game_state.apply_dict(missing_tutorial))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_tutorial := savedata.duplicate(true)
	invalid_tutorial["tutorial"] = (savedata["tutorial"] as Dictionary).duplicate(true)
	invalid_tutorial["tutorial"]["flags"] = {"bad": 1}
	assert(not game_state.apply_dict(invalid_tutorial))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_story := savedata.duplicate(true)
	invalid_story["story"] = (savedata["story"] as Dictionary).duplicate(true)
	invalid_story["story"]["flags"] = []
	assert(not game_state.apply_dict(invalid_story))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	var missing_map := savedata.duplicate(true)
	missing_map.erase("map")
	assert(not game_state.apply_dict(missing_map))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_map := savedata.duplicate(true)
	invalid_map["map"] = saved_map.duplicate(true)
	invalid_map["map"]["route_states"] = []
	assert(not game_state.apply_dict(invalid_map))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var missing_liandan := savedata.duplicate(true)
	missing_liandan.erase("liandan")
	assert(not game_state.apply_dict(missing_liandan))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_liandan := savedata.duplicate(true)
	invalid_liandan["liandan"] = (savedata["liandan"] as Dictionary).duplicate(true)
	invalid_liandan["liandan"]["last_strategy"] = "standard"
	assert(not game_state.apply_dict(invalid_liandan))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var missing_weituo := savedata.duplicate(true)
	missing_weituo.erase("weituo")
	assert(not game_state.apply_dict(missing_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var invalid_weituo := savedata.duplicate(true)
	invalid_weituo["weituo"] = WeituoStateScript.default_state()
	invalid_weituo["weituo"]["board"]["refresh_day"] = 0
	assert(not game_state.apply_dict(invalid_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
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
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	var unknown_board_weituo := savedata.duplicate(true)
	unknown_board_weituo["weituo"] = WeituoStateScript.default_state()
	unknown_board_weituo["weituo"]["board"]["offer_ids"] = ["missing.commission"]
	assert(not game_state.apply_dict(unknown_board_weituo))
	assert(store.export_savedata() == before_failed_load)
	assert(store.rundata == runtime_before_failed_load)
	assert(navigation_manager.navigation_snapshot() == navigation_before_failed_load)
	assert(navigation_manager.peek_payload(SceneManager.MAIN_MENU) == payload_before_failed_load)
	Engine.print_error_messages = true
	assert(lilian_state.session_snapshot() == lilian_before_failed_load)

	print("PASS: game entry config and current session reset protocol")
	lilian_state.queue_free()
	game_state.queue_free()
	quit(0)
