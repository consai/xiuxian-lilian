extends Node

## 全局配置中心：启动时预处理战斗配置表，并提供缓存读取接口。

var _items: Array = []
var _items_by_id: Dictionary = {}
var _items_by_fight_id: Dictionary = {}
var _item_name_by_id: Dictionary = {}
var _item_id_aliases: Dictionary = {}
var _skills_by_id: Dictionary = {}
var _equips_by_id: Dictionary = {}
var _battle_time_limit_default: float = 200.0
var _buff_by_id: Dictionary = {}
var _monsters_by_id: Dictionary = {}
var _locations_by_id: Dictionary = {}
var _world_map_meta: Dictionary = {}
var _cities_by_id: Dictionary = {}
var _world_routes: Array = []
var _wilderness_regions_by_id: Dictionary = {}
var _wilderness_locations_by_id: Dictionary = {}
var _lilian_common_events_by_id: Dictionary = {}
var _lilian_events_by_id: Dictionary = {}
var _lilian_rules: Dictionary = {}
const ConfigValidatorScript := preload("res://scripts/core/config_validator.gd")


func _ready() -> void:
	reload_all()
	call_deferred("_validate_lilian_data")


func reload_all() -> void:
	const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
	const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
	const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
	const KnowledgeEffectServiceScript := preload("res://scripts/dao/knowledge_effect_service.gd")
	DaoTreeServiceScript.reload()
	XiulianMethodServiceScript.reload()
	AbilityServiceScript.reload()
	KnowledgeEffectServiceScript.reload()
	_load_items_local()
	_load_skills_local()
	_load_equips_local()
	_load_buffs_local()
	_load_monsters_local()
	_load_locations_local()
	_load_world_map_local()
	_load_lilian_events_local()
	_load_lilian_rules_local()
	_validate_all_config()


func _validate_lilian_data() -> void:
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
	var canonical_id := _resolve_item_id_alias(iid)
	var found: Variant = _items_by_id.get(canonical_id)
	if found is ItemDef:
		return found as ItemDef
	return null


func skill_by_id(skill_id: int) -> Dictionary:
	const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
	var game_state: Node = null
	if is_inside_tree():
		game_state = get_tree().root.get_node_or_null("GameState")
	var savedata: Dictionary = {}
	if game_state != null and game_state.has_method("to_dict"):
		savedata = game_state.to_dict()
	var aid := AbilityServiceScript.ability_id_for_combat_id(int(skill_id))
	if aid != "":
		var runtime := AbilityServiceScript.to_runtime_dict(aid, savedata)
		if not runtime.is_empty():
			return runtime
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


func lilian_event_by_id(event_id: String) -> Dictionary:
	var eid := event_id.strip_edges()
	var row_v: Variant = _lilian_events_by_id.get(eid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = eid
	return row


func lilian_common_event_by_id(event_id: String) -> Dictionary:
	var eid := event_id.strip_edges()
	var row_v: Variant = _lilian_common_events_by_id.get(eid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = eid
	return row


func location_drop_pool(location_id: String, pool_id: String) -> Dictionary:
	var normalized_pool_id := pool_id.strip_edges()
	if normalized_pool_id.begins_with("monster:"):
		var monster_ref := normalized_pool_id.substr("monster:".length()).strip_edges()
		var monster := location_enemy_pool(location_id, monster_ref)
		return _monster_drop_pool(monster)
	var location := location_by_id(location_id)
	var pools_v: Variant = location.get("drop_pools", {})
	if not pools_v is Dictionary:
		return {}
	var pool_v: Variant = (pools_v as Dictionary).get(normalized_pool_id, {})
	if pool_v is Dictionary:
		return (pool_v as Dictionary).duplicate(true)
	return {}


func location_enemy_pool(location_id: String, pool_id: String) -> Dictionary:
	return _monster_for_location_ref(location_id, pool_id)


func location_monsters(location_id: String) -> Array:
	var location := location_by_id(location_id)
	var out: Array = []
	for id_v in location.get("monsters", []) as Array:
		var monster := monster_by_id(str(id_v))
		if not monster.is_empty():
			out.append(monster)
	return out


func monster_by_id(monster_id: String) -> Dictionary:
	var mid := monster_id.strip_edges()
	var row_v: Variant = _monsters_by_id.get(mid)
	if not row_v is Dictionary:
		return {}
	var row := (row_v as Dictionary).duplicate(true)
	row["id"] = mid
	return row


func all_monster_ids() -> Array:
	return (_monsters_by_id.keys() as Array).duplicate()


func location_materials(location_id: String) -> Array:
	var location := location_by_id(location_id)
	var out: Array = []
	for row_v in location.get("materials", []) as Array:
		if row_v is Dictionary:
			out.append((row_v as Dictionary).duplicate(true))
	return out


func _monster_for_location_ref(location_id: String, monster_ref: String) -> Dictionary:
	var ref := monster_ref.strip_edges()
	if ref == "":
		return {}
	var location := location_by_id(location_id)
	var monster_ids := location.get("monsters", []) as Array
	if monster_ids.has(ref):
		return monster_by_id(ref)
	var direct := monster_by_id(ref)
	if not direct.is_empty() and monster_ids.has(str(direct.get("id", ref))):
		return direct
	for id_v in monster_ids:
		var monster := monster_by_id(str(id_v))
		if monster.is_empty():
			continue
		if str(monster.get("species", "")).strip_edges() == ref:
			return monster
		for tag_v in monster.get("tags", []) as Array:
			if str(tag_v).strip_edges() == ref:
				return monster
	return {}


func monster_drop_entries(monster: Dictionary) -> Array:
	return _monster_drop_entries(monster)


func _monster_drop_pool(monster: Dictionary) -> Dictionary:
	if monster.is_empty():
		return {}
	var entries: Array = _monster_drop_entries(monster)
	if not entries.is_empty():
		return {"entries": entries}
	return {}


## 怪物表 dropitem 为 [kind, id, min, max, weight] 行数组。
func _monster_drop_entries(monster: Dictionary) -> Array:
	var dropitem_v: Variant = monster.get("dropitem", [])
	if dropitem_v is Array:
		var out: Array = []
		for row_v in dropitem_v as Array:
			if not row_v is Array:
				continue
			var cells: Array = row_v as Array
			if cells.size() < 5:
				continue
			var reward_id: Variant = cells[1]
			if str(cells[0]).strip_edges() == "equip" and str(reward_id).is_valid_int():
				reward_id = int(reward_id)
			out.append({
				"kind": str(cells[0]).strip_edges(),
				"id": reward_id,
				"min": int(cells[2]),
				"max": int(cells[3]),
				"weight": int(cells[4]),
			})
		if not out.is_empty():
			return out
	return []


## exportjson guaiwu 扁平字段 → 运行时怪物字典（species/attrs/icon）。
func _normalize_monster_row(monster_id: String, row: Dictionary) -> Dictionary:
	var out: Dictionary = row.duplicate(true)
	if str(out.get("id", "")).strip_edges() == "":
		out["id"] = monster_id
	if str(out.get("species", "")).strip_edges() == "":
		out["species"] = str(out.get("type", "")).strip_edges()
	if str(out.get("icon", "")).strip_edges() == "":
		var icon_path: String = str(out.get("headicon", out.get("obj", ""))).strip_edges()
		if icon_path != "":
			out["icon"] = icon_path
	var attrs: Dictionary = (out.get("attrs", {}) as Dictionary).duplicate(true)
	for attr_key in [
		ZhandouAttr.HP_MAX, ZhandouAttr.MP_MAX, ZhandouAttr.SHIELD,
		ZhandouAttr.PHYSICAL_ATK, ZhandouAttr.MAGIC_ATK,
		ZhandouAttr.PHYSICAL_DEF, ZhandouAttr.MAGIC_DEF, ZhandouAttr.SPD,
		ZhandouAttr.CONTROL_POWER, ZhandouAttr.CONTROL_RESIST,
	]:
		if out.has(attr_key) and not attrs.has(attr_key):
			attrs[attr_key] = out[attr_key]
	if not attrs.is_empty():
		out["attrs"] = CharacterStats.finalize_combat_attrs(attrs)
	out["skills"] = _normalize_monster_skills(out.get("skills", []))
	return out


## exportjson guaiwu：skills 为技能 id 数组；未配置调息 0 时自动补上。
func _normalize_monster_skills(skills_v: Variant) -> Array:
	if not skills_v is Array or (skills_v as Array).is_empty():
		return [0]
	var out: Array = []
	var has_tiaoxi: bool = false
	for sid_v in skills_v as Array:
		if sid_v is Dictionary:
			var slot: Dictionary = (sid_v as Dictionary).duplicate(true)
			var sid: int = int(slot.get("id", -1))
			if sid == 0:
				has_tiaoxi = true
			out.append(slot)
		else:
			var sid: int = int(sid_v)
			if sid == 0:
				has_tiaoxi = true
			out.append(sid)
	if not has_tiaoxi:
		out.append(0)
	return out


func all_lilian_common_event_ids() -> Array:
	return (_lilian_common_events_by_id.keys() as Array).duplicate()


func all_lilian_event_ids() -> Array:
	return (_lilian_events_by_id.keys() as Array).duplicate()


func lilian_rules() -> Dictionary:
	return _lilian_rules.duplicate(true)


func all_skill_ids() -> Array:
	return (_skills_by_id.keys() as Array).duplicate()


func all_equip_ids() -> Array:
	return (_equips_by_id.keys() as Array).duplicate()


func all_buff_ids() -> Array:
	return (_buff_by_id.keys() as Array).duplicate()


func tiaoxi_cfg() -> Dictionary:
	return skill_by_id(0)


func basic_attack_cfg() -> Dictionary:
	return tiaoxi_cfg()


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
		if key_str == "basic_attack" or key_str == "tiaoxi_cfg":
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
	var canonical_id := _resolve_item_id_alias(iid)
	return str(_item_name_by_id.get(canonical_id, canonical_id))


func _load_items_local() -> void:
	_items = JsonLoader.load_items()
	_item_name_by_id.clear()
	_item_id_aliases = JsonLoader.load_item_aliases()
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


func _load_locations_local() -> void:
	_locations_by_id.clear()
	var root := JsonLoader.load_locations_bundle()
	var raw_v: Variant = root.get("locations", {})
	if not raw_v is Dictionary:
		return
	for key in (raw_v as Dictionary).keys():
		var row_v: Variant = (raw_v as Dictionary)[key]
		if row_v is Dictionary:
				_locations_by_id[str(key)] = (row_v as Dictionary).duplicate(true)


func _load_monsters_local() -> void:
	_monsters_by_id.clear()
	var root := JsonLoader._read_json_root_object(JsonLoader.export_path("exportjson_guaiwu.json"))
	if not root is Dictionary:
		return
	for key in (root as Dictionary).keys():
		var row_v: Variant = (root as Dictionary)[key]
		if row_v is Dictionary:
			_monsters_by_id[str(key)] = _normalize_monster_row(str(key), row_v as Dictionary)


func _load_world_map_local() -> void:
	_world_map_meta.clear()
	_cities_by_id.clear()
	_world_routes.clear()
	_wilderness_regions_by_id.clear()
	_wilderness_locations_by_id.clear()
	var root := JsonLoader.load_world_map_bundle()
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


func _load_lilian_events_local() -> void:
	_lilian_common_events_by_id.clear()
	_lilian_events_by_id.clear()
	var common_root := JsonLoader.load_lilian_common_events_bundle()
	var common_v: Variant = common_root.get("events", {})
	if common_v is Dictionary:
		for key in (common_v as Dictionary).keys():
			var row_v: Variant = (common_v as Dictionary)[key]
			if row_v is Dictionary:
				_lilian_common_events_by_id[str(key)] = (row_v as Dictionary).duplicate(true)
	var root := JsonLoader.load_lilian_events_bundle()
	var raw_v: Variant = root.get("events", {})
	if not raw_v is Dictionary:
		return
	for key in (raw_v as Dictionary).keys():
		var row_v: Variant = (raw_v as Dictionary)[key]
		if row_v is Dictionary:
			_lilian_events_by_id[str(key)] = (row_v as Dictionary).duplicate(true)


func _load_lilian_rules_local() -> void:
	_lilian_rules = JsonLoader.load_lilian_rules_bundle().duplicate(true)


func _load_skills_local() -> void:
	_skills_by_id.clear()
	_battle_time_limit_default = 200.0
	const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
	AbilityServiceScript.reload()
	var bundle: Dictionary = AbilityServiceScript.build_skill_cfg({})
	_battle_time_limit_default = maxf(1.0, float(bundle.get("battle_time_limit", 200.0)))
	var skills_v: Variant = bundle.get("skills", {})
	if not skills_v is Dictionary:
		return
	for key in (skills_v as Dictionary).keys():
		var row_v: Variant = (skills_v as Dictionary)[key]
		if not row_v is Dictionary:
			continue
		var row := (row_v as Dictionary).duplicate(true)
		row["id"] = int(key)
		var skill = SkillDef.from_dict(row)
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
