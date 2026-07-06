class_name DaoTreeGraphView
extends Control

const NODE_SCENE := preload("res://scenes/ui/components/dao_tree_node.tscn")
const DaoTreeNodeViewScript := preload("res://scripts/ui/dao_tree_node_view.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")

signal node_pressed(skill_id: String)
signal node_double_pressed(skill_id: String)

const DOMAIN_COLUMN_MIN_WIDTH := 136.0
const COLUMN_INNER_PADDING := 24.0
const DOMAIN_GAP := 20.0
const DOMAIN_FAMILY_GAP := 72.0
const REALM_BAND_GAP := 36.0
const NODE_X_GAP := 20.0
const NODE_Y_GAP := 16.0
const NODE_SIZE := Vector2(112.0, 112.0)
const TREE_PADDING := Vector2(48.0, 40.0)

var _content: Control
var _lines_layer: Control
var _nodes_layer: Control

var _built := false
var _nodes_by_id: Dictionary = {}
var _positions: Dictionary = {}
var _domain_regions: Dictionary = {}
var _realm_regions: Dictionary = {}
var _savedata: Dictionary = {}
var _player_major_realm := "lianqi"
var _zoom := 1.0
var _pan := Vector2.ZERO
var _pan_dragging := false
var _click_dragging := false
var _click_moved := false
var _drag_press_local := Vector2.ZERO
var _drag_press_pan := Vector2.ZERO
var _last_click := 0.0

const DRAG_THRESHOLD := 8.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_lines_layer = Control.new()
	_lines_layer.name = "Lines"
	_lines_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_lines_layer)
	_nodes_layer = Control.new()
	_nodes_layer.name = "Nodes"
	_nodes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_nodes_layer)


func setup(savedata: Dictionary, player_major_realm: String) -> void:
	_savedata = savedata
	_player_major_realm = player_major_realm
	if not _built:
		_build_full_tree()
	else:
		_refresh_node_states()


func focus_domain(domain_id: String) -> void:
	if not _built:
		return
	var region_v: Variant = _domain_regions.get(domain_id.strip_edges())
	if region_v is Rect2:
		_focus_rect(region_v as Rect2)


func focus_realm(realm_id: String) -> void:
	if not _built:
		return
	var region_v: Variant = _realm_regions.get(realm_id.strip_edges())
	if region_v is Rect2:
		_focus_rect(region_v as Rect2)


func reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_apply_transform()


func _focus_rect(rect: Rect2) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		call_deferred("_focus_rect", rect)
		return
	var center := rect.get_center()
	_pan = size * 0.5 - center * _zoom
	_apply_transform()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var inside := _is_mouse_inside()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and inside:
			_apply_zoom(_zoom + 0.1)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and inside:
			_apply_zoom(_zoom - 0.1)
			get_viewport().set_input_as_handled()
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			if mb.pressed and inside:
				_begin_pan_drag(_event_local(mb.global_position))
				get_viewport().set_input_as_handled()
			elif not mb.pressed and _pan_dragging:
				_end_pan_drag()
				get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and inside:
				_begin_click_drag(_event_local(mb.global_position))
			elif not mb.pressed and _click_dragging:
				_end_click_drag(_event_local(mb.global_position))
	elif event is InputEventMouseMotion and (_pan_dragging or _click_dragging):
		var motion := event as InputEventMouseMotion
		var local := _event_local(motion.global_position)
		if _pan_dragging:
			_pan = _drag_press_pan + (local - _drag_press_local)
			_apply_transform()
			get_viewport().set_input_as_handled()
		elif _click_dragging:
			if local.distance_to(_drag_press_local) > DRAG_THRESHOLD:
				_click_moved = true
			if _click_moved:
				_pan = _drag_press_pan + (local - _drag_press_local)
				_apply_transform()
				get_viewport().set_input_as_handled()


func _is_mouse_inside() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _event_local(global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_pos


func _begin_pan_drag(local_pos: Vector2) -> void:
	_pan_dragging = true
	_drag_press_local = local_pos
	_drag_press_pan = _pan


func _end_pan_drag() -> void:
	_pan_dragging = false


func _begin_click_drag(local_pos: Vector2) -> void:
	_click_dragging = true
	_click_moved = false
	_drag_press_local = local_pos
	_drag_press_pan = _pan


func _end_click_drag(local_pos: Vector2) -> void:
	if _click_dragging and not _click_moved:
		_handle_node_click(local_pos)
	_click_dragging = false
	_click_moved = false


func _handle_node_click(local_pos: Vector2) -> void:
	var skill_id := _skill_at_content_pos(_to_content_pos(local_pos))
	if skill_id == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_click < 0.35:
		node_double_pressed.emit(skill_id)
	else:
		node_pressed.emit(skill_id)
	_last_click = now


func _to_content_pos(local_pos: Vector2) -> Vector2:
	return (local_pos - _pan) / _zoom


func _skill_at_content_pos(content_pos: Vector2) -> String:
	for sid in _nodes_by_id.keys():
		var node: Control = _nodes_by_id[sid]
		var rect := Rect2(node.position, NODE_SIZE)
		if rect.has_point(content_pos):
			return str(sid)
	return ""


func _apply_zoom(new_zoom: float) -> void:
	var clamped := clampf(new_zoom, 0.45, 2.0)
	if is_equal_approx(clamped, _zoom):
		return
	if size.x <= 1.0 or size.y <= 1.0:
		_zoom = clamped
		_apply_transform()
		return
	var center := size * 0.5
	var focus_content := (center - _pan) / _zoom
	_zoom = clamped
	_pan = center - focus_content * _zoom
	_apply_transform()


func _apply_transform() -> void:
	if _content == null:
		return
	_content.scale = Vector2.ONE * _zoom
	_content.position = _pan


func _build_full_tree() -> void:
	_positions = _compute_full_layout()
	_spawn_nodes()
	_spawn_lines()
	_built = true
	_refresh_node_states()
	_update_content_size()


func _layer_x_step() -> float:
	return NODE_SIZE.x + NODE_X_GAP


func _layer_y_step() -> float:
	return NODE_SIZE.y + NODE_Y_GAP


func _compute_full_layout() -> Dictionary:
	var positions := {}
	_domain_regions.clear()
	_realm_regions.clear()
	var realms := DaoTreeServiceScript.realms()
	var column_widths := _compute_domain_column_widths()
	var realm_tops := _compute_realm_row_tops()
	var realm_bounds: Dictionary = {}
	var x_cursor := TREE_PADDING.x
	var groups := DaoTreeServiceScript.domain_groups()

	for group_index in groups.size():
		var group_v: Variant = groups[group_index]
		if not group_v is Dictionary:
			continue
		var group := group_v as Dictionary
		var domain_ids: Array = []
		for domain_id_v in group.get("domains", []) as Array:
			var domain_id := str(domain_id_v)
			if domain_id != "" and not DaoTreeServiceScript.domain_by_id(domain_id).is_empty():
				domain_ids.append(domain_id)
		if domain_ids.is_empty():
			continue

		for domain_index in domain_ids.size():
			var domain_id := str(domain_ids[domain_index])
			var col_width := float(column_widths.get(domain_id, DOMAIN_COLUMN_MIN_WIDTH))
			var col_min_x := x_cursor
			var col_max_x := x_cursor + col_width
			var domain_min_y := INF
			var domain_max_y := -INF

			for realm_v in realms:
				if not realm_v is Dictionary:
					continue
				var realm_id := str((realm_v as Dictionary).get("id", ""))
				if not realm_tops.has(realm_id):
					continue
				var skills := _skills_for_domain_realm(domain_id, realm_id)
				if skills.is_empty():
					continue
				var band_top := float(realm_tops[realm_id])
				var band_positions := _layout_realm_band(skills, x_cursor, band_top)
				var band_bottom := band_top
				for sid in band_positions.keys():
					var pos: Vector2 = band_positions[sid]
					positions[sid] = pos
					band_bottom = maxf(band_bottom, pos.y + NODE_SIZE.y)
				_expand_bounds(realm_bounds, realm_id, Rect2(
					col_min_x,
					band_top,
					col_max_x - col_min_x,
					band_bottom - band_top,
				))
				domain_min_y = minf(domain_min_y, band_top)
				domain_max_y = maxf(domain_max_y, band_bottom)

			if domain_max_y >= domain_min_y:
				_domain_regions[domain_id] = Rect2(
					col_min_x - 12.0,
					domain_min_y - 12.0,
					col_max_x - col_min_x + 24.0,
					domain_max_y - domain_min_y + 24.0,
				)

			x_cursor += col_width
			if domain_index < domain_ids.size() - 1:
				x_cursor += DOMAIN_GAP
			elif group_index < groups.size() - 1:
				x_cursor += DOMAIN_FAMILY_GAP

	for realm_id in realm_bounds.keys():
		var bounds: Dictionary = realm_bounds[realm_id]
		_realm_regions[realm_id] = Rect2(
			float(bounds.get("min_x", TREE_PADDING.x)) - 16.0,
			float(bounds.get("min_y", TREE_PADDING.y)) - 16.0,
			float(bounds.get("max_x", x_cursor)) - float(bounds.get("min_x", TREE_PADDING.x)) + 32.0,
			float(bounds.get("max_y", TREE_PADDING.y)) - float(bounds.get("min_y", TREE_PADDING.y)) + 32.0,
		)
	return positions


func _ordered_domain_ids() -> Array:
	var out: Array = []
	for group_v in DaoTreeServiceScript.domain_groups():
		if not group_v is Dictionary:
			continue
		for domain_id_v in (group_v as Dictionary).get("domains", []) as Array:
			out.append(str(domain_id_v))
	return out


func _compute_domain_column_widths() -> Dictionary:
	var widths := {}
	var realms := DaoTreeServiceScript.realms()
	for domain_id_v in _ordered_domain_ids():
		var domain_id := str(domain_id_v)
		var max_layers := 1
		for realm_v in realms:
			if not realm_v is Dictionary:
				continue
			var realm_id := str((realm_v as Dictionary).get("id", ""))
			max_layers = maxi(
				max_layers,
				_realm_band_layer_count(_skills_for_domain_realm(domain_id, realm_id)),
			)
		widths[domain_id] = maxf(
			DOMAIN_COLUMN_MIN_WIDTH,
			float(max_layers) * _layer_x_step() + COLUMN_INNER_PADDING,
		)
	return widths


func _realm_band_layer_count(skills: Array) -> int:
	if skills.is_empty():
		return 0
	var ids := _skills_index(skills)
	if ids.is_empty():
		return 0
	var max_layer := 0
	for sid in ids.keys():
		max_layer = maxi(max_layer, _band_depth(str(sid), ids, {}))
	return max_layer + 1


func _compute_realm_row_tops() -> Dictionary:
	var tops := {}
	var realms := DaoTreeServiceScript.realms()
	var domain_ids := _ordered_domain_ids()
	var y_cursor := TREE_PADDING.y

	for realm_v in realms:
		if not realm_v is Dictionary:
			continue
		var realm_id := str((realm_v as Dictionary).get("id", ""))
		var row_height := 0.0
		for domain_id_v in domain_ids:
			var skills := _skills_for_domain_realm(str(domain_id_v), realm_id)
			row_height = maxf(row_height, _measure_realm_band_height(skills))
		if row_height <= 0.0:
			continue
		tops[realm_id] = y_cursor
		y_cursor += row_height + REALM_BAND_GAP
	return tops


func _measure_realm_band_height(skills: Array) -> float:
	var layers := _realm_band_layers(skills)
	if layers.is_empty():
		return 0.0
	var tallest := NODE_SIZE.y
	for layer_key in layers.keys():
		var row_count := (layers[layer_key] as Array).size()
		var band_height := float(maxi(0, row_count - 1)) * _layer_y_step() + NODE_SIZE.y
		tallest = maxf(tallest, band_height)
	return tallest


func _skills_index(skills: Array) -> Dictionary:
	var ids := {}
	for skill_v in skills:
		if skill_v is Dictionary:
			var skill := skill_v as Dictionary
			var sid := str(skill.get("id", ""))
			if sid != "":
				ids[sid] = skill
	return ids


func _realm_band_layers(skills: Array) -> Dictionary:
	var ids := _skills_index(skills)
	var layers: Dictionary = {}
	for sid in ids.keys():
		var layer := _band_depth(str(sid), ids, {})
		if not layers.has(layer):
			layers[layer] = []
		(layers[layer] as Array).append(sid)
	return layers


func _expand_bounds(store: Dictionary, realm_id: String, rect: Rect2) -> void:
	if not store.has(realm_id):
		store[realm_id] = {
			"min_x": rect.position.x,
			"min_y": rect.position.y,
			"max_x": rect.position.x + rect.size.x,
			"max_y": rect.position.y + rect.size.y,
		}
		return
	var bounds: Dictionary = store[realm_id]
	bounds["min_x"] = minf(float(bounds.get("min_x", rect.position.x)), rect.position.x)
	bounds["min_y"] = minf(float(bounds.get("min_y", rect.position.y)), rect.position.y)
	bounds["max_x"] = maxf(float(bounds.get("max_x", rect.position.x)), rect.position.x + rect.size.x)
	bounds["max_y"] = maxf(float(bounds.get("max_y", rect.position.y)), rect.position.y + rect.size.y)
	store[realm_id] = bounds


func _skills_for_domain_realm(domain_id: String, realm_id: String) -> Array:
	var out: Array = []
	for skill_v in DaoTreeServiceScript.skills_in_domain(domain_id):
		if skill_v is Dictionary and str((skill_v as Dictionary).get("realm", "")) == realm_id:
			out.append(skill_v)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return out


func _layout_realm_band(skills: Array, x_col: float, y_top: float) -> Dictionary:
	var ids := _skills_index(skills)
	var layers := _realm_band_layers(skills)
	var positions := {}
	for layer_key in layers.keys():
		var layer := int(layer_key)
		var row_ids: Array = layers[layer_key] as Array
		row_ids.sort_custom(func(a: String, b: String) -> bool:
			return str((ids[a] as Dictionary).get("name", a)) < str((ids[b] as Dictionary).get("name", b))
		)
		for i in row_ids.size():
			var sid := str(row_ids[i])
			positions[sid] = Vector2(
				x_col + float(layer) * _layer_x_step(),
				y_top + float(i) * _layer_y_step(),
			)
	return positions


func _band_depth(skill_id: String, ids: Dictionary, memo: Dictionary) -> int:
	if memo.has(skill_id):
		return int(memo[skill_id])
	var skill_v: Variant = ids.get(skill_id)
	if not skill_v is Dictionary:
		memo[skill_id] = 0
		return 0
	var max_parent := -1
	for req_v in (skill_v as Dictionary).get("prereqs", []) as Array:
		if not req_v is Dictionary:
			continue
		var parent_id := str((req_v as Dictionary).get("id", ""))
		if ids.has(parent_id):
			max_parent = maxi(max_parent, _band_depth(parent_id, ids, memo))
	memo[skill_id] = max_parent + 1
	return int(memo[skill_id])


func _spawn_nodes() -> void:
	_nodes_by_id.clear()
	for skill_v in DaoTreeServiceScript.config().get("skills", []) as Array:
		if not skill_v is Dictionary:
			continue
		var skill := skill_v as Dictionary
		var sid := str(skill.get("id", ""))
		if sid == "" or not _positions.has(sid):
			continue
		var node := NODE_SCENE.instantiate() as DaoTreeNodeViewScript
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nodes_layer.add_child(node)
		node.position = _positions[sid]
		_nodes_by_id[sid] = node
		node.pressed.connect(func(id: String) -> void: node_pressed.emit(id))
		node.double_pressed.connect(func(id: String) -> void: node_double_pressed.emit(id))


func _spawn_lines() -> void:
	for child in _lines_layer.get_children():
		child.queue_free()
	var line_color := Color(0.42, 0.32, 0.21, 0.72)
	for skill_v in DaoTreeServiceScript.config().get("skills", []) as Array:
		if not skill_v is Dictionary:
			continue
		var skill := skill_v as Dictionary
		var child_id := str(skill.get("id", ""))
		if child_id == "" or not _positions.has(child_id):
			continue
		var child_domain := str(skill.get("domain", ""))
		var child_center := (_positions[child_id] as Vector2) + NODE_SIZE * 0.5
		for req_v in skill.get("prereqs", []) as Array:
			if not req_v is Dictionary:
				continue
			var parent_id := str((req_v as Dictionary).get("id", ""))
			if parent_id == "" or not _positions.has(parent_id):
				continue
			var parent_skill := DaoTreeServiceScript.skill_by_id(parent_id)
			if parent_skill.is_empty():
				continue
			if str(parent_skill.get("domain", "")) != child_domain:
				continue
			var parent_center := (_positions[parent_id] as Vector2) + NODE_SIZE * 0.5
			var line := Line2D.new()
			line.width = 3.0
			line.default_color = line_color
			line.antialiased = true
			line.points = PackedVector2Array([parent_center, child_center])
			_lines_layer.add_child(line)


func _refresh_node_states() -> void:
	var levels_map := KnowledgeServiceScript.effective_levels_map(_savedata)
	for sid in _nodes_by_id.keys():
		var node: DaoTreeNodeViewScript = _nodes_by_id[sid]
		var skill := DaoTreeServiceScript.skill_by_id(str(sid))
		if skill.is_empty():
			continue
		var entry := KnowledgeServiceScript.get_entry(_savedata, str(sid))
		var state := DaoTreeServiceScript.node_display_state(
			str(sid),
			KnowledgeServiceScript.effective_level(_savedata, str(sid)),
			str(entry.get("growth_source", "")),
			_player_major_realm,
			levels_map,
		)
		node.bind(
			skill,
			state,
			KnowledgeServiceScript.effective_level(_savedata, str(sid)),
			bool(entry.get("marked", false)),
		)


func _update_content_size() -> void:
	var max_pos := Vector2.ZERO
	for pos_v in _positions.values():
		if pos_v is Vector2:
			var pos := pos_v as Vector2
			max_pos.x = maxf(max_pos.x, pos.x + NODE_SIZE.x)
			max_pos.y = maxf(max_pos.y, pos.y + NODE_SIZE.y)
	_content.custom_minimum_size = max_pos + TREE_PADDING
