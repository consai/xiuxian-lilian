extends Node

const StoryDirectorScript := preload("res://scripts/story/story_director.gd")

@onready var _scene_host: Node = %SceneHost
@onready var _story_playback_ui: StoryPlaybackPresenter = %StoryPlaybackUI
@onready var _story_director: StoryDirectorScript = %StoryDirector


func _ready() -> void:
	_story_director.bind_presenter(_story_playback_ui)
	TutorialService.bind_story_director(_story_director)
	SceneManager.bind_scene_host(_scene_host)
	var result: Dictionary = SceneManager.go_to(
		SceneManager.MAIN_MENU,
		{},
		{"reset_history": true}
	)
	if not bool(result.get("ok", false)):
		push_error("AppRoot: 无法进入主菜单: %s" % str(result.get("error", "unknown")))
