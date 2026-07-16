extends Control

signal close_requested
signal accept_requested(weituo_id: String)
signal submit_requested(instance_id: String)
signal abandon_requested(instance_id: String)

const CARD_SCENE_PATH := "res://scenes/ui/components/weituo_card.tscn"
const REQUIREMENT_ROW_SCENE_PATH := "res://scenes/ui/components/weituo_requirement_row.tscn"
const ITEM_SCENE_PATH := "res://scenes/items/item.tscn"
const ItemIconResolverScript := preload(
	"res://scripts/features/inventory/presentation/item_icon_resolver.gd"
)
const WeituoApplicationScript := preload(
	"res://scripts/features/commission/application/weituo_application.gd"
)

const FILTER_ALL := "all"
const FILTER_AVAILABLE := "available"
const FILTER_ACTIVE := "active"
const FILTER_READY := "ready"
const FILTER_COMPLETED := "completed"

@onready var _close_button: TextureButton = %CloseButton
@onready var _active_limit_label: Label = %ActiveLimitLabel
@onready var _refresh_label: Label = %RefreshLabel
@onready var _weituo_list: VBoxContainer = %WeituoList
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_issuer: Label = %DetailIssuer
@onready var _detail_desc: RichTextLabel = %DetailDesc
@onready var _requirement_list: VBoxContainer = %RequirementList
@onready var _reward_list: HBoxContainer = %RewardList
@onready var _state_hint: Label = %StateHint
@onready var _accept_button: TextureButton = %AcceptButton
@onready var _submit_button: TextureButton = %SubmitButton
@onready var _abandon_button: TextureButton = %AbandonButton
@onready var _confirm_abandon_popup: PanelContainer = %ConfirmAbandonPopup
@onready var _all_filter_button: Button = %AllFilterButton
@onready var _available_filter_button: Button = %AvailableFilterButton
@onready var _active_filter_button: Button = %ActiveFilterButton
@onready var _ready_filter_button: Button = %ReadyFilterButton
@onready var _completed_filter_button: Button = %CompletedFilterButton

var _entries: Array = []
var _filter_id := FILTER_ALL
var _selected_key := ""
var _pending_abandon_id := ""
var _card_nodes: Dictionary = {}
var _filter_buttons: Dictionary = {}
var _cancel_abandon_button: Button
var _confirm_abandon_button: Button
var _application: Variant


func _ready() -> void:
	_application = WeituoApplicationScript.production()
	_confirm_abandon_popup.visible = false
	_cancel_abandon_button = _confirm_abandon_popup.find_child("CancelAbandonButton", true, false) as Button
	_confirm_abandon_button = _confirm_abandon_popup.find_child("ConfirmAbandonButton", true, false) as Button
	_close_button.pressed.connect(_on_close_pressed)
	_accept_button.pressed.connect(_on_accept_pressed)
	_submit_button.pressed.connect(_on_submit_pressed)
	_abandon_button.pressed.connect(_on_abandon_pressed)
	_all_filter_button.pressed.connect(func() -> void: set_filter(FILTER_ALL))
	_available_filter_button.pressed.connect(func() -> void: set_filter(FILTER_AVAILABLE))
	_active_filter_button.pressed.connect(func() -> void: set_filter(FILTER_ACTIVE))
	_ready_filter_button.pressed.connect(func() -> void: set_filter(FILTER_READY))
	_completed_filter_button.pressed.connect(func() -> void: set_filter(FILTER_COMPLETED))
	if _cancel_abandon_button != null:
		_cancel_abandon_button.pressed.connect(close_abandon_confirm)
	if _confirm_abandon_button != null:
		_confirm_abandon_button.pressed.connect(_on_confirm_abandon_pressed)
	_filter_buttons = {
		FILTER_ALL: _all_filter_button,
		FILTER_AVAILABLE: _available_filter_button,
		FILTER_ACTIVE: _active_filter_button,
		FILTER_READY: _ready_filter_button,
		FILTER_COMPLETED: _completed_filter_button,
	}
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirm_abandon_popup.visible:
			close_abandon_confirm()
		else:
			_on_close_pressed()
		get_viewport().set_input_as_handled()


func refresh(entries: Array = []) -> void:
	var snapshot: Dictionary = _application.refresh_board_snapshot(entries)
	if not bool(snapshot.get("ok", false)):
		show_empty_state(str(snapshot.get("error", "委托榜单刷新失败")))
		return
	_entries = (snapshot.get("entries", []) as Array).duplicate(true)
	var header := snapshot.get("header", {}) as Dictionary
	_active_limit_label.text = str(header.get("active_text", ""))
	_refresh_label.text = str(header.get("refresh_text", ""))
	_rebuild_cards()
	_apply_filter_visibility()
	if _selected_key == "" or _find_entry(_selected_key).is_empty():
		_select_default_entry()
	else:
		select_entry(_selected_key)


func set_filter(filter_id: String) -> void:
	_filter_id = filter_id
	_update_filter_styles()
	_apply_filter_visibility()
	if _entries.is_empty():
		show_empty_state("本月暂无合适委托。先修炼、巡山或整理背包。")
		return
	if _visible_entries().is_empty():
		_selected_key = ""
		_clear_detail_actions("当前筛选下暂无委托。")
		return
	if _find_entry(_selected_key).is_empty():
		_select_default_entry()
	else:
		select_entry(_selected_key)


func select_entry(entry_key: String) -> void:
	var entry := _find_entry(entry_key)
	if entry.is_empty():
		return
	_selected_key = entry_key
	for key in _card_nodes.keys():
		var card := _card_nodes[key] as Control
		if card != null and card.has_method("set_selected"):
			card.call("set_selected", str(key) == entry_key)
	bind_detail(entry)


func bind_detail(entry: Dictionary) -> void:
	_detail_title.text = str(entry.get("title", ""))
	_detail_issuer.text = "发布者：%s" % str(entry.get("issuer", ""))
	_detail_desc.text = str(entry.get("desc", ""))
	_state_hint.text = _detail_hint(entry)
	_accept_button.visible = bool(entry.get("can_accept", false)) or int(entry.get("state", -1)) == EnumWeituoState.State.AVAILABLE
	_submit_button.visible = bool(entry.get("can_submit", false)) or int(entry.get("state", -1)) == EnumWeituoState.State.READY
	_abandon_button.visible = bool(entry.get("can_abandon", false))
	_accept_button.disabled = not bool(entry.get("can_accept", false))
	_submit_button.disabled = not bool(entry.get("can_submit", false))
	_abandon_button.disabled = not bool(entry.get("can_abandon", false))
	_rebuild_requirement_rows(entry.get("requirements", []) as Array)
	_rebuild_reward_rows(entry.get("rewards", []) as Array)


func show_empty_state(message: String) -> void:
	_clear_children(_weituo_list)
	_selected_key = ""
	_card_nodes.clear()
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 120)
	_weituo_list.add_child(label)
	_detail_title.text = ""
	_detail_issuer.text = ""
	_detail_desc.text = ""
	_clear_children(_requirement_list)
	_clear_children(_reward_list)
	_state_hint.text = message
	_accept_button.visible = false
	_submit_button.visible = false
	_abandon_button.visible = false


func show_state_hint(message: String) -> void:
	_state_hint.text = message


func open_abandon_confirm(instance_id: String) -> void:
	_pending_abandon_id = instance_id
	_confirm_abandon_popup.visible = true


func close_abandon_confirm() -> void:
	_pending_abandon_id = ""
	_confirm_abandon_popup.visible = false


func _on_close_pressed() -> void:
	close_abandon_confirm()
	close_requested.emit()


func _on_accept_pressed() -> void:
	var entry := _find_entry(_selected_key)
	if entry.is_empty() or not bool(entry.get("can_accept", false)):
		if bool(entry.get("active_full", false)):
			show_state_hint("当前委托已满，先提交或放弃一项。")
		return
	accept_requested.emit(str(entry.get("weituo_id", "")))


func _on_submit_pressed() -> void:
	var entry := _find_entry(_selected_key)
	if entry.is_empty() or not bool(entry.get("can_submit", false)):
		return
	submit_requested.emit(str(entry.get("instance_id", "")))


func _on_abandon_pressed() -> void:
	var entry := _find_entry(_selected_key)
	if entry.is_empty() or not bool(entry.get("can_abandon", false)):
		return
	open_abandon_confirm(str(entry.get("instance_id", "")))


func _on_confirm_abandon_pressed() -> void:
	if _pending_abandon_id == "":
		return
	abandon_requested.emit(_pending_abandon_id)
	close_abandon_confirm()


func _rebuild_cards() -> void:
	_clear_children(_weituo_list)
	_card_nodes.clear()
	if _entries.is_empty():
		show_empty_state("本月暂无合适委托。先修炼、巡山或整理背包。")
		return
	for entry_v in _entries:
		var entry := entry_v as Dictionary
		var card: Node = load(CARD_SCENE_PATH).instantiate()
		_weituo_list.add_child(card)
		card.bind(entry)
		var key := str(entry.get("key", ""))
		_card_nodes[key] = card
		card.selected.connect(_on_card_selected)


func _rebuild_requirement_rows(requirements: Array) -> void:
	_clear_children(_requirement_list)
	for req_v in requirements:
		if not req_v is Dictionary:
			continue
		var row: Node = load(REQUIREMENT_ROW_SCENE_PATH).instantiate()
		_requirement_list.add_child(row)
		row.bind(req_v as Dictionary)


func _rebuild_reward_rows(rewards: Array) -> void:
	_clear_children(_reward_list)
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var item_row: Dictionary = (reward_v as Dictionary).duplicate()
		if str(item_row.get("name", "")) == "":
			item_row["name"] = str(item_row.get("display_name", ""))
		var icon_path: String = str(item_row.get("icon_path", "")).strip_edges()
		if icon_path != "" and not item_row.get("icon") is Texture2D:
			item_row["icon"] = ItemIconResolverScript.resolve(icon_path, null)
		var item_slot: ItemView = load(ITEM_SCENE_PATH).instantiate() as ItemView
		_reward_list.add_child(item_slot)
		ItemView.apply_reward_row(item_slot, item_row, {"click_enabled": true, "show_info_on_click": true})


func _apply_filter_visibility() -> void:
	if _entries.is_empty():
		return
	for key in _card_nodes.keys():
		var card := _card_nodes[key] as CanvasItem
		if card == null:
			continue
		card.visible = _entry_matches_filter(_find_entry(str(key)))


func _visible_entries() -> Array:
	var out: Array = []
	for entry_v in _entries:
		var entry := entry_v as Dictionary
		if _entry_matches_filter(entry):
			out.append(entry)
	return out


func _entry_matches_filter(entry: Dictionary) -> bool:
	var state := int(entry.get("state", EnumWeituoState.State.LOCKED))
	match _filter_id:
		FILTER_AVAILABLE:
			return state == EnumWeituoState.State.AVAILABLE
		FILTER_ACTIVE:
			return state == EnumWeituoState.State.ACTIVE
		FILTER_READY:
			return state == EnumWeituoState.State.READY
		FILTER_COMPLETED:
			return state == EnumWeituoState.State.COMPLETED
		_:
			return state != EnumWeituoState.State.LOCKED


func _select_default_entry() -> void:
	var priorities := [
		EnumWeituoState.State.READY,
		EnumWeituoState.State.ACTIVE,
		EnumWeituoState.State.AVAILABLE,
		EnumWeituoState.State.COMPLETED,
	]
	for state in priorities:
		for entry_v in _visible_entries():
			var entry := entry_v as Dictionary
			if int(entry.get("state", -1)) == state:
				select_entry(str(entry.get("key", "")))
				return
	var visible_entries_list: Array = _visible_entries()
	if not visible_entries_list.is_empty():
		select_entry(str((visible_entries_list[0] as Dictionary).get("key", "")))


func _find_entry(entry_key: String) -> Dictionary:
	for entry_v in _entries:
		var entry := entry_v as Dictionary
		if str(entry.get("key", "")) == entry_key:
			return entry
	return {}


func _on_card_selected(entry_key: String) -> void:
	select_entry(entry_key)


func _detail_hint(entry: Dictionary) -> String:
	var state := int(entry.get("state", EnumWeituoState.State.LOCKED))
	match state:
		EnumWeituoState.State.READY:
			return "委托已完成，可提交奖励。"
		EnumWeituoState.State.ACTIVE:
			return "委托进行中，完成目标后回道观提交。"
		EnumWeituoState.State.AVAILABLE:
			if bool(entry.get("active_full", false)):
				return "当前委托已满，先提交或放弃一项。"
			return "接受后顺路完成即可领取预定奖励。"
		EnumWeituoState.State.COMPLETED:
			return "该委托已完成。"
		_:
			return ""


func _update_filter_styles() -> void:
	for filter_id in _filter_buttons.keys():
		var button := _filter_buttons[filter_id] as Button
		if button == null:
			continue
		var is_selected: bool = filter_id == _filter_id
		button.disabled = is_selected


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _clear_detail_actions(message: String) -> void:
	_detail_title.text = ""
	_detail_issuer.text = ""
	_detail_desc.text = ""
	_clear_children(_requirement_list)
	_clear_children(_reward_list)
	_state_hint.text = message
	_accept_button.visible = false
	_submit_button.visible = false
	_abandon_button.visible = false
