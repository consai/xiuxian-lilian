extends SceneTree

const ConfigManagerScript := preload("res://scripts/core/config_manager.gd")


func _init() -> void:
	var config := ConfigManagerScript.new()
	for choice_type in ["origin", "root", "talent"]:
		var rows: Array = config.character_creation_choices(choice_type)
		assert(not rows.is_empty(), "%s choices must not be empty" % choice_type)
		for i in range(1, rows.size()):
			assert(int(rows[i - 1].get("sortOrder", 0)) <= int(rows[i].get("sortOrder", 0)))
	var origins := config.character_creation_choices("origin")
	var roots := config.character_creation_choices("root")
	assert(roots[0].get("starterSkillId") is Array)
	var original_id := str(origins[0].get("id", ""))
	origins[0]["id"] = "mutated"
	assert(str(config.character_creation_choices("origin")[0].get("id", "")) == original_id)
	config.free()
	print("PASS: character creation config queries")
	quit()
