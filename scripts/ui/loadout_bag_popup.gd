class_name LoadoutBagPopup
extends Control

signal entry_picked(entry: Dictionary)
signal closed

@onready var _bag: BagBaseView = %BagBase
@onready var _close_button: TextureButton = %CloseButton
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint

var _slot_index := -1
var _pick_kind := ""


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide_popup)
	_bag.entry_clicked.connect(_on_entry_clicked)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_popup()
		get_viewport().set_input_as_handled()


func open_for_equip(slot_index: int) -> void:
	_open(slot_index, "equip", "选择法宝", "点击法宝即可装备到当前槽位")


func open_for_item(slot_index: int) -> void:
	_open(slot_index, "item", "选择战斗道具", "点击道具即可装备到当前槽位")


func open_for_cultivation_pill() -> void:
	_open(-1, "cultivation_pill", "选择修炼丹药", "点击丹药即可设为炼化材料")


func hide_popup() -> void:
	if not visible:
		return
	visible = false
	_slot_index = -1
	_pick_kind = ""
	closed.emit()
	call_deferred("_reset_bag_picker_mode")


func _open(slot_index: int, kind: String, title: String, hint: String) -> void:
	_slot_index = slot_index
	_pick_kind = kind
	_title.text = title
	_hint.text = hint
	_bag.set_title(title)
	match kind:
		"equip":
			_bag.set_picker_mode(BagBaseView.PickerFilter.EQUIP)
		"cultivation_pill":
			_bag.set_picker_mode(BagBaseView.PickerFilter.CULTIVATION_PILL)
		_:
			_bag.set_picker_mode(BagBaseView.PickerFilter.BATTLE_ITEM)
	_bag.bind_inventory(GameState.inventory, GameState.owned_equips)
	visible = true


func _reset_bag_picker_mode() -> void:
	_bag.set_picker_mode(BagBaseView.PickerFilter.NONE)


func _on_entry_clicked(entry: Dictionary) -> void:
	if _pick_kind == "":
		return
	var picked := entry.duplicate(true)
	if _pick_kind == "cultivation_pill":
		entry_picked.emit(picked)
		hide_popup()
		return
	if _slot_index < 0:
		return
	picked["loadout_slot"] = _slot_index
	picked["loadout_kind"] = _pick_kind
	entry_picked.emit(picked)
	hide_popup()
