extends Button

signal chosen(event_id: String)

var _event_id := ""


func _ready() -> void:
	pressed.connect(_on_pressed)


func setup(event: Dictionary) -> void:
	var title := %Title as Label
	var detail := %Detail as Label
	var risk := %Risk as Label
	var glyph := %ArtGlyph as Label
	_event_id = str(event.get("id", ""))
	title.text = str(event.get("name", ""))
	var enemy_name := ""
	if event.has("enemy"):
		enemy_name = str((event.get("enemy", {}) as Dictionary).get("name", ""))
	risk.text = str(event.get("risk_text", "未知"))
	detail.text = enemy_name if enemy_name != "" else str(event.get("desc", ""))
	glyph.text = _glyph_for_type(str(event.get("type", "")))


func _on_pressed() -> void:
	if _event_id != "":
		emit_signal("chosen", _event_id)


func _glyph_for_type(event_type: String) -> String:
	match event_type:
		"gather":
			return "♧"
		"travel":
			return "→"
		"recover":
			return "◉"
		"hazard":
			return "!"
		"decision_option":
			return "？"
		"battle", "elite", "boss":
			return "⚔"
		_:
			return "?"
