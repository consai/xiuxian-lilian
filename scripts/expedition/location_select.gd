extends Control

const LocationRowScene := preload("res://scenes/expedition/location_row.tscn")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")


func _ready() -> void:
	if ExpeditionState.active:
		_show_blocked("历练尚未结束，请先完成或结算当前历练。")
		return
	_refresh()


func _refresh() -> void:
	var title := %Title as Label
	var summary := %Summary as RichTextLabel
	var location_list := %LocationList as VBoxContainer
	title.text = "选择历练地点"
	summary.text = "气血 %.0f/%.0f   法力 %.0f/%.0f\n确认整备后出发；历练期间无法调整整备或存档。" % [
		GameState.hp, float(GameState.attrs.get(FightAttr.HP_MAX, 100.0)),
		GameState.mp, float(GameState.attrs.get(FightAttr.MP_MAX, 100.0)),
	]
	for child in location_list.get_children():
		child.queue_free()
	for location_v in LocationServiceScript.all_locations():
		var location := location_v as Dictionary
		var row := LocationRowScene.instantiate()
		location_list.add_child(row)
		row.setup(location, _on_start_pressed)


func _on_start_pressed(location_id: String) -> void:
	var started: Dictionary = ExpeditionState.start(location_id, GameState)
	if not bool(started.get("ok", false)):
		_show_blocked(str(started.get("error", "无法开始历练")))
		return
	get_tree().change_scene_to_file(ExpeditionState.LOOP_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GameState.HUB_SCENE)


func _show_blocked(message: String) -> void:
	var summary := %Summary as RichTextLabel
	summary.text = message
