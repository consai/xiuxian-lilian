extends SceneTree

const LiandanCatalogScript := preload("res://scripts/features/alchemy/infrastructure/liandan_catalog.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")
const InventoryQueryApplicationScript := preload("res://scripts/features/inventory/application/inventory_query_application.gd")


func _init() -> void:
	Engine.print_error_messages = false
	var roots := _roots()
	var item_ids := _known_item_ids()
	var catalog = LiandanCatalogScript.new()
	_check(catalog.reload_from_roots(roots.settings, roots.furnaces, roots.recipes, roots.strategies, item_ids), "valid roots must load")
	_check(catalog.snapshot(item_ids).get("schema_version") == 1, "schema version must be preserved")
	_check(catalog.all_recipes(item_ids).size() == 6, "catalog must load six recipes")
	_check(catalog.all_strategies(item_ids).size() == 2, "catalog must load two strategies")
	_check(catalog.furnace_by_id("furnace.old_copper", item_ids).get("max_durability") == 30, "furnace lookup must work")
	var recipe := catalog.recipe_by_id("recipe.huiqi", item_ids)
	_check((recipe.get("ingredients", []) as Array).size() == 1, "ingredients must decode from export JSON")
	_check((recipe.get("products", {}) as Dictionary).get("supreme") == "items_HuiQiDan_Supreme", "products must decode from export JSON")
	recipe["name"] = "mutated"
	_check(catalog.recipe_by_id("recipe.huiqi", item_ids).get("name") == "回气丹方", "queries must deep clone")

	var bad_root := roots.duplicate(true)
	_check(not catalog.reload_from_roots([], bad_root.furnaces, bad_root.recipes, bad_root.strategies, item_ids), "bad root must reject")
	_check(_has_error(catalog.collect_errors(), "invalid_root"), "bad root must have stable error")
	_check(catalog.recipe_by_id("recipe.huiqi", item_ids).get("name") == "回气丹方", "failed reload must retain previous snapshot")

	var first_fail = LiandanCatalogScript.new()
	_check(not first_fail.reload_from_roots({}, bad_root.furnaces, bad_root.recipes, bad_root.strategies, item_ids), "first invalid load must fail")
	_check(first_fail.snapshot(item_ids).is_empty(), "first invalid load must expose no snapshot")

	var bad_row := roots.duplicate(true)
	(bad_row.recipes["recipe.huiqi"] as Dictionary)["ingredients"] = "[]"
	_check(not catalog.reload_from_roots(bad_row.settings, bad_row.furnaces, bad_row.recipes, bad_row.strategies, item_ids), "invalid recipe row must reject")
	_check(_has_error(catalog.collect_errors(), "ingredients_invalid"), "bad ingredients must have stable error")

	var bad_reference := roots.duplicate(true)
	var ingredients := JSON.parse_string(str((bad_reference.recipes["recipe.huiqi"] as Dictionary)["ingredients"])) as Array
	((ingredients[0] as Dictionary)["options"] as Array)[0] = {"id": "", "quality": 1}
	(bad_reference.recipes["recipe.huiqi"] as Dictionary)["ingredients"] = JSON.stringify(ingredients)
	_check(not catalog.reload_from_roots(bad_reference.settings, bad_reference.furnaces, bad_reference.recipes, bad_reference.strategies, item_ids), "invalid item reference must reject")
	_check(_has_error(catalog.collect_errors(), "ingredient_reference_invalid"), "bad reference must have stable error")

	var unknown_reference := roots.duplicate(true)
	var unknown_ingredients := JSON.parse_string(str((unknown_reference.recipes["recipe.huiqi"] as Dictionary)["ingredients"])) as Array
	((unknown_ingredients[0] as Dictionary)["options"] as Array)[0] = {"id": "items_not_real", "quality": 1}
	(unknown_reference.recipes["recipe.huiqi"] as Dictionary)["ingredients"] = JSON.stringify(unknown_ingredients)
	_check(not catalog.reload_from_roots(unknown_reference.settings, unknown_reference.furnaces, unknown_reference.recipes, unknown_reference.strategies, item_ids), "unknown item reference must reject")
	_check(_has_error(catalog.collect_errors(), "ingredient_reference_unknown"), "unknown reference must have stable error")

	print("PASS: liandan catalog contract")
	quit(0)


func _roots() -> Dictionary:
	return {
		"settings": JsonReaderScript.read_variant("res://data/exportjson/liandan.json"),
		"furnaces": JsonReaderScript.read_variant("res://data/exportjson/liandan_furnaces.json"),
		"recipes": JsonReaderScript.read_variant("res://data/exportjson/liandan_recipes.json"),
		"strategies": JsonReaderScript.read_variant("res://data/exportjson/liandan_strategies.json"),
	}


func _known_item_ids() -> Dictionary:
	var out: Dictionary = {}
	for definition_v in InventoryQueryApplicationScript.all_definitions():
		if definition_v is ItemDef:
			out[(definition_v as ItemDef).id] = true
	return out


func _has_error(errors: PackedStringArray, code: String) -> bool:
	for message in errors:
		if message.contains(":" + code + "]"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
