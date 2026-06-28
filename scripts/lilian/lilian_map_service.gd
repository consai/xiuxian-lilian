class_name LilianMapService
extends RefCounted

const EnumLilianNodeTypeScript := preload("res://scripts/enum/enum_lilian_node_type.gd")
const LilianEventServiceScript := preload("res://scripts/lilian/lilian_event_service.gd")

const DEFAULT_MIDDLE_LAYERS := 8
const ROUTE_LANE_COUNT := 3
const MIN_ROUTE_CROSSES := 2
const MAX_ROUTE_CROSSES := 3
## 节点数不超过此值时历练路线图使用紧凑横向布局（新手三节点地图）。
const COMPACT_MAP_NODE_LIMIT := 3
const COMPACT_MAP_WIDTH := 480.0
const COMPACT_MAP_HEIGHT := 280.0
const COMPACT_NODE_GAP := 140.0


static func is_compact_map(nodes: Array) -> bool:
	return nodes.size() <= COMPACT_MAP_NODE_LIMIT


## 新手引导首次历练：起点 → 采集 → 怪物，单线三路节点。
static func generate_tutorial(location: Dictionary) -> Dictionary:
	var difficulty := maxi(1, int(location.get("min_difficulty", 1)))
	var nodes: Array = []
	var edges: Array = []
	var start_node := _make_node("start", 0, 0, EnumLilianNodeTypeScript.ID_START, difficulty, "启程")
	nodes.append(start_node)
	var gather_node := _make_node("tutorial_gather", 1, 0, EnumLilianNodeTypeScript.ID_GATHER, difficulty, "安全")
	gather_node["fixed_event_id"] = "tutorial_valley_herbs"
	nodes.append(gather_node)
	var battle_node := _make_node("tutorial_battle", 2, 0, EnumLilianNodeTypeScript.ID_BATTLE, difficulty, "普通")
	battle_node["label"] = "怪物"
	battle_node["fixed_event_id"] = "qinglan_wolf"
	nodes.append(battle_node)
	edges.append({"from": "start", "to": "tutorial_gather"})
	edges.append({"from": "tutorial_gather", "to": "tutorial_battle"})
	return {
		"nodes": nodes,
		"edges": edges,
		"start_node_id": str(start_node.get("id", "")),
	}


static func generate(location: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(seed_value, str(location.get("id", "")))
	var nodes: Array = []
	var edges: Array = []
	var start_node := _make_node("start", 0, 0, EnumLilianNodeTypeScript.ID_START, 1, "启程")
	nodes.append(start_node)
	var previous_layer_ids: Array = [str(start_node.get("id", ""))]
	var available_types := _available_node_types(location)
	var cross_layers := _pick_cross_layers(rng)
	for layer in range(1, DEFAULT_MIDDLE_LAYERS + 1):
		var layer_ids: Array = []
		for lane in ROUTE_LANE_COUNT:
			var type_id := _pick_node_type(available_types, layer, rng)
			var difficulty := _difficulty_for_layer(location, layer)
			var node_id := "node_%d_%d" % [layer, lane]
			nodes.append(_make_node(node_id, layer, lane, type_id, difficulty, _risk_for(type_id)))
			layer_ids.append(node_id)
		edges.append_array(_connect_layers(previous_layer_ids, layer_ids, cross_layers.has(layer - 1), rng))
		previous_layer_ids = layer_ids
	var exit_type := EnumLilianNodeTypeScript.ID_BOSS
	var exit_node := _make_node("exit", DEFAULT_MIDDLE_LAYERS + 1, 0, exit_type, _difficulty_for_layer(location, DEFAULT_MIDDLE_LAYERS + 1), _risk_for(exit_type))
	nodes.append(exit_node)
	edges.append_array(_connect_layers(previous_layer_ids, [str(exit_node.get("id", ""))], false, rng))
	return {
		"nodes": nodes,
		"edges": edges,
		"start_node_id": str(start_node.get("id", "")),
	}


static func next_node_ids(map_data: Dictionary, current_node_id: String, visited: Array) -> Array:
	var out: Array = []
	var visited_lookup := {}
	for id_v in visited:
		visited_lookup[str(id_v)] = true
	for edge_v in map_data.get("edges", []) as Array:
		if not edge_v is Dictionary:
			continue
		var edge := edge_v as Dictionary
		if str(edge.get("from", "")) != current_node_id:
			continue
		var to_id := str(edge.get("to", ""))
		if to_id != "" and not visited_lookup.has(to_id) and not out.has(to_id):
			out.append(to_id)
	return out


static func _pick_cross_layers(rng: RandomNumberGenerator) -> Array:
	var candidate_layers: Array = []
	for layer in range(1, DEFAULT_MIDDLE_LAYERS):
		candidate_layers.append(layer)
	var target_count := rng.randi_range(MIN_ROUTE_CROSSES, MAX_ROUTE_CROSSES)
	var out: Array = []
	while not candidate_layers.is_empty() and out.size() < target_count:
		var picked_index := rng.randi_range(0, candidate_layers.size() - 1)
		var layer := int(candidate_layers[picked_index])
		candidate_layers.remove_at(picked_index)
		var too_close := false
		for chosen_v in out:
			if absi(layer - int(chosen_v)) <= 1:
				too_close = true
				break
		if too_close:
			continue
		out.append(layer)
		if out.size() >= target_count:
			break
	out.sort()
	return out


static func node_by_id(nodes: Array, node_id: String) -> Dictionary:
	for node_v in nodes:
		if node_v is Dictionary and str((node_v as Dictionary).get("id", "")) == node_id:
			return (node_v as Dictionary).duplicate(true)
	return {}


static func is_reachable_to_exit(map_data: Dictionary) -> bool:
	var start_id := str(map_data.get("start_node_id", ""))
	if start_id == "":
		return false
	var stack: Array = [start_id]
	var seen := {}
	while not stack.is_empty():
		var current := str(stack.pop_back())
		if seen.has(current):
			continue
		seen[current] = true
		if current == "exit":
			return true
		for edge_v in map_data.get("edges", []) as Array:
			if edge_v is Dictionary and str((edge_v as Dictionary).get("from", "")) == current:
				stack.append(str((edge_v as Dictionary).get("to", "")))
	return false


static func _make_node(
		node_id: String,
		layer: int,
		lane: int,
		type_id: String,
		difficulty: int,
		risk_text: String
) -> Dictionary:
	return {
		"id": node_id,
		"layer": layer,
		"lane": lane,
		"type": type_id,
		"label": EnumLilianNodeTypeScript.label(type_id),
		"risk_text": risk_text,
		"difficulty": difficulty,
		"event_filter_tags": _event_filter_tags(type_id),
	}


static func _available_node_types(location: Dictionary) -> Array:
	var out: Array = []
	for event_v in LilianEventServiceScript.event_pool_for_location(location):
		if not event_v is Dictionary:
			continue
		var type_id := EnumLilianNodeTypeScript.from_event(event_v as Dictionary)
		# 首领节点仅出现在路线图终点，中途层不纳入可选类型。
		if type_id == EnumLilianNodeTypeScript.ID_BOSS:
			continue
		if not out.has(type_id):
			out.append(type_id)
	if out.is_empty():
		out.append(EnumLilianNodeTypeScript.ID_TRAVEL)
	return out


static func _pick_node_type(available_types: Array, layer: int, rng: RandomNumberGenerator) -> String:
	var weighted: Array = []
	for type_v in available_types:
		var type_id := str(type_v)
		var weight := _type_weight(type_id)
		if type_id == EnumLilianNodeTypeScript.ID_BOSS:
			weight = 0
		elif layer <= 1 and type_id == EnumLilianNodeTypeScript.ID_ELITE:
			weight = 0
		for _i in weight:
			weighted.append(type_id)
	if weighted.is_empty():
		weighted = available_types.duplicate()
	return str(weighted[rng.randi_range(0, weighted.size() - 1)])


static func _type_weight(type_id: String) -> int:
	match type_id:
		EnumLilianNodeTypeScript.ID_GATHER:
			return 5
		EnumLilianNodeTypeScript.ID_BATTLE:
			return 9
		EnumLilianNodeTypeScript.ID_RECOVER:
			return 4
		EnumLilianNodeTypeScript.ID_TRAVEL:
			return 4
		EnumLilianNodeTypeScript.ID_HAZARD:
			return 3
		EnumLilianNodeTypeScript.ID_DECISION:
			return 3
		EnumLilianNodeTypeScript.ID_TREASURE:
			return 2
		EnumLilianNodeTypeScript.ID_ELITE:
			return 3
		EnumLilianNodeTypeScript.ID_BOSS:
			return 2
		_:
			return 1


static func _difficulty_for_layer(location: Dictionary, layer: int) -> int:
	var min_difficulty := maxi(1, int(location.get("min_difficulty", 1)))
	var max_difficulty := int(location.get("max_difficulty", min_difficulty))
	if max_difficulty <= 0:
		max_difficulty = min_difficulty
	var layer_count := DEFAULT_MIDDLE_LAYERS + 1
	var ratio := clampf(float(layer - 1) / float(maxi(1, layer_count - 1)), 0.0, 1.0)
	return clampi(int(round(lerpf(float(min_difficulty), float(max_difficulty), ratio))), min_difficulty, max_difficulty)


static func _risk_for(type_id: String) -> String:
	match type_id:
		EnumLilianNodeTypeScript.ID_BATTLE:
			return "普通"
		EnumLilianNodeTypeScript.ID_ELITE:
			return "精英"
		EnumLilianNodeTypeScript.ID_BOSS:
			return "首领"
		EnumLilianNodeTypeScript.ID_HAZARD:
			return "险地"
		EnumLilianNodeTypeScript.ID_DECISION:
			return "奇遇"
		EnumLilianNodeTypeScript.ID_TREASURE:
			return "机缘"
		_:
			return "安全"


static func _event_filter_tags(type_id: String) -> Array:
	if type_id == EnumLilianNodeTypeScript.ID_TREASURE:
		return ["gather"]
	if type_id == EnumLilianNodeTypeScript.ID_REST:
		return ["recover"]
	return Array(EnumLilianNodeTypeScript.event_types_for(type_id))


static func _connect_layers(from_ids: Array, to_ids: Array, can_cross: bool, rng: RandomNumberGenerator) -> Array:
	var edges: Array = []
	if from_ids.size() == 1:
		var from_id := str(from_ids[0])
		for to_v in to_ids:
			edges.append({"from": from_id, "to": str(to_v)})
		return edges
	if to_ids.size() == 1:
		var to_id := str(to_ids[0])
		for from_v in from_ids:
			edges.append({"from": str(from_v), "to": to_id})
		return edges
	var lane_count := mini(from_ids.size(), to_ids.size())
	for lane in lane_count:
		edges.append({"from": str(from_ids[lane]), "to": str(to_ids[lane])})
	if not can_cross:
		return edges
	var first_cross_lane := rng.randi_range(0, maxi(0, lane_count - 2))
	var second_cross_lane := first_cross_lane + 1
	edges.append({"from": str(from_ids[first_cross_lane]), "to": str(to_ids[second_cross_lane])})
	edges.append({"from": str(from_ids[second_cross_lane]), "to": str(to_ids[first_cross_lane])})
	return edges


static func _mix_seed(seed_value: int, location_id: String) -> int:
	var hash_value := seed_value
	for i in location_id.length():
		hash_value = int(hash_value * 31 + location_id.unicode_at(i)) & 0x7fffffff
	return maxi(1, hash_value)
