extends Control

const DaoTreeGraphViewScript := preload("res://scripts/ui/dao_tree_graph_view.gd")
const DaoTreeNodeViewScript := preload("res://scripts/ui/dao_tree_node_view.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")

@onready var _player_card: Label = $PlayerCard/Text
@onready var _by_dao: Button = $ModeTabs/Tabs/ByDao
@onready var _by_realm: Button = $ModeTabs/Tabs/ByRealm
@onready var _close: TextureButton = $Close
@onready var _categories: VBoxContainer = $MainPanel/CategoryScroll/Categories
@onready var _tree_area: Control = $MainPanel/TreeArea
@onready var _details_heading: Label = $MainPanel/Details/VBox/Heading
@onready var _details_desc: Label = $MainPanel/Details/VBox/Description
@onready var _details_state: Label = $MainPanel/Details/VBox/State
@onready var _details_progress: ProgressBar = $MainPanel/Details/VBox/Progress
@onready var _details_impact: Label = $MainPanel/Details/VBox/Impact
@onready var _path_button: Button = $MainPanel/Details/VBox/PathButton
@onready var _related_button: Button = $MainPanel/Details/VBox/RelatedButton
@onready var _route_panel: PanelContainer = $RoutePanel
@onready var _route_heading: Label = $RoutePanel/VBox/Heading
@onready var _back: TextureButton = $BottomActions/Back
@onready var _zoom: TextureButton = $BottomActions/Zoom

var _graph: DaoTreeGraphViewScript
var _selected_skill_id := ""
var _current_domain := "foundation"
var _realm_mode := false
var _category_buttons: Array = []
var _tree_initialized := false


func _ready() -> void:
	_clear_demo_nodes()
	_build_graph()
	_build_categories()
	_bind_header()
	_close.pressed.connect(_on_close)
	_back.pressed.connect(_on_close)
	_zoom.pressed.connect(_on_reset_zoom)
	_by_dao.pressed.connect(func() -> void: _set_mode(false))
	_by_realm.pressed.connect(func() -> void: _set_mode(true))
	_path_button.pressed.connect(_show_routes)
	_related_button.pressed.connect(_show_related)
	_route_panel.visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _route_panel.visible:
			_route_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		_on_close()
		get_viewport().set_input_as_handled()


func _bind_header() -> void:
	_player_card.text = "%s\n%s" % [GameState.player_name, GameState.realm_name]


func _clear_demo_nodes() -> void:
	for child in _tree_area.get_children():
		child.queue_free()


func _build_graph() -> void:
	_graph = DaoTreeGraphViewScript.new()
	_graph.name = "GraphView"
	_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tree_area.add_child(_graph)
	_graph.node_pressed.connect(_on_node_pressed)
	_graph.node_double_pressed.connect(_on_node_double_pressed)


func _build_categories() -> void:
	for child in _categories.get_children():
		child.queue_free()
	_category_buttons.clear()
	for domain_v in DaoTreeServiceScript.domains():
		if domain_v is Dictionary:
			_add_category_button(domain_v as Dictionary)


func _add_category_button(domain: Dictionary) -> void:
	var button := _create_category_button()
	button.text = str(domain.get("name", ""))
	var domain_id := str(domain.get("id", ""))
	button.pressed.connect(func() -> void: _select_domain(domain_id))
	_categories.add_child(button)
	_category_buttons.append({"button": button, "id": domain_id})


func _create_category_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 52)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_hover_color", Color(0.12, 0.16, 0.09, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.17, 0.13, 0.06, 1))
	button.add_theme_stylebox_override("normal", _category_style_normal())
	button.add_theme_stylebox_override("hover", _category_style_hover())
	button.add_theme_stylebox_override("pressed", _category_style_selected())
	button.add_theme_stylebox_override("focus", _category_style_selected())
	button.add_theme_stylebox_override("disabled", _category_style_disabled())
	return button


func _category_style_normal() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.9, 0.78, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.47, 0.34, 0.2, 0.8)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	return style


func _category_style_selected() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.86, 0.55, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.91, 0.64, 0.16, 1)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(1, 0.76, 0.18, 0.55)
	style.shadow_size = 7
	return style


func _category_style_hover() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.76, 0.57, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.38, 0.43, 0.27, 0.9)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	return style


func _category_style_disabled() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.83, 0.79, 0.68, 0.65)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.48, 0.43, 0.34, 0.48)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	return style


func _select_domain(domain_id: String) -> void:
	_current_domain = domain_id
	_realm_mode = false
	_highlight_category(domain_id)
	_focus_view()


func _set_mode(realm_mode: bool) -> void:
	_realm_mode = realm_mode
	_by_dao.disabled = realm_mode
	_by_realm.disabled = not realm_mode
	_focus_view()


func _highlight_category(domain_id: String) -> void:
	for item in _category_buttons:
		var button: Button = item["button"]
		var selected := str(item["id"]) == domain_id and not _realm_mode
		button.disabled = selected


func _refresh() -> void:
	_bind_header()
	_sync_tree_data()
	if _selected_skill_id != "":
		_bind_details(_selected_skill_id)


func _sync_tree_data() -> void:
	if _graph == null:
		return
	_graph.setup(GameState.to_dict(), GameState.major_realm_id())
	if not _tree_initialized:
		_tree_initialized = true
		_current_domain = str((DaoTreeServiceScript.domains().front() as Dictionary).get("id", "foundation"))
		_highlight_category(_current_domain)
	_focus_view()


func _focus_view() -> void:
	if _graph == null:
		return
	if _realm_mode:
		_graph.focus_realm(GameState.major_realm_id())
	else:
		_graph.focus_domain(_current_domain)


func _on_node_pressed(skill_id: String) -> void:
	_selected_skill_id = skill_id
	_bind_details(skill_id)


func _on_node_double_pressed(skill_id: String) -> void:
	_selected_skill_id = skill_id
	_show_routes()


func _bind_details(skill_id: String) -> void:
	var skill := DaoTreeServiceScript.skill_by_id(skill_id)
	if skill.is_empty():
		return
	var effective := KnowledgeServiceScript.effective_level(GameState.to_dict(), skill_id)
	var level := int(floor(effective))
	_details_heading.text = "%s  %s" % [
		str(skill.get("name", "")),
		DaoTreeNodeViewScript._roman_level(maxi(1, level)) if level > 0 else "—",
	]
	_details_desc.text = str(skill.get("description", ""))
	_details_state.text = "当前掌握                         %s" % (
		DaoTreeNodeViewScript._roman_level(level) if level > 0 else "—"
	)
	var next_req := DaoTreeServiceScript.required_xp_for_level(skill_id, level + 1)
	var frac := 0.0 if next_req <= 0.0 else clampf(effective - float(level), 0.0, 1.0)
	_details_progress.max_value = 100.0
	_details_progress.value = frac * 100.0 if level < int(skill.get("maxLevel", 5)) else 100.0
	var impact_lines: PackedStringArray = []
	for ability in KnowledgeServiceScript.related_abilities(skill_id):
		impact_lines.append("技能：%s" % str(ability.get("name", "")))
	for family in KnowledgeServiceScript.related_method_families(skill_id):
		impact_lines.append("功法：%s" % str(family.get("name", "")))
	var prereq_lines: PackedStringArray = []
	for req_v in skill.get("prereqs", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		var parent := DaoTreeServiceScript.skill_by_id(str(req.get("id", "")))
		var have := KnowledgeServiceScript.effective_level(GameState.to_dict(), str(req.get("id", "")))
		var ok := have >= float(req.get("level", 1))
		prereq_lines.append(
			"%s%s %s" % [
				"✓ " if ok else "× ",
				str(parent.get("name", req.get("id", ""))),
				DaoTreeNodeViewScript._roman_level(int(req.get("level", 1))),
			]
		)
	_details_impact.text = "掌握度 %.0f%%\n\n影响：\n%s\n\n前置：\n%s" % [
		frac * 100.0 if level < int(skill.get("maxLevel", 5)) else 100.0,
		"\n".join(impact_lines) if not impact_lines.is_empty() else "暂无",
		"\n".join(prereq_lines) if not prereq_lines.is_empty() else "无",
	]


func _show_routes() -> void:
	if _selected_skill_id == "":
		return
	_route_panel.visible = true
	_route_heading.text = "提升途径 · %s" % str(
		DaoTreeServiceScript.skill_by_id(_selected_skill_id).get("name", "")
	)


func _show_related() -> void:
	if _selected_skill_id == "":
		return
	_bind_details(_selected_skill_id)


func _on_reset_zoom() -> void:
	if _graph != null:
		_graph.reset_view()
		_focus_view()


func _on_close() -> void:
	SceneManager.go_back()
