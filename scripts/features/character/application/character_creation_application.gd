class_name CharacterCreationApplication
extends RefCounted

const CharacterCreationCatalogScript := preload(
	"res://scripts/sim/character_creation_catalog.gd"
)
const CharacterSavedataStateScript := preload(
	"res://scripts/features/character/domain/character_savedata_state.gd"
)

const PROFILE_FIELDS := {
	"origin_id": CharacterSavedataStateScript.CHARACTER_ORIGIN_ID,
	"root_id": CharacterSavedataStateScript.CHARACTER_ROOT_ID,
	"talent_id": CharacterSavedataStateScript.CHARACTER_TALENT_ID,
}
const PROFILE_INPUT_FIELDS := ["origin_id", "root_id", "talent_id"]


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


static func apply_profile(savedata: Dictionary, profile: Dictionary) -> Dictionary:
	for profile_field in PROFILE_INPUT_FIELDS:
		if profile.has(profile_field) and not profile[profile_field] is String:
			return _profile_error(
				"invalid_profile_field_type",
				"角色档案字段 %s 必须为 String，实际为 %s"
				% [profile_field, type_string(typeof(profile[profile_field]))]
			)

	var current_slice := CharacterSavedataStateScript.coalesce_slice(savedata)
	if current_slice.is_empty():
		return _profile_error(
			"invalid_character_savedata",
			"角色存档切片无效"
		)

	var candidate := current_slice.duplicate(true)
	for profile_field in PROFILE_INPUT_FIELDS:
		var savedata_field: String = PROFILE_FIELDS[profile_field]
		candidate[savedata_field] = profile.get(profile_field, "")
	var root_id := str(profile.get("root_id", "")).strip_edges()
	if root_id != "":
		var next_aptitudes := (candidate[CharacterSavedataStateScript.APTITUDES] as Dictionary).duplicate(true)
		next_aptitudes[EnumPlayerAttr.ROOTS] = {root_id: 80.0}
		candidate[CharacterSavedataStateScript.APTITUDES] = next_aptitudes

	var prepared := CharacterSavedataStateScript.coalesce_slice(candidate)
	if prepared.is_empty():
		return _profile_error(
			"invalid_character_profile",
			"角色档案无法提交"
		)

	for profile_field in PROFILE_INPUT_FIELDS:
		var savedata_field: String = PROFILE_FIELDS[profile_field]
		savedata[savedata_field] = prepared[savedata_field]
	if root_id != "":
		savedata[CharacterSavedataStateScript.APTITUDES] = (
			prepared[CharacterSavedataStateScript.APTITUDES] as Dictionary
		).duplicate(true)
	return {
		"ok": true,
		"error_code": "",
		"message": "",
		"snapshot": prepared.duplicate(true),
	}


static func _profile_error(error_code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"message": message,
		"snapshot": {},
	}
