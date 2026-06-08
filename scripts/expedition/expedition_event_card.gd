extends Button

signal chosen(event_id: String)


func setup(event: Dictionary) -> void:
	var title := %Title as Label
	var detail := %Detail as Label
	var event_id := str(event.get("id", ""))
	title.text = str(event.get("name", ""))
	var enemy_name := ""
	if event.has("enemy"):
		enemy_name = str((event.get("enemy", {}) as Dictionary).get("name", ""))
	detail.text = "%s · %s\n%s" % [
		str(event.get("type", "")),
		str(event.get("risk_text", "")),
		enemy_name if enemy_name != "" else str(event.get("desc", "")),
	]
	pressed.connect(func() -> void: emit_signal("chosen", event_id))
