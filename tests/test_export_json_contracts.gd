extends SceneTree

const LiandanQueryApplicationScript := preload("res://scripts/features/alchemy/application/liandan_query_application.gd")
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const EquipCatalogScript := preload("res://scripts/zhandou/equip_catalog.gd")
const BuffCatalogScript := preload("res://scripts/zhandou/buff_catalog.gd")
const StringsZhScript := preload("res://scripts/core/strings_zh.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")
const LilianLocationCatalogScript := preload("res://scripts/lilian/lilian_location_catalog.gd")
const TupoCatalogScript := preload("res://scripts/sim/tupo_catalog.gd")
const WeituoCatalogScript := preload(
	"res://scripts/features/commission/infrastructure/weituo_catalog.gd"
)
const MonsterCatalogScript := preload(
	"res://scripts/features/battle/infrastructure/monster_catalog.gd"
)
const BattleConfigQueryApplicationScript := preload(
	"res://scripts/features/battle/application/battle_config_query_application.gd"
)
const CultivationMethodQueryApplicationScript := preload(
	"res://scripts/features/cultivation/application/cultivation_method_query_application.gd"
)


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
	var buff_ids := BuffCatalogScript.all_buff_ids()
	var first_buff := BuffCatalogScript.buff_by_id(str(buff_ids[0])) if not buff_ids.is_empty() else {}
	if buff_ids.size() != 14 or str(first_buff.get("id", "")) == "":
		errors.append("BuffCatalog must load all validated exported buffs")
	_check_type(errors, first_buff.get("modifiers"), TYPE_DICTIONARY, "buff.modifiers")
	_check_type(errors, first_buff.get("tick_effects"), TYPE_ARRAY, "buff.tick_effects")
	var commissions := WeituoCatalogScript.commissions()
	var commission := commissions.get("qingxin_herb_delivery_001", {}) as Dictionary
	_check_type(errors, commission.get("requirements"), TYPE_ARRAY, "weituo.requirements")
	_check_type(errors, commission.get("rewards"), TYPE_ARRAY, "weituo.rewards")
	_check_type(errors, commission.get("ui"), TYPE_DICTIONARY, "weituo.ui")
	_validate_weituo_references(errors, commissions)
	var raw_monsters := MonsterCatalogScript.all_monsters_snapshot()
	if raw_monsters.size() != 10:
		errors.append("MonsterCatalog must load all 10 validated exported monsters")
	var raw_wolf := raw_monsters.get("qinglan_wolf", {}) as Dictionary
	_check_type(errors, raw_wolf.get("dropitem"), TYPE_ARRAY, "monster.dropitem")
	_check_type(errors, raw_wolf.get("skills"), TYPE_ARRAY, "monster.skills")
	var runtime_wolf := BattleConfigQueryApplicationScript.monster_by_id("qinglan_wolf")
	_check_type(errors, runtime_wolf.get("attrs"), TYPE_DICTIONARY, "monster.attrs")
	if str(runtime_wolf.get("species", "")) != "beast" \
			or (runtime_wolf.get("skills", []) as Array) != [1, 0]:
		errors.append("battle monster query must preserve normalized runtime shape")

	var methods := CultivationMethodQueryApplicationScript.all_definitions()
	var method := methods.front() as Dictionary
	_check_type(errors, method.get("practice"), TYPE_DICTIONARY, "xiulian_method.practice")
	_check_type(errors, method.get("effects"), TYPE_ARRAY, "xiulian_method.effects")

	var recipes := LiandanQueryApplicationScript.all_recipes()
	var recipe := recipes.front() as Dictionary
	_check_type(errors, recipe.get("ingredients"), TYPE_ARRAY, "liandan.ingredients")
	_check_type(errors, recipe.get("products"), TYPE_DICTIONARY, "liandan.products")

	var lingguo: ItemDef = null
	for item_v in InventoryQueryApplicationScript.all_definitions():
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


func _validate_weituo_references(errors: PackedStringArray, commissions: Dictionary) -> void:
	var item_ids: Dictionary = {}
	for item_v in InventoryQueryApplicationScript.all_definitions():
		if item_v is ItemDef:
			item_ids[(item_v as ItemDef).id] = true
	var equip_ids: Dictionary = {}
	for equip_v in EquipCatalogScript.load_bundle().get("equips", []) as Array:
		if equip_v is EquipDef:
			equip_ids[(equip_v as EquipDef).id] = true
	var location_ids := LilianLocationCatalogScript.new().all_location_ids()
	for commission_id_v in commissions.keys():
		var commission_id := str(commission_id_v)
		var row := commissions[commission_id_v] as Dictionary
		for index in (row.get("requirements", []) as Array).size():
			var requirement := (row["requirements"] as Array)[index] as Dictionary
			var kind := str(requirement.get("kind", ""))
			if kind == "item":
				var item_id := str(requirement.get("id", ""))
				if not item_ids.has(item_id):
					errors.append("weituo.%s.requirements[%d].id unknown item %s" % [commission_id, index, item_id])
			elif kind == "lilian":
				var location_id := str(requirement.get("location_id", ""))
				if not location_ids.has(location_id):
					errors.append("weituo.%s.requirements[%d].location_id unknown location %s" % [commission_id, index, location_id])
		for index in (row.get("rewards", []) as Array).size():
			var reward := (row["rewards"] as Array)[index] as Dictionary
			var kind := str(reward.get("kind", ""))
			if kind == "item":
				var item_id := str(reward.get("id", ""))
				if not item_ids.has(item_id):
					errors.append("weituo.%s.rewards[%d].id unknown item %s" % [commission_id, index, item_id])
			elif kind == "equip":
				var equip_id := int(reward.get("id", -1))
				if not equip_ids.has(equip_id):
					errors.append("weituo.%s.rewards[%d].id unknown equip %d" % [commission_id, index, equip_id])
