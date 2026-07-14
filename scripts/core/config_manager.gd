extends Node

## 全局配置中心：启动时预处理战斗配置表，并提供缓存读取接口。

var _items: Array = []
var _items_by_id: Dictionary = {}
var _items_by_fight_id: Dictionary = {}
var _item_name_by_id: Dictionary = {}
var _item_id_aliases: Dictionary = {}
var _equips_by_id: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_load_items_local()
	_load_equips_local()


func items() -> Array:
	return _items.duplicate()


func item_def_by_id(item_id: String) -> ItemDef:
	var iid := item_id.strip_edges()
	var canonical_id := _resolve_item_id_alias(iid)
	var found: Variant = _items_by_id.get(canonical_id)
	if found is ItemDef:
		return found as ItemDef
	return null


func equip_by_id(equip_id: int) -> Dictionary:
	var v: Variant = _equips_by_id.get(equip_id, _equips_by_id.get(str(equip_id), null))
	if v is EquipDef:
		return (v as EquipDef).to_runtime_dict()
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return {}


func item_by_fight_id(fight_id: int) -> Dictionary:
	var def := item_def_by_fight_id(fight_id)
	if def == null:
		return {}
	return def.to_fight_runtime_dict()


func item_def_by_fight_id(fight_id: int) -> ItemDef:
	if fight_id <= 0:
		return null
	var found: Variant = _items_by_fight_id.get(fight_id)
	if found is ItemDef:
		return found as ItemDef
	return null


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


func build_item_cfg(extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for it in _items:
		if it == null or not it is ItemDef:
			continue
		var def := it as ItemDef
		if not def.has_fight_config():
			continue
		var row := def.to_fight_runtime_dict()
		var fid := int(row.get("id", 0))
		if fid <= 0:
			continue
		out[fid] = row
		out[str(fid)] = row
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


func get_item_display_name(item_id: String) -> String:
	var iid := item_id.strip_edges()
	if iid == "":
		return ""
	var canonical_id := _resolve_item_id_alias(iid)
	return str(_item_name_by_id.get(canonical_id, canonical_id))


func _load_items_local() -> void:
	const ItemAliasCatalogScript := preload("res://scripts/sim/item_alias_catalog.gd")
	_items = JsonLoader.load_items()
	_item_name_by_id.clear()
	_item_id_aliases = ItemAliasCatalogScript.load_all()
	_items_by_id.clear()
	_items_by_fight_id.clear()
	for it in _items:
		if it == null or not it is ItemDef:
			continue
		var def := it as ItemDef
		var iid := JsonLoader.config_id_to_string(str(def.id))
		if iid == "":
			continue
		_items_by_id[iid] = def
		if def.fight_id > 0:
			_items_by_fight_id[def.fight_id] = def
		var nm := str(def.name).strip_edges()
		if nm == "":
			nm = iid
		_item_name_by_id[iid] = nm
	for alias_id_v in _item_id_aliases.keys():
		var alias_id := str(alias_id_v)
		var canonical_id := _resolve_item_id_alias(alias_id)
		if _item_name_by_id.has(canonical_id):
			_item_name_by_id[alias_id] = _item_name_by_id[canonical_id]


func _resolve_item_id_alias(item_id: String) -> String:
	var iid := item_id.strip_edges()
	if iid == "":
		return ""
	var seen := {}
	var current := iid
	while _item_id_aliases.has(current):
		if seen.has(current):
			break
		seen[current] = true
		current = str(_item_id_aliases.get(current, current)).strip_edges()
		if current == "":
			return iid
	return current


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
