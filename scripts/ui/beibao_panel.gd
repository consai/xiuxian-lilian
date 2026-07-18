extends Control

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")

@onready var _bag: BagBaseView = %BagBase
@onready var _close_button: TextureButton = %CloseButton

var _lilian_mode := false
var _lilian_session_host: Node
var _game_session_host: Node


func bind_lilian_session_host(host: Node) -> void:
	_lilian_session_host = host


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host
	var game_session := _game_session()
	if game_session != null and not game_session.inventory_changed.is_connected(_refresh):
		game_session.inventory_changed.connect(_refresh)


func _game_session() -> Node:
	if _game_session_host == null:
		push_error("BeibaoPanel: GameSessionHost 未注入")
		return null
	return _game_session_host.session()


func _lilian_session() -> Node:
	if _lilian_session_host == null:
		push_error("BeibaoPanel: LilianSessionHost 未注入")
		return null
	return _lilian_session_host.session()


func _ready() -> void:
	var payload: Dictionary = SceneManager.take_payload(SceneManagerScript.BEIBAO_PANEL)
	_lilian_mode = str(payload.get("context", "")) == "lilian"
	_close_button.pressed.connect(_go_back)
	_bag.sort_requested.connect(func(_entries: Array) -> void: _refresh())
	if _lilian_mode:
		_bag.entry_right_clicked.connect(_on_lilian_entry_right_clicked)
		_bag.set_title("历练储物")
	else:
		if _game_session() == null:
			return
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _lilian_mode:
		var lilian := _lilian_session()
		if lilian == null or not lilian.active:
			_bag.set_entries([])
			return
		var runtime: Dictionary = lilian.runtime
		_bag.bind_inventory(
			runtime.get("inventory", {}) as Dictionary,
			runtime.get("owned_equips", []) as Array,
			_game_session()
		)
		return
	var game_session := _game_session()
	if game_session != null:
		_bag.bind_inventory(game_session.inventory, game_session.owned_equips, game_session)


## 历练模式：右键消耗品立即使用并刷新背包。
func _on_lilian_entry_right_clicked(entry: Dictionary) -> void:
	if str(entry.get("kind", "item")) != "item":
		return
	var lilian := _lilian_session()
	if lilian == null:
		return
	lilian.use_runtime_inventory_item(str(entry.get("id", "")))
	_refresh()


func _go_back() -> void:
	var lilian := _lilian_session()
	if lilian != null:
		LilianFlowService.close_lilian_utility_panel(_lilian_mode, lilian, SceneManager)
