extends Control

const EncounterServiceScript := preload("res://scripts/sim/encounter_service.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#ead6b5")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.position = Vector2(250, 90)
	root.size = Vector2(780, 620)
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	var title := Label.new()
	title.text = "选择今日历练"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	root.add_child(title)
	var note := Label.new()
	note.text = "历练会消耗一日。胜利获得战利品；战败会带伤返回洞府。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)
	for encounter_v in EncounterServiceScript.all_encounters():
		var encounter := encounter_v as Dictionary
		var panel := PanelContainer.new()
		var box := VBoxContainer.new()
		var label := Label.new()
		label.text = "%s · %s\n%s\n可能掉落：%s" % [
			str(encounter.get("risk", "")), str(encounter.get("name", "")),
			str(encounter.get("desc", "")), _reward_names(encounter)
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
		var button := Button.new()
		button.text = "前往挑战"
		button.pressed.connect(_start.bind(str(encounter.get("id", ""))))
		box.add_child(button)
		panel.add_child(box)
		root.add_child(panel)
	var back := Button.new()
	back.text = "返回洞府"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(GameState.HUB_SCENE))
	root.add_child(back)


func _start(encounter_id: String) -> void:
	GameState.start_encounter(encounter_id, get_tree())


func _reward_names(encounter: Dictionary) -> String:
	var names: PackedStringArray = []
	for reward_v in encounter.get("rewards", []) as Array:
		var reward := reward_v as Dictionary
		if str(reward.get("kind", "item")) == "equip":
			names.append(str(ConfigManager.equip_by_id(int(reward.get("id", -1))).get("name", "法宝")))
		else:
			names.append(ConfigManager.get_item_display_name(str(reward.get("id", ""))))
	return "、".join(names)
