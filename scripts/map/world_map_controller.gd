extends Control

signal city_travel_requested(city_id: String)
signal wilderness_entry_requested(region_id: String)
signal return_requested

const WorldMapServiceScript := preload("res://scripts/map/world_map_service.gd")
const LocationServiceScript := preload("res://scripts/expedition/location_service.gd")

const _ROUTE_COLORS := {
	"hidden": Color(0.48, 0.34, 0.2, 0.0),
	"discovered": Color(0.48, 0.34, 0.2, 0.72),
	"available": Color(0.45, 0.62, 0.35, 0.9),
	"blocked": Color(0.75, 0.25, 0.2, 0.8),
}

@onready var _map_canvas: Control = %MapCanvas
@onready var _routes_root: Control = $MapFrame/MapCanvas/Routes
@onready var _status_label: Label = $Header/Status
@onready var _selection_summary: Label = %Summary
@onready var _city_popup: Control = %CityDetailPopup
@onready var _wilderness_popup: Control = %WildernessDetailPopup
@onready var _location_popup: Control = $WildernessLocationDetailPopup
@onready var _travel_popup: Control = %TravelConfirmPopup

var _city_nodes: Dictionary = {}
var _region_nodes: Dictionary = {}
var _location_nodes: Dictionary = {}
var _route_lines: Dictionary = {}


func _ready() -> void:
	_collect_map_nodes()
	_connect_popups()
	refresh_map()
	TutorialService.game_event("tutorial.world_map_opened")


func refresh_map() -> void:
	var map_data := GameState.map_data()
	map_data = _sync_nearby_region_discovery(map_data)
	_update_header(map_data)
	_update_cities(map_data)
	_update_regions(map_data)
	_update_locations(map_data)
	_update_routes(map_data)
	_update_selection_panel(map_data)


func select_city(city_id: String) -> void:
	var map_data := GameState.map_data()
	var state := WorldMapServiceScript.city_visual_state(city_id, map_data)
	if state == "undiscovered" or state == "vanished":
		return
	var city := WorldMapServiceScript.city_by_id(city_id)
	if city.is_empty():
		return
	var preview := WorldMapServiceScript.build_travel_preview(
		str(map_data.get("current_city_id", "")),
		city_id,
		map_data
	)
	DataStore.map_runtime()["selected_city_id"] = city_id
	_update_selection_for_city(city, preview)
	if _city_popup.has_method("show_city"):
		_city_popup.call("show_city", city_id, city, preview)


func select_wilderness(region_id: String) -> void:
	var map_data := GameState.map_data()
	var region := WorldMapServiceScript.wilderness_region_by_id(region_id)
	if region.is_empty():
		return
	var can_enter := WorldMapServiceScript.can_enter_wilderness(region_id, map_data)
	var bounds := WorldMapServiceScript.region_difficulty_bounds(region)
	DataStore.map_runtime()["selected_region_id"] = region_id
	_update_selection_for_region(region, map_data)
	if _wilderness_popup.has_method("show_region"):
		_wilderness_popup.call(
			"show_region",
			region_id,
			region,
			WorldMapServiceScript.region_exploration(map_data, region_id),
			bool(can_enter.get("ok", false)),
			str(can_enter.get("error", "")),
			bounds
		)
func select_wilderness_location(location_id: String) -> void:
	var map_data := GameState.map_data()
	var current_city := str(map_data.get("current_city_id", ""))
	var state := WorldMapServiceScript.location_visual_state(location_id, map_data, current_city)
	if state != "discovered":
		return
	var row := WorldMapServiceScript.wilderness_location_by_id(location_id)
	if row.is_empty():
		return
	var can_enter := WorldMapServiceScript.can_enter_wilderness_location(location_id, map_data)
	DataStore.map_runtime()["selected_location_id"] = location_id
	if _location_popup.has_method("show_location"):
		_location_popup.call(
			"show_location",
			location_id,
			row,
			bool(can_enter.get("ok", false)),
			str(can_enter.get("error", "")),
			0
		)
	if location_id == "wild_wolf_valley":
		TutorialService.game_event("tutorial.wolf_valley_selected")


func request_travel(target_city_id: String) -> void:
	var map_data := GameState.map_data()
	var from_id := str(map_data.get("current_city_id", ""))
	var preview := WorldMapServiceScript.build_travel_preview(from_id, target_city_id, map_data)
	if not bool(preview.get("ok", false)):
		return
	DataStore.map_runtime()["pending_travel"] = preview.duplicate(true)
	confirm_travel()


func confirm_travel() -> void:
	var pending_v: Variant = DataStore.map_runtime().get("pending_travel", {})
	if not pending_v is Dictionary:
		return
	var pending := pending_v as Dictionary
	var path: Array = pending.get("path", []) as Array
	if path.is_empty():
		return
	var target_city_id := str(path.back())
	var result := GameState.travel_to_city(
		target_city_id,
		path,
		int(pending.get("total_days", 0))
	)
	if not bool(result.get("ok", false)):
		return
	city_travel_requested.emit(target_city_id)
	close_popups()
	refresh_map()


func enter_wilderness(region_id: String, options: Dictionary = {}) -> void:
	var map_data := GameState.map_data()
	var can_enter := WorldMapServiceScript.can_enter_wilderness(region_id, map_data)
	if not bool(can_enter.get("ok", false)):
		return
	var location_id := str(can_enter.get("location_id", ""))
	var clamped := WorldMapServiceScript.clamp_difficulty_options(
		location_id,
		int(options.get("min_difficulty", 1)),
		int(options.get("max_difficulty", 1))
	)
	if not bool(clamped.get("ok", false)):
		return
	DataStore.expedition_runtime()["difficulty_override"] = {
		"min_difficulty": int(clamped.get("min_difficulty", 1)),
		"max_difficulty": int(clamped.get("max_difficulty", 1)),
	}
	wilderness_entry_requested.emit(region_id)
	var nav := SceneManager.start_expedition(location_id)
	if not bool(nav.get("ok", false)):
		DataStore.expedition_runtime().erase("difficulty_override")


func enter_wilderness_location(location_id: String, options: Dictionary = {}) -> void:
	var map_data := GameState.map_data()
	var can_enter := WorldMapServiceScript.can_enter_wilderness_location(location_id, map_data)
	if not bool(can_enter.get("ok", false)):
		return
	var expedition_id := str(can_enter.get("location_id", ""))
	var clamped := WorldMapServiceScript.clamp_difficulty_options(
		expedition_id,
		int(options.get("min_difficulty", 1)),
		int(options.get("max_difficulty", 1))
	)
	if not bool(clamped.get("ok", false)):
		return
	DataStore.expedition_runtime()["difficulty_override"] = {
		"min_difficulty": int(clamped.get("min_difficulty", 1)),
		"max_difficulty": int(clamped.get("max_difficulty", 1)),
	}
	wilderness_entry_requested.emit(location_id)
	var nav := SceneManager.start_expedition(expedition_id)
	if not bool(nav.get("ok", false)):
		DataStore.expedition_runtime().erase("difficulty_override")


func close_popups() -> void:
	for popup in [_city_popup, _wilderness_popup, _location_popup, _travel_popup]:
		if popup != null and popup.has_method("hide_popup"):
			popup.call("hide_popup")
	DataStore.map_runtime()["pending_travel"] = {}


func _on_return_pressed() -> void:
	return_requested.emit()
	SceneManager.go_hub()


func _collect_map_nodes() -> void:
	for child in $MapFrame/MapCanvas/Cities.get_children():
		if child.has_signal("city_selected"):
			var city_id := str(child.city_id)
			_city_nodes[city_id] = child
			child.city_selected.connect(select_city)
	for child in $MapFrame/MapCanvas/WildernessRegions.get_children():
		if child.has_signal("region_selected"):
			var region_id := str(child.region_id)
			_region_nodes[region_id] = child
			child.region_selected.connect(select_wilderness)
	for child in $MapFrame/MapCanvas/WildernessLocations.get_children():
		if not child.has_signal("location_selected"):
			continue
		var location_id := str(child.location_id)
		_location_nodes[location_id] = child
		if not child.location_selected.is_connected(select_wilderness_location):
			child.location_selected.connect(select_wilderness_location)


func _connect_popups() -> void:
	if _city_popup.has_signal("travel_requested"):
		_city_popup.travel_requested.connect(request_travel)
	if _city_popup.has_signal("closed"):
		_city_popup.closed.connect(func(): DataStore.map_runtime()["selected_city_id"] = "")
	if _wilderness_popup.has_signal("enter_requested"):
		_wilderness_popup.enter_requested.connect(enter_wilderness)
	if _wilderness_popup.has_signal("closed"):
		_wilderness_popup.closed.connect(func(): DataStore.map_runtime()["selected_region_id"] = "")
	if _location_popup.has_signal("enter_requested"):
		_location_popup.enter_requested.connect(enter_wilderness_location)
	if _location_popup.has_signal("closed"):
		_location_popup.closed.connect(func(): DataStore.map_runtime()["selected_location_id"] = "")
	if _travel_popup.has_signal("confirmed"):
		_travel_popup.confirmed.connect(confirm_travel)
	if _travel_popup.has_signal("cancelled"):
		_travel_popup.cancelled.connect(close_popups)


func _update_header(map_data: Dictionary) -> void:
	var current_id := str(map_data.get("current_city_id", ""))
	var city_name := str(WorldMapServiceScript.city_by_id(current_id).get("name", current_id))
	_status_label.text = "当前位置：%s    第 %d 日    灵石 %d" % [city_name, GameState.day, GameState.ling_stones]


func _update_cities(map_data: Dictionary) -> void:
	for city_id in _city_nodes.keys():
		var node: Node = _city_nodes[city_id]
		var city := WorldMapServiceScript.city_by_id(str(city_id))
		if node.has_method("setup"):
			node.call("setup", city)
		if node.has_method("set_map_state"):
			node.call("set_map_state", WorldMapServiceScript.city_visual_state(str(city_id), map_data))


func _update_regions(map_data: Dictionary) -> void:
	for region_id in _region_nodes.keys():
		var node: Node = _region_nodes[region_id]
		var region := WorldMapServiceScript.wilderness_region_by_id(str(region_id))
		var polygon_v: Variant = region.get("polygon", [])
		if polygon_v is Array and (polygon_v as Array).size() >= 3:
			var center := _polygon_center(polygon_v as Array)
			node.position = center - node.size * 0.5
		if node.has_method("setup"):
			node.call(
				"setup",
				region,
				WorldMapServiceScript.region_exploration(map_data, str(region_id))
			)
		if node.has_method("set_map_state"):
			node.call("set_map_state", WorldMapServiceScript.region_visual_state(str(region_id), map_data))


func _update_locations(map_data: Dictionary) -> void:
	var current_city := str(map_data.get("current_city_id", ""))
	for child in $MapFrame/MapCanvas/WildernessLocations.get_children():
		var location_id := str(child.get("location_id")) if child.get("location_id") != null else ""
		if location_id == "":
			continue
		_location_nodes[location_id] = child
		var row := WorldMapServiceScript.wilderness_location_by_id(location_id)
		var pos_v: Variant = row.get("position", [])
		if pos_v is Array and (pos_v as Array).size() >= 2:
			child.position = Vector2(float(pos_v[0]), float(pos_v[1])) - child.size * 0.5
		if child.has_method("setup"):
			child.call("setup", row)
		if child.has_method("set_map_state"):
			var state := WorldMapServiceScript.location_visual_state(location_id, map_data, current_city)
			child.call("set_map_state", state)
			if state == "discovered" and location_id not in (map_data.get("discovered_locations", []) as Array):
				GameState.discover_map_node(location_id, "location")


func _update_routes(map_data: Dictionary) -> void:
	var current_city := str(map_data.get("current_city_id", ""))
	for route in WorldMapServiceScript.all_routes():
		if not route is Dictionary:
			continue
		var from_id := str((route as Dictionary).get("from", ""))
		var to_id := str((route as Dictionary).get("to", ""))
		var key := WorldMapServiceScript.route_key(from_id, to_id)
		var visual := WorldMapServiceScript.route_visual_state(key, map_data, current_city)
		var line: Line2D = _ensure_route_line(key)
		line.points = _route_points(from_id, to_id)
		line.default_color = _ROUTE_COLORS.get(visual, _ROUTE_COLORS["discovered"])
		line.visible = visual != "hidden"


func _update_selection_panel(map_data: Dictionary) -> void:
	var current_id := str(map_data.get("current_city_id", ""))
	var city := WorldMapServiceScript.city_by_id(current_id)
	if city.is_empty():
		_selection_summary.text = "尚未定位当前城市。"
		return
	var preview_lines: PackedStringArray = ["相邻路线："]
	for route in WorldMapServiceScript.all_routes():
		if not route is Dictionary:
			continue
		var from_id := str((route as Dictionary).get("from", ""))
		var to_id := str((route as Dictionary).get("to", ""))
		if from_id != current_id and to_id != current_id:
			continue
		var other := to_id if from_id == current_id else from_id
		if WorldMapServiceScript.city_visual_state(other, map_data) == "undiscovered":
			continue
		var preview := WorldMapServiceScript.build_travel_preview(current_id, other, map_data)
		if bool(preview.get("ok", false)):
			preview_lines.append("%s %d日" % [
				str(WorldMapServiceScript.city_by_id(other).get("name", other)),
				int(preview.get("total_days", 0)),
			])
	_update_selection_for_city(city, {"ok": true, "total_days": 0})
	_selection_summary.text = "%s\n\n%s\n\n%s" % [
		str(city.get("name", current_id)),
		str(city.get("desc", "")),
		"\n".join(preview_lines),
	]


func _update_selection_for_city(city: Dictionary, preview: Dictionary) -> void:
	_selection_summary.text = "%s\n\n%s" % [
		str(city.get("name", "")),
		str(city.get("desc", "")),
	]
	if bool(preview.get("ok", false)) and int(preview.get("total_days", 0)) > 0:
		_selection_summary.text += "\n\n预计路程：%d 日" % int(preview.get("total_days", 0))


func _update_selection_for_region(region: Dictionary, map_data: Dictionary) -> void:
	_selection_summary.text = "%s\n\n危险%s星 · 探索 %d%%" % [
		str(region.get("name", "")),
		str(region.get("danger", 1)),
		WorldMapServiceScript.region_exploration(map_data, str(region.get("id", ""))),
	]


func _ensure_route_line(route_key: String) -> Line2D:
	if _route_lines.has(route_key):
		return _route_lines[route_key]
	var line := Line2D.new()
	line.width = 6.0
	_routes_root.add_child(line)
	_route_lines[route_key] = line
	return line


func _route_points(from_id: String, to_id: String) -> PackedVector2Array:
	var from_city := WorldMapServiceScript.city_by_id(from_id)
	var to_city := WorldMapServiceScript.city_by_id(to_id)
	var from_pos_v: Variant = from_city.get("position", [])
	var to_pos_v: Variant = to_city.get("position", [])
	if not from_pos_v is Array or not to_pos_v is Array:
		return PackedVector2Array()
	return PackedVector2Array([
		Vector2(float(from_pos_v[0]), float(from_pos_v[1])),
		Vector2(float(to_pos_v[0]), float(to_pos_v[1])),
	])


func _polygon_center(points: Array) -> Vector2:
	var total := Vector2.ZERO
	if points.is_empty():
		return total
	for point_v in points:
		if point_v is Array and (point_v as Array).size() >= 2:
			total += Vector2(float(point_v[0]), float(point_v[1]))
	return total / float(points.size())


func _sync_nearby_region_discovery(map_data: Dictionary) -> Dictionary:
	var current_city := str(map_data.get("current_city_id", ""))
	var before: Array = (map_data.get("discovered_regions", []) as Array).duplicate()
	var synced := WorldMapServiceScript.discover_regions_near_city(map_data, current_city)
	var after: Array = synced.get("discovered_regions", []) as Array
	if after.size() != before.size():
		GameState.set_map_data(synced)
		return synced
	return map_data
