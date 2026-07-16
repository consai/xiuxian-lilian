extends Node

## 全局配置中心：启动时预处理战斗配置表，并提供缓存读取接口。

var _equips_by_id: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_load_equips_local()


func equip_by_id(equip_id: int) -> Dictionary:
	var v: Variant = _equips_by_id.get(equip_id, _equips_by_id.get(str(equip_id), null))
	if v is EquipDef:
		return (v as EquipDef).to_runtime_dict()
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return {}


func all_equip_ids() -> Array:
	return (_equips_by_id.keys() as Array).duplicate()


func build_equip_cfg(extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for eid in _equips_by_id.keys():
		var row: Dictionary = equip_by_id(int(eid) if str(eid).is_valid_int() else eid)
		if row.is_empty():
			continue
		var id_val := int(row.get("id", eid))
		out[id_val] = row
		out[str(id_val)] = row
	if extra.is_empty():
		return out
	for k in extra.keys():
		var key_str := str(k)
		var ev: Variant = extra[k]
		if not ev is Dictionary:
			continue
		var entry := (ev as Dictionary).duplicate(true)
		if key_str.is_valid_int():
			var iid := int(key_str)
			out[iid] = entry
			out[str(iid)] = entry
		else:
			out[key_str] = entry
	return out


func _load_equips_local() -> void:
	const EquipCatalogScript := preload("res://scripts/zhandou/equip_catalog.gd")
	_equips_by_id.clear()
	var bundle: Dictionary = EquipCatalogScript.load_bundle()
	var equips_v: Variant = bundle.get("equips", [])
	if not equips_v is Array:
		return
	for ev in equips_v as Array:
		if ev is EquipDef:
			_equips_by_id[(ev as EquipDef).id] = ev
		elif ev is Dictionary:
			var equip := EquipDef.from_dict(ev as Dictionary)
			if equip != null:
				_equips_by_id[equip.id] = equip
