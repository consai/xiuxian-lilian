class_name LiandanQueryApplication
extends RefCounted

const LiandanCatalogScript := preload("res://scripts/features/alchemy/infrastructure/liandan_catalog.gd")
const InventoryQueryApplicationScript := preload("res://scripts/features/inventory/application/inventory_query_application.gd")

static var _catalog := LiandanCatalogScript.new()


static func all_recipes() -> Array:
	return _catalog.all_recipes(_known_item_ids())


static func all_strategies() -> Array:
	return _catalog.all_strategies(_known_item_ids())


static func recipe_by_id(recipe_id: String) -> Dictionary:
	return _catalog.recipe_by_id(recipe_id, _known_item_ids())


static func strategy_by_id(strategy_id: String) -> Dictionary:
	return _catalog.strategy_by_id(strategy_id, _known_item_ids())


static func furnace_by_id(furnace_id: String) -> Dictionary:
	return _catalog.furnace_by_id(furnace_id, _known_item_ids())


static func collect_errors() -> PackedStringArray:
	return _catalog.collect_errors()


static func _known_item_ids() -> Dictionary:
	var out: Dictionary = {}
	for definition_v in InventoryQueryApplicationScript.all_definitions():
		if definition_v is ItemDef:
			out[(definition_v as ItemDef).id] = true
	return out
