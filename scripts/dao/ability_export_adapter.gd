class_name AbilityExportAdapter
extends RefCounted

## 将 data/exportjson 表格式技能 JSON 规范化为 AbilityService 内部字典结构。


static func normalize_table_rows(table_key: String, root: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = root.keys()
	keys.sort()
	for key_v in keys:
		var row_v: Variant = root[key_v]
		if not row_v is Dictionary:
			continue
		var row := (row_v as Dictionary).duplicate(true)
		if not row.has("id") or str(row.get("id", "")).strip_edges() == "":
			row["id"] = str(key_v).strip_edges()
		var normalized: Dictionary = {}
		match table_key.strip_edges().to_lower():
			EnumSkill.LABEL_ZHANDOU_ACTIVE:
				normalized = _normalize_zhandou_active_row(row)
			EnumSkill.LABEL_PASSIVE:
				normalized = _normalize_zhandou_passive_row(row)
			_:
				push_warning("AbilityExportAdapter: unknown table %s" % table_key)
				continue
		if not normalized.is_empty():
			out.append(normalized)
	return out


static func is_export_root(table: Dictionary) -> bool:
	if table.is_empty():
		return false
	if table.has("abilities") and table.get("abilities") is Array:
		return false
	return true


static func _normalize_zhandou_active_row(raw: Dictionary) -> Dictionary:
	var ability_id := str(raw.get("id", "")).strip_edges()
	if ability_id == "":
		return {}
	var ability_type := str(raw.get("type", "combat_active")).strip_edges()
	if ability_type == "":
		ability_type = "combat_active"
	var tier := int(raw.get("tier", EnumItemTier.Type.lianqi))
	if not raw.has("tier") and raw.has("req_realm"):
		tier = EnumItemTier.tier_for_realm_id(str(raw.get("req_realm", "")))
	var costs: Array = []
	var cost_resource := str(raw.get("cost_resource", "")).strip_edges().to_lower()
	var cost_value := float(raw.get("cost_value", 0.0))
	if cost_resource != "" and cost_value > 0.0:
		costs.append({"resource": cost_resource, "value": cost_value})
	var target_arg := ""
	if raw.has("targetarg"):
		target_arg = str(raw.get("targetarg", "")).strip_edges()
	elif raw.has("target_arg"):
		target_arg = str(raw.get("target_arg", "")).strip_edges()
	if ZhandouEffectCodec.is_null_sentinel(target_arg):
		target_arg = ""
	var combat := {
		"target": str(raw.get("target", EnumZhandouTarget.LABEL_ENEMY)).strip_edges().to_lower(),
		"castTime": float(raw.get("cast_time", raw.get("castTime", 0.8))),
		"cooldown": float(raw.get("cooldown", 0.0)),
		"costs": costs,
		"upkeepCostsPerSecond": [],
		"activation": str(raw.get("activation", "cast")).strip_edges(),
	}
	if target_arg != "":
		combat["targetArg"] = target_arg
	var effects: Array = ZhandouEffectCodec.parse_positional_config_effects(raw.get("effects", []))
	var vfx_preset: Variant = raw.get("vfx_preset", raw.get("vfxPreset", null))
	var out := {
		"id": ability_id,
		"name": str(raw.get("name", ability_id)),
		"type": ability_type,
		"tier": EnumItemTier.clamp_tier(tier),
		"quality": clampi(int(raw.get("quality", 1)), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME),
		"description": str(raw.get("description", raw.get("desc", ""))),
		"tags": ZhandouEffectCodec.split_csv_tags(raw.get("tags", [])),
		"combat": combat,
		"effects": effects,
		"learningRequirements": {"knowledge": []},
		"trigger": {},
		"upgrade_options": [],
		"evolution_conditions": [],
	}
	var icon_v: Variant = raw.get("icon", null)
	if icon_v != null and str(icon_v).strip_edges() != "":
		out["icon"] = str(icon_v).strip_edges()
	if vfx_preset != null and not ZhandouEffectCodec.is_null_sentinel(vfx_preset):
		out["vfx_preset"] = str(vfx_preset).strip_edges()
	return out


static func _normalize_zhandou_passive_row(raw: Dictionary) -> Dictionary:
	var ability_id := str(raw.get("id", "")).strip_edges()
	if ability_id == "":
		return {}
	var tier := int(raw.get("tier", EnumItemTier.Type.lianqi))
	var effects := ZhandouEffectCodec.parse_positional_config_effects(raw.get("effects", []))
	# heal_hp 在战斗被动校验中映射为 hp_regen
	for i in effects.size():
		var effect_v: Variant = effects[i]
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		if str(effect.get("effectId", "")) == "heal_hp":
			effect["effectId"] = EnumZhandouPassiveEffect.LABEL_HP_REGEN
	var tags: Array = []
	if raw.get("tag") is Array:
		tags = ZhandouEffectCodec.split_csv_tags(raw.get("tag"))
	elif raw.has("tags"):
		tags = ZhandouEffectCodec.split_csv_tags(raw.get("tags"))
	var cooldown_v: Variant = raw.get("cd", 0.0)
	var out := {
		"id": ability_id,
		"name": str(raw.get("name", ability_id)),
		"type": "combat_passive",
		"sourceType": int(raw.get("type", 0)),
		"tier": EnumItemTier.clamp_tier(tier),
		"quality": clampi(int(raw.get("quality", 1)), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME),
		"description": str(raw.get("desc", raw.get("description", ""))),
		"tags": tags,
		"combat": {
			"target": EnumZhandouTarget.LABEL_SELF,
			"castTime": 0.0,
			"cooldown": float(cooldown_v) if cooldown_v != null else 0.0,
			"costs": [],
			"upkeepCostsPerSecond": [],
			"activation": "learned",
		},
		"effects": effects,
		"learningRequirements": {"knowledge": []},
		"trigger": _trigger_from_runtype(str(raw.get("runtype", ""))),
		"upgrade_options": [],
		"evolution_conditions": [],
	}
	var icon_v: Variant = raw.get("icon", null)
	if icon_v != null and str(icon_v).strip_edges() != "":
		out["icon"] = str(icon_v).strip_edges()
	return out


static func _trigger_from_runtype(runtype: String) -> Dictionary:
	var key := runtype.strip_edges().to_lower()
	if key == "":
		return {}
	return {"runtype": key}
