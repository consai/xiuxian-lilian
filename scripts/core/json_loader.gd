class_name JsonLoader
extends RefCounted

const EXPORT_DIR := "res://data/exportjson"
## 运行参数子目录：时间/模拟/UI/规则/平衡等，与内容表分开放。
const YUNXING_PARAMS_DIR := "%s/yunxing_params" % EXPORT_DIR
const ITEMS_PATH := "%s/item_items.json" % EXPORT_DIR
const ITEM_GENERATED_BOOKS_PATH := "%s/item_generated_learning_books.json" % EXPORT_DIR
const ZHANDOU_VFX_INDEX_PATH := "%s/zhandou_vfx_index.json" % EXPORT_DIR
const ZHANDOU_FLOAT_STYLES_PATH := "%s/zhandou_float_styles.json" % EXPORT_DIR
const ZHANDOU_FLOAT_STYLE_ROWS_PATH := "%s/zhandou_float_styles_styles.json" % EXPORT_DIR

const ItemDefScript = preload("res://scripts/core/item_def.gd")
const ExportTableReaderScript = preload("res://scripts/core/config/export_table_reader.gd")

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


static func _read_json_root_object(path: String) -> Dictionary:
	return JsonReader.read_object(path)


static func _read_json_variant(path: String) -> Variant:
	return JsonReader.read_variant(path)


static func _read_config_variant(path: String) -> Variant:
	return JsonReader.read_variant(path)

static func load_items() -> Array:
	var out: Array = []
	var raw := _expand_learning_book_items({
		"generated_learning_books": ExportTableReaderScript.read_row_array(ITEM_GENERATED_BOOKS_PATH),
	}, ExportTableReaderScript.read_row_array(ITEMS_PATH))
	for item in raw:
		if not item is Dictionary:
			continue
		var it = ItemDefScript.from_dict(item as Dictionary)
		if it != null:
			out.append(it)
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
		"stackable": int(template.get("stackable", 1)),
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
	out.sort_custom(ExportTableReaderScript.compare_keys)
	return out


static func load_zhandou_float_styles() -> Dictionary:
	var raw := ExportTableReaderScript.read_settings(ZHANDOU_FLOAT_STYLES_PATH)
	if raw.is_empty():
		return {"version": 1, "jitter_x": 18.0, "max_per_unit_per_frame": 6, "styles": {}}
	raw["styles"] = ExportTableReaderScript.read_keyed_rows(ZHANDOU_FLOAT_STYLE_ROWS_PATH)
	return strip_json_comments(raw) as Dictionary


static func load_zhandou_vfx_index() -> Dictionary:
	var raw := ExportTableReaderScript.read_settings(ZHANDOU_VFX_INDEX_PATH)
	if raw.is_empty():
		return {"version": 1, "default": "melee_default", "impact_preset": "hit_default", "preset_dir": "presets"}
	return strip_json_comments(raw) as Dictionary


static func load_zhandou_vfx_preset_file(preset_ref: String) -> Dictionary:
	var path := zhandou_vfx_preset_path(preset_ref)
	if path == "" or not FileAccess.file_exists(path):
		push_warning("JsonLoader: zhandou vfx preset not found: %s" % path)
		return {}
	var sequence := ExportTableReaderScript.read_row_array(path)
	if sequence.is_empty():
		return {}
	return strip_json_comments({"sequence": sequence}) as Dictionary


static func load_dao_tree() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("dao_tree.json"))
	root["metadata"] = ExportTableReaderScript.read_settings(export_path("dao_tree_metadata.json"))
	root["training"] = ExportTableReaderScript.read_settings(export_path("dao_tree_training.json"))
	root["attributes"] = ExportTableReaderScript.read_settings(export_path("dao_tree_attributes.json"))
	root["realms"] = ExportTableReaderScript.read_row_array(export_path("dao_tree_realms.json"))
	root["domainGroups"] = ExportTableReaderScript.read_row_array(export_path("dao_tree_domainGroups.json"))
	root["domains"] = ExportTableReaderScript.read_row_array(export_path("dao_tree_domains.json"))
	root["skills"] = ExportTableReaderScript.read_row_array(export_path("dao_tree_skills.json"))
	return root


static func load_xiulian_methods_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("xiulian_methods.json"))
	root["metadata"] = ExportTableReaderScript.read_settings(export_path("xiulian_methods_metadata.json"))
	root["families"] = ExportTableReaderScript.read_row_array(export_path("xiulian_methods_families.json"))
	root["methods"] = ExportTableReaderScript.read_row_array(export_path("xiulian_methods_methods.json"))
	root["effectCatalog"] = ExportTableReaderScript.read_keyed_rows(export_path("xiulian_methods_effectCatalog.json"))
	return root


static func load_abilities_bundle() -> Dictionary:
	var bundle: Dictionary = {}
	var merged: Array = []
	var tables_out: Dictionary = {}
	# 分表路径以 EnumSkill 为准，不再读独立 abilityTables 配置文件。
	var tables: Dictionary = {}
	for table_key in EnumSkill.LOAD_ORDER:
		tables[table_key] = EnumSkill.default_path(table_key)
	for table_key in _ability_table_load_order(tables):
		var rows := _load_ability_table_file(str(table_key), tables)
		tables_out[str(table_key)] = rows
		merged.append_array(rows)
	bundle["abilityTables"] = tables
	bundle["tables"] = tables_out
	bundle["abilities"] = merged
	return bundle


static func load_ability_table(table_key: String) -> Dictionary:
	var path := _ability_table_path(table_key)
	return _read_json_root_object(path)


static func _ability_table_load_order(tables: Dictionary) -> Array:
	var out: Array = []
	for table_key in EnumSkill.LOAD_ORDER:
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
		rel = EnumSkill.default_path(table_key)
	var path := rel if rel.begins_with("res://") else "res://data/%s" % rel.trim_prefix("/")
	var table := _read_json_root_object(path)
	var rows_v: Variant = table.get("abilities", [])
	if rows_v is Array and not (rows_v as Array).is_empty():
		return (rows_v as Array).duplicate(true)
	if AbilityExportAdapter.is_export_root(table):
		return AbilityExportAdapter.normalize_table_rows(table_key, table)
	return []


static func _ability_table_path(table_key: String) -> String:
	var rel := EnumSkill.default_path(table_key)
	return rel if rel.begins_with("res://") else "res://data/%s" % rel.trim_prefix("/")


static func load_effect_catalog() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("xiaoguo_catalog.json"))
	root["metadata"] = ExportTableReaderScript.read_settings(export_path("xiaoguo_catalog_metadata.json"))
	root["effects"] = ExportTableReaderScript.read_keyed_rows(export_path("xiaoguo_catalog_effects.json"))
	root["stackPolicies"] = ExportTableReaderScript.read_settings(export_path("xiaoguo_catalog_stackPolicies.json"))
	return root


static func load_locations_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("didian.json"))
	root["locations"] = ExportTableReaderScript.read_keyed_rows(export_path("didian_locations.json"))
	return root


static func load_world_map_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("shijie_map.json"))
	root["cities"] = ExportTableReaderScript.read_keyed_rows(export_path("shijie_map_cities.json"))
	root["routes"] = ExportTableReaderScript.read_row_array(export_path("shijie_map_routes.json"))
	root["wilderness_regions"] = ExportTableReaderScript.read_keyed_rows(export_path("shijie_map_wilderness_regions.json"))
	root["wilderness_locations"] = ExportTableReaderScript.read_keyed_rows(export_path("shijie_map_wilderness_locatio.json"))
	return root


static func load_lilian_common_events_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("lilian_common_events.json"))
	root["events"] = ExportTableReaderScript.read_keyed_rows(export_path("lilian_common_events_events.json"))
	return root


static func load_lilian_events_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("lilian_events.json"))
	root["events"] = ExportTableReaderScript.read_keyed_rows(export_path("lilian_events_events.json"))
	return root


static func load_lilian_rules_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(yunxing_params_path("lilian_rules.json"))
	root["reward_budget"] = ExportTableReaderScript.read_settings(yunxing_params_path("lilian_rules_reward_budget.json"))
	return root


static func load_moni_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(yunxing_params_path("moni.json"))
	root["activities"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("moni_activities.json"))
	root["initial_player"] = ExportTableReaderScript.read_settings(yunxing_params_path("moni_initial_player.json"))
	return root


static func load_jingjie_balance_bundle() -> Dictionary:
	var root := {}
	root["acceptance"] = ExportTableReaderScript.read_settings(yunxing_params_path("jingjie_balance_acceptance.json"))
	root["benchmark_enemies"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("jingjie_balance_benchmark_ene.json"))
	root["budgets"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("jingjie_balance_budgets.json"))
	root["combat_attribute_formula"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("jingjie_balance_combat_attrib.json"))
	root["cultivation_progression"] = ExportTableReaderScript.read_settings(yunxing_params_path("jingjie_balance_cultivation_p.json"))
	root["encounter_bands"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("jingjie_balance_encounter_ban.json"))
	root["major_realms"] = ExportTableReaderScript.read_row_array(yunxing_params_path("jingjie_balance_major_realms.json"))
	root["standard_players"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("jingjie_balance_standard_play.json"))
	return root


static func load_liandan_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("liandan.json"))
	root["furnaces"] = ExportTableReaderScript.read_row_array(export_path("liandan_furnaces.json"))
	root["recipes"] = ExportTableReaderScript.read_row_array(export_path("liandan_recipes.json"))
	root["strategies"] = ExportTableReaderScript.read_row_array(export_path("liandan_strategies.json"))
	return root


static func load_weituo_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(export_path("weituo.json"))
	root["rules"] = ExportTableReaderScript.read_settings(export_path("weituo_rules.json"))
	root["weituo"] = ExportTableReaderScript.read_keyed_rows(export_path("weituo_weituo.json"))
	return root


static func load_tip_policy_bundle() -> Dictionary:
	var root := ExportTableReaderScript.read_settings(yunxing_params_path("ui_tip_policy.json"))
	root["channels"] = ExportTableReaderScript.read_keyed_rows(yunxing_params_path("ui_tip_policy_channels.json"))
	return root
