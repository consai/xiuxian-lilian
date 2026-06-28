class_name ItemView
extends Control

## 道具展示块，场景 [code]item.tscn[/code]。
## [member click_enabled] 为 [code]false[/code] 时仅展示（如详情弹窗）；为 [code]true[/code] 时可点击并带缩放反馈（如背包）。
## [member show_info_on_click] 为 [code]true[/code] 且已 [method set_info_entry] 时，左键打开全局道具详情。
## [code]%GcItemQualityTint[/code] / [code]%GcItemHighlight[/code] 为品质底盘与边框，[code]%GcItemTierLabel[/code] 显示阶位文字。
## [code]%GcItemCountBadge[/code] 在 [member show_name_label] 为真且数量大于 1 时显示角标；
## [member always_show_count_badge] 为真时，数量大于 0 即显示角标（如消耗展示）。

const INSUFFICIENT_TEXT_COLOR := Color(0.92, 0.2, 0.12, 1)

signal clicked
signal right_clicked

@export var show_info_on_click: bool = true
@export var click_enabled: bool = false:
	set(value):
		click_enabled = value
		if is_node_ready():
			_apply_click_enabled()

@export var show_name_label: bool = true:
	set(value):
		show_name_label = value
		if is_node_ready():
			_refresh_name_count_text()

@export var always_show_count_badge: bool = false:
	set(value):
		always_show_count_badge = value
		if is_node_ready():
			_refresh_count_badge()

@onready var _icon: TextureRect = %GcDetailIcon
@onready var _learn_blocked: Control = %GcLearnBlocked
@onready var _name_count: Label = %GcItemNameCount
@onready var _count_badge_wrap: Control = %GcItemCountBadgeWrap
@onready var _count_badge: Label = %GcItemCountBadge
@onready var _press: PressScale = %GcItemPress
@onready var _quality_tint: Panel = %GcItemQualityTint
@onready var _quality_border: Panel = %GcItemHighlight
@onready var _tier_label: Label = %GcItemTierLabel

var _display_name: String = ""
var _display_count: int = 0
var _quality: String = ""
var _tier: int = 1
var _learn_blocked_flag: bool = false
var _icon_modulate: Color = Color.WHITE
var _info_entry: Dictionary = {}
var _insufficient: bool = false
var _name_label_settings_normal: LabelSettings
var _name_label_settings_insufficient: LabelSettings
var _count_label_settings_normal: LabelSettings
var _count_label_settings_insufficient: LabelSettings


func _ready() -> void:
	if _name_count != null:
		_name_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _count_badge_wrap != null:
		_count_badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _count_badge != null:
		_count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_click_enabled()
	_apply_quality_border(_quality)
	_set_learn_blocked(_learn_blocked_flag)
	_cache_label_settings()
	_refresh_name_count_text()
	gui_input.connect(_on_gui_input)


func _cache_label_settings() -> void:
	if _name_count != null and _name_count.label_settings != null:
		_name_label_settings_normal = _name_count.label_settings
		_name_label_settings_insufficient = _name_count.label_settings.duplicate()
		_name_label_settings_insufficient.font_color = INSUFFICIENT_TEXT_COLOR
	if _count_badge != null and _count_badge.label_settings != null:
		_count_label_settings_normal = _count_badge.label_settings
		_count_label_settings_insufficient = _count_badge.label_settings.duplicate()
		_count_label_settings_insufficient.font_color = INSUFFICIENT_TEXT_COLOR


func set_click_enabled(enabled: bool) -> void:
	click_enabled = enabled


func set_info_entry(entry: Dictionary) -> void:
	_info_entry = entry.duplicate(true) if entry is Dictionary else {}


func clear_info_entry() -> void:
	_info_entry = {}


static func apply_item_id(view: ItemView, item_id: String, count: int = 0, options: Dictionary = {}) -> void:
	if view == null:
		return
	var iid := item_id.strip_edges()
	var show_name: bool = bool(options.get("show_name", true))
	var always_count: bool = bool(options.get("always_show_count", false))
	var name_override: String = str(options.get("name_override", "")).strip_edges()
	var click: bool = bool(options.get("click_enabled", false))
	var show_info: bool = bool(options.get("show_info_on_click", false))
	var insufficient: bool = bool(options.get("insufficient", false))
	view.show_name_label = show_name
	view.always_show_count_badge = always_count
	view.set_click_enabled(click)
	view.show_info_on_click = show_info
	var icon: Texture2D = null
	var item_name := name_override
	var quality := ""
	var tier := 1
	if iid != "" and ConfigManager != null:
		var def := ConfigManager.item_def_by_id(iid)
		if def != null:
			icon = ItemDef.resolve_icon_texture(def.icon_path, null)
			if item_name == "":
				item_name = def.name
			quality = EnumQuality.display_label(def.quality)
			tier = def.tier
	view.apply_display(icon, item_name, maxi(0, count), Color.WHITE, quality, false, tier)
	view.set_insufficient(insufficient)
	if show_info and iid != "":
		view.set_info_entry({"kind": EnumRewardKind.LABEL_ITEM, "id": iid, "count": maxi(1, count)})
	else:
		view.clear_info_entry()


static func apply_reward_row(view: ItemView, row: Dictionary, options: Dictionary = {}) -> void:
	if view == null or not row is Dictionary:
		return
	const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
	var click: bool = bool(options.get("click_enabled", true))
	var show_info: bool = bool(options.get("show_info_on_click", true))
	var show_name: bool = bool(options.get("show_name", true))
	view.set_click_enabled(click)
	view.show_info_on_click = show_info
	view.show_name_label = show_name
	var kind := str(row.get("kind", EnumRewardKind.LABEL_ITEM))
	var count := maxi(1, int(row.get("count", row.get("amount", 1))))
	var item_name := str(row.get("name", row.get("item_name", ""))).strip_edges()
	var quality := str(row.get("quality", row.get("pin_zhi", ""))).strip_edges()
	var tier := maxi(1, int(row.get("tier", 1)))
	var icon: Texture2D = null
	var icon_v: Variant = row.get("icon")
	if icon_v is Texture2D:
		icon = icon_v
	elif kind == EnumRewardKind.LABEL_CURRENCY:
		if item_name == "":
			item_name = "灵石" if str(row.get("id", "")) == "ling_stones" else str(row.get("id", "货币"))
	elif kind == EnumRewardKind.LABEL_EQUIP:
		var equip_cfg := ConfigManager.equip_by_id(int(row.get("id", -1)))
		if item_name == "":
			item_name = str(equip_cfg.get("name", "法宝"))
		icon = ZhandouInitDataScript._resolve_icon_texture(equip_cfg)
		if quality == "":
			quality = EnumQuality.display_label(int(equip_cfg.get("quality", 1)))
		tier = maxi(1, int(equip_cfg.get("tier", tier)))
	elif kind == EnumRewardKind.LABEL_ITEM:
		var item_id := str(row.get("id", ""))
		if item_name == "" and ConfigManager != null:
			item_name = str(ConfigManager.get_item_display_name(item_id))
		if ConfigManager != null:
			var def := ConfigManager.item_def_by_id(item_id)
			if def != null:
				icon = ItemDef.resolve_icon_texture(def.icon_path, null)
				if quality == "":
					quality = EnumQuality.display_label(def.quality)
				tier = def.tier
	else:
		if item_name == "":
			item_name = str(row.get("id", "奖励"))
		var path := str(row.get("icon_path", row.get("icon", ""))).strip_edges()
		if path != "":
			icon = ItemDef.resolve_icon_texture(path, null)
	view.apply_display(icon, item_name, count, Color.WHITE, quality, false, tier)
	view.set_info_entry(entry_from_reward_row(row))


static func entry_from_reward_row(row: Dictionary) -> Dictionary:
	var kind := str(row.get("kind", EnumRewardKind.LABEL_ITEM))
	match kind:
		EnumRewardKind.LABEL_EQUIP:
			var equip_id := int(row.get("id", -1))
			if equip_id <= 0:
				return {}
			return {"kind": EnumRewardKind.LABEL_EQUIP, "id": equip_id, "count": 1}
		EnumRewardKind.LABEL_ITEM:
			var item_id := str(row.get("id", "")).strip_edges()
			if item_id == "":
				return {}
			return {
				"kind": EnumRewardKind.LABEL_ITEM,
				"id": item_id,
				"count": maxi(1, int(row.get("count", row.get("amount", 1)))),
			}
		_:
			return {}


func set_insufficient(insufficient: bool) -> void:
	_insufficient = insufficient
	_apply_text_colors()


func apply_empty(placeholder: Texture2D, icon_modulate: Color = Color(1, 1, 1, 0.28)) -> void:
	_display_name = ""
	_display_count = 0
	_quality = ""
	_tier = 1
	_insufficient = false
	clear_info_entry()
	_icon_modulate = icon_modulate
	_icon.texture = placeholder
	_apply_icon_modulate(false)
	_apply_quality_border("")
	_set_learn_blocked(false)
	_refresh_name_count_text()


func apply_display(
	icon: Texture2D,
	item_name: String = "",
	count: int = 0,
	icon_modulate: Color = Color.WHITE,
	quality: String = "",
	learn_blocked: bool = false,
	tier: int = 1
) -> void:
	_display_name = item_name.strip_edges()
	_display_count = maxi(0, count)
	_quality = quality.strip_edges()
	_tier = maxi(1, tier)
	_icon_modulate = icon_modulate
	_icon.texture = icon
	_apply_icon_modulate(learn_blocked)
	_apply_quality_border(_quality)
	_set_learn_blocked(learn_blocked)
	_refresh_name_count_text()


func _apply_text_colors() -> void:
	if _name_label_settings_normal == null and is_node_ready():
		_cache_label_settings()
	if _name_count != null:
		if _insufficient and _name_label_settings_insufficient != null:
			_name_count.label_settings = _name_label_settings_insufficient
			_name_count.add_theme_color_override("font_color", INSUFFICIENT_TEXT_COLOR)
		elif _name_label_settings_normal != null:
			_name_count.label_settings = _name_label_settings_normal
			_name_count.remove_theme_color_override("font_color")
	if _count_badge != null:
		if _insufficient:
			if _count_label_settings_insufficient != null:
				_count_badge.label_settings = _count_label_settings_insufficient
			_count_badge.add_theme_color_override("font_color", INSUFFICIENT_TEXT_COLOR)
		else:
			if _count_label_settings_normal != null:
				_count_badge.label_settings = _count_label_settings_normal
			_count_badge.remove_theme_color_override("font_color")


func set_learn_blocked(blocked: bool) -> void:
	_set_learn_blocked(blocked)
	_apply_icon_modulate(blocked)


func apply_row(row: Dictionary, fallback_icon: Texture2D = null) -> void:
	var path := str(row.get("wuPinTuBiao", row.get("icon", ""))).strip_edges()
	var tex: Texture2D = null
	if path != "":
		var loaded := load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		tex = fallback_icon
	var nm := str(row.get("wuPinMing", row.get("wuPinId", "")))
	var cnt := maxi(1, int(row.get("shuLiang", 1)))
	var pin := str(row.get("pinZhi", ""))
	var tier := maxi(1, int(row.get("tier", 1)))
	apply_display(tex, nm, cnt, Color.WHITE, pin, false, tier)


func _on_press_clicked() -> void:
	var should_show_info := show_info_on_click
	clicked.emit()
	if should_show_info and not _info_entry.is_empty():
		ItemInfoPopupHost.show_entry(_info_entry)


func _on_gui_input(event: InputEvent) -> void:
	if not click_enabled:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			right_clicked.emit()
			accept_event()


func _apply_click_enabled() -> void:
	if _press == null:
		return
	if click_enabled:
		_press.process_mode = Node.PROCESS_MODE_INHERIT
		mouse_filter = Control.MOUSE_FILTER_STOP
		if not _press.clicked.is_connected(_on_press_clicked):
			_press.clicked.connect(_on_press_clicked)
	else:
		_press.process_mode = Node.PROCESS_MODE_DISABLED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		scale = Vector2.ONE
		if _press.clicked.is_connected(_on_press_clicked):
			_press.clicked.disconnect(_on_press_clicked)


func _apply_icon_modulate(blocked: bool) -> void:
	if _icon == null:
		return
	if blocked:
		_icon.self_modulate = Color(
			_icon_modulate.r * 0.58,
			_icon_modulate.g * 0.58,
			_icon_modulate.b * 0.58,
			_icon_modulate.a
		)
	else:
		_icon.self_modulate = _icon_modulate


func _set_learn_blocked(blocked: bool) -> void:
	_learn_blocked_flag = blocked
	var marker := _learn_blocked if _learn_blocked != null else get_node_or_null("%GcLearnBlocked") as Control
	if marker != null:
		marker.visible = blocked


func _apply_quality_border(pin_zhi: String) -> void:
	var quality_text := pin_zhi.strip_edges()
	var quality_color := EnumQuality.border_color_from_label(quality_text)
	if _quality_tint != null:
		_quality_tint.visible = quality_text != ""
		_quality_tint.self_modulate = Color(
			quality_color.r,
			quality_color.g,
			quality_color.b,
			0.18 if _quality_tint.visible else 0.0
		)
	if _quality_border != null:
		_quality_border.visible = quality_text != ""
		if _quality_border.visible:
			_quality_border.self_modulate = quality_color
	if _tier_label != null:
		_tier_label.visible = quality_text != ""
		_tier_label.text = EnumItemTier.label(_tier)


func _refresh_name_count_text() -> void:
	if show_name_label and _display_name != "":
		_name_count.text = _display_name
		_name_count.visible = true
	else:
		_name_count.text = ""
		_name_count.visible = false
	_apply_text_colors()
	_refresh_count_badge()


func _refresh_count_badge() -> void:
	var badge := _count_badge if _count_badge != null else get_node_or_null("%GcItemCountBadge") as Label
	var badge_wrap := _count_badge_wrap if _count_badge_wrap != null else get_node_or_null("%GcItemCountBadgeWrap") as PanelContainer
	if badge == null:
		return
	if _display_count > 1 or (always_show_count_badge and _display_count > 0):
		badge.text = str(_display_count)
		if badge_wrap != null:
			badge_wrap.visible = true
			badge_wrap.self_modulate = Color.WHITE
		else:
			badge.visible = true
		_apply_text_colors()
	else:
		_set_count_badge_visible(false)


func _set_count_badge_visible(visible_flag: bool) -> void:
	var badge_wrap := _count_badge_wrap if _count_badge_wrap != null else get_node_or_null("%GcItemCountBadgeWrap") as PanelContainer
	if badge_wrap != null:
		badge_wrap.visible = visible_flag
	elif _count_badge != null:
		_count_badge.visible = visible_flag
