extends Control

@onready var _save_overlay: Control = %SaveSlotsOverlay
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	_save_overlay.visible = false
	%StartButton.pressed.connect(_on_start_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)
	_save_overlay.closed.connect(_on_save_overlay_closed)
	_save_overlay.loaded.connect(_on_game_loaded)


func _on_start_pressed() -> void:
	GameState.new_game()
	_enter_game()


func _on_load_pressed() -> void:
	_save_overlay.refresh()
	_save_overlay.visible = true
	_set_message("选择要读取的存档槽位。")


func _on_game_loaded(_slot: int) -> void:
	_enter_game()


func _on_save_overlay_closed(message: String) -> void:
	if message != "":
		_set_message(message)


func _enter_game() -> void:
	var result: Dictionary = SceneManager.go_hub({}, {"reset_history": true})
	if not bool(result.get("ok", false)):
		_set_message(str(result.get("error", "进入游戏失败")))


func _set_message(text: String) -> void:
	_message_label.text = text
