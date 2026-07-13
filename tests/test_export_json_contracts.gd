extends SceneTree

const JsonLoaderScript := preload("res://scripts/core/json_loader.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const EquipCatalogScript := preload("res://scripts/zhandou/equip_catalog.gd")
const BuffCatalogScript := preload("res://scripts/zhandou/buff_catalog.gd")
const StringsZhScript := preload("res://scripts/core/strings_zh.gd")


func _init() -> void:
	var errors: PackedStringArray = []
	if JsonReaderScript.read_object("res://data/exportjson/weituo.json").is_empty():
		errors.append("JsonReader must load a valid exported object")
	if JsonLoaderScript._strip_null_fields("{name}") != "{name}":
		errors.append("template-like strings must remain strings")
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
