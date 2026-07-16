class_name ZhandouVfxPresetLibrary
extends RefCounted

const _VFX_QUERY := preload("res://scripts/features/battle/application/battle_vfx_query_application.gd")

var _default_preset_id: String = "melee_default"
var _impact_preset_id: String = "hit_default"
var _sequence_cache: Dictionary = {} # preset_id -> Array


static func load_default() -> ZhandouVfxPresetLibrary:
	var lib := ZhandouVfxPresetLibrary.new()
	lib.load_from_index(_VFX_QUERY.index_snapshot())
	return lib


func load_from_index(index: Dictionary) -> void:
	_default_preset_id = str(index.get("default", index.get("defaults", "melee_default"))).strip_edges()
	_impact_preset_id = str(index.get("impact_preset", "hit_default")).strip_edges()
	_sequence_cache.clear()


func get_default_preset_id() -> String:
	return _default_preset_id


func get_impact_preset_id() -> String:
	return _impact_preset_id


func has_preset(preset_id: String) -> bool:
	var id := _VFX_QUERY.normalize_preset_id(preset_id)
	if id == "":
		return false
	if _sequence_cache.has(id):
		return true
	return _VFX_QUERY.has_preset(id)


func get_preset_ids() -> Array:
	return _VFX_QUERY.preset_ids()


func get_sequence(preset_ref: String) -> Array:
	var id := _VFX_QUERY.normalize_preset_id(preset_ref)
	if id == "":
		id = _default_preset_id
	if _sequence_cache.has(id):
		return duplicate_steps(_sequence_cache[id] as Array)
	if not has_preset(id):
		if id != _default_preset_id and has_preset(_default_preset_id):
			push_warning("ZhandouVfxPresetLibrary: 缺少 preset '%s'，回退 '%s'" % [id, _default_preset_id])
			return get_sequence(_default_preset_id)
		push_warning("ZhandouVfxPresetLibrary: 无法加载 preset '%s'" % id)
		return []
	var seq: Variant = _VFX_QUERY.sequence(id)
	if seq is Array:
		var steps := duplicate_steps(seq as Array)
		_sequence_cache[id] = steps
		return steps
	push_warning("ZhandouVfxPresetLibrary: preset '%s' 无 sequence" % id)
	return []


func reload_preset(preset_ref: String) -> void:
	var id := _VFX_QUERY.normalize_preset_id(preset_ref)
	_sequence_cache.erase(id)


func reload_all() -> void:
	_sequence_cache.clear()


static func legacy_preset_for_vfx_type(vfx_type: String) -> String:
	var key := vfx_type.strip_edges().to_lower()
	match key:
		"ranged", "remote", "magic", "spell", "远程", "法术":
			return "ranged_default"
		"heal", "buff", "shield", "other", "治疗", "护盾":
			return "status_cast"
		_:
			return "melee_default"


static func duplicate_steps(steps: Array) -> Array:
	var out: Array = []
	for step_v in steps:
		if step_v is Dictionary:
			out.append((step_v as Dictionary).duplicate(true))
		else:
			out.append(step_v)
	return out
