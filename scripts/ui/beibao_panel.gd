extends Control

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")

@onready var _bag: BagBaseView = %BagBase
@onready var _close_button: TextureButton = %CloseButton

var _lilian_mode := false


func _ready() -> void:
	var payload: Dictionary = SceneManager.take_payload(SceneManagerScript.BEIBAO_PANEL)
	_lilian_mode = str(payload.get("context", "")) == "lilian"
	_close_button.pressed.connect(_go_back)
	_bag.sort_requested.connect(func(_entries: Array) -> void: _refresh())
	if _lilian_mode:
		_bag.entry_right_clicked.connect(_on_lilian_entry_right_clicked)
		_bag.set_title("历练储物")
	else:
		DataEvents.inventory_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _lilian_mode:
		if LilianState == null or not LilianState.active:
			_bag.set_entries([])
			return
		var runtime := LilianState.runtime
		_bag.bind_inventory(
			runtime.get("inventory", {}) as Dictionary,
			runtime.get("owned_equips", []) as Array
		)
		return
	_bag.bind_inventory(GameState.inventory, GameState.owned_equips)


## 历练模式：右键消耗品立即使用并刷新背包。
func _on_lilian_entry_right_clicked(entry: Dictionary) -> void:
	if str(entry.get("kind", "item")) != "item":
		return
	LilianState.use_runtime_inventory_item(str(entry.get("id", "")))
	_refresh()


func _go_back() -> void:
	LilianFlowService.close_lilian_utility_panel(_lilian_mode, LilianState, SceneManager)
