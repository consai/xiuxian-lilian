extends SceneTree

const CharacterCreationApplicationScript := preload(
	"res://scripts/features/character/application/character_creation_application.gd"
)
const CharacterCreationCatalogScript := preload(
	"res://scripts/sim/character_creation_catalog.gd"
)


func _init() -> void:
	for choice_type in ["origin", "root", "talent"]:
		var result: Dictionary = CharacterCreationApplicationScript.query_choices(choice_type)
		assert(bool(result.get("ok", false)), "%s choices query must succeed" % choice_type)
		var rows: Array = result.get("value", []) as Array
		assert(not rows.is_empty(), "%s choices must not be empty" % choice_type)
		for i in range(1, rows.size()):
			assert(int(rows[i - 1].get("sortOrder", 0)) <= int(rows[i].get("sortOrder", 0)))

	var origins_result: Dictionary = CharacterCreationApplicationScript.query_choices("origin")
	var roots_result: Dictionary = CharacterCreationApplicationScript.query_choices("root")
	var origins: Array = origins_result.get("value", []) as Array
	var roots: Array = roots_result.get("value", []) as Array
	assert(roots[0].get("starterSkillId") is Array)
	var original_id := str(origins[0].get("id", ""))
	origins[0]["id"] = "mutated"
	var fresh_result: Dictionary = CharacterCreationApplicationScript.query_choices("origin")
	var fresh_origins: Array = fresh_result.get("value", []) as Array
	assert(str(fresh_origins[0].get("id", "")) == original_id)

	var unknown: Dictionary = CharacterCreationApplicationScript.query_choices("mystery")
	assert(not bool(unknown.get("ok", true)))
	assert(str(unknown.get("error_code", "")) == "unknown_character_choice_type")
	assert((unknown.get("value", []) as Array).is_empty())

	var invalid_errors := CharacterCreationCatalogScript.validate_table(
		{
			"broken": {
				"id": "different",
				"name": "",
				"description": 1,
				"sortOrder": 1.5,
				"enabled": "yes",
				"iconPath": "",
				"passiveid": "",
			},
		},
		"origin",
		"fixture://character_origins.json"
	)
	assert(invalid_errors.size() >= 7)
	assert(str(invalid_errors[0]).begins_with("[character_creation_catalog:"))
	assert(str(invalid_errors[0]).contains("file=fixture://character_origins.json"))

	print("PASS: character creation application config queries")
	quit()
