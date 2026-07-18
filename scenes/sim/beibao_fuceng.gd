extends TextureRect

const InventoryApplicationScript := preload("res://scripts/features/inventory/application/inventory_application.gd")

@onready var _bag_left: BagBaseView = %BagLeft
@onready var _bag_right: BagBaseView = %BagRight
@onready var _save_all_button: Button = %SaveAll
@onready var _withdraw_all_button: Button = %WithdrawAll
@onready var _close_button: TextureButton = %btn_close
@onready var _storage_count: Label = %StorageCount
@onready var _backpack_count: Label = %BackpackCount
@onready var _status: Label = %Status
var _game_session_host: Node


func bind_game_session_host(host: Node) -> void:
	_game_session_host = host
	var game_session: Node = _game_session()
	if game_session != null and not game_session.inventory_changed.is_connected(refresh):
		game_session.inventory_changed.connect(refresh)


func _game_session() -> Node:
	if _game_session_host == null:
		push_error("BeibaoFuceng: GameSessionHost 未注入")
		return null
	return _game_session_host.session()


func _ready() -> void:
	_bag_left.set_title("仓库")
	_bag_right.set_title("背包")
	_bag_left.entry_right_clicked.connect(_on_storage_entry_right_clicked)
	_bag_right.entry_right_clicked.connect(_on_backpack_entry_right_clicked)
	_save_all_button.pressed.connect(_deposit_all)
	_withdraw_all_button.pressed.connect(_withdraw_all)
	_close_button.pressed.connect(_close)
	call_deferred("_refresh_after_session")


func _refresh_after_session() -> void:
	if _game_session() != null:
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
	var game_session: Node = _game_session()
	if game_session == null:
		return
	_bag_left.bind_inventory(game_session.storage, game_session.storage_equips, game_session)
	_bag_right.bind_inventory(game_session.inventory, game_session.owned_equips, game_session)
	_storage_count.text = _inventory_summary(game_session.storage, game_session.storage_equips)
	_backpack_count.text = _inventory_summary(game_session.inventory, game_session.owned_equips)
	_withdraw_all_button.disabled = game_session.storage.is_empty() and game_session.storage_equips.is_empty()
	_save_all_button.disabled = game_session.inventory.is_empty() and game_session.owned_equips.is_empty()


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
		var game_session: Node = _game_session()
		var inventory: Dictionary = game_session.inventory
		var storage: Dictionary = game_session.storage
		var moved := InventoryApplicationScript.transfer_item(inventory, storage, item_id, count)
		if moved > 0:
			game_session.inventory = inventory
			game_session.storage = storage
			_clear_item_slots_if_empty(item_id)
			_show_status("已存入 %s × %d" % [_entry_name(entry), moved])
	refresh()


func _withdraw_entry(entry: Dictionary) -> void:
	if str(entry.get("kind", "item")) == "equip":
		_withdraw_equip(int(entry.get("id", -1)))
	else:
		var item_id := str(entry.get("id", "")).strip_edges()
		var count := maxi(1, int(entry.get("count", 1)))
		if item_id == "":
			return
		var game_session: Node = _game_session()
		var storage: Dictionary = game_session.storage
		var inventory: Dictionary = game_session.inventory
		var moved := InventoryApplicationScript.transfer_item(storage, inventory, item_id, count)
		if moved > 0:
			game_session.storage = storage
			game_session.inventory = inventory
			_show_status("已取出 %s × %d" % [_entry_name(entry), moved])
	refresh()


func _deposit_equip(equip_id: int) -> void:
	if equip_id <= 0:
		return
	var game_session: Node = _game_session()
	if not InventoryApplicationScript.transfer_equip(game_session.owned_equips, game_session.storage_equips, equip_id):
		return
	_clear_equip_slots(equip_id)
	_show_status("已将法宝存入仓库")
	refresh()


func _withdraw_equip(equip_id: int) -> void:
	if equip_id <= 0:
		return
	var game_session: Node = _game_session()
	if InventoryApplicationScript.transfer_equip(game_session.storage_equips, game_session.owned_equips, equip_id):
		_show_status("已从仓库取出法宝")
	refresh()


func _deposit_all() -> void:
	var game_session: Node = _game_session()
	var inventory: Dictionary = game_session.inventory
	var storage: Dictionary = game_session.storage
	InventoryApplicationScript.transfer_all_items(inventory, storage)
	game_session.inventory = inventory
	game_session.storage = storage
	var item_slots: Array = game_session.item_slots
	for i in item_slots.size():
		item_slots[i] = ""
	game_session.item_slots = item_slots
	for equip_id_v in game_session.owned_equips.duplicate():
		var equip_id := int(equip_id_v)
		if equip_id <= 0:
			continue
		if InventoryApplicationScript.transfer_equip(game_session.owned_equips, game_session.storage_equips, equip_id):
			_clear_equip_slots(equip_id)
	_show_status("背包物品已全部存入仓库")
	refresh()


func _withdraw_all() -> void:
	var game_session: Node = _game_session()
	var storage: Dictionary = game_session.storage
	var inventory: Dictionary = game_session.inventory
	InventoryApplicationScript.transfer_all_items(storage, inventory)
	game_session.storage = storage
	game_session.inventory = inventory
	InventoryApplicationScript.transfer_all_equips(game_session.storage_equips, game_session.owned_equips)
	_show_status("仓库物品已全部取出")
	refresh()


func _inventory_summary(inventory: Dictionary, equips: Array) -> String:
	var stack_count := 0
	for count_v in inventory.values():
		stack_count += maxi(0, int(count_v))
	return "%d 类物品 · %d 件物品 · %d 件法宝" % [inventory.size(), stack_count, equips.size()]


func _entry_name(entry: Dictionary) -> String:
	var display_name := str(entry.get("name", "")).strip_edges()
	if display_name != "":
		return display_name
	return str(entry.get("id", "物品"))


func _show_status(message: String) -> void:
	_status.text = message


func _clear_item_slots_if_empty(item_id: String) -> void:
	var game_session: Node = _game_session()
	if int(game_session.inventory.get(item_id, 0)) > 0:
		return
	var item_slots: Array = game_session.item_slots
	var changed := false
	for i in item_slots.size():
		if str(item_slots[i]) == item_id:
			item_slots[i] = ""
			changed = true
	if changed:
		game_session.item_slots = item_slots
	for i in game_session.treasure_item_slots.size():
		if str(game_session.treasure_item_slots[i]) == item_id:
			game_session.treasure_item_slots[i] = ""


func _clear_equip_slots(equip_id: int) -> void:
	var game_session: Node = _game_session()
	for i in game_session.equip_slots.size():
		if int(game_session.equip_slots[i]) == equip_id:
			game_session.equip_slots[i] = -1
