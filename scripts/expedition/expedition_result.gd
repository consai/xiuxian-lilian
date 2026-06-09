extends Control

const ExpeditionFlowService := preload("res://scripts/expedition/expedition_flow_service.gd")

var _result: Dictionary = {}


func _ready() -> void:
	var payload: Dictionary = SceneManager.peek_payload(SceneManager.EXPEDITION_RESULT)
	var reason: String = str(payload.get("reason", "manual"))
	if ExpeditionState.active:
		_result = ExpeditionFlowService.settle_active_expedition(reason)
	elif not GameState.last_expedition_summary.is_empty():
		_result = GameState.last_expedition_summary.duplicate(true)
	else:
		SceneManager.go_hub()
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
	elif reason == "journey_complete":
		reason_text = "历练完成"
	title.text = "历练结算 · %s" % reason_text
	var stats := _result.get("stats", {}) as Dictionary
	var lines: PackedStringArray = [
		"深入 %d 层，事件 %d 个，消耗 %d 日" % [
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
	var world_changes := _result.get("world_changes", []) as Array
	if not world_changes.is_empty():
		lines.append("\n世界变化：")
		for change_v in world_changes:
			var change := change_v as Dictionary
			lines.append("%s %s%d" % [
				_world_label(str(change.get("state", ""))),
				"+" if int(change.get("value", 0)) >= 0 else "",
				int(change.get("value", 0)),
			])
	var chronicle := _result.get("chronicle", []) as Array
	if not chronicle.is_empty():
		lines.append("\n历练纪要：")
		for line in chronicle:
			lines.append(str(line))
	body.text = "\n".join(lines)


func _on_return_pressed() -> void:
	SceneManager.take_payload(SceneManager.EXPEDITION_RESULT)
	SceneManager.go_hub()


func _world_label(key: String) -> String:
	return {"wolf_threat": "狼患", "sword_tomb_opening": "剑冢开启度", "sect_unrest": "宗门混乱度"}.get(key, key)
