extends Control

func _ready() -> void:
	var summary: Dictionary = SceneManager.take_payload(SceneManager.BREAKTHROUGH_SUMMARY)
	var bg := ColorRect.new()
	bg.color = Color("#f3dfb8")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.position = Vector2(340, 170)
	root.size = Vector2(600, 460)
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	var title := Label.new()
	title.text = "突破成功"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	root.add_child(title)
	var totals := summary.get("totals", {}) as Dictionary
	var body := Label.new()
	body.text = "%s → %s\n历时 %d 日\n历练 %d 次，胜 %d 次，负 %d 次\n累计获得物品 %d 件" % [
		str(summary.get("old_realm", "")), str(summary.get("new_realm", "")), int(summary.get("day", GameState.day)),
		int(totals.get("battles", 0)), int(totals.get("wins", 0)), int(totals.get("losses", 0)), int(totals.get("items_gained", 0))
	]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 24)
	root.add_child(body)
	var button := Button.new()
	button.text = "继续修行"
	button.pressed.connect(func() -> void: SceneManager.go_hub())
	root.add_child(button)
