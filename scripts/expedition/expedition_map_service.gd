class_name ExpeditionMapService
extends RefCounted

const EnumExpeditionNodeTypeScript := preload("res://scripts/enum/enum_expedition_node_type.gd")
const ExpeditionEventServiceScript := preload("res://scripts/expedition/expedition_event_service.gd")

const DEFAULT_MIDDLE_LAYERS := 5
const MIN_LANES := 2
const MAX_LANES := 4


static func generate(location: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(seed_value, str(location.get("id", "")))
	var nodes: Array = []
	var edges: Array = []
	var start_node := _make_node("start", 0, 0, EnumExpeditionNodeTypeScript.ID_START, 1, "启程")
	nodes.append(start_node)
	var previous_layer_ids: Array = [str(start_node.get("id", ""))]
	var available_types := _available_node_types(location)
	for layer in range(1, DEFAULT_MIDDLE_LAYERS + 1):
		var lane_count := rng.randi_range(MIN_LANES, MAX_LANES)
		var layer_ids: Array = []
		for lane in lane_count:
			var type_id := _pick_node_type(available_types, layer, rng)
			var difficulty := _difficulty_for_layer(location, layer)
			var node_id := "node_%d_%d" % [layer, lane]
			nodes.append(_make_node(node_id, layer, lane, type_id, difficulty, _risk_for(type_id)))
			layer_ids.append(node_id)
		edges.append_array(_connect_layers(previous_layer_ids, layer_ids, rng))
		previous_layer_ids = layer_ids
	var exit_type := EnumExpeditionNodeTypeScript.ID_BOSS if available_types.has(EnumExpeditionNodeTypeScript.ID_BOSS) else EnumExpeditionNodeTypeScript.ID_TREASURE
	var exit_node := _make_node("exit", DEFAULT_MIDDLE_LAYERS + 1, 0, exit_type, _difficulty_for_layer(location, DEFAULT_MIDDLE_LAYERS + 1), _risk_for(exit_type))
	nodes.append(exit_node)
	edges.append_array(_connect_layers(previous_layer_ids, [str(exit_node.get("id", ""))], rng))
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
		"label": EnumExpeditionNodeTypeScript.label(type_id),
		"risk_text": risk_text,
		"difficulty": difficulty,
		"event_filter_tags": _event_filter_tags(type_id),
	}


static func _available_node_types(location: Dictionary) -> Array:
	var out: Array = []
	for event_v in ExpeditionEventServiceScript.event_pool_for_location(location):
		if not event_v is Dictionary:
			continue
		var type_id := EnumExpeditionNodeTypeScript.from_event(event_v as Dictionary)
		if not out.has(type_id):
			out.append(type_id)
	if out.is_empty():
		out.append(EnumExpeditionNodeTypeScript.ID_TRAVEL)
	return out


static func _pick_node_type(available_types: Array, layer: int, rng: RandomNumberGenerator) -> String:
	var weighted: Array = []
	for type_v in available_types:
		var type_id := str(type_v)
		var weight := _type_weight(type_id)
		if layer <= 1 and type_id in [EnumExpeditionNodeTypeScript.ID_ELITE, EnumExpeditionNodeTypeScript.ID_BOSS]:
			weight = 0
		for _i in weight:
			weighted.append(type_id)
	if weighted.is_empty():
		weighted = available_types.duplicate()
	return str(weighted[rng.randi_range(0, weighted.size() - 1)])


static func _type_weight(type_id: String) -> int:
	match type_id:
		EnumExpeditionNodeTypeScript.ID_GATHER:
			return 7
		EnumExpeditionNodeTypeScript.ID_BATTLE:
			return 5
		EnumExpeditionNodeTypeScript.ID_RECOVER:
			return 4
		EnumExpeditionNodeTypeScript.ID_TRAVEL:
			return 4
		EnumExpeditionNodeTypeScript.ID_HAZARD:
			return 3
		EnumExpeditionNodeTypeScript.ID_DECISION:
			return 3
		EnumExpeditionNodeTypeScript.ID_TREASURE:
			return 2
		EnumExpeditionNodeTypeScript.ID_ELITE:
			return 2
		EnumExpeditionNodeTypeScript.ID_BOSS:
			return 1
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
		EnumExpeditionNodeTypeScript.ID_BATTLE:
			return "普通"
		EnumExpeditionNodeTypeScript.ID_ELITE:
			return "精英"
		EnumExpeditionNodeTypeScript.ID_BOSS:
			return "首领"
		EnumExpeditionNodeTypeScript.ID_HAZARD:
			return "险地"
		EnumExpeditionNodeTypeScript.ID_DECISION:
			return "奇遇"
		EnumExpeditionNodeTypeScript.ID_TREASURE:
			return "机缘"
		_:
			return "安全"


static func _event_filter_tags(type_id: String) -> Array:
	if type_id == EnumExpeditionNodeTypeScript.ID_TREASURE:
		return ["gather"]
	if type_id == EnumExpeditionNodeTypeScript.ID_REST:
		return ["recover"]
	return Array(EnumExpeditionNodeTypeScript.event_types_for(type_id))


static func _connect_layers(from_ids: Array, to_ids: Array, rng: RandomNumberGenerator) -> Array:
	var edges: Array = []
	var incoming := {}
	for from_v in from_ids:
		var from_id := str(from_v)
		var connection_count := mini(to_ids.size(), rng.randi_range(1, 2))
		var used: Array = []
		for _i in connection_count:
			var to_id := str(to_ids[rng.randi_range(0, to_ids.size() - 1)])
			if used.has(to_id):
				continue
			used.append(to_id)
			incoming[to_id] = true
			edges.append({"from": from_id, "to": to_id})
	for to_v in to_ids:
		var to_id := str(to_v)
		if incoming.has(to_id):
			continue
		var from_id := str(from_ids[rng.randi_range(0, from_ids.size() - 1)])
		edges.append({"from": from_id, "to": to_id})
	return edges


static func _mix_seed(seed_value: int, location_id: String) -> int:
	var hash_value := seed_value
	for i in location_id.length():
		hash_value = int(hash_value * 31 + location_id.unicode_at(i)) & 0x7fffffff
	return maxi(1, hash_value)
