class_name ZhandouVfxSequenceResolver
extends RefCounted

const _VFX_QUERY := preload("res://scripts/features/battle/application/battle_vfx_query_application.gd")


## 从技能配置 / 事件载荷解析 vfx 绑定（支持文件名、preset 对象、内联 sequence）。
static func normalize_vfx_binding(vfx_v: Variant) -> Dictionary:
	if vfx_v is String:
		var id := _VFX_QUERY.normalize_preset_id(str(vfx_v))
		if id != "":
			return {"preset": id}
		return {}
	if not vfx_v is Dictionary:
		return {}
	var d := (vfx_v as Dictionary).duplicate(true)
	if d.has("file"):
		d["preset"] = _VFX_QUERY.normalize_preset_id(str(d["file"]))
		d.erase("file")
	elif d.has("preset"):
		d["preset"] = _VFX_QUERY.normalize_preset_id(str(d["preset"]))
	return d


static func vfx_binding_from_skill_cfg(cfg: Dictionary) -> Dictionary:
	if cfg.is_empty():
		return {}
	if cfg.has("vfx"):
		return normalize_vfx_binding(cfg["vfx"])
	for alias_key in ["vfx_file", "vfx_preset"]:
		if cfg.has(alias_key):
			var id := _VFX_QUERY.normalize_preset_id(str(cfg[alias_key]))
			if id != "":
				return {"preset": id}
	return {}


static func resolve(event: ZhandouVfxEvent, library: ZhandouVfxPresetLibrary) -> Array:
	if library == null:
		return []
	var vfx := {}
	if event != null and event.extra is Dictionary:
		var ex: Variant = event.extra.get("vfx", {})
		vfx = normalize_vfx_binding(ex)
	if vfx.has("sequence"):
		var seq: Variant = vfx["sequence"]
		if seq is Array:
			return ZhandouVfxPresetLibrary.duplicate_steps(seq as Array)
	var preset_id := str(vfx.get("preset", "")).strip_edges()
	if preset_id != "":
		return library.get_sequence(preset_id)
	if event != null:
		return library.get_sequence(
			ZhandouVfxPresetLibrary.legacy_preset_for_vfx_type(
				_skill_type_to_vfx_type(event.skill_type)
			)
		)
	return library.get_sequence(library.get_default_preset_id())


static func resolve_vfx_cfg(cfg: Dictionary, library: ZhandouVfxPresetLibrary) -> Array:
	if library == null:
		return []
	var vfx := vfx_binding_from_skill_cfg(cfg)
	if vfx.has("sequence"):
		var seq: Variant = vfx["sequence"]
		if seq is Array:
			return ZhandouVfxPresetLibrary.duplicate_steps(seq as Array)
	var preset_id := str(vfx.get("preset", "")).strip_edges()
	if preset_id != "":
		return library.get_sequence(preset_id)
	var vfx_type := str(cfg.get("vfx_type", "")).strip_edges().to_lower()
	if vfx_type == "":
		var tags: Variant = cfg.get("tags", [])
		if tags is Array:
			for tag_v in tags as Array:
				var tag := str(tag_v).strip_edges().to_lower()
				if tag in ["magic", "spell", "ranged", "remote", "远程", "法术"]:
					vfx_type = "ranged"
					break
	if vfx_type == "":
		vfx_type = "melee"
	return library.get_sequence(ZhandouVfxPresetLibrary.legacy_preset_for_vfx_type(vfx_type))


static func overrides_from_event(event: ZhandouVfxEvent) -> Dictionary:
	if event == null or not event.extra is Dictionary:
		return {}
	var vfx := normalize_vfx_binding(event.extra.get("vfx", {}))
	var ov: Variant = vfx.get("overrides", {})
	if ov is Dictionary:
		return (ov as Dictionary).duplicate(true)
	return {}


static func overrides_from_cfg(cfg: Dictionary) -> Dictionary:
	var vfx := vfx_binding_from_skill_cfg(cfg)
	var ov: Variant = vfx.get("overrides", {})
	if ov is Dictionary:
		return (ov as Dictionary).duplicate(true)
	return {}


static func _skill_type_to_vfx_type(skill_type: EnumBattleVfxSkillType.Type) -> String:
	match skill_type:
		EnumBattleVfxSkillType.Type.RANGED:
			return "ranged"
		EnumBattleVfxSkillType.Type.HEAL, \
		EnumBattleVfxSkillType.Type.BUFF, \
		EnumBattleVfxSkillType.Type.OTHER:
			return "other"
		_:
			return "melee"
