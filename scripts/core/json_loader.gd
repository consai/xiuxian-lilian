class_name JsonLoader
extends RefCounted

const EXPORT_DIR := "res://data/exportjson"
## 运行参数子目录：时间/模拟/UI/规则/平衡等，与内容表分开放。
const YUNXING_PARAMS_DIR := "%s/yunxing_params" % EXPORT_DIR
const ZHANDOU_VFX_INDEX_PATH := "%s/zhandou_vfx_index.json" % EXPORT_DIR
const ZHANDOU_FLOAT_STYLES_PATH := "%s/zhandou_float_styles.json" % EXPORT_DIR
const ZHANDOU_FLOAT_STYLE_ROWS_PATH := "%s/zhandou_float_styles_styles.json" % EXPORT_DIR

const ExportTableReaderScript = preload("res://scripts/core/config/export_table_reader.gd")
const InventoryQueryApplicationScript = preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)

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


static func load_items() -> Array:
	# ConfigManager 迁移前的临时桥；物品读取、组合、alias 与索引只属于 Inventory。
	return InventoryQueryApplicationScript.all_definitions()


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
