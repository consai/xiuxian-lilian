class_name ExpeditionMapCanvas
extends Control

const ExpeditionMapServiceScript := preload("res://scripts/expedition/expedition_map_service.gd")

const NODE_X_MARGIN := 104.0
const NODE_Y_MARGIN := 78.0

var _nodes: Array = []
var _edges: Array = []


func setup(nodes: Array, edges: Array) -> void:
	_nodes = nodes.duplicate(true)
	_edges = edges.duplicate(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func node_position(node: Dictionary) -> Vector2:
	var max_layer := 1
	var max_lane_by_layer := {}
	for node_v in _nodes:
		if not node_v is Dictionary:
			continue
		var row := node_v as Dictionary
		var layer := int(row.get("layer", 0))
		var lane := int(row.get("lane", 0))
		max_layer = maxi(max_layer, layer)
		max_lane_by_layer[layer] = maxi(int(max_lane_by_layer.get(layer, 0)), lane)
	var layer := int(node.get("layer", 0))
	var lane := int(node.get("lane", 0))
	var max_lane := int(max_lane_by_layer.get(layer, 0))
	var x: float
	if ExpeditionMapServiceScript.is_compact_map(_nodes):
		var gap := ExpeditionMapServiceScript.COMPACT_NODE_GAP
		var chain_width := float(max_layer) * gap
		x = (size.x - chain_width) * 0.5 + float(layer) * gap
	else:
		x = lerpf(NODE_X_MARGIN, maxf(NODE_X_MARGIN, size.x - NODE_X_MARGIN), float(layer) / float(maxi(1, max_layer)))
	var y := size.y * 0.5
	if max_lane > 0:
		y = lerpf(NODE_Y_MARGIN, maxf(NODE_Y_MARGIN, size.y - NODE_Y_MARGIN), float(lane) / float(max_lane))
	return Vector2(x, y)


func _draw() -> void:
	var by_id := {}
	for node_v in _nodes:
		if node_v is Dictionary:
			by_id[str((node_v as Dictionary).get("id", ""))] = node_v
	for edge_v in _edges:
		if not edge_v is Dictionary:
			continue
		var edge := edge_v as Dictionary
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		if not by_id.has(from_id) or not by_id.has(to_id):
			continue
		var from_pos := node_position(by_id[from_id] as Dictionary)
		var to_pos := node_position(by_id[to_id] as Dictionary)
		draw_line(from_pos, to_pos, Color(0.43, 0.30, 0.18, 0.55), 3.0, true)
