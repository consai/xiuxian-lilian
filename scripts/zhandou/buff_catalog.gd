class_name BuffCatalog
extends RefCounted

const PATH := "res://data/exportjson/buff.json"


static func load_all() -> Array:
	var root := JsonReader.read_object(PATH)
	var out: Array = []
	if root.is_empty():
		return out
	var raw: Variant = root.get("buffs", root)
	if not raw is Dictionary:
		push_error("BuffCatalog: config root must be an object keyed by buff id")
		return out
	var rows := raw as Dictionary
	for key_v in rows.keys():
		var buff_id := str(key_v).strip_edges()
		if buff_id == "":
			push_error("BuffCatalog: config key must be non-empty string")
			continue
		var row_v: Variant = rows[key_v]
		if not row_v is Dictionary:
			push_error("BuffCatalog: buff '%s' entry must be an object" % buff_id)
			continue
		var row := _normalize_export_row(buff_id, row_v as Dictionary)
		_validate_effects_schema(
			row.get("tick_effects", []),
			"buff config buffs['%s'].tick_effects" % buff_id,
			false
		)
		var buff := BuffDef.from_dict(row)
		if buff != null:
			out.append(buff)
	return out


static func _normalize_export_row(buff_id: String, raw: Dictionary) -> Dictionary:
	var row := raw.duplicate(true)
	row["id"] = buff_id
	if row.has("type") and not row.has("tags"):
		row["tags"] = ZhandouEffectCodec.split_csv_tags(row.get("type", ""))
	var ticktime := float(row.get("ticktime", 1.0))
	if ticktime < 0.0:
		row["ticktime"] = 0.0
	var modifiers_v: Variant = row.get("modifiers", {})
	if modifiers_v is Array:
		row["modifiers"] = ZhandouEffectCodec.normalize_buff_modifiers(modifiers_v)
	var tick_effects_v: Variant = row.get("tick_effects", [])
	if tick_effects_v is Array:
		row["tick_effects"] = ZhandouEffectCodec.normalize_buff_tick_effects(tick_effects_v)
	return row


static func _validate_effects_schema(raw: Variant, path_label: String, allow_target: bool) -> void:
	if raw == null:
		return
	if not raw is Array:
		push_error("BuffCatalog: %s must be Array" % path_label)
		return
	for i in (raw as Array).size():
		var item_v: Variant = (raw as Array)[i]
		if item_v is Array:
			var cells := item_v as Array
			if cells.is_empty():
				push_error("BuffCatalog: %s[%d] positional effect is empty" % [path_label, i])
				continue
			var effect_id := str(cells[0]).strip_edges().to_lower()
			if not ZhandouEffectCodec.is_schema_effect_id(effect_id):
				push_error("BuffCatalog: %s[%d] effect '%s' is unsupported" % [path_label, i, effect_id])
			continue
		if not item_v is Dictionary:
			push_error("BuffCatalog: %s[%d] must be object or positional array" % [path_label, i])
			continue
		var item := item_v as Dictionary
		if item.has("type"):
			var effect_type := str(item.get("type", "")).strip_edges().to_lower()
			if effect_type == "":
				push_error("BuffCatalog: %s[%d].type is required" % [path_label, i])
				continue
			if not EnumCombatEffectType.is_valid_label(effect_type):
				push_error("BuffCatalog: %s[%d].type '%s' is unsupported" % [path_label, i, effect_type])
			if allow_target and item.has("target"):
				var target := str(item.get("target", "")).strip_edges().to_lower()
				if target != "" and not EnumZhandouTarget.is_valid_label(target):
					push_error("BuffCatalog: %s[%d].target '%s' is unsupported" % [path_label, i, target])
				if item.has("target_arg") or item.has("targetArg"):
					var target_arg := str(item.get("target_arg", item.get("targetArg", ""))).strip_edges().to_lower()
					if target_arg != "" and not EnumZhandouTargetArg.is_valid_label(target_arg):
						push_error("BuffCatalog: %s[%d].target_arg '%s' is unsupported" % [path_label, i, target_arg])
			if EnumCombatEffectType.requires_value(effect_type) and not item.has("value"):
				push_error("BuffCatalog: %s[%d].value is required for type '%s'" % [path_label, i, effect_type])
			continue
		var effect_type := str(item.get("type", "")).strip_edges().to_lower()
		if effect_type == "":
			push_error("BuffCatalog: %s[%d].type is required" % [path_label, i])
			continue
		if not EnumCombatEffectType.is_valid_label(effect_type):
			push_error("BuffCatalog: %s[%d].type '%s' is unsupported" % [path_label, i, effect_type])
		if allow_target and item.has("target"):
			var target := str(item.get("target", "")).strip_edges().to_lower()
			if target != "" and not EnumZhandouTarget.is_valid_label(target):
				push_error("BuffCatalog: %s[%d].target '%s' is unsupported" % [path_label, i, target])
			if item.has("target_arg") or item.has("targetArg"):
				var target_arg := str(item.get("target_arg", item.get("targetArg", ""))).strip_edges().to_lower()
				if target_arg != "" and not EnumZhandouTargetArg.is_valid_label(target_arg):
					push_error("BuffCatalog: %s[%d].target_arg '%s' is unsupported" % [path_label, i, target_arg])
		if EnumCombatEffectType.requires_value(effect_type) and not item.has("value"):
			push_error("BuffCatalog: %s[%d].value is required for type '%s'" % [path_label, i, effect_type])
