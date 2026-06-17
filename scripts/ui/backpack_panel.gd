extends Control

@onready var _bag: BagBaseView = %BagBase
@onready var _close_button: TextureButton = %CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_go_back)
	_bag.sort_requested.connect(func(_entries: Array) -> void: _refresh())
	DataEvents.inventory_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_bag.bind_inventory(GameState.inventory, GameState.owned_equips)


func _go_back() -> void:
	SceneManager.go_back()
