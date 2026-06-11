extends Node

## 全局配置中心：启动时预处理战斗配置表，并提供缓存读取接口。

var _items: Array = []
var _items_by_id: Dictionary = {}
var _items_by_fight_id: Dictionary = {}
var _item_name_by_id: Dictionary = {}
var _skills_by_id: Dictionary = {}
var _equips_by_id: Dictionary = {}
var _battle_time_limit_default: float = 200.0
var _buff_by_id: Dictionary = {}
var _locations_by_id: Dictionary = {}
var _world_map_meta: Dictionary = {}
var _cities_by_id: Dictionary = {}
var _world_routes: Array = []
var _wilderness_regions_by_id: Dictionary = {}
var _wilderness_locations_by_id: Dictionary = {}
var _common_expedition_events_by_id: Dictionary = {}
var _expedition_events_by_id: Dictionary = {}
var _expedition_rules: Dictionary = {}
const ConfigValidatorScript := preload("res://scripts/core/config_validator.gd")


func _ready() -> void:
	reload_all()
	call_deferred("_validate_expedition_data")


func reload_all() -> void:
	_load_items_local()
	_load_skills_local()
	_load_equips_local()
	_load_buffs_local()
	_load_locations_local()
	_load_world_map_local()
	_load_expedition_events_local()
	_load_expedition_rules_local()
	_validate_all_config()


func _validate_expedition_data() -> void:
	_validate_all_config()


func _validate_all_config() -> void:
	var game_state: Node = null
	if is_inside_tree():
		game_state = get_tree().root.get_node_or_null("GameState")
	for msg in ConfigValidatorScript.collect_all_errors(self, game_state):
		push_error("ConfigValidator: %s" % msg)


func items() -> Array:
	return _items.duplicate()


func item_def_by_id(item_id: String) -> ItemDef:
	var iid := item_id.strip_edges()
	var found: Variant = _items_by_id.get(iid)
	if found is ItemDef:
		return found as ItemDef
	return null


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
	var found: Variant = _items_by_fight_id.get(fight_id)
	if found is ItemDef:
		return found as ItemDef
	return null


func location_by_id(location_id: String) -> Dictionary:
	var lid := location_id.strip_edges()
	var row_v: Variant = _locations_by_id.get(lid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = lid
	return row


func all_locations() -> Array:
	var out: Array = []
	for key in _locations_by_id.keys():
		out.append(location_by_id(str(key)))
	return out


func all_location_ids() -> Array:
	return (_locations_by_id.keys() as Array).duplicate()


func world_map_meta() -> Dictionary:
	return _world_map_meta.duplicate(true)


func city_by_id(city_id: String) -> Dictionary:
	var cid := city_id.strip_edges()
	var row_v: Variant = _cities_by_id.get(cid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = cid
	return row


func all_city_ids() -> Array:
	return (_cities_by_id.keys() as Array).duplicate()


func all_routes() -> Array:
	var out: Array = []
	for route_v in _world_routes:
		if route_v is Dictionary:
			out.append((route_v as Dictionary).duplicate(true))
	return out


func wilderness_region_by_id(region_id: String) -> Dictionary:
	var rid := region_id.strip_edges()
	var row_v: Variant = _wilderness_regions_by_id.get(rid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = rid
	return row


func all_wilderness_region_ids() -> Array:
	return (_wilderness_regions_by_id.keys() as Array).duplicate()


func wilderness_location_by_id(location_id: String) -> Dictionary:
	var lid := location_id.strip_edges()
	var row_v: Variant = _wilderness_locations_by_id.get(lid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = lid
	return row


func all_wilderness_location_ids() -> Array:
	return (_wilderness_locations_by_id.keys() as Array).duplicate()


func expedition_event_by_id(event_id: String) -> Dictionary:
	var eid := event_id.strip_edges()
	var row_v: Variant = _expedition_events_by_id.get(eid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = eid
	for key in ["chain_id", "beat_tags", "requires", "chain_effects", "world_effects"]:
		if not row.has(key):
			row[key] = [] if key in ["beat_tags", "chain_effects", "world_effects"] else ({} if key == "requires" else "")
	return row


func common_expedition_event_by_id(event_id: String) -> Dictionary:
	var eid := event_id.strip_edges()
	var row_v: Variant = _common_expedition_events_by_id.get(eid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = eid
	return row


func all_common_expedition_event_ids() -> Array:
	return (_common_expedition_events_by_id.keys() as Array).duplicate()


func all_expedition_event_ids() -> Array:
	return (_expedition_events_by_id.keys() as Array).duplicate()


func expedition_rules() -> Dictionary:
	return _expedition_rules.duplicate(true)


func all_skill_ids() -> Array:
	return (_skills_by_id.keys() as Array).duplicate()


func all_equip_ids() -> Array:
	return (_equips_by_id.keys() as Array).duplicate()


func all_buff_ids() -> Array:
	return (_buff_by_id.keys() as Array).duplicate()


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


func _load_items_local() -> void:
	_items = JsonLoader.load_items()
	_item_name_by_id.clear()
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


func _load_locations_local() -> void:
	_locations_by_id.clear()
	var root := JsonLoader._read_json_root_object("res://data/locations.json")
	var raw_v: Variant = root.get("locations", {})
	if not raw_v is Dictionary:
		return
	for key in (raw_v as Dictionary).keys():
		var row_v: Variant = (raw_v as Dictionary)[key]
		if row_v is Dictionary:
			_locations_by_id[str(key)] = (row_v as Dictionary).duplicate(true)


func _load_world_map_local() -> void:
	_world_map_meta.clear()
	_cities_by_id.clear()
	_world_routes.clear()
	_wilderness_regions_by_id.clear()
	_wilderness_locations_by_id.clear()
	var root := JsonLoader._read_json_root_object("res://data/world_map.json")
	_world_map_meta = {
		"schema_version": int(root.get("schema_version", 1)),
		"starter_city_id": str(root.get("starter_city_id", "qingshi_market")),
	}
	var cities_v: Variant = root.get("cities", {})
	if cities_v is Dictionary:
		for key in (cities_v as Dictionary).keys():
			var row_v: Variant = (cities_v as Dictionary)[key]
			if row_v is Dictionary:
				_cities_by_id[str(key)] = (row_v as Dictionary).duplicate(true)
	var routes_v: Variant = root.get("routes", [])
	if routes_v is Array:
		for route_v in routes_v as Array:
			if route_v is Dictionary:
				_world_routes.append((route_v as Dictionary).duplicate(true))
	var regions_v: Variant = root.get("wilderness_regions", {})
	if regions_v is Dictionary:
		for key in (regions_v as Dictionary).keys():
			var row_v: Variant = (regions_v as Dictionary)[key]
			if row_v is Dictionary:
				_wilderness_regions_by_id[str(key)] = (row_v as Dictionary).duplicate(true)
	var locations_v: Variant = root.get("wilderness_locations", {})
	if locations_v is Dictionary:
		for key in (locations_v as Dictionary).keys():
			var row_v: Variant = (locations_v as Dictionary)[key]
			if row_v is Dictionary:
				_wilderness_locations_by_id[str(key)] = (row_v as Dictionary).duplicate(true)


func _load_expedition_events_local() -> void:
	_common_expedition_events_by_id.clear()
	_expedition_events_by_id.clear()
	var common_root := JsonLoader._read_json_root_object("res://data/expedition_common_events.json")
	var common_v: Variant = common_root.get("events", {})
	if common_v is Dictionary:
		for key in (common_v as Dictionary).keys():
			var row_v: Variant = (common_v as Dictionary)[key]
			if row_v is Dictionary:
				_common_expedition_events_by_id[str(key)] = (row_v as Dictionary).duplicate(true)
	var root := JsonLoader._read_json_root_object("res://data/expedition_events.json")
	var raw_v: Variant = root.get("map_events", root.get("events", {}))
	if not raw_v is Dictionary:
		return
	for key in (raw_v as Dictionary).keys():
		var row_v: Variant = (raw_v as Dictionary)[key]
		if row_v is Dictionary:
			_expedition_events_by_id[str(key)] = (row_v as Dictionary).duplicate(true)


func _load_expedition_rules_local() -> void:
	_expedition_rules = JsonLoader._read_json_root_object("res://data/expedition_rules.json").duplicate(true)


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
