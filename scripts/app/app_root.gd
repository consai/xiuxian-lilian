extends Node

const StoryDirectorScript := preload("res://scripts/story/story_director.gd")
const TipPolicyCatalogScript := preload("res://scripts/tips/tip_policy_catalog.gd")
const TipsHostScript := preload("res://scripts/ui/tips_host.gd")

@onready var _scene_host: Node = %SceneHost
@onready var _tips_host: TipsHostScript = %TipsHost
@onready var _story_playback_ui: StoryPlaybackPresenter = %StoryPlaybackUI
@onready var _story_director: StoryDirectorScript = %StoryDirector


func _ready() -> void:
	var tip_policy := TipPolicyCatalogScript.snapshot()
	if tip_policy.is_empty():
		push_error("AppRoot: 提示策略加载失败")
		return
	_tips_host.bind_dependencies(DataEvents, tip_policy)
	_story_playback_ui.bind_scene_manager(SceneManager)
	_story_director.bind_store(DataStore)
	_story_director.bind_presenter(_story_playback_ui)
	TutorialService.bind_store(DataStore)
	TutorialService.bind_story_director(_story_director)
	SceneManager.bind_scene_host(_scene_host)
	var result: Dictionary = SceneManager.go_to(
		SceneManager.MAIN_MENU,
		{},
		{"reset_history": true}
	)
	if not bool(result.get("ok", false)):
		push_error("AppRoot: 无法进入主菜单: %s" % str(result.get("error", "unknown")))
