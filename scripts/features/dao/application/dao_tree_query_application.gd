class_name DaoTreeQueryApplication
extends RefCounted

const CatalogScript := preload("res://scripts/features/dao/infrastructure/dao_tree_catalog.gd")

static var _catalog := CatalogScript.new()


static func reload() -> bool:
	return _catalog.reload()


static func snapshot() -> Dictionary:
	return _catalog.snapshot()


static func collect_errors() -> PackedStringArray:
	return _catalog.collect_errors()


static func metadata() -> Dictionary:
	return _catalog.metadata()


static func training() -> Dictionary:
	return _catalog.training()


static func attributes() -> Dictionary:
	return _catalog.attributes()


static func all_skills() -> Array:
	return _catalog.all_skills()


static func domains() -> Array:
	return _catalog.domains()


static func domain_groups() -> Array:
	return _catalog.domain_groups()


static func realms() -> Array:
	return _catalog.realms()


static func skill_by_id(skill_id: String) -> Dictionary:
	return _catalog.skill_by_id(skill_id)


static func skills_in_domain(domain_id: String) -> Array:
	return _catalog.skills_in_domain(domain_id)


static func skills_in_realm(realm_id: String) -> Array:
	return _catalog.skills_in_realm(realm_id)


static func domain_by_id(domain_id: String) -> Dictionary:
	return _catalog.domain_by_id(domain_id)


static func realm_by_id(realm_id: String) -> Dictionary:
	return _catalog.realm_by_id(realm_id)


static func realm_display_name(realm_id: String) -> String:
	return _catalog.realm_display_name(realm_id)


static func realm_order(realm_id: String) -> int:
	return _catalog.realm_order(realm_id)
