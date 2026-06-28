extends Button

signal selected(entry_key: String)

@onready var _portrait: TextureRect = %Portrait
@onready var _title_label: Label = %TitleLabel
@onready var _state_badge: Label = %StateBadge
@onready var _issuer_label: Label = %IssuerLabel
@onready var _summary_label: Label = %SummaryLabel
@onready var _reward_preview: HBoxContainer = %RewardPreview

var _entry_key := ""
var _normal_style: StyleBox
var _selected_style: StyleBox


func _ready() -> void:
	pressed.connect(_on_pressed)
	_normal_style = get_theme_stylebox("normal")
	_selected_style = _normal_style.duplicate() if _normal_style != null else null
	if _selected_style is StyleBoxFlat:
		(_selected_style as StyleBoxFlat).border_color = Color(0.42, 0.56, 0.32, 0.95)
		(_selected_style as StyleBoxFlat).border_width_left = 3
		(_selected_style as StyleBoxFlat).border_width_top = 3
		(_selected_style as StyleBoxFlat).border_width_right = 3
		(_selected_style as StyleBoxFlat).border_width_bottom = 3


func bind(entry: Dictionary) -> void:
	_entry_key = str(entry.get("key", ""))
	_title_label.text = str(entry.get("title", ""))
	_issuer_label.text = str(entry.get("issuer", ""))
	_summary_label.text = str(entry.get("summary", ""))
	var portrait_path := str(entry.get("portrait", "")).strip_edges()
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path) as Texture2D
	set_state(int(entry.get("state", EnumWeituoState.State.AVAILABLE)))
	_bind_reward_preview(entry.get("rewards", []) as Array)


func set_selected(selected_flag: bool) -> void:
	if _selected_style != null and selected_flag:
		add_theme_stylebox_override("normal", _selected_style)
		add_theme_stylebox_override("hover", _selected_style)
		add_theme_stylebox_override("pressed", _selected_style)
	elif _normal_style != null:
		add_theme_stylebox_override("normal", _normal_style)
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")


func set_state(state: int) -> void:
	_state_badge.text = EnumWeituoState.label(state)
	if _state_badge.has_theme_stylebox_override("normal") and _state_badge.get_theme_stylebox("normal") is StyleBoxFlat:
		var badge_style := (_state_badge.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
		badge_style.bg_color = EnumWeituoState.badge_color(state)
		_state_badge.add_theme_stylebox_override("normal", badge_style)


func _bind_reward_preview(rewards: Array) -> void:
	var slots: Array = _reward_preview.get_children()
	for i in slots.size():
		var slot: Node = slots[i]
		if i >= rewards.size():
			slot.visible = false
			continue
		slot.visible = true
		var reward := rewards[i] as Dictionary
		var icon_node := slot.get_node_or_null("Icon") as TextureRect
		var count_node := slot.get_node_or_null("Count") as Label
		if count_node != null:
			count_node.text = str(maxi(1, int(reward.get("count", 1))))
		if icon_node != null:
			var icon_path := str(reward.get("icon_path", "")).strip_edges()
			if icon_path != "":
				icon_node.texture = ItemDef.resolve_icon_texture(icon_path, icon_node.texture)


func _on_pressed() -> void:
	if _entry_key != "":
		selected.emit(_entry_key)
