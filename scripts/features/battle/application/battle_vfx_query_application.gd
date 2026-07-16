class_name BattleVfxQueryApplication
extends RefCounted

const CatalogScript := preload("res://scripts/features/battle/infrastructure/battle_vfx_catalog.gd")

static var _catalog: RefCounted


static func float_styles() -> Dictionary:
	return _get_catalog().float_styles()


static func index_snapshot() -> Dictionary:
	return _get_catalog().index_snapshot()


static func preset_ids() -> Array:
	return _get_catalog().preset_ids()


static func has_preset(preset_id: String) -> bool:
	return _get_catalog().has_preset(preset_id)


static func sequence(preset_id: String) -> Array:
	return _get_catalog().sequence(preset_id)


static func normalize_preset_id(ref: String) -> String:
	return CatalogScript.normalize_preset_id(ref)


static func collect_errors() -> PackedStringArray:
	return _get_catalog().collect_errors()


static func reload() -> bool:
	return _get_catalog().reload()


static func _get_catalog() -> RefCounted:
	if _catalog == null:
		_catalog = CatalogScript.new()
	return _catalog
