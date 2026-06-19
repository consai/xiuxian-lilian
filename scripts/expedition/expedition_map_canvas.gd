class_name ExpeditionMapCanvas
extends Control

var _nodes: Array = []
var _edges: Array = []


func setup(nodes: Array, edges: Array) -> void:
	_nodes = nodes.duplicate(true)
	_edges = edges.duplicate(true)
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
	var x := lerpf(56.0, maxf(56.0, size.x - 56.0), float(layer) / float(maxi(1, max_layer)))
	var y := size.y * 0.5
	if max_lane > 0:
		y = lerpf(54.0, maxf(54.0, size.y - 54.0), float(lane) / float(max_lane))
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
