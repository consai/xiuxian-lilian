extends Node

const StoryDirectorScript := preload("res://scripts/story/story_director.gd")
const TipPolicyCatalogScript := preload("res://scripts/tips/tip_policy_catalog.gd")
const TipsHostScript := preload("res://scripts/ui/tips_host.gd")
const TutorialCoordinatorScript := preload("res://scripts/app/tutorial_coordinator.gd")
const LilianSessionHostScript := preload("res://scripts/app/lilian_session_host.gd")
const LilianSessionScript := preload("res://scripts/lilian/lilian_state.gd")
const GameSessionHostScript := preload("res://scripts/app/game_session_host.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")

@onready var _scene_host: Node = %SceneHost
@onready var _tips_host: TipsHostScript = %TipsHost
@onready var _story_playback_ui: StoryPlaybackPresenter = %StoryPlaybackUI
@onready var _story_director: StoryDirectorScript = %StoryDirector
@onready var _gm_panel_host: Node = %GmPanelHost
@onready var _item_info_popup_host: Node = %ItemInfoPopupHost
var _tutorial_coordinator: Node
var _lilian_session_host: Node
var _game_session_host: Node


func _ready() -> void:
	var tip_policy := TipPolicyCatalogScript.snapshot()
	if tip_policy.is_empty():
		push_error("AppRoot: 提示策略加载失败")
		return
	_tips_host.bind_dependencies(tip_policy)
	_story_playback_ui.bind_scene_manager(SceneManager)
	_story_director.bind_store(DataStore)
	_story_director.bind_presenter(_story_playback_ui)
	_tutorial_coordinator = TutorialCoordinatorScript.new()
	_tutorial_coordinator.name = "TutorialCoordinator"
	add_child(_tutorial_coordinator)
	_tutorial_coordinator.bind_scene_manager(SceneManager)
	_tutorial_coordinator.bind_store(DataStore)
	_tutorial_coordinator.bind_story_director(_story_director)
	_game_session_host = GameSessionHostScript.new()
	_game_session_host.name = "GameSessionHost"
	add_child(_game_session_host)
	var game_session := GameSessionScript.new()
	game_session.name = "GameSession"
	_game_session_host.add_child(game_session)
	_game_session_host.bind_session(game_session)
	game_session.bind_store(DataStore)
	game_session.bind_scene_manager(SceneManager)
	game_session.bind_tip_host(_tips_host)
	_lilian_session_host = LilianSessionHostScript.new()
	_lilian_session_host.name = "LilianSessionHost"
	add_child(_lilian_session_host)
	var lilian_session := LilianSessionScript.new()
	lilian_session.name = "LilianSession"
	_lilian_session_host.add_child(lilian_session)
	_lilian_session_host.bind_session(lilian_session)
	lilian_session.bind_scene_manager(SceneManager)
	game_session.bind_lilian_session(lilian_session)
	_item_info_popup_host.bind_game_session_host(_game_session_host)
	_item_info_popup_host.bind_tips_host(_tips_host)
	_gm_panel_host.bind_game_session_host(_game_session_host)
	_gm_panel_host.bind_lilian_session_host(_lilian_session_host)
	_gm_panel_host.bind_tutorial_coordinator(_tutorial_coordinator)
	SceneManager.active_scene_changed.connect(_on_active_scene_changed)
	SceneManager.bind_scene_host(_scene_host)
	SceneManager.bind_page_dependencies(
		_game_session_host, _lilian_session_host, _tips_host, _tutorial_coordinator
	)
	var result: Dictionary = SceneManager.go_to(
		SceneManager.MAIN_MENU,
		{},
		{"reset_history": true}
	)
	if not bool(result.get("ok", false)):
		push_error("AppRoot: 无法进入主菜单: %s" % str(result.get("error", "unknown")))


func _on_active_scene_changed(scene: Node) -> void:
	if scene != null and scene.has_method("bind_tutorial_coordinator"):
		scene.call("bind_tutorial_coordinator", _tutorial_coordinator)
	if scene != null and scene.has_method("bind_lilian_session_host"):
		scene.call("bind_lilian_session_host", _lilian_session_host)
	if scene != null and scene.has_method("bind_game_session_host"):
		scene.call("bind_game_session_host", _game_session_host)
	if scene != null and scene.has_method("bind_tips_host"):
		scene.call("bind_tips_host", _tips_host)
