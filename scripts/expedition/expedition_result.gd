extends Control

var _result: Dictionary = {}


func _ready() -> void:
	var reason := str(get_tree().root.get_meta("expedition_exit_reason", "manual"))
	if ExpeditionState.active:
		_result = ExpeditionState.finish(reason)
		GameState.settle_expedition(_result)
	elif not ExpeditionState.last_finish_result.is_empty():
		_result = ExpeditionState.last_finish_result.duplicate(true)
	else:
		get_tree().change_scene_to_file(GameState.HUB_SCENE)
		return
	(%ReturnButton as Button).pressed.connect(_on_return_pressed)
	_render()


func _render() -> void:
	var title := %Title as Label
	var body := %Body as RichTextLabel
	var reason := str(_result.get("exit_reason", "manual"))
	var reason_text := "主动返程"
	if reason == "defeated":
		reason_text = "战败撤退"
	elif reason == "boss_complete":
		reason_text = "首领告捷"
	title.text = "历练结算 · %s" % reason_text
	var stats := _result.get("stats", {}) as Dictionary
	var lines: PackedStringArray = [
		"深入 %d 层，步数 %d，消耗 %d 日" % [
			int(stats.get("max_depth", 0)),
			int(stats.get("steps", 0)),
			int(_result.get("elapsed_days", 1)),
		],
		"战斗 %d 场，胜 %d，负 %d" % [
			int(stats.get("battles", 0)),
			int(stats.get("wins", 0)),
			int(stats.get("losses", 0)),
		],
		"最终气血 %.0f，法力 %.0f" % [float(_result.get("hp", 0.0)), float(_result.get("mp", 0.0))],
	]
	var loot_lines: PackedStringArray = []
	for reward_v in _result.get("loot", []) as Array:
		loot_lines.append(GameState.reward_label(reward_v as Dictionary))
	if not loot_lines.is_empty():
		lines.append("获得：" + "、".join(loot_lines))
	var lost_v: Variant = _result.get("loot_lost", [])
	if lost_v is Array and not (lost_v as Array).is_empty():
		var lost_labels: PackedStringArray = []
		for reward_v in lost_v as Array:
			lost_labels.append(GameState.reward_label(reward_v as Dictionary))
		lines.append("损失：" + "、".join(lost_labels))
	if reason == "defeated":
		lines.append("伤势加重，需回洞府静养。")
	body.text = "\n".join(lines)


func _on_return_pressed() -> void:
	get_tree().root.remove_meta("expedition_exit_reason")
	get_tree().change_scene_to_file(GameState.HUB_SCENE)
