class_name RealmBalanceQueryApplication
extends RefCounted

const CatalogScript := preload("res://scripts/features/cultivation/infrastructure/realm_balance_catalog.gd")

static var _catalog := CatalogScript.new()


static func reload() -> bool:
	return _catalog.reload()


static func bundle() -> Dictionary:
	return _catalog.bundle()


static func collect_errors() -> PackedStringArray:
	return _catalog.collect_errors()


static func major_realms() -> Array:
	return _catalog.major_realms()
