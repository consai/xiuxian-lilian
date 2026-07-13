extends SceneTree


func _init() -> void:
	var rows: Array = [
		["damage", "10", "magic_atk", "500"],
		["shield", "12"],
		["heal_hp", "14"],
		["restore_mana", "16"],
		["attrschange", "physical_atk", "18", "20"],
		["buff", "buff_0001"],
		["hp", "22"],
		["mp", "24"],
		["pill_cultivation", "60"],
		["alchemy_mastery", "alchemy_fire_basic", "50"],
		["attrs", "hp_max", "120"],
	]
	var configs := ZhandouEffectCodec.parse_positional_config_effects(rows)
	var runtimes := ZhandouEffectCodec.parse_positional_effects(rows, {"magic_atk": 20.0})
	assert(configs.size() == 11, "all protected config effect ids must be preserved")
	assert(runtimes.size() == 11, "all protected runtime effect ids must be preserved")
	assert(configs[0]["effectId"] == "damage" and configs[2]["effectId"] == "heal_hp")
	assert(runtimes[0]["type"] == "damage" and runtimes[0]["value"] == 20.0)
	assert(runtimes[2]["type"] == "heal")
	assert(ZhandouEffectCodec.resolve_runtime_effect_value(runtimes[0], {"magic_atk": 20.0}) == 20.0)
	assert(configs[6]["effectId"] == "heal_hp" and configs[6]["sourceEffectId"] == "hp")
	assert(configs[7]["effectId"] == "restore_mana" and configs[7]["sourceEffectId"] == "mp")
	assert(runtimes[6]["type"] == "heal" and runtimes[6]["source_effect_id"] == "hp")
	assert(runtimes[7]["type"] == "restore_mp" and runtimes[7]["source_effect_id"] == "mp")
	for index in range(8, 11):
		assert(configs[index].has("op") and not configs[index].has("effectId"))
		assert(runtimes[index].has("op") and not runtimes[index].has("type"))
		assert(not runtimes[index].has("value"))
	assert(configs[9]["args"] == ["alchemy_fire_basic", "50"])
	assert(configs[10]["args"] == ["hp_max", "120"])
	print("test_zhandou_effect_codec: PASS")
	quit()
