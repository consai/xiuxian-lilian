class_name CharacterCreationApplication
extends RefCounted

const CharacterCreationCatalogScript := preload(
	"res://scripts/sim/character_creation_catalog.gd"
)


static func query_choices(choice_type: String) -> Dictionary:
	var type_id := choice_type.strip_edges().to_lower()
	if not CharacterCreationCatalogScript.has_choice_type(type_id):
		return {
			"ok": false,
			"error_code": "unknown_character_choice_type",
			"message": "未知角色选项类型：%s" % choice_type,
			"value": [],
		}
	var result: Dictionary = CharacterCreationCatalogScript.query_choices(type_id)
	if not bool(result.get("ok", false)):
		return {
			"ok": false,
			"error_code": "invalid_character_creation_config",
			"message": str(result.get("message", "角色创建配置无效")),
			"value": [],
		}
	return {
		"ok": true,
		"value": (result.get("value", []) as Array).duplicate(true),
	}
