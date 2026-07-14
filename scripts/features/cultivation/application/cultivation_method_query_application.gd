class_name CultivationMethodQueryApplication
extends RefCounted

const CatalogScript := preload(
	"res://scripts/features/cultivation/infrastructure/cultivation_method_catalog.gd"
)

static var _catalog := CatalogScript.new()


static func all_definitions() -> Array:
	return _catalog.all_definitions()


static func definition_by_id(method_id: String) -> Dictionary:
	return _catalog.definition_by_id(method_id)


static func family_by_id(family_id: String) -> Dictionary:
	return _catalog.family_by_id(family_id)
