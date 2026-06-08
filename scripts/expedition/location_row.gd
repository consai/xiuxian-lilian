extends PanelContainer

signal start_requested(location_id: String)


func setup(location: Dictionary, on_start: Callable) -> void:
	var title := %Name as Label
	var detail := %Detail as Label
	var button := %StartButton as Button
	title.text = str(location.get("name", ""))
	detail.text = "%s\n%s\n推荐：%s   危险度：%d" % [
		str(location.get("subtitle", "")),
		str(location.get("desc", "")),
		str(location.get("recommended_realm", "")),
		int(location.get("danger", 1)),
	]
	var location_id := str(location.get("id", ""))
	button.pressed.connect(func() -> void: on_start.call(location_id))
