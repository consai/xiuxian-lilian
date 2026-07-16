extends SceneTree

const CharacterSavedataStateScript := preload(
	"res://scripts/features/character/domain/character_savedata_state.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults := CharacterSavedataStateScript.default_slice()
	assert(defaults["character_origin_id"] == "")
	assert(defaults["character_root_id"] == "")
	assert(defaults["character_talent_id"] == "")
	assert(defaults["foundations"] == {
		"roushen": 10.0, "lingli": 10.0, "shenshi": 10.0, "shenfa": 10.0,
	})
	assert(defaults["aptitudes"] == {
		"comprehension": 10.0, "will": 10.0, "fortune": 10.0,
		"roots": {"fire": 80.0},
	})
	(defaults["foundations"] as Dictionary)["roushen"] = 999.0
	assert(float((CharacterSavedataStateScript.default_slice()["foundations"] as Dictionary)["roushen"]) == 10.0)

	var missing := CharacterSavedataStateScript.apply_to_snapshot({"day": 3})
	assert(missing["character_origin_id"] == "")
	assert(missing["character_root_id"] == "")
	assert(missing["character_talent_id"] == "")
	assert((missing["aptitudes"] as Dictionary)["roots"] == {"fire": 80.0})
	var explicit_empty := CharacterSavedataStateScript.apply_to_snapshot({"aptitudes": {}})
	assert((explicit_empty["aptitudes"] as Dictionary)["roots"] == {})

	var raw := {
		"foundations": {
			"body": 21,
			"lingli": -5,
			"shenshi": "invalid",
			"agility": 14.5,
		},
		"aptitudes": {
			"comprehension": -3,
			"will": "invalid",
			"fortune": 22,
			"roots": {" Fire ": 130, "ICE": -2, "  ": 50},
		},
	}
	var before := raw.duplicate(true)
	var normalized := CharacterSavedataStateScript.apply_to_snapshot(raw)
	assert(raw == before)
	assert(normalized["foundations"] == {
		"roushen": 21.0, "lingli": 0.0, "shenshi": 10.0, "shenfa": 14.5,
	})
	assert(normalized["aptitudes"] == {
		"comprehension": 0.0, "will": 10.0, "fortune": 22.0,
		"roots": {"fire": 100.0, "ice": 0.0},
	})
	(normalized["aptitudes"] as Dictionary)["fortune"] = 999.0
	assert((raw["aptitudes"] as Dictionary)["fortune"] == 22)

	Engine.print_error_messages = false
	var invalid_id := CharacterSavedataStateScript.apply_to_snapshot({
		"character_origin_id": 12,
	})
	Engine.print_error_messages = true
	assert(invalid_id.is_empty())
	var errors := CharacterSavedataStateScript.collect_errors({
		"character_origin_id": 12,
	})
	assert(errors == PackedStringArray([
		"[character_savedata_state:invalid_field_type] field=character_origin_id expected=String actual=int",
	]))

	print("PASS: character savedata state ownership")
	quit(0)
