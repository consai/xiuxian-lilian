class_name JsonLoader
extends RefCounted

const EXPORT_DIR := "res://data/exportjson"
## 运行参数子目录：时间/模拟/UI/规则/平衡等，与内容表分开放。
const YUNXING_PARAMS_DIR := "%s/yunxing_params" % EXPORT_DIR
const ITEMS_PATH := "%s/item_items.json" % EXPORT_DIR
const ITEM_GENERATED_BOOKS_PATH := "%s/item_generated_learning_books.json" % EXPORT_DIR
const ITEM_ALIASES_PATH := "%s/item_legacy_learning_book_ali.json" % EXPORT_DIR
const EQUIPS_PATH := "%s/zhuangbei_equips.json" % EXPORT_DIR
const BUFFS_PATH := "%s/buff.json" % EXPORT_DIR
const ZHANDOU_EFFECT_SCHEMA_PATH := "%s/战斗effects效果介绍.json" % EXPORT_DIR
const ZHANDOU_VFX_INDEX_PATH := "%s/zhandou_vfx_index.json" % EXPORT_DIR
const ZHANDOU_FLOAT_STYLES_PATH := "%s/zhandou_float_styles.json" % EXPORT_DIR
const ZHANDOU_FLOAT_STYLE_ROWS_PATH := "%s/zhandou_float_styles_styles.json" % EXPORT_DIR

const ItemDefScript = preload("res://scripts/core/item_def.gd")
const EquipDefScript = preload("res://scripts/zhandou/equip_def.gd")
const BuffDefScript = preload("res://scripts/zhandou/buff_def.gd")

## 配置文件中的文档用元数据键（加载后剔除）。
const JSON_COMMENT_KEYS: Array[String] = ["_comment", "_说明", "_doc", "_备注"]
const ZHANDOU_VFX_PRESET_FILES: Dictionary = {
	"hit_default": "zhandou_presets_hit_default_s.json",
	"hit_only": "zhandou_presets_hit_only_sequ.json",
	"melee_default": "zhandou_presets_melee_default.json",
	"qi_bolt_projectile": "zhandou_presets_qi_bolt_proje.json",
	"ranged_default": "zhandou_presets_ranged_defaul.json",
	"status_cast": "zhandou_presets_status_cast_s.json",
	"sword_qi_projectile": "zhandou_presets_sword_qi_proj.json",
}

## 配置表 id 统一为 String（空串表示无效/缺省）。
static func config_id_to_string(v: Variant) -> String:
	return str(v).strip_edges()


static func export_path(file_name: String) -> String:
	return "%s/%s" % [EXPORT_DIR, file_name]


## 运行参数目录下的配置路径。
static func yunxing_params_path(file_name: String) -> String:
	return "%s/%s" % [YUNXING_PARAMS_DIR, file_name]


static func _export_keyed_rows(path: String) -> Dictionary:
	var root := _read_json_root_object(path)
	var out := {}
	for key_v in root.keys():
		var row_v: Variant = root[key_v]
		if row_v is Dictionary:
			out[str(key_v)] = _strip_null_fields(row_v)
	return out


static func _strip_null_fields(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key_v in (value as Dictionary).keys():
			var cell: Variant = value[key_v]
			if cell != null:
				out[key_v] = _strip_null_fields(cell)
		return out
	if value is Array:
		var out: Array = []
		for cell in value:
			out.append(_strip_null_fields(cell))
		return out
	return value


static func _export_row_array(path: String) -> Array:
	var rows := _export_keyed_rows(path)
	var keys: Array = rows.keys()
	keys.sort_custom(_sort_config_keys)
	var out: Array = []
	for key_v in keys:
		out.append((rows[key_v] as Dictionary).duplicate(true))
	return out


static func _export_settings(path: String) -> Dictionary:
	var rows := _export_keyed_rows(path)
	var out := {}
	for key_v in rows.keys():
		var row := rows[key_v] as Dictionary
		var key := str(row.get("key", key_v)).strip_edges()
		if key == "":
			continue
		out[key] = _export_setting_payload(row)
	return out


static func _export_setting_payload(row: Dictionary) -> Variant:
	if row.has("value") and row["value"] != null:
		return _coerce_export_scalar(row["value"])
	var out := {}
	for key_v in row.keys():
		var key := str(key_v)
		if key == "key" or key == "value":
			continue
		var value: Variant = row[key_v]
		if value == null:
			continue
		out[key] = _coerce_export_scalar(value)
	return out


static func _coerce_export_scalar(value: Variant) -> Variant:
	if not value is String:
		return value
	var s := str(value).strip_edges()
	var comment_at := s.find(" #")
	if comment_at >= 0:
		var before_comment := s.substr(0, comment_at).strip_edges()
		if before_comment.is_valid_int() or before_comment.is_valid_float() \
				or before_comment.to_lower() in ["true", "false"]:
			s = before_comment
	var lower := s.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if s.is_valid_int():
		return int(s)
	if s.is_valid_float():
		return float(s)
	return s


static func _sort_config_keys(a: Variant, b: Variant) -> bool:
	var sa := str(a)
	var sb := str(b)
	if sa.is_valid_int() and sb.is_valid_int():
		return int(sa) < int(sb)
	return sa.naturalnocasecmp_to(sb) < 0


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
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("JsonLoader: invalid JSON: %s" % path)
		return null
	return parsed

static func load_items() -> Array:
	var out: Array = []
	var raw := _expand_learning_book_items({
		"generated_learning_books": _export_row_array(ITEM_GENERATED_BOOKS_PATH),
	}, _export_row_array(ITEMS_PATH))
	for item in raw:
		if not item is Dictionary:
			continue
		var it = ItemDefScript.from_dict(item as Dictionary)
		if it != null:
			out.append(it)
	return out


static func load_item_aliases() -> Dictionary:
	var rows := _export_settings(ITEM_ALIASES_PATH)
	var out := {}
	for from_v in rows.keys():
		var from_id := config_id_to_string(from_v)
		var to_id := config_id_to_string(rows.get(from_v, ""))
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
	var bundle := load_xiulian_methods_bundle()
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
	return {"equips": _parse_equip_rows(root)}


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
	var raw: Variant = root.get("buffs", root)
	if not raw is Dictionary:
		push_error("JsonLoader: buff config root must be an object keyed by buff id")
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
		var row := _normalize_export_buff_row(bid, row_v as Dictionary)
		_validate_zhandou_effects_schema(
			row.get("tick_effects", []),
			"buff config buffs['%s'].tick_effects" % bid,
			false
		)
		var buff = BuffDefScript.from_dict(row)
		if buff != null:
			out.append(buff)
	return out


static func load_zhandou_effect_schema() -> Dictionary:
	return _read_json_root_object(ZHANDOU_EFFECT_SCHEMA_PATH)


static func _normalize_export_buff_row(buff_id: String, raw: Dictionary) -> Dictionary:
	var row := raw.duplicate(true)
	row["id"] = buff_id
	if row.has("type") and not row.has("tags"):
		row["tags"] = ZhandouEffectCodec.split_csv_tags(row.get("type", ""))
	var ticktime := float(row.get("ticktime", 1.0))
	if ticktime < 0.0:
		row["ticktime"] = 0.0
	var mods_v: Variant = row.get("modifiers", {})
	if mods_v is Array:
		row["modifiers"] = ZhandouEffectCodec.normalize_buff_modifiers(mods_v)
	var tick_v: Variant = row.get("tick_effects", [])
	if tick_v is Array:
		row["tick_effects"] = ZhandouEffectCodec.normalize_buff_tick_effects(tick_v)
	return row


static func _validate_zhandou_effects_schema(raw: Variant, path_label: String, allow_target: bool) -> void:
	if raw == null:
		return
	if not raw is Array:
		push_error("JsonLoader: %s must be Array" % path_label)
		return
	for i in (raw as Array).size():
		var item_v: Variant = (raw as Array)[i]
		if item_v is Array:
			var cells := item_v as Array
			if cells.is_empty():
				push_error("JsonLoader: %s[%d] positional effect is empty" % [path_label, i])
				continue
			var effect_id := str(cells[0]).strip_edges().to_lower()
			if not ZhandouEffectCodec.is_schema_effect_id(effect_id):
				push_error("JsonLoader: %s[%d] effect '%s' is unsupported" % [path_label, i, effect_id])
			continue
		if not item_v is Dictionary:
			push_error("JsonLoader: %s[%d] must be object or positional array" % [path_label, i])
			continue
		var item := item_v as Dictionary
		if item.has("type"):
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
				if item.has("target_arg") or item.has("targetArg"):
					var target_arg := str(item.get("target_arg", item.get("targetArg", ""))).strip_edges().to_lower()
					if target_arg != "" and not EnumZhandouTargetArg.is_valid_label(target_arg):
						push_error("JsonLoader: %s[%d].target_arg '%s' is unsupported" % [path_label, i, target_arg])
			if EnumCombatEffectType.requires_value(etype) and not item.has("value"):
				push_error("JsonLoader: %s[%d].value is required for type '%s'" % [path_label, i, etype])
			continue
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
			if item.has("target_arg") or item.has("targetArg"):
				var target_arg := str(item.get("target_arg", item.get("targetArg", ""))).strip_edges().to_lower()
				if target_arg != "" and not EnumZhandouTargetArg.is_valid_label(target_arg):
					push_error("JsonLoader: %s[%d].target_arg '%s' is unsupported" % [path_label, i, target_arg])
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
	if s.ends_with(".json"):
		s = s.substr(0, s.length() - 5)
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
	var file_name := str(ZHANDOU_VFX_PRESET_FILES.get(id, ""))
	return export_path(file_name) if file_name != "" else ""


static func zhandou_vfx_preset_ids() -> Array:
	var out: Array = ZHANDOU_VFX_PRESET_FILES.keys()
	out.sort_custom(_sort_config_keys)
	return out


static func load_zhandou_float_styles() -> Dictionary:
	var raw := _export_settings(ZHANDOU_FLOAT_STYLES_PATH)
	if raw.is_empty():
		return {"version": 1, "jitter_x": 18.0, "max_per_unit_per_frame": 6, "styles": {}}
	raw["styles"] = _export_keyed_rows(ZHANDOU_FLOAT_STYLE_ROWS_PATH)
	return strip_json_comments(raw) as Dictionary


static func load_zhandou_vfx_index() -> Dictionary:
	var raw := _export_settings(ZHANDOU_VFX_INDEX_PATH)
	if raw.is_empty():
		return {"version": 1, "default": "melee_default", "impact_preset": "hit_default", "preset_dir": "presets"}
	return strip_json_comments(raw) as Dictionary


static func load_zhandou_vfx_preset_file(preset_ref: String) -> Dictionary:
	var path := zhandou_vfx_preset_path(preset_ref)
	if path == "" or not FileAccess.file_exists(path):
		push_warning("JsonLoader: zhandou vfx preset not found: %s" % path)
		return {}
	var sequence := _export_row_array(path)
	if sequence.is_empty():
		return {}
	return strip_json_comments({"sequence": sequence}) as Dictionary


static func load_dao_tree() -> Dictionary:
	var root := _export_settings(export_path("dao_tree.json"))
	root["metadata"] = _export_settings(export_path("dao_tree_metadata.json"))
	root["training"] = _export_settings(export_path("dao_tree_training.json"))
	root["attributes"] = _export_settings(export_path("dao_tree_attributes.json"))
	root["realms"] = _export_row_array(export_path("dao_tree_realms.json"))
	root["domainGroups"] = _export_row_array(export_path("dao_tree_domainGroups.json"))
	root["domains"] = _export_row_array(export_path("dao_tree_domains.json"))
	root["skills"] = _export_row_array(export_path("dao_tree_skills.json"))
	return root


static func load_xiulian_methods_bundle() -> Dictionary:
	var root := _export_settings(export_path("xiulian_methods.json"))
	root["metadata"] = _export_settings(export_path("xiulian_methods_metadata.json"))
	root["families"] = _export_row_array(export_path("xiulian_methods_families.json"))
	root["methods"] = _export_row_array(export_path("xiulian_methods_methods.json"))
	root["effectCatalog"] = _export_keyed_rows(export_path("xiulian_methods_effectCatalog.json"))
	return root


static func load_abilities_bundle() -> Dictionary:
	var bundle := _export_settings(export_path("jineng.json"))
	bundle["metadata"] = _export_settings(export_path("jineng_metadata.json"))
	bundle["rules"] = _export_settings(export_path("jineng_rules.json"))
	var merged: Array = []
	var tables_out: Dictionary = {}
	# 分表路径以 EnumAbilityTable 为准，不再读独立 abilityTables 配置文件。
	var tables: Dictionary = {}
	for table_key in EnumAbilityTable.LOAD_ORDER:
		tables[table_key] = EnumAbilityTable.default_path(table_key)
	for table_key in _ability_table_load_order(tables):
		var rows := _load_ability_table_file(str(table_key), tables)
		tables_out[str(table_key)] = rows
		merged.append_array(rows)
	bundle["abilityTables"] = tables
	bundle["tables"] = tables_out
	bundle["abilities"] = merged
	var meta_v: Variant = bundle.get("metadata", {})
	if meta_v is Dictionary:
		(meta_v as Dictionary)["abilityCount"] = merged.size()
	return bundle


static func load_ability_table(table_key: String) -> Dictionary:
	var path := _ability_table_path(table_key)
	return _read_json_root_object(path)


static func _ability_table_load_order(tables: Dictionary) -> Array:
	var out: Array = []
	for table_key in EnumAbilityTable.LOAD_ORDER:
		if tables.has(table_key):
			out.append(table_key)
	for table_key in tables.keys():
		var key := str(table_key)
		if key not in out:
			out.append(key)
	return out


static func _load_ability_table_file(table_key: String, tables: Dictionary) -> Array:
	var rel := str(tables.get(table_key, "")).strip_edges()
	if rel == "":
		rel = EnumAbilityTable.default_path(table_key)
	var path := rel if rel.begins_with("res://") else "res://data/%s" % rel.trim_prefix("/")
	var table := _read_json_root_object(path)
	var rows_v: Variant = table.get("abilities", [])
	if rows_v is Array and not (rows_v as Array).is_empty():
		return (rows_v as Array).duplicate(true)
	if AbilityExportAdapter.is_export_root(table):
		return AbilityExportAdapter.normalize_table_rows(table_key, table)
	return []


static func _ability_table_path(table_key: String) -> String:
	var rel := EnumAbilityTable.default_path(table_key)
	return rel if rel.begins_with("res://") else "res://data/%s" % rel.trim_prefix("/")


static func load_effect_catalog() -> Dictionary:
	var root := _export_settings(export_path("xiaoguo_catalog.json"))
	root["metadata"] = _export_settings(export_path("xiaoguo_catalog_metadata.json"))
	root["effects"] = _export_keyed_rows(export_path("xiaoguo_catalog_effects.json"))
	root["stackPolicies"] = _export_settings(export_path("xiaoguo_catalog_stackPolicies.json"))
	return root


static func load_locations_bundle() -> Dictionary:
	var root := _export_settings(export_path("didian.json"))
	root["locations"] = _export_keyed_rows(export_path("didian_locations.json"))
	return root


static func load_world_map_bundle() -> Dictionary:
	var root := _export_settings(export_path("shijie_map.json"))
	root["cities"] = _export_keyed_rows(export_path("shijie_map_cities.json"))
	root["routes"] = _export_row_array(export_path("shijie_map_routes.json"))
	root["wilderness_regions"] = _export_keyed_rows(export_path("shijie_map_wilderness_regions.json"))
	root["wilderness_locations"] = _export_keyed_rows(export_path("shijie_map_wilderness_locatio.json"))
	return root


static func load_lilian_common_events_bundle() -> Dictionary:
	var root := _export_settings(export_path("lilian_common_events.json"))
	root["events"] = _export_keyed_rows(export_path("lilian_common_events_events.json"))
	return root


static func load_lilian_events_bundle() -> Dictionary:
	var root := _export_settings(export_path("lilian_events.json"))
	root["events"] = _export_keyed_rows(export_path("lilian_events_events.json"))
	return root


static func load_lilian_rules_bundle() -> Dictionary:
	var root := _export_settings(yunxing_params_path("lilian_rules.json"))
	root["reward_budget"] = _export_settings(yunxing_params_path("lilian_rules_reward_budget.json"))
	return root


static func load_moni_bundle() -> Dictionary:
	var root := _export_settings(yunxing_params_path("moni.json"))
	root["rules"] = _export_settings(yunxing_params_path("moni_rules.json"))
	root["activities"] = _export_keyed_rows(yunxing_params_path("moni_activities.json"))
	root["initial_player"] = _export_settings(yunxing_params_path("moni_initial_player.json"))
	return root


static func load_jingjie_balance_bundle() -> Dictionary:
	var root := {}
	root["acceptance"] = _export_settings(yunxing_params_path("jingjie_balance_acceptance.json"))
	root["benchmark_enemies"] = _export_keyed_rows(yunxing_params_path("jingjie_balance_benchmark_ene.json"))
	root["budgets"] = _export_keyed_rows(yunxing_params_path("jingjie_balance_budgets.json"))
	root["combat_attribute_formula"] = _export_keyed_rows(yunxing_params_path("jingjie_balance_combat_attrib.json"))
	root["cultivation_progression"] = _export_settings(yunxing_params_path("jingjie_balance_cultivation_p.json"))
	root["encounter_bands"] = _export_keyed_rows(yunxing_params_path("jingjie_balance_encounter_ban.json"))
	root["major_realms"] = _export_row_array(yunxing_params_path("jingjie_balance_major_realms.json"))
	root["standard_players"] = _export_keyed_rows(yunxing_params_path("jingjie_balance_standard_play.json"))
	return root


static func load_liandan_bundle() -> Dictionary:
	var root := _export_settings(export_path("liandan.json"))
	root["furnaces"] = _export_row_array(export_path("liandan_furnaces.json"))
	root["recipes"] = _export_row_array(export_path("liandan_recipes.json"))
	root["strategies"] = _export_row_array(export_path("liandan_strategies.json"))
	return root


static func load_shijian_rules_bundle() -> Dictionary:
	return _export_settings(yunxing_params_path("shijian_rules.json"))


static func load_tupo_rules_bundle() -> Dictionary:
	var root := _export_settings(yunxing_params_path("tupo_rules.json"))
	root["component_caps"] = _export_settings(yunxing_params_path("tupo_rules_component_caps.json"))
	root["major_breakthroughs"] = _export_keyed_rows(yunxing_params_path("tupo_rules_major_breakthrough.json"))
	return root


static func load_weituo_bundle() -> Dictionary:
	var root := _export_settings(export_path("weituo.json"))
	root["rules"] = _export_settings(export_path("weituo_rules.json"))
	root["weituo"] = _export_keyed_rows(export_path("weituo_weituo.json"))
	return root


static func load_tip_policy_bundle() -> Dictionary:
	var root := _export_settings(yunxing_params_path("ui_tip_policy.json"))
	root["channels"] = _export_keyed_rows(yunxing_params_path("ui_tip_policy_channels.json"))
	return root


static func load_story_bundle(story_id: String) -> Dictionary:
	var name := story_id.replace(".", "_").replace("/", "_").replace("\\", "_")
	var root := _export_settings(export_path("gushi_%s.json" % name))
	root["nodes"] = _export_keyed_rows(export_path("gushi_%s_nodes.json" % name))
	return root


static func load_zhandou_vfx_presets() -> Dictionary:
	var index := load_zhandou_vfx_index()
	return {
		"version": index.get("version", 1),
		"defaults": index.get("default", "melee_default"),
		"impact_preset": index.get("impact_preset", "hit_default"),
		"preset_names": zhandou_vfx_preset_ids(),
	}
