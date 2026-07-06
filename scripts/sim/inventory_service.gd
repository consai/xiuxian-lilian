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


static func transfer_capacity(inventory: Dictionary, item_id: String) -> int:
	var iid := item_id.strip_edges()
	if iid == "":
		return 0
	var def := _item_def(iid)
	if def == null:
		return 0
	var current := int(inventory.get(iid, 0))
	var cap := maxi(1, def.max_stack)
	return maxi(0, cap - current)


static func transfer_item(from_inventory: Dictionary, to_inventory: Dictionary, item_id: String, count: int) -> int:
	var iid := item_id.strip_edges()
	if iid == "" or count <= 0:
		return 0
	var source_count := int(from_inventory.get(iid, 0))
	if source_count <= 0:
		return 0
	var room := transfer_capacity(to_inventory, iid)
	var movable := mini(count, mini(source_count, room))
	if movable <= 0:
		return 0
	remove_item(from_inventory, iid, movable)
	add_item(to_inventory, iid, movable)
	return movable


static func transfer_all_items(from_inventory: Dictionary, to_inventory: Dictionary) -> void:
	for iid_v in (from_inventory.keys() as Array).duplicate():
		var iid := str(iid_v)
		transfer_item(from_inventory, to_inventory, iid, int(from_inventory.get(iid, 0)))


static func transfer_equip(from_equips: Array, to_equips: Array, equip_id: int) -> bool:
	if equip_id <= 0:
		return false
	var from_idx := _find_equip_index(from_equips, equip_id)
	if from_idx < 0:
		return false
	from_equips.remove_at(from_idx)
	return add_equip(to_equips, equip_id)


static func transfer_all_equips(from_equips: Array, to_equips: Array) -> void:
	for eid_v in (from_equips as Array).duplicate():
		transfer_equip(from_equips, to_equips, int(eid_v))


static func add_equip(owned_equips: Array, equip_id: int) -> bool:
	if equip_id <= 0 or _find_equip_index(owned_equips, equip_id) >= 0:
		return false
	owned_equips.append(equip_id)
	return true


static func _find_equip_index(equips: Array, equip_id: int) -> int:
	for i in equips.size():
		if int(equips[i]) == equip_id:
			return i
	return -1


static func cycle_equip_slot(owned_equips: Array, slots: Array, index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	var choices: Array = [-1]
	for value in owned_equips:
		var eid := int(value)
		if eid > 0 and (eid == int(slots[index]) or not slots.has(eid)) and not choices.has(eid):
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
		if (
			def != null
			and def.has_fight_config()
			and int(inventory[iid]) > 0
			and (iid == str(slots[index]) or not slots.has(iid))
		):
			choices.append(iid)
	choices.sort()
	var current := str(slots[index])
	var pos := choices.find(current)
	slots[index] = choices[(pos + 1) % choices.size()]


static func build_battle_item_slots(inventory: Dictionary, slots: Array) -> Array:
	var out: Array = []
	for i in slots.size():
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
			slots[i] = ""


static func _item_def(item_id: String) -> ItemDef:
	var cm := _config_manager()
	if cm != null and cm.has_method("item_def_by_id"):
		var found: ItemDef = cm.call("item_def_by_id", item_id) as ItemDef
		if found != null:
			return found
	for item_v in JsonLoader.load_items():
		if item_v is ItemDef and (item_v as ItemDef).id == item_id:
			return item_v as ItemDef
	return null


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
