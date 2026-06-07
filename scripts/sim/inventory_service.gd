class_name InventoryService
extends RefCounted


static func add_item(inventory: Dictionary, item_id: String, count: int) -> int:
	var iid := item_id.strip_edges()
	if iid == "" or count <= 0:
		return 0
	var def := _item_def(iid)
	if def == null:
		return 0
	var current := int(inventory.get(iid, 0))
	var cap := maxi(1, def.max_stack)
	var added := mini(count, cap - current)
	if added > 0:
		inventory[iid] = current + added
	return added


static func remove_item(inventory: Dictionary, item_id: String, count: int) -> int:
	var iid := item_id.strip_edges()
	var current := int(inventory.get(iid, 0))
	var removed := mini(maxi(0, count), current)
	if removed <= 0:
		return 0
	var left := current - removed
	if left > 0:
		inventory[iid] = left
	else:
		inventory.erase(iid)
	return removed


static func add_equip(owned_equips: Array, equip_id: int) -> bool:
	if equip_id <= 0 or owned_equips.has(equip_id):
		return false
	owned_equips.append(equip_id)
	return true


static func cycle_equip_slot(owned_equips: Array, slots: Array, index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	var choices: Array = [-1]
	for value in owned_equips:
		var eid := int(value)
		if eid > 0 and not choices.has(eid):
			choices.append(eid)
	var current := int(slots[index])
	var pos := choices.find(current)
	slots[index] = choices[(pos + 1) % choices.size()]


static func cycle_item_slot(inventory: Dictionary, slots: Array, index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	var choices: Array = [""]
	for iid_v in inventory.keys():
		var iid := str(iid_v)
		var def := _item_def(iid)
		if def != null and def.has_fight_config() and int(inventory[iid]) > 0:
			choices.append(iid)
	choices.sort()
	var current := str(slots[index])
	var pos := choices.find(current)
	slots[index] = choices[(pos + 1) % choices.size()]


static func build_battle_item_slots(inventory: Dictionary, slots: Array) -> Array:
	var out: Array = []
	for i in 2:
		var iid := str(slots[i]) if i < slots.size() else ""
		var def := _item_def(iid)
		if def == null or not def.has_fight_config():
			out.append({"id": -1, "cd": 0.0})
			continue
		out.append({"id": def.fight_id, "count": int(inventory.get(iid, 0)), "cd": 0.0})
	return out


static func sync_battle_item_counts(inventory: Dictionary, slots: Array, battle_slots: Array) -> void:
	for i in mini(slots.size(), battle_slots.size()):
		if not battle_slots[i] is Dictionary:
			continue
		var iid := str(slots[i])
		if iid == "":
			continue
		var remaining := maxi(0, int((battle_slots[i] as Dictionary).get("count", 0)))
		if remaining > 0:
			inventory[iid] = remaining
		else:
			inventory.erase(iid)


static func _item_def(item_id: String) -> ItemDef:
	if ConfigManager == null:
		return null
	return ConfigManager.item_def_by_id(item_id)
