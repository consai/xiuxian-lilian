class_name InventoryEquipQueryApplication
extends RefCounted

const CatalogScript := preload("res://scripts/features/inventory/infrastructure/equip_catalog.gd")


static func equip_by_id(equip_id: int) -> Dictionary:
	for equip_v in _equips():
		if int(equip_v.id) == equip_id:
			return equip_v.to_runtime_dict().duplicate(true)
	return {}


static func all_equip_ids() -> Array:
	var ids: Array = []
	for equip_v in _equips():
		ids.append(int(equip_v.id))
	return ids.duplicate()


static func build_equip_cfg(extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for equip_v in _equips():
		var row: Dictionary = equip_v.to_runtime_dict()
		var equip_id := int(row.get("id", -1))
		if equip_id <= 0:
			continue
		out[equip_id] = row
		out[str(equip_id)] = row
	for key_v in extra.keys():
		var key_str := str(key_v)
		var entry_v: Variant = extra[key_v]
		if not entry_v is Dictionary:
			continue
		var entry := (entry_v as Dictionary).duplicate(true)
		if key_str.is_valid_int():
			var equip_id := int(key_str)
			out[equip_id] = entry
			out[str(equip_id)] = entry
		else:
			out[key_str] = entry
	return out.duplicate(true)


static func _equips() -> Array:
	return (CatalogScript.load_bundle().get("equips", []) as Array).duplicate()
