extends Control

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")

@onready var _bag: BagBaseView = %BagBase
@onready var _close_button: TextureButton = %CloseButton

var _expedition_mode := false


func _ready() -> void:
	var payload: Dictionary = SceneManager.take_payload(SceneManagerScript.BACKPACK_PANEL)
	_expedition_mode = str(payload.get("context", "")) == "expedition"
	_close_button.pressed.connect(_go_back)
	_bag.sort_requested.connect(func(_entries: Array) -> void: _refresh())
	if _expedition_mode:
		_bag.entry_right_clicked.connect(_on_expedition_entry_right_clicked)
		_bag.set_title("历练储物")
	else:
		DataEvents.inventory_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _expedition_mode:
		if ExpeditionState == null or not ExpeditionState.active:
			_bag.set_entries([])
			return
		var runtime := ExpeditionState.runtime
		_bag.bind_inventory(
			runtime.get("inventory", {}) as Dictionary,
			runtime.get("owned_equips", []) as Array
		)
		return
	_bag.bind_inventory(GameState.inventory, GameState.owned_equips)


## 历练模式：右键消耗品立即使用并刷新背包。
func _on_expedition_entry_right_clicked(entry: Dictionary) -> void:
	if str(entry.get("kind", "item")) != "item":
		return
	var result: Dictionary = ExpeditionState.use_runtime_inventory_item(str(entry.get("id", "")))
	var feedback := str(result.get("feedback", result.get("error", ""))).strip_edges()
	if feedback != "":
		DataStore.ui_runtime()["expedition_bag_feedback"] = feedback
	_refresh()


func _go_back() -> void:
	if SceneManager.is_panel_popup_active():
		SceneManager.dismiss_panel_popup()
		return
	SceneManager.go_back()
