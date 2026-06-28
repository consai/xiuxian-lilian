class_name JsonLoader
extends RefCounted

const ITEMS_PATH := "res://data/item.yaml"
const DAO_TREE_PATH := "res://data/dao_tree.yaml"
const XIULIAN_METHODS_PATH := "res://data/xiulian_methods.yaml"
const KNOWLEDGE_EFFECTS_PATH := "res://data/knowledge_effects.yaml"
const ABILITIES_PATH := "res://data/abilities.yaml"
const EFFECT_CATALOG_PATH := "res://data/effect_catalog.yaml"
const EQUIPS_PATH := "res://data/equip.yaml"
const BUFFS_PATH := "res://data/buff.yaml"
const ZHANDOU_VFX_INDEX_PATH := "res://data/zhandou/vfx_index.yaml"
const ZHANDOU_FLOAT_STYLES_PATH := "res://data/zhandou/float_styles.yaml"
const ZHANDOU_VFX_PRESETS_DIR := "res://data/zhandou/presets"
const ItemDefScript = preload("res://scripts/core/item_def.gd")
const EquipDefScript = preload("res://scripts/zhandou/equip_def.gd")
const BuffDefScript = preload("res://scripts/zhandou/buff_def.gd")

## 配置文件中的文档用元数据键（加载后剔除）。
const JSON_COMMENT_KEYS: Array[String] = ["_comment", "_说明", "_doc", "_备注"]

## 配置表 id 统一为 String（空串表示无效/缺省）。
static func config_id_to_string(v: Variant) -> String:
	return str(v).strip_edges()


static func _read_json_root_object(path: String) -> Dictionary:
	var v: Variant = _read_config_variant(path)
	if v == null:
		return {}
	if v is Dictionary:
		return v as Dictionary
	push_error("JsonLoader: root must be a JSON object: %s" % path)
	return {}


static func _read_json_variant(path: String) -> Variant:
	return _read_config_variant(path)


static func _read_config_variant(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JsonLoader: file not found: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if path.ends_with(".yaml") or path.ends_with(".yml"):
		return _parse_yaml(text, path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("JsonLoader: invalid JSON: %s" % path)
		return null
	return parsed


static func _parse_yaml(text: String, path: String = "") -> Variant:
	var trimmed := text.strip_edges()
	if trimmed.begins_with("{") or trimmed.begins_with("["):
		var json_fallback: Variant = JSON.parse_string(text)
		if json_fallback != null:
			return json_fallback
	var lines := _yaml_significant_lines(text)
	if lines.is_empty():
		return {}
	var cursor := {"i": 0}
	var parsed: Variant = _parse_yaml_block(lines, cursor, int(lines[0].get("indent", 0)))
	if parsed == null:
		push_error("JsonLoader: invalid YAML: %s" % path)
	return parsed


static func _yaml_significant_lines(text: String) -> Array:
	var out: Array = []
	for raw_line in text.split("\n"):
		var line := str(raw_line).trim_suffix("\r")
		if line.strip_edges() == "" or line.strip_edges().begins_with("#"):
			continue
		var content := line.substr(_yaml_indent(line))
		out.append({"indent": _yaml_indent(line), "text": content})
	return out


static func _yaml_indent(line: String) -> int:
	var indent := 0
	while indent < line.length() and line[indent] == " ":
		indent += 1
	return indent


static func _parse_yaml_block(lines: Array, cursor: Dictionary, indent: int) -> Variant:
	if int(cursor.get("i", 0)) >= lines.size():
		return {}
	var line := lines[int(cursor["i"])] as Dictionary
	var text := str(line.get("text", ""))
	if text.begins_with("-"):
		return _parse_yaml_array(lines, cursor, indent)
	return _parse_yaml_dict(lines, cursor, indent)


static func _parse_yaml_array(lines: Array, cursor: Dictionary, indent: int) -> Array:
	var out: Array = []
	while int(cursor.get("i", 0)) < lines.size():
		var line := lines[int(cursor["i"])] as Dictionary
		var line_indent := int(line.get("indent", 0))
		if line_indent < indent:
			break
		if line_indent != indent:
			break
		var text := str(line.get("text", ""))
		if not text.begins_with("-"):
			break
		var rest := text.substr(1).strip_edges()
		cursor["i"] = int(cursor["i"]) + 1
		if rest == "":
			out.append(_parse_yaml_block(lines, cursor, _yaml_next_indent(lines, cursor, indent)))
			continue
		var split := _yaml_split_key_value(rest)
		if split.size() == 2:
			var row := {}
			_yaml_assign_pair(row, str(split[0]), str(split[1]), lines, cursor, indent)
			if int(cursor.get("i", 0)) < lines.size():
				var next_line := lines[int(cursor["i"])] as Dictionary
				if int(next_line.get("indent", 0)) > indent and not str(next_line.get("text", "")).begins_with("-"):
					var extra: Variant = _parse_yaml_dict(lines, cursor, int(next_line.get("indent", 0)))
					if extra is Dictionary:
						for key in (extra as Dictionary).keys():
							row[key] = (extra as Dictionary)[key]
			out.append(row)
		else:
			out.append(_yaml_parse_scalar(rest))
	return out


static func _parse_yaml_dict(lines: Array, cursor: Dictionary, indent: int) -> Dictionary:
	var out := {}
	while int(cursor.get("i", 0)) < lines.size():
		var line := lines[int(cursor["i"])] as Dictionary
		var line_indent := int(line.get("indent", 0))
		if line_indent < indent:
			break
		if line_indent != indent:
			break
		var text := str(line.get("text", ""))
		if text.begins_with("-"):
			break
		var split := _yaml_split_key_value(text)
		if split.size() != 2:
			cursor["i"] = int(cursor["i"]) + 1
			continue
		cursor["i"] = int(cursor["i"]) + 1
		_yaml_assign_pair(out, str(split[0]), str(split[1]), lines, cursor, indent)
	return out


static func _yaml_assign_pair(out: Dictionary, raw_key: String, raw_value: String, lines: Array, cursor: Dictionary, indent: int) -> void:
	var key_v: Variant = _yaml_parse_scalar(raw_key.strip_edges())
	var key := str(key_v)
	var value := raw_value.strip_edges()
	if value == "":
		if int(cursor.get("i", 0)) < lines.size():
			out[key] = _parse_yaml_block(lines, cursor, _yaml_next_indent(lines, cursor, indent))
		else:
			out[key] = {}
	else:
		out[key] = _yaml_parse_scalar(value)


static func _yaml_next_indent(lines: Array, cursor: Dictionary, fallback: int) -> int:
	if int(cursor.get("i", 0)) >= lines.size():
		return fallback + 2
	return int((lines[int(cursor["i"])] as Dictionary).get("indent", fallback + 2))


static func _yaml_split_key_value(text: String) -> Array:
	var in_quote := false
	var quote := ""
	var escaped := false
	for i in text.length():
		var ch := text[i]
		if escaped:
			escaped = false
			continue
		if ch == "\\":
			escaped = true
			continue
		if in_quote:
			if ch == quote:
				in_quote = false
			continue
		if ch == "\"" or ch == "'":
			in_quote = true
			quote = ch
			continue
		if ch == ":":
			return [text.substr(0, i), text.substr(i + 1)]
	return []


static func _yaml_parse_scalar(raw: String) -> Variant:
	var s := raw.strip_edges()
	if s == "":
		return ""
	if s.begins_with("{") or s.begins_with("[") or s.begins_with("\""):
		var parsed: Variant = JSON.parse_string(s)
		if parsed != null:
			return parsed
	var lower := s.to_lower()
	if lower == "null" or lower == "~":
		return null
	if lower == "true":
		return true
	if lower == "false":
		return false
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	if (s.begins_with("'") and s.ends_with("'")) or (s.begins_with("\"") and s.ends_with("\"")):
		return s.substr(1, s.length() - 2)
	return s


static func load_items() -> Array:
	var parsed: Variant = _read_json_variant(ITEMS_PATH)
	var out: Array = []
	var raw: Array = []
	if parsed is Dictionary:
		var d := parsed as Dictionary
		if d.has("items") and d["items"] is Array:
			raw = _expand_learning_book_items(d, d["items"] as Array)
		else:
			push_error("JsonLoader: item config object missing 'items' array")
			return out
	elif parsed is Array:
		raw = parsed as Array
	else:
		push_error("JsonLoader: item config root must be object or array")
		return out
	for item in raw:
		if not item is Dictionary:
			continue
		var it = ItemDefScript.from_dict(item as Dictionary)
		if it != null:
			out.append(it)
	return out


static func load_item_aliases() -> Dictionary:
	var parsed: Variant = _read_json_variant(ITEMS_PATH)
	if not parsed is Dictionary:
		return {}
	var root := parsed as Dictionary
	var aliases_v: Variant = root.get("legacy_learning_book_aliases", {})
	if not aliases_v is Dictionary:
		return {}
	var out := {}
	for from_v in (aliases_v as Dictionary).keys():
		var from_id := config_id_to_string(from_v)
		var to_id := config_id_to_string((aliases_v as Dictionary).get(from_v, ""))
		if from_id == "" or to_id == "":
			continue
		out[from_id] = to_id
	return out


static func _expand_learning_book_items(root: Dictionary, base_items: Array) -> Array:
	var expanded: Array = []
	var existing_ids := {}
	var existing_ability_targets := {}
	var existing_method_targets := {}
	for item_v in base_items:
		if not item_v is Dictionary:
			continue
		var item := (item_v as Dictionary).duplicate(true)
		expanded.append(item)
		var item_id := config_id_to_string(item.get("id", ""))
		if item_id != "":
			existing_ids[item_id] = true
		var ability_id := config_id_to_string(item.get("learn_ability_id", ""))
		if ability_id != "":
			existing_ability_targets[ability_id] = true
		var method_id := config_id_to_string(item.get("learn_method_id", ""))
		if method_id != "":
			existing_method_targets[method_id] = true
	var templates_v: Variant = root.get("generated_learning_books", [])
	if not templates_v is Array:
		return expanded
	for template_v in templates_v as Array:
		if not template_v is Dictionary:
			continue
		var template := template_v as Dictionary
		if not bool(template.get("enabled", true)):
			continue
		var category := str(template.get("category", "")).strip_edges().to_lower()
		match category:
			"ability":
				_append_generated_ability_books(template, expanded, existing_ids, existing_ability_targets)
			"method":
				_append_generated_method_books(template, expanded, existing_ids, existing_method_targets)
			_:
				push_warning("JsonLoader: unknown generated_learning_books category %s" % category)
	return expanded


static func _append_generated_ability_books(
		template: Dictionary,
		expanded: Array,
		existing_ids: Dictionary,
		existing_targets: Dictionary
) -> void:
	var bundle := load_abilities_bundle()
	var abilities_v: Variant = bundle.get("abilities", [])
	if not abilities_v is Array:
		return
	for ability_v in abilities_v as Array:
		if not ability_v is Dictionary:
			continue
		var ability := ability_v as Dictionary
		var ability_id := config_id_to_string(ability.get("id", ""))
		if ability_id == "" or existing_targets.has(ability_id):
			continue
		var item_id := _generated_learning_book_id(str(template.get("id_prefix", "book_skill_")), ability_id, "ability")
		if item_id == "" or existing_ids.has(item_id):
			continue
		expanded.append(_build_generated_learning_book(template, ability, "ability", item_id))
		existing_ids[item_id] = true
		existing_targets[ability_id] = true


static func _append_generated_method_books(
		template: Dictionary,
		expanded: Array,
		existing_ids: Dictionary,
		existing_targets: Dictionary
) -> void:
	var bundle := _read_json_root_object(XIULIAN_METHODS_PATH)
	var methods_v: Variant = bundle.get("methods", [])
	if not methods_v is Array:
		return
	for method_v in methods_v as Array:
		if not method_v is Dictionary:
			continue
		var method := method_v as Dictionary
		var method_id := config_id_to_string(method.get("id", ""))
		if method_id == "" or existing_targets.has(method_id):
			continue
		var item_id := _generated_learning_book_id(str(template.get("id_prefix", "book_method_")), method_id, "method")
		if item_id == "" or existing_ids.has(item_id):
			continue
		expanded.append(_build_generated_learning_book(template, method, "method", item_id))
		existing_ids[item_id] = true
		existing_targets[method_id] = true


static func _build_generated_learning_book(
		template: Dictionary,
		source_row: Dictionary,
		category: String,
		item_id: String
) -> Dictionary:
	var name := str(source_row.get("name", item_id)).strip_edges()
	var values := {
		"name": name,
		"id": str(source_row.get("id", "")),
		"realm": str(source_row.get("realm", "")),
	}
	var out := {
		"id": item_id,
		"name": StringsZh.format_template(str(template.get("name_template", "{name}")), values),
		"type": str(template.get("secondary_type", template.get("type", "学习典籍"))),
		"primary_type": str(template.get("primary_type", "")),
		"secondary_type": str(template.get("secondary_type", "")),
		"quality": clampi(
			int(source_row.get("quality", template.get("quality", 1))),
			EnumQuality.Type.LOW,
			EnumQuality.Type.SUPREME
		),
		"tier": EnumItemTier.clamp_tier(int(source_row.get("tier", template.get("tier", 1)))),
		"stackable": bool(template.get("stackable", true)),
		"max_stack": maxi(1, int(template.get("max_stack", 9))),
		"desc": StringsZh.format_template(
			str(template.get("desc_template", "研读后习得{name}。")),
			values
		),
		"icon": str(template.get("icon", "")),
	}
	if category == "ability":
		out["learn_ability_id"] = str(source_row.get("id", ""))
	else:
		out["learn_method_id"] = str(source_row.get("id", ""))
	return out


static func _generated_learning_book_id(prefix: String, target_id: String, category: String) -> String:
	var suffix := target_id.strip_edges()
	if category == "ability" and suffix.begins_with("ability.combat."):
		suffix = suffix.trim_prefix("ability.combat.")
	elif category == "ability" and suffix.begins_with("ability."):
		suffix = suffix.trim_prefix("ability.")
	elif category == "method" and suffix.begins_with("method."):
		suffix = suffix.trim_prefix("method.")
	suffix = suffix.replace(".", "_").replace("/", "_").replace("-", "_")
	return "%s%s" % [prefix.strip_edges(), suffix]


static func _template_lookup_string(table_v: Variant, key: String, fallback: String) -> String:
	if table_v is Dictionary:
		var value: Variant = (table_v as Dictionary).get(key, fallback)
		return str(value)
	return fallback


static func _template_lookup_int(table_v: Variant, key: String, fallback: int) -> int:
	if table_v is Dictionary:
		return int((table_v as Dictionary).get(key, fallback))
	return fallback


static func _sort_skill_dict_keys(a: Variant, b: Variant) -> bool:
	var sa := str(a)
	var sb := str(b)
	if sa.is_valid_int() and sb.is_valid_int():
		return int(sa) < int(sb)
	return sa.naturalnocasecmp_to(sb) < 0


static func load_equips_bundle() -> Dictionary:
	var root := _read_json_root_object(EQUIPS_PATH)
	if root.is_empty():
		return {"equips": []}
	return {"equips": _parse_equip_rows(root.get("equips", {}))}


static func _parse_equip_rows(raw: Variant) -> Array:
	var equips_out: Array = []
	if not raw is Dictionary:
		push_error("JsonLoader: equip config 'equips' must be an object keyed by equip id")
		return equips_out
	var d := raw as Dictionary
	var keys: Array = d.keys()
	keys.sort_custom(_sort_skill_dict_keys)
	for k in keys:
		var key_str := str(k).strip_edges()
		if not key_str.is_valid_int():
			push_error("JsonLoader: equip config equips key must be numeric id, got '%s'" % key_str)
			continue
		var eid := int(key_str)
		if eid <= 0:
			push_error("JsonLoader: equip id must be positive, got %d" % eid)
			continue
		var row_v: Variant = d[k]
		if not row_v is Dictionary:
			push_error("JsonLoader: equip %d entry must be an object" % eid)
			continue
		var row := (row_v as Dictionary).duplicate(true)
		row["id"] = eid
		var equip = EquipDefScript.from_dict(row)
		if equip != null:
			equips_out.append(equip)
	return equips_out


static func load_buffs() -> Array:
	var root := _read_json_root_object(BUFFS_PATH)
	var out: Array = []
	if root.is_empty():
		return out
	var raw: Variant = root.get("buffs", {})
	if not raw is Dictionary:
		push_error("JsonLoader: buff config 'buffs' must be an object keyed by buff id")
		return out
	var d := raw as Dictionary
	for k in d.keys():
		var bid := str(k).strip_edges()
		if bid == "":
			push_error("JsonLoader: buff config buffs key must be non-empty string")
			continue
		var row_v: Variant = d[k]
		if not row_v is Dictionary:
			push_error("JsonLoader: buff '%s' entry must be an object" % bid)
			continue
		var row := (row_v as Dictionary).duplicate(true)
		row["id"] = bid
		_validate_zhandou_effects_schema(
			row.get("tick_effects", []),
			"buff config buffs['%s'].tick_effects" % bid,
			false
		)
		var buff = BuffDefScript.from_dict(row)
		if buff != null:
			out.append(buff)
	return out


static func _validate_zhandou_effects_schema(raw: Variant, path_label: String, allow_target: bool) -> void:
	if raw == null:
		return
	if not raw is Array:
		push_error("JsonLoader: %s must be Array" % path_label)
		return
	for i in (raw as Array).size():
		var item_v: Variant = (raw as Array)[i]
		if not item_v is Dictionary:
			push_error("JsonLoader: %s[%d] must be object" % [path_label, i])
			continue
		var item := item_v as Dictionary
		var etype := str(item.get("type", "")).strip_edges().to_lower()
		if etype == "":
			push_error("JsonLoader: %s[%d].type is required" % [path_label, i])
			continue
		if not EnumCombatEffectType.is_valid_label(etype):
			push_error("JsonLoader: %s[%d].type '%s' is unsupported" % [path_label, i, etype])
		if allow_target and item.has("target"):
			var target := str(item.get("target", "")).strip_edges().to_lower()
			if target != "" and not EnumZhandouTarget.is_valid_label(target):
				push_error("JsonLoader: %s[%d].target '%s' is unsupported" % [path_label, i, target])
		if EnumCombatEffectType.requires_value(etype) and not item.has("value"):
			push_error("JsonLoader: %s[%d].value is required for type '%s'" % [path_label, i, etype])


static func strip_json_comments(variant: Variant) -> Variant:
	if variant is Dictionary:
		var out := {}
		for key in (variant as Dictionary).keys():
			var ks := str(key)
			if ks in JSON_COMMENT_KEYS:
				continue
			out[key] = strip_json_comments((variant as Dictionary)[key])
		return out
	if variant is Array:
		var arr: Array = []
		for item in variant as Array:
			arr.append(strip_json_comments(item))
		return arr
	return variant


static func normalize_zhandou_vfx_preset_id(ref: String) -> String:
	var s := ref.strip_edges()
	if s == "":
		return ""
	if s.ends_with(".json") or s.ends_with(".yaml"):
		s = s.substr(0, s.length() - 5)
	elif s.ends_with(".yml"):
		s = s.substr(0, s.length() - 4)
	var slash := s.rfind("/")
	if slash >= 0:
		s = s.substr(slash + 1)
	var backslash := s.rfind("\\")
	if backslash >= 0:
		s = s.substr(backslash + 1)
	return s


static func zhandou_vfx_preset_path(preset_id: String) -> String:
	var id := normalize_zhandou_vfx_preset_id(preset_id)
	if id == "":
		return ""
	return "%s/%s.yaml" % [ZHANDOU_VFX_PRESETS_DIR, id]


static func load_zhandou_float_styles() -> Dictionary:
	var raw: Variant = _read_config_variant(ZHANDOU_FLOAT_STYLES_PATH)
	if raw == null or not raw is Dictionary:
		return {"version": 1, "jitter_x": 18.0, "max_per_unit_per_frame": 6, "styles": {}}
	return strip_json_comments(raw) as Dictionary


static func load_zhandou_vfx_index() -> Dictionary:
	var raw: Variant = _read_config_variant(ZHANDOU_VFX_INDEX_PATH)
	if raw == null or not raw is Dictionary:
		return {"version": 1, "default": "melee_default", "impact_preset": "hit_default", "preset_dir": "presets"}
	return strip_json_comments(raw) as Dictionary


static func load_zhandou_vfx_preset_file(preset_ref: String) -> Dictionary:
	var path := zhandou_vfx_preset_path(preset_ref)
	if path == "" or not FileAccess.file_exists(path):
		push_warning("JsonLoader: zhandou vfx preset not found: %s" % path)
		return {}
	var raw: Variant = _read_config_variant(path)
	if raw == null or not raw is Dictionary:
		return {}
	return strip_json_comments(raw) as Dictionary


static func load_dao_tree() -> Dictionary:
	return _read_json_root_object(DAO_TREE_PATH)


static func load_xiulian_methods_bundle() -> Dictionary:
	return _read_json_root_object(XIULIAN_METHODS_PATH)


static func load_knowledge_effects_bundle() -> Dictionary:
	return _read_json_root_object(KNOWLEDGE_EFFECTS_PATH)


static func load_abilities_bundle() -> Dictionary:
	var bundle := _read_json_root_object(ABILITIES_PATH)
	var merged: Array = []
	var tables_v: Variant = bundle.get("abilityTables", {})
	if tables_v is Dictionary and not (tables_v as Dictionary).is_empty():
		for type_name in _ability_table_load_order(bundle, tables_v as Dictionary):
			merged.append_array(_load_ability_table_rows(str(type_name), tables_v as Dictionary))
	else:
		# ponytail: 兼容仍内联 abilities 的旧版单文件
		var legacy_v: Variant = bundle.get("abilities", [])
		if legacy_v is Array:
			merged = (legacy_v as Array).duplicate(true)
	bundle["abilities"] = merged
	var meta_v: Variant = bundle.get("metadata", {})
	if meta_v is Dictionary:
		(meta_v as Dictionary)["abilityCount"] = merged.size()
	return bundle


static func _ability_table_load_order(bundle: Dictionary, tables: Dictionary) -> Array:
	var rules_v: Variant = bundle.get("rules", {})
	if rules_v is Dictionary:
		var types_v: Variant = (rules_v as Dictionary).get("types", [])
		if types_v is Array and not (types_v as Array).is_empty():
			return types_v as Array
	return tables.keys()


static func _load_ability_table_rows(type_name: String, tables: Dictionary) -> Array:
	var rel := str(tables.get(type_name, "")).strip_edges()
	if rel == "":
		rel = "abilities/%s.yaml" % type_name
	var path := rel if rel.begins_with("res://") else "res://data/%s" % rel.trim_prefix("/")
	var table := _read_json_root_object(path)
	var rows_v: Variant = table.get("abilities", [])
	return (rows_v as Array).duplicate(true) if rows_v is Array else []


static func load_effect_catalog() -> Dictionary:
	return _read_json_root_object(EFFECT_CATALOG_PATH)


static func load_zhandou_vfx_presets() -> Dictionary:
	var index := load_zhandou_vfx_index()
	var names: Array = []
	var dir := DirAccess.open(ZHANDOU_VFX_PRESETS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if not dir.current_is_dir() and (fn.ends_with(".yaml") or fn.ends_with(".yml")):
				names.append(fn.get_basename())
			fn = dir.get_next()
		dir.list_dir_end()
	return {
		"version": index.get("version", 1),
		"defaults": index.get("default", "melee_default"),
		"impact_preset": index.get("impact_preset", "hit_default"),
		"preset_names": names,
	}
