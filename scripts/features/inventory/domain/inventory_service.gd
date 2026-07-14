class_name InventoryDomainService
extends RefCounted


static func add_item(inventory: Dictionary, definition: ItemDef, count: int) -> int:
	if definition == null or count <= 0:
		return 0
	var item_id := definition.id.strip_edges()
	if item_id == "":
		return 0
	var current := int(inventory.get(item_id, 0))
	var added := mini(count, maxi(0, maxi(1, definition.max_stack) - current))
	if added > 0:
		inventory[item_id] = current + added
	return added


static func remove_item(inventory: Dictionary, item_id: String, count: int) -> int:
	var id := item_id.strip_edges()
	var removed := mini(maxi(0, count), int(inventory.get(id, 0)))
	if removed <= 0:
		return 0
	var remaining := int(inventory[id]) - removed
	if remaining > 0:
		inventory[id] = remaining
	else:
		inventory.erase(id)
	return removed


static func recovery_result(current_hp: float, current_mp: float, max_hp: float, max_mp: float, hp_amount: float, mp_amount: float) -> Dictionary:
	var next_hp := minf(current_hp + hp_amount, max_hp)
	var next_mp := minf(current_mp + mp_amount, max_mp)
	return {"hp": next_hp, "mp": next_mp, "hp_gained": next_hp - current_hp, "mp_gained": next_mp - current_mp}


static func transfer_capacity(inventory: Dictionary, definition: ItemDef) -> int:
	if definition == null:
		return 0
	return maxi(0, maxi(1, definition.max_stack) - int(inventory.get(definition.id, 0)))


static func transfer_item(from_inventory: Dictionary, to_inventory: Dictionary, definition: ItemDef, count: int) -> int:
	if definition == null or count <= 0:
		return 0
	var id := definition.id
	var movable := mini(count, mini(int(from_inventory.get(id, 0)), transfer_capacity(to_inventory, definition)))
	if movable <= 0:
		return 0
	remove_item(from_inventory, id, movable)
	add_item(to_inventory, definition, movable)
	return movable


static func transfer_all_items(from_inventory: Dictionary, to_inventory: Dictionary, definitions: Dictionary) -> void:
	for item_id_v in (from_inventory.keys() as Array).duplicate():
		var definition: ItemDef = definitions.get(str(item_id_v), null) as ItemDef
		transfer_item(from_inventory, to_inventory, definition, int(from_inventory.get(item_id_v, 0)))


static func add_equip(owned_equips: Array, equip_id: int) -> bool:
	if equip_id <= 0 or owned_equips.has(equip_id):
		return false
	owned_equips.append(equip_id)
	return true


static func transfer_equip(from_equips: Array, to_equips: Array, equip_id: int) -> bool:
	if equip_id <= 0:
		return false
	var index := _find_equip_index(from_equips, equip_id)
	if index < 0:
		return false
	from_equips.remove_at(index)
	return add_equip(to_equips, equip_id)


static func transfer_all_equips(from_equips: Array, to_equips: Array) -> void:
	for equip_id_v in from_equips.duplicate():
		transfer_equip(from_equips, to_equips, int(equip_id_v))


static func cycle_equip_slot(owned_equips: Array, slots: Array, index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	var choices: Array = [-1]
	for equip_id_v in owned_equips:
		var equip_id := int(equip_id_v)
		if equip_id > 0 and (equip_id == int(slots[index]) or not slots.has(equip_id)) and not choices.has(equip_id):
			choices.append(equip_id)
	var current := int(slots[index])
	var position := choices.find(current)
	slots[index] = choices[(position + 1) % choices.size()]


static func cycle_item_slot(inventory: Dictionary, slots: Array, index: int, definitions: Dictionary) -> void:
	if index < 0 or index >= slots.size():
		return
	var choices: Array = [""]
	for item_id_v in inventory.keys():
		var item_id := str(item_id_v)
		var definition: ItemDef = definitions.get(item_id, null) as ItemDef
		if definition != null and definition.has_fight_config() and int(inventory[item_id_v]) > 0 and (item_id == str(slots[index]) or not slots.has(item_id)):
			choices.append(item_id)
	choices.sort()
	var position := choices.find(str(slots[index]))
	slots[index] = choices[(position + 1) % choices.size()]


static func build_battle_item_slots(inventory: Dictionary, slots: Array, definitions: Dictionary) -> Array:
	var out: Array = []
	for slot_v in slots:
		var definition: ItemDef = definitions.get(str(slot_v), null) as ItemDef
		if definition == null or not definition.has_fight_config():
			out.append({"id": -1, "cd": 0.0})
		else:
			out.append({"id": definition.fight_id, "count": int(inventory.get(definition.id, 0)), "cd": 0.0})
	return out


static func sync_battle_item_counts(inventory: Dictionary, slots: Array, battle_slots: Array) -> void:
	for i in mini(slots.size(), battle_slots.size()):
		if not battle_slots[i] is Dictionary:
			continue
		var item_id := str(slots[i])
		if item_id == "":
			continue
		var count := maxi(0, int((battle_slots[i] as Dictionary).get("count", 0)))
		if count > 0:
			inventory[item_id] = count
		else:
			inventory.erase(item_id)
			slots[i] = ""


static func _find_equip_index(equips: Array, equip_id: int) -> int:
	for index in equips.size():
		if int(equips[index]) == equip_id:
			return index
	return -1
