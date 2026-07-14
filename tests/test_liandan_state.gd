extends SceneTree

const LiandanStateScript := preload("res://scripts/features/alchemy/domain/liandan_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := {
		"level": 1,
		"xp": 0,
		"known_recipes": [
			"recipe.huiqi", "recipe.huiling", "recipe.liaoshang",
			"recipe.juqi", "recipe.qingmai", "recipe.guben",
		],
		"owned_furnaces": {"furnace.old_copper": {"durability": 30}},
		"equipped_furnace": "furnace.old_copper",
		"last_recipe": "recipe.huiqi",
		"last_strategy": "steady",
		"total_batches": 0,
		"recipe_mastery": {},
	}
	var first := LiandanStateScript.default_state()
	var second := LiandanStateScript.default_state()
	assert(first == expected)
	(first["known_recipes"] as Array).append("recipe.mutated")
	(first["owned_furnaces"] as Dictionary)["furnace.old_copper"]["durability"] = 0
	assert(second == expected)

	var valid := expected.duplicate(true)
	valid["level"] = 3
	valid["xp"] = 42
	valid["last_strategy"] = "supreme"
	valid["total_batches"] = 7
	valid["recipe_mastery"] = {"recipe.huiqi": 1000}
	var input_before := valid.duplicate(true)
	var prepared := LiandanStateScript.prepare(valid)
	assert(prepared == valid)
	(prepared["known_recipes"] as Array).append("recipe.copy_only")
	assert(valid == input_before)

	Engine.print_error_messages = false
	assert(not LiandanStateScript.validate([]))
	var missing := expected.duplicate(true)
	missing.erase("xp")
	var missing_before := missing.duplicate(true)
	assert(not LiandanStateScript.validate(missing))
	assert(missing == missing_before)
	var wrong_type := expected.duplicate(true)
	wrong_type["known_recipes"] = {}
	assert(not LiandanStateScript.validate(wrong_type))
	var missing_nested := expected.duplicate(true)
	missing_nested["owned_furnaces"] = {"furnace.old_copper": {}}
	assert(not LiandanStateScript.validate(missing_nested))
	var removed_strategy := expected.duplicate(true)
	removed_strategy["last_strategy"] = "standard"
	assert(not LiandanStateScript.validate(removed_strategy))
	var out_of_range := expected.duplicate(true)
	out_of_range["recipe_mastery"] = {"recipe.huiqi": 1001}
	assert(not LiandanStateScript.validate(out_of_range))
	Engine.print_error_messages = true

	print("PASS: liandan current-schema state contract")
	quit(0)
