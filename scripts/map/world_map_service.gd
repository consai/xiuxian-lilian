class_name WorldMapService
extends RefCounted

const DidianServiceScript := preload("res://scripts/lilian/didian_service.gd")
const GameTimeServiceScript := preload("res://scripts/sim/game_time_service.gd")

const ROUTE_KEY_SEP := "|"


static func starter_city_id() -> String:
	var meta := _world_map_meta()
	return str(meta.get("starter_city_id", "qingshi_market"))


static func all_city_ids() -> Array:
	return _config_manager().all_city_ids() if _config_manager() != null else []


static func city_by_id(city_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm == null:
		return {}
	return cm.city_by_id(city_id)


static func all_routes() -> Array:
	var cm := _config_manager()
	if cm == null:
		return []
	return cm.all_routes()


static func wilderness_region_by_id(region_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm == null:
		return {}
	return cm.wilderness_region_by_id(region_id)


static func all_wilderness_region_ids() -> Array:
	return _config_manager().all_wilderness_region_ids() if _config_manager() != null else []


static func wilderness_location_by_id(location_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm == null:
		return {}
	return cm.wilderness_location_by_id(location_id)


static func all_wilderness_location_ids() -> Array:
	return _config_manager().all_wilderness_location_ids() if _config_manager() != null else []


static func route_key(from_id: String, to_id: String) -> String:
	var ids := [from_id, to_id]
	ids.sort()
	return "%s%s%s" % [ids[0], ROUTE_KEY_SEP, ids[1]]


static func lilian_location_id_for_region(region_id: String) -> String:
	var region := wilderness_region_by_id(region_id)
	var configured := str(region.get("lilian_location_id", "")).strip_edges()
	if configured != "":
		return configured
	return region_id


static func lilian_location_id_for_wilderness_location(location_id: String) -> String:
	var row := wilderness_location_by_id(location_id)
	var configured := str(row.get("lilian_location_id", "")).strip_edges()
	if configured != "":
		return configured
	return location_id


static func can_enter_wilderness(region_id: String, map_data: Dictionary) -> Dictionary:
	if is_vanished(map_data, region_id):
		return {"ok": false, "error": "该区域已消失"}
	if not is_discovered(map_data, region_id, "region"):
		return {"ok": false, "error": "尚未发现该区域"}
	var current_city := str(map_data.get("current_city_id", ""))
	if not can_enter_region_from_city(region_id, current_city):
		return {"ok": false, "error": region_entry_city_hint(region_id)}
	var lilian_id := lilian_location_id_for_region(region_id)
	if lilian_id == "":
		return {"ok": false, "error": "尚未开放"}
	if not DidianServiceScript.has_location(lilian_id):
		return {"ok": false, "error": "尚未开放"}
	return {"ok": true, "location_id": lilian_id}


static func can_enter_region_from_city(region_id: String, city_id: String) -> bool:
	var region := wilderness_region_by_id(region_id)
	if region.is_empty():
		return false
	var near_cities: Array = region.get("near_city", []) as Array
	if near_cities.is_empty():
		return true
	for near_city_v in near_cities:
		if str(near_city_v) == city_id:
			return true
	return false


static func region_entry_city_hint(region_id: String) -> String:
	var region := wilderness_region_by_id(region_id)
	var names: PackedStringArray = []
	for near_city_v in region.get("near_city", []) as Array:
		var near_id := str(near_city_v)
		var city_name := str(city_by_id(near_id).get("name", near_id))
		if city_name not in names:
			names.append(city_name)
	if names.is_empty():
		return "当前城市无法进入该区域"
	return "需从%s进入" % "、".join(names)


static func can_enter_wilderness_location(location_id: String, map_data: Dictionary) -> Dictionary:
	if is_vanished(map_data, location_id):
		return {"ok": false, "error": "该地点已消失"}
	if not is_discovered(map_data, location_id, "location"):
		return {"ok": false, "error": "尚未发现该地点"}
	var lilian_id := lilian_location_id_for_wilderness_location(location_id)
	if lilian_id == "":
		return {"ok": false, "error": "尚未开放"}
	if not DidianServiceScript.has_location(lilian_id):
		return {"ok": false, "error": "尚未开放"}
	return {"ok": true, "location_id": lilian_id}


static func build_travel_preview(from_id: String, to_id: String, map_data: Dictionary) -> Dictionary:
	if from_id == to_id:
		return {
			"ok": true,
			"path": [from_id],
			"total_days": 0,
			"duration_label": GameTimeServiceScript.duration_label(0),
			"route_keys": [],
		}
	var result := _shortest_path(from_id, to_id, map_data)
	if not bool(result.get("ok", false)):
		return result
	return {
		"ok": true,
		"path": result.get("path", []),
		"total_days": int(result.get("total_days", 0)),
		"duration_label": GameTimeServiceScript.duration_label(int(result.get("total_days", 0))),
		"route_keys": result.get("route_keys", []),
	}


static func city_visual_state(city_id: String, map_data: Dictionary) -> String:
	if is_vanished(map_data, city_id):
		return "vanished"
	if str(map_data.get("current_city_id", "")) == city_id:
		return "current"
	if is_discovered(map_data, city_id, "city"):
		if city_id in _reachable_city_ids(map_data):
			return "reachable"
		return "discovered"
	return "undiscovered"


static func region_visual_state(region_id: String, map_data: Dictionary) -> String:
	if is_vanished(map_data, region_id):
		return "vanished"
	if is_discovered(map_data, region_id, "region"):
		return "discovered"
	return "undiscovered"


static func location_visual_state(location_id: String, map_data: Dictionary, current_city_id: String) -> String:
	if is_vanished(map_data, location_id):
		return "vanished"
	if is_discovered(map_data, location_id, "location"):
		return "discovered"
	var row := wilderness_location_by_id(location_id)
	if row.is_empty():
		return "undiscovered"
	var city := city_by_id(current_city_id)
	var city_pos_v: Variant = city.get("position", [])
	if city_pos_v is Array and (city_pos_v as Array).size() >= 2:
		var pos_v: Variant = row.get("position", [])
		if pos_v is Array and (pos_v as Array).size() >= 2:
			var radius := float(row.get("reveal_radius", 120))
			var city_pos := Vector2(float(city_pos_v[0]), float(city_pos_v[1]))
			var loc_pos := Vector2(float(pos_v[0]), float(pos_v[1]))
			if city_pos.distance_to(loc_pos) <= radius:
				return "discovered"
	return "undiscovered"


static func route_visual_state(route_key_value: String, map_data: Dictionary, current_city_id: String) -> String:
	var route_states: Dictionary = map_data.get("route_states", {}) as Dictionary
	var saved := str(route_states.get(route_key_value, ""))
	if saved == "blocked":
		return "blocked"
	var parts := route_key_value.split(ROUTE_KEY_SEP)
	if parts.size() != 2:
		return "hidden"
	if not is_route_discovered(map_data, str(parts[0]), str(parts[1])):
		return "hidden"
	if _is_route_traversable(str(parts[0]), str(parts[1]), map_data) and (
		str(parts[0]) == current_city_id or str(parts[1]) == current_city_id
	):
		return "available"
	return "discovered"


static func apply_starter_discovery(map_data: Dictionary) -> Dictionary:
	var out := map_data.duplicate(true)
	var starter := str(out.get("current_city_id", starter_city_id()))
	if starter == "":
		starter = starter_city_id()
	out["current_city_id"] = starter
	out = discover_map_node(out, starter, "city")
	for route in all_routes():
		if not route is Dictionary:
			continue
		var from_id := str((route as Dictionary).get("from", ""))
		var to_id := str((route as Dictionary).get("to", ""))
		if from_id == starter or to_id == starter:
			out = discover_route(out, from_id, to_id)
			var other := to_id if from_id == starter else from_id
			out = discover_map_node(out, other, "city")
	out = discover_regions_near_city(out, starter)
	for location_id in all_wilderness_location_ids():
		var row := wilderness_location_by_id(str(location_id))
		if bool(row.get("default_discovered", false)):
			out = discover_map_node(out, str(location_id), "location")
	return out


static func discover_regions_near_city(map_data: Dictionary, city_id: String) -> Dictionary:
	var out := map_data.duplicate(true)
	var cid := city_id.strip_edges()
	if cid == "":
		return out
	for region_id in all_wilderness_region_ids():
		var region := wilderness_region_by_id(str(region_id))
		for near_city_v in region.get("near_city", []) as Array:
			if str(near_city_v) == cid:
				out = discover_map_node(out, str(region_id), "region")
				break
	return out


static func discover_map_node(map_data: Dictionary, node_id: String, category: String) -> Dictionary:
	var out := map_data.duplicate(true)
	if node_id == "" or is_vanished(out, node_id):
		return out
	match category:
		"city":
			var cities: Array = (out.get("discovered_cities", []) as Array).duplicate()
			if node_id not in cities:
				cities.append(node_id)
			out["discovered_cities"] = cities
		"region":
			var regions: Array = (out.get("discovered_regions", []) as Array).duplicate()
			if node_id not in regions:
				regions.append(node_id)
			out["discovered_regions"] = regions
		"location":
			var locations: Array = (out.get("discovered_locations", []) as Array).duplicate()
			if node_id not in locations:
				locations.append(node_id)
			out["discovered_locations"] = locations
	return out


static func discover_route(map_data: Dictionary, from_id: String, to_id: String) -> Dictionary:
	var out := map_data.duplicate(true)
	var key := route_key(from_id, to_id)
	var route_states: Dictionary = (out.get("route_states", {}) as Dictionary).duplicate(true)
	if not route_states.has(key):
		var default_state := _default_route_state(from_id, to_id)
		route_states[key] = "discovered" if default_state != "blocked" else "blocked"
	out["route_states"] = route_states
	return out


static func discover_along_path(map_data: Dictionary, path: Array) -> Dictionary:
	var out := map_data.duplicate(true)
	for city_id_v in path:
		var city_id := str(city_id_v)
		out = discover_map_node(out, city_id, "city")
		out = discover_regions_near_city(out, city_id)
	for i in range(path.size() - 1):
		out = discover_route(out, str(path[i]), str(path[i + 1]))
	return out


static func is_discovered(map_data: Dictionary, node_id: String, category: String) -> bool:
	match category:
		"city":
			return node_id in (map_data.get("discovered_cities", []) as Array)
		"region":
			return node_id in (map_data.get("discovered_regions", []) as Array)
		"location":
			return node_id in (map_data.get("discovered_locations", []) as Array)
	return false


static func is_vanished(map_data: Dictionary, node_id: String) -> bool:
	return node_id in (map_data.get("vanished_nodes", []) as Array)


static func is_route_discovered(map_data: Dictionary, from_id: String, to_id: String) -> bool:
	var key := route_key(from_id, to_id)
	var route_states: Dictionary = map_data.get("route_states", {}) as Dictionary
	return route_states.has(key)


static func region_exploration(map_data: Dictionary, region_id: String) -> int:
	var exploration: Dictionary = map_data.get("region_exploration", {}) as Dictionary
	return clampi(int(exploration.get(region_id, 0)), 0, 100)


static func region_difficulty_bounds(region_data: Dictionary) -> Dictionary:
	var loc_min := maxi(1, int(region_data.get("min_difficulty", 1)))
	var loc_max := int(region_data.get("max_difficulty", 0))
	if loc_max <= 0:
		loc_max = loc_min
	return {"min": loc_min, "max": loc_max}


static func difficulty_tier_bounds(loc_min: int, loc_max: int, tier: int) -> Dictionary:
	loc_min = maxi(1, loc_min)
	loc_max = maxi(loc_min, loc_max)
	if loc_max <= loc_min:
		return {"min": loc_min, "max": loc_max}
	var span := float(loc_max - loc_min)
	var t_low := 0.0
	var t_high := 1.0
	match clampi(tier, 0, 2):
		0:
			t_low = 0.0
			t_high = 0.2
		1:
			t_low = 0.2
			t_high = 0.8
		2:
			t_low = 0.8
			t_high = 1.0
	var out_min := loc_min + int(floor(span * t_low))
	var out_max := loc_min + int(ceil(span * t_high))
	if tier <= 0:
		out_min = loc_min
	if tier >= 2:
		out_max = loc_max
	out_min = clampi(out_min, loc_min, loc_max)
	out_max = clampi(out_max, loc_min, loc_max)
	if out_max < out_min:
		out_max = out_min
	return {"min": out_min, "max": out_max}


static func clamp_difficulty_options(
	location_id: String,
	min_difficulty: int,
	max_difficulty: int
) -> Dictionary:
	var location := DidianServiceScript.by_id(location_id)
	if location.is_empty():
		return {"ok": false, "error": "未知地点"}
	var loc_min := maxi(1, int(location.get("min_difficulty", 1)))
	var loc_max := int(location.get("max_difficulty", 0))
	if loc_max <= 0:
		loc_max = loc_min
	var out_min := clampi(min_difficulty, loc_min, loc_max)
	var out_max := clampi(max_difficulty, loc_min, loc_max)
	if out_max < out_min:
		out_max = out_min
	return {
		"ok": true,
		"min_difficulty": out_min,
		"max_difficulty": out_max,
		"location_min": loc_min,
		"location_max": loc_max,
	}


static func _reachable_city_ids(map_data: Dictionary) -> Array:
	var current := str(map_data.get("current_city_id", ""))
	var out: Array = []
	for route in all_routes():
		if not route is Dictionary:
			continue
		var from_id := str((route as Dictionary).get("from", ""))
		var to_id := str((route as Dictionary).get("to", ""))
		if not _is_route_traversable(from_id, to_id, map_data):
			continue
		if from_id == current and to_id not in out:
			out.append(to_id)
		elif to_id == current and from_id not in out:
			out.append(from_id)
	return out


static func _shortest_path(from_id: String, to_id: String, map_data: Dictionary) -> Dictionary:
	var distances := {from_id: 0}
	var previous := {}
	var visited := {}
	var queue: Array = [from_id]
	while not queue.is_empty():
		queue.sort_custom(func(a, b): return int(distances.get(a, 1_000_000)) < int(distances.get(b, 1_000_000)))
		var current := str(queue.pop_front())
		if visited.has(current):
			continue
		visited[current] = true
		if current == to_id:
			break
		for edge in _neighbors(current, map_data):
			var next_id := str(edge.get("city_id", ""))
			var cost := int(edge.get("days", 1))
			var alt := int(distances.get(current, 1_000_000)) + cost
			if alt < int(distances.get(next_id, 1_000_000)):
				distances[next_id] = alt
				previous[next_id] = {"city_id": current, "route_key": str(edge.get("route_key", ""))}
				if not visited.has(next_id):
					queue.append(next_id)
	if not distances.has(to_id):
		return {"ok": false, "error": "无法抵达目标城市"}
	var path: Array = []
	var route_keys: Array = []
	var cursor := to_id
	while cursor != from_id:
		path.push_front(cursor)
		var prev_v: Variant = previous.get(cursor)
		if not prev_v is Dictionary:
			return {"ok": false, "error": "路径回溯失败"}
		var prev := prev_v as Dictionary
		var route_key_value := str(prev.get("route_key", ""))
		if route_key_value != "":
			route_keys.push_front(route_key_value)
		cursor = str(prev.get("city_id", ""))
	path.push_front(from_id)
	return {"ok": true, "path": path, "total_days": int(distances.get(to_id, 0)), "route_keys": route_keys}


static func _neighbors(city_id: String, map_data: Dictionary) -> Array:
	var out: Array = []
	for route in all_routes():
		if not route is Dictionary:
			continue
		var row := route as Dictionary
		var from_id := str(row.get("from", ""))
		var to_id := str(row.get("to", ""))
		var other := ""
		if from_id == city_id:
			other = to_id
		elif to_id == city_id:
			other = from_id
		else:
			continue
		if not _is_route_traversable(from_id, to_id, map_data):
			continue
		out.append({
			"city_id": other,
			"days": maxi(1, int(row.get("days", 1))),
			"route_key": route_key(from_id, to_id),
		})
	return out


static func _is_route_traversable(from_id: String, to_id: String, map_data: Dictionary) -> bool:
	var key := route_key(from_id, to_id)
	var route_states: Dictionary = map_data.get("route_states", {}) as Dictionary
	if str(route_states.get(key, "")) == "blocked":
		return false
	return _default_route_state(from_id, to_id) != "blocked"


static func _default_route_state(from_id: String, to_id: String) -> String:
	for route in all_routes():
		if not route is Dictionary:
			continue
		var row := route as Dictionary
		var a := str(row.get("from", ""))
		var b := str(row.get("to", ""))
		if (a == from_id and b == to_id) or (a == to_id and b == from_id):
			return str(row.get("default_state", "open"))
	return "open"


static func _world_map_meta() -> Dictionary:
	var cm := _config_manager()
	if cm == null or not cm.has_method("world_map_meta"):
		return {}
	return cm.world_map_meta()


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
