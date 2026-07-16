extends SceneTree

const CharacterCreationApplicationScript := preload(
	"res://scripts/features/character/application/character_creation_application.gd"
)
const CharacterSavedataStateScript := preload(
	"res://scripts/features/character/domain/character_savedata_state.gd"
)
const DataStoreScript := preload("res://scripts/core/data_store.gd")


func _init() -> void:
	var defaults := CharacterSavedataStateScript.default_slice()
	var profile := {
		"origin_id": "origin.village",
		"root_id": "fire",
		"talent_id": "talent.focused",
	}
	var profile_before := profile.duplicate(true)
	var foundations_before := (defaults["foundations"] as Dictionary).duplicate(true)
	var applied := CharacterCreationApplicationScript.apply_profile(defaults, profile)
	assert(bool(applied.get("ok", false)))
	assert(profile == profile_before)
	assert(defaults["character_origin_id"] == "origin.village")
	assert(defaults["character_root_id"] == "fire")
	assert(defaults["character_talent_id"] == "talent.focused")
	assert((defaults["aptitudes"] as Dictionary)["roots"] == {"fire": 80.0})
	assert(defaults["foundations"] == foundations_before)
	assert(float((defaults["aptitudes"] as Dictionary)["comprehension"]) == 10.0)
	assert(defaults.keys().size() == 5)

	var returned := applied["snapshot"] as Dictionary
	returned["character_origin_id"] = "mutated"
	(returned["aptitudes"] as Dictionary)["roots"] = {"ice": 1.0}
	assert(defaults["character_origin_id"] == "origin.village")
	assert((defaults["aptitudes"] as Dictionary)["roots"] == {"fire": 80.0})

	var empty_root := CharacterSavedataStateScript.default_slice()
	(empty_root["aptitudes"] as Dictionary)["roots"] = {"wood": 37.0}
	var empty_result := CharacterCreationApplicationScript.apply_profile(empty_root, {
		"origin_id": "",
		"talent_id": "",
	})
	assert(bool(empty_result.get("ok", false)))
	assert((empty_root["aptitudes"] as Dictionary)["roots"] == {"wood": 37.0})
	assert(empty_root["character_root_id"] == "")

	var invalid := CharacterSavedataStateScript.default_slice()
	var invalid_before := invalid.duplicate(true)
	var failed := CharacterCreationApplicationScript.apply_profile(invalid, {
		"origin_id": 7,
		"root_id": "fire",
	})
	assert(not bool(failed.get("ok", true)))
	assert(failed.get("error_code") == "invalid_profile_field_type")
	assert((failed.get("snapshot", {}) as Dictionary).is_empty())
	assert(invalid == invalid_before)

	var invalid_store := CharacterSavedataStateScript.default_slice()
	invalid_store["character_talent_id"] = []
	var invalid_store_before := invalid_store.duplicate(true)
	Engine.print_error_messages = false
	var rejected := CharacterCreationApplicationScript.apply_profile(invalid_store, {})
	Engine.print_error_messages = true
	assert(not bool(rejected.get("ok", true)))
	assert(rejected.get("error_code") == "invalid_character_savedata")
	assert(invalid_store == invalid_store_before)

	var store := DataStoreScript.new()
	store.reset_savedata()
	var core_defaults := store.export_savedata()
	assert(not core_defaults.has("character_origin_id"))
	assert(not core_defaults.has("character_root_id"))
	assert(not core_defaults.has("character_talent_id"))
	var initialized := CharacterSavedataStateScript.apply_to_snapshot(core_defaults)
	assert(initialized["character_origin_id"] == "")
	assert(initialized["character_root_id"] == "")
	assert(initialized["character_talent_id"] == "")
	store.free()

	print("PASS: character profile application ownership")
	quit(0)
