extends SceneTree

const TutorialApplicationScript := preload(
	"res://scripts/features/tutorial/application/tutorial_application.gd"
)


class TutorialFixture extends Node:
	var active := true
	var application: Variant

	func is_active() -> bool:
		return active

	func is_waiting_for_any(_event_ids: Array) -> bool:
		return active

	func game_event(_event_id: String) -> void:
		if application != null:
			application.record_game_event(_event_id)
		active = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_root: Node = load("res://scenes/app/app_root.tscn").instantiate()
	root.add_child(app_root)
	var game_session: Node = app_root.get_node("GameSessionHost/GameSession")
	var store := root.get_node("DataStore")
	var lilian_state: Node = app_root.get_node("LilianSessionHost/LilianSession")
	var tutorial_coordinator := TutorialFixture.new()
	root.add_child(tutorial_coordinator)
	var tutorial_application := TutorialApplicationScript.new()
	tutorial_coordinator.application = tutorial_application
	var battle_flow_script := load("res://scripts/lilian/lilian_battle_flow.gd")
	tutorial_application.bind_store(store)
	store.reset_all()
	game_session.new_game()
	assert(tutorial_application.start_new_game())
	_prepare_won_battle(lilian_state, "generated.tutorial_win")
	assert(lilian_state.auto_advance)
	battle_flow_script.call("handle_result_close", lilian_state, game_session, tutorial_coordinator)
	assert(not lilian_state.auto_advance)
	assert(tutorial_application.has_event_flag("tutorial.first_battle_won"))

	store.reset_all()
	game_session.new_game()
	assert(tutorial_application.initialize_missing())
	tutorial_coordinator.active = false
	_prepare_won_battle(lilian_state, "generated.normal_win")
	assert(lilian_state.auto_advance)
	battle_flow_script.call("handle_result_close", lilian_state, game_session, tutorial_coordinator)
	assert(lilian_state.auto_advance)

	lilian_state.reset()
	print("PASS: tutorial first battle auto advance side effect")
	quit(0)


func _prepare_won_battle(lilian_state: Node, event_id: String) -> void:
	lilian_state.reset()
	lilian_state.active = true
	lilian_state.auto_advance = true
	lilian_state.remember_generated_event({
		"id": event_id,
		"name": "测试战斗",
		"type": "battle",
		"duration_days": 1,
	})
	lilian_state.pending_battle_event_id = event_id
	lilian_state.pending_battle_summary = {"outcome": "win", "player_runtime": {}}
	lilian_state.pending_battle_rewards = []
