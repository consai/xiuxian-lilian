extends SceneTree

const JsonLoaderScript := preload("res://scripts/core/json_loader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const EquipCatalogScript := preload("res://scripts/zhandou/equip_catalog.gd")
const BuffCatalogScript := preload("res://scripts/zhandou/buff_catalog.gd")
const StringsZhScript := preload("res://scripts/core/strings_zh.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const TupoCatalogScript := preload("res://scripts/sim/tupo_catalog.gd")


func _init() -> void:
	var errors: PackedStringArray = []
	if JsonReaderScript.read_object("res://data/exportjson/weituo.json").is_empty():
		errors.append("JsonReader must load a valid exported object")
	var templates := ExportTableReaderScript.read_row_array(
		"res://data/exportjson/item_generated_learning_books.json"
	)
	if templates.is_empty() or str(templates[0].get("name_template", "")) != "{name}":
		errors.append("template-like strings must remain strings")
	var tupo_settings := TupoCatalogScript.load_rules()
	if not tupo_settings.get("schema_version") is int \
			or not tupo_settings.get("consume_pills_on_fail") is bool:
		errors.append("export settings must coerce int and bool values")
	var component_caps := tupo_settings.get("component_caps", {}) as Dictionary
	if int(component_caps.get("cultivation", 0)) != 400:
		errors.append("TupoCatalog must combine typed component caps")
	var breakthroughs := tupo_settings.get("major_breakthroughs", {}) as Dictionary
	var first_breakthrough := breakthroughs.get("lianqi_to_zhuji", {}) as Dictionary
	var tiers := first_breakthrough.get("tiers", []) as Array
	if tiers.is_empty() or not tiers[0] is Dictionary:
		errors.append("TupoCatalog must decode breakthrough tiers")
	else:
		var first_tier := tiers[0] as Dictionary
		_check_type(errors, first_tier.get("perks"), TYPE_ARRAY, "tupo.tier.perks")
		if not first_tier.get("success_rate") is int \
				and not first_tier.get("success_rate") is float:
			errors.append("tupo.tier.success_rate expected numeric value")
	var story_nodes := ExportTableReaderScript.read_keyed_rows(
		"res://data/exportjson/gushi_prologue_tutorial_nodes.json"
	)
	if (story_nodes.get("empty_cave", {}) as Dictionary).has("speaker"):
		errors.append("null object fields must be removed")
	if StringsZhScript.getp("hover.target.self") != "自身":
		errors.append("StringsZh must load exported key/value rows and normalize dotted paths")
	var equips := EquipCatalogScript.load_bundle().get("equips", []) as Array
	if equips.is_empty() or not equips[0] is EquipDef or (equips[0] as EquipDef).id <= 0:
		errors.append("EquipCatalog must load typed exported equips")
	var buffs := BuffCatalogScript.load_all()
	if buffs.is_empty() or not buffs[0] is BuffDef or (buffs[0] as BuffDef).id == "":
		errors.append("BuffCatalog must load typed exported buffs")
	var weituo := JsonLoaderScript.load_weituo_bundle()
	var commission := (weituo.get("weituo", {}) as Dictionary).get("qingxin_herb_delivery_001", {}) as Dictionary
	_check_type(errors, commission.get("requirements"), TYPE_ARRAY, "weituo.requirements")
	_check_type(errors, commission.get("rewards"), TYPE_ARRAY, "weituo.rewards")
	_check_type(errors, commission.get("ui"), TYPE_DICTIONARY, "weituo.ui")

	var methods := JsonLoaderScript.load_xiulian_methods_bundle().get("methods", []) as Array
	var method := methods.front() as Dictionary
	_check_type(errors, method.get("practice"), TYPE_DICTIONARY, "xiulian_method.practice")
	_check_type(errors, method.get("effects"), TYPE_ARRAY, "xiulian_method.effects")

	var recipes := JsonLoaderScript.load_liandan_bundle().get("recipes", []) as Array
	var recipe := recipes.front() as Dictionary
	_check_type(errors, recipe.get("ingredients"), TYPE_ARRAY, "liandan.ingredients")
	_check_type(errors, recipe.get("products"), TYPE_DICTIONARY, "liandan.products")

	var lingguo: ItemDef = null
	for item_v in JsonLoaderScript.load_items():
		if item_v is ItemDef and (item_v as ItemDef).id == "items_LingGuo":
			lingguo = item_v as ItemDef
			break
	if lingguo == null or lingguo.use_effect.is_empty() \
			or not lingguo.use_effect[0] is Dictionary \
			or str((lingguo.use_effect[0] as Dictionary).get("op", "")) != "hp":
		errors.append("item positional use_effect must normalize to op/args")

	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: export JSON complex cells")
	quit(0)


func _check_type(errors: PackedStringArray, value: Variant, expected: Variant.Type, label: String) -> void:
	if typeof(value) != expected:
		errors.append("%s expected %s, got %s" % [label, type_string(expected), type_string(typeof(value))])
