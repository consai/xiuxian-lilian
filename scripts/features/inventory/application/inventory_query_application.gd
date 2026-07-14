class_name InventoryQueryApplication
extends RefCounted

const AbilityQueryApplicationScript := preload(
	"res://scripts/features/ability/application/ability_query_application.gd"
)
const CultivationMethodQueryApplicationScript := preload(
	"res://scripts/features/cultivation/application/cultivation_method_query_application.gd"
)
const ItemCatalogScript := preload(
	"res://scripts/features/inventory/infrastructure/item_catalog.gd"
)

static var _catalog := ItemCatalogScript.new()


static func all_definitions() -> Array:
	return _catalog.all_definitions(_ability_definitions(), _method_definitions())


static func definition_by_id(item_id: String) -> ItemDef:
	return _catalog.definition_by_id(item_id, _ability_definitions(), _method_definitions())


static func definition_by_fight_id(fight_id: int) -> ItemDef:
	return _catalog.definition_by_fight_id(fight_id, _ability_definitions(), _method_definitions())


static func display_name(item_id: String) -> String:
	var id := item_id.strip_edges()
	if id == "":
		return ""
	var definition := definition_by_id(id)
	return definition.name if definition != null else id


static func build_item_cfg(extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for definition_v in all_definitions():
		var definition := definition_v as ItemDef
		if not definition.has_fight_config():
			continue
		var fight_id := definition.fight_id
		var row := definition.to_fight_runtime_dict()
		out[fight_id] = row.duplicate(true)
		out[str(fight_id)] = row.duplicate(true)
	for key_v in extra.keys():
		var value_v: Variant = extra[key_v]
		if not value_v is Dictionary:
			continue
		var key := str(key_v)
		var entry := (value_v as Dictionary).duplicate(true)
		if key.is_valid_int():
			var fight_id := int(key)
			out[fight_id] = entry.duplicate(true)
			out[str(fight_id)] = entry.duplicate(true)
		else:
			out[key] = entry
	return out


static func _ability_definitions() -> Array:
	return AbilityQueryApplicationScript.all_definitions()


static func _method_definitions() -> Array:
	return CultivationMethodQueryApplicationScript.all_definitions()
