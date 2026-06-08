extends TextureRect

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")

@onready var _bag_left: BagBaseView = $BagLeft
@onready var _bag_right: BagBaseView = $BagRight
@onready var _save_all_button: Button = %SaveAll
@onready var _close_button: TextureButton = %btn_close


func _ready() -> void:
	_bag_left.set_title("仓库")
	_bag_right.set_title("背包")
	_bag_left.entry_right_clicked.connect(_on_storage_entry_right_clicked)
	_bag_right.entry_right_clicked.connect(_on_backpack_entry_right_clicked)
	_save_all_button.pressed.connect(_deposit_all)
	_close_button.pressed.connect(_close)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	visible = false


func refresh() -> void:
	_bag_left.bind_inventory(GameState.storage, GameState.storage_equips)
	_bag_right.bind_inventory(GameState.inventory, GameState.owned_equips)


func _on_backpack_entry_right_clicked(entry: Dictionary) -> void:
	_deposit_entry(entry)


func _on_storage_entry_right_clicked(entry: Dictionary) -> void:
	_withdraw_entry(entry)


func _deposit_entry(entry: Dictionary) -> void:
	if str(entry.get("kind", "item")) == "equip":
		_deposit_equip(int(entry.get("id", -1)))
	else:
		var item_id := str(entry.get("id", "")).strip_edges()
		var count := maxi(1, int(entry.get("count", 1)))
		if item_id == "":
			return
		var moved := InventoryServiceScript.transfer_item(GameState.inventory, GameState.storage, item_id, count)
		if moved > 0:
			_clear_item_slots_if_empty(item_id)
	refresh()


func _withdraw_entry(entry: Dictionary) -> void:
	if str(entry.get("kind", "item")) == "equip":
		_withdraw_equip(int(entry.get("id", -1)))
	else:
		var item_id := str(entry.get("id", "")).strip_edges()
		var count := maxi(1, int(entry.get("count", 1)))
		if item_id == "":
			return
		InventoryServiceScript.transfer_item(GameState.storage, GameState.inventory, item_id, count)
	refresh()


func _deposit_equip(equip_id: int) -> void:
	if equip_id <= 0:
		return
	if not InventoryServiceScript.transfer_equip(GameState.owned_equips, GameState.storage_equips, equip_id):
		return
	_clear_equip_slots(equip_id)
	refresh()


func _withdraw_equip(equip_id: int) -> void:
	if equip_id <= 0:
		return
	InventoryServiceScript.transfer_equip(GameState.storage_equips, GameState.owned_equips, equip_id)
	refresh()


func _deposit_all() -> void:
	InventoryServiceScript.transfer_all_items(GameState.inventory, GameState.storage)
	for i in GameState.item_slots.size():
		GameState.item_slots[i] = ""
	for equip_id_v in GameState.owned_equips.duplicate():
		var equip_id := int(equip_id_v)
		if equip_id <= 0:
			continue
		if InventoryServiceScript.transfer_equip(GameState.owned_equips, GameState.storage_equips, equip_id):
			_clear_equip_slots(equip_id)
	refresh()


func _clear_item_slots_if_empty(item_id: String) -> void:
	if int(GameState.inventory.get(item_id, 0)) > 0:
		return
	for i in GameState.item_slots.size():
		if str(GameState.item_slots[i]) == item_id:
			GameState.item_slots[i] = ""


func _clear_equip_slots(equip_id: int) -> void:
	for i in GameState.equip_slots.size():
		if int(GameState.equip_slots[i]) == equip_id:
			GameState.equip_slots[i] = -1
