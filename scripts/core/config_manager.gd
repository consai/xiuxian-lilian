extends Node

## 全局配置中心：启动时预处理战斗配置表，并提供缓存读取接口。

var _items: Array = []
var _item_name_by_id: Dictionary = {}
var _skills_by_id: Dictionary = {}
var _equips_by_id: Dictionary = {}
var _battle_time_limit_default: float = 200.0
var _buff_by_id: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_items = JsonLoader.load_items()
	_item_name_by_id.clear()
	for it in _items:
		if it == null:
			continue
		var iid := JsonLoader.config_id_to_string(str(it.id))
		if iid == "":
			continue
		var nm := str(it.name).strip_edges()
		if nm == "":
			nm = iid
		_item_name_by_id[iid] = nm
	_load_skills_local()
	_load_equips_local()
	_load_buffs_local()


func items() -> Array:
	return _items.duplicate()


func skill_by_id(skill_id: int) -> Dictionary:
	var v: Variant = _skills_by_id.get(skill_id, _skills_by_id.get(str(skill_id), null))
	if v is SkillDef:
		return (v as SkillDef).to_runtime_dict()
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return {}


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
	for it in _items:
		if it is ItemDef and (it as ItemDef).fight_id == fight_id:
			return it
	return null


func basic_attack_cfg() -> Dictionary:
	return skill_by_id(0)


func battle_time_limit_default() -> float:
	return _battle_time_limit_default


func buff_by_id(buff_id: String) -> Dictionary:
	var bid := buff_id.strip_edges()
	if bid == "":
		return {}
	var v: Variant = _buff_by_id.get(bid, null)
	if v is BuffDef:
		return (v as BuffDef).to_dict()
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	return {}


func build_skill_cfg(extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for sid in _skills_by_id.keys():
		var row: Dictionary = skill_by_id(int(sid) if str(sid).is_valid_int() else sid)
		if row.is_empty():
			continue
		var id_val := int(row.get("id", sid))
		out[id_val] = row
		out[str(id_val)] = row
	if extra.is_empty():
		return out
	for k in extra.keys():
		var key_str := str(k)
		if key_str == "basic_attack":
			var ba_v: Variant = extra[k]
			if ba_v is Dictionary:
				var merged := out.get(0, out.get("0", {})) as Dictionary
				if not merged is Dictionary:
					merged = {}
				for bk in (ba_v as Dictionary).keys():
					merged[bk] = (ba_v as Dictionary)[bk]
				out[0] = merged
				out["0"] = merged
			continue
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
	return str(_item_name_by_id.get(iid, iid))


func _load_skills_local() -> void:
	_skills_by_id.clear()
	_battle_time_limit_default = 200.0
	var bundle: Dictionary = JsonLoader.load_skills_bundle()
	_battle_time_limit_default = maxf(1.0, float(bundle.get("battle_time_limit", 200.0)))
	var skills_v: Variant = bundle.get("skills", [])
	if not skills_v is Array:
		return
	for sv in skills_v as Array:
		if sv is SkillDef:
			_skills_by_id[(sv as SkillDef).id] = sv
		elif sv is Dictionary:
			var skill = SkillDef.from_dict(sv as Dictionary)
			if skill != null:
				_skills_by_id[skill.id] = skill


func _load_equips_local() -> void:
	_equips_by_id.clear()
	var bundle: Dictionary = JsonLoader.load_equips_bundle()
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


func _load_buffs_local() -> void:
	_buff_by_id.clear()
	for bv in JsonLoader.load_buffs():
		if bv is BuffDef:
			_buff_by_id[(bv as BuffDef).id] = bv
		elif bv is Dictionary:
			var bid := JsonLoader.config_id_to_string((bv as Dictionary).get("id", ""))
			if bid != "":
				_buff_by_id[bid] = (bv as Dictionary).duplicate(true)
