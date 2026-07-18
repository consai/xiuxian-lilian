extends Control

var _lilian_session_host: Node
var _game_session_host: Node


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host


func bind_lilian_session_host(host: Node) -> void:
	_lilian_session_host = host


func _lilian_session() -> Node:
	if _lilian_session_host == null:
		push_error("MainMenu: LilianSessionHost 未注入")
		return null
	return _lilian_session_host.session()

@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	%StartButton.pressed.connect(_on_start_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)


func _on_start_pressed() -> void:
	var result: Dictionary = SceneManager.go_character_creation()
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("error", "进入新建角色失败")))


func _on_load_pressed() -> void:
	if _game_session_host == null:
		_set_message("游戏会话未注入")
		return
	var result: Dictionary = _game_session_host.continue_game()
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("error", "没有可继续的自动存档")))
		return
	_enter_game()


func _enter_game() -> void:
	var lilian := _lilian_session()
	if lilian == null: return
	var result: Dictionary = LilianFlowService.open_hub(
		lilian,
		SceneManager,
		{},
		{"reset_history": true}
	)
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("error", "进入游戏失败")))


func _set_message(text: String) -> void:
	_message_label.text = text
