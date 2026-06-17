class_name BagBaseView
extends Control

## 储物/背包公用组件：无物品时不显示占位格；有物品时视口内最多 [member max_slots_show] 格，滚动时动态换绑数据。

const ItemScene := preload("res://scenes/items/item.tscn")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")
const ItemInfoPayloadBuilderScript := preload("res://scripts/ui/item_info_payload_builder.gd")
const EnumItemTypeScript := preload("res://scripts/enum/enum_itemtype.gd")
const HoverTipSourceScript := preload("res://scripts/ui/hover/hover_tip_source.gd")
const HoverTipPayloadScript := preload("res://scripts/ui/hover/hover_tip_payload.gd")
const ItemHoverTipBuilderScript := preload("res://scripts/ui/hover/builders/item_hover_tip_builder.gd")
const EquipHoverTipBuilderScript := preload("res://scripts/ui/hover/builders/equip_hover_tip_builder.gd")

enum TabFilter { ALL, MATERIAL, PILL, EQUIP }
enum PickerFilter { NONE, EQUIP, BATTLE_ITEM, CULTIVATION_PILL }

const TAB_LABELS := ["全部", "材料", "丹药", "法宝"]

signal entry_clicked(entry: Dictionary)
signal entry_right_clicked(entry: Dictionary)
signal sort_requested(entries: Array)

@export var max_slots_show: int = 25
@export var grid_columns: int = 5
@export var title_text: String = "背包"
@export var show_info_on_click: bool = true

@onready var _title: Label = %Title
@onready var _content: Control = %BagContent
@onready var _grid: GridContainer = %BagGrid
@onready var _scroll: ScrollContainer = %Scroll
@onready var _filter_option: OptionButton = %FilterOption
@onready var _sort_button: TextureButton = %BagSort
@onready var _tabs_row: HBoxContainer = $Tabs

var _entries: Array = []
var _filtered_cache: Array = []
var _active_tab: TabFilter = TabFilter.ALL
var _picker_filter: PickerFilter = PickerFilter.NONE
var _saved_show_info_on_click := true
var _window_start: int = -1
var _slot_pool: Array[ItemView] = []
var _row_height: float = 96.0


func _ready() -> void:
	_grid.columns = maxi(1, grid_columns)
	_title.text = title_text
	for label in TAB_LABELS:
		_filter_option.add_item(label)
	_filter_option.item_selected.connect(_on_filter_selected)
	_bind_option_menu(_filter_option)
	_sort_button.pressed.connect(_on_sort_pressed)
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	_set_active_tab(TabFilter.ALL)
	_ensure_slot_pool()
	call_deferred("_measure_row_height")
	call_deferred("_refresh")


func set_title(text: String) -> void:
	title_text = text.strip_edges()
	if is_node_ready() and _title != null:
		_title.text = title_text if title_text != "" else "背包"


func set_entries(entries: Array) -> void:
	_entries = _normalize_entries(entries)
	if is_node_ready():
		_scroll.scroll_vertical = 0
		_refresh()


func set_picker_mode(filter: PickerFilter) -> void:
	if filter != PickerFilter.NONE and _picker_filter == PickerFilter.NONE:
		_saved_show_info_on_click = show_info_on_click
	_picker_filter = filter
	var is_picker := filter != PickerFilter.NONE
	show_info_on_click = false if is_picker else _saved_show_info_on_click
	if is_picker:
		_active_tab = TabFilter.ALL
	if is_node_ready():
		_set_picker_chrome(not is_picker)
		if is_picker:
			_set_active_tab(TabFilter.ALL)
		_scroll.scroll_vertical = 0
		_refresh()


func bind_inventory(inventory: Dictionary, owned_equips: Array = []) -> void:
	set_entries(build_entries_from_inventory(inventory, owned_equips))


static func build_entries_from_inventory(inventory: Dictionary, owned_equips: Array = []) -> Array:
	var out: Array = []
	for iid_v in inventory.keys():
		var iid := str(iid_v).strip_edges()
		var count := int(inventory.get(iid_v, 0))
		if iid == "" or count <= 0:
			continue
		var entry := _entry_from_item(iid, count)
		if not entry.is_empty():
			out.append(entry)
	for eid_v in owned_equips:
		var eid := int(eid_v)
		if eid <= 0:
			continue
		var entry := _entry_from_equip(eid)
		if not entry.is_empty():
			out.append(entry)
	out.sort_custom(_compare_entries)
	return out


func _refresh() -> void:
	_filtered_cache = _filtered_entries()
	_configure_content_size()
	_window_start = -1
	_sync_window_from_scroll(true)


func _ensure_slot_pool() -> void:
	var target := maxi(1, max_slots_show)
	while _slot_pool.size() < target:
		var view := _create_slot_view()
		if view != null:
			_slot_pool.append(view)
	while _slot_pool.size() > target:
		var last_idx := _slot_pool.size() - 1
		var extra: ItemView = _slot_pool[last_idx]
		_slot_pool.remove_at(last_idx)
		if is_instance_valid(extra):
			extra.queue_free()


func _measure_row_height() -> void:
	if _slot_pool.is_empty():
		return
	var sep := float(_grid.get_theme_constant("v_separation"))
	if sep <= 0.0:
		sep = 8.0
	_row_height = maxf(1.0, float(_slot_pool[0].custom_minimum_size.y) + sep)
	_refresh()


func _configure_content_size() -> void:
	var cols := maxi(1, grid_columns)
	var item_count := _filtered_cache.size()
	if item_count <= 0:
		if _content != null:
			_content.custom_minimum_size = Vector2.ZERO
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		return
	var data_rows := ceili(float(item_count) / float(cols))
	var content_h := maxf(_row_height, data_rows * _row_height)
	if _content != null:
		_content.custom_minimum_size = Vector2(0.0, content_h)
	var viewport_h := float(_scroll.size.y)
	_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if content_h > viewport_h + 1.0
		else ScrollContainer.SCROLL_MODE_DISABLED
	)


func _visible_row_count() -> int:
	return ceili(float(maxi(1, max_slots_show)) / float(maxi(1, grid_columns)))


func _max_window_start_row() -> int:
	var cols := maxi(1, grid_columns)
	var data_rows := ceili(float(_filtered_cache.size()) / float(cols))
	return maxi(0, data_rows - _visible_row_count())


func _on_scroll_changed(_value: float) -> void:
	_sync_window_from_scroll(false)


func _sync_window_from_scroll(force: bool) -> void:
	if _slot_pool.is_empty() or _row_height <= 0.0:
		return
	if _filtered_cache.is_empty():
		_window_start = 0
		_grid.position = Vector2.ZERO
		for view in _slot_pool:
			_hide_slot(view)
		return
	var cols := maxi(1, grid_columns)
	var start_row := mini(_max_window_start_row(), maxi(0, int(floor(float(_scroll.scroll_vertical) / _row_height))))
	var new_start := start_row * cols
	if not force and new_start == _window_start:
		return
	_window_start = new_start
	_grid.position = Vector2(0.0, start_row * _row_height)
	for i in _slot_pool.size():
		var view: ItemView = _slot_pool[i]
		var data_index := _window_start + i
		if data_index < _filtered_cache.size():
			view.visible = true
			_bind_entry(view, _filtered_cache[data_index] as Dictionary, data_index)
		else:
			_hide_slot(view)


func _create_slot_view() -> ItemView:
	var node := ItemScene.instantiate()
	if not node is ItemView:
		node.queue_free()
		return null
	var view := node as ItemView
	view.show_name_label = true
	view.click_enabled = true
	view.visible = false
	_grid.add_child(view)
	return view


func _hide_slot(view: ItemView) -> void:
	if view == null:
		return
	_disconnect_slot(view)
	_clear_hover_tip(view)
	view.apply_empty(null)
	view.set_learn_blocked(false)
	view.visible = false
	view.show_info_on_click = false
	view.set_click_enabled(false)


func _bind_entry(view: ItemView, entry: Dictionary, index: int) -> void:
	if view == null:
		return
	_disconnect_slot(view)
	var icon: Texture2D = null
	var item_name := str(entry.get("name", "")).strip_edges()
	var quality := str(entry.get("quality", "")).strip_edges()
	var count := maxi(1, int(entry.get("count", 1)))
	var kind := str(entry.get("kind", "item"))
	if kind == "equip":
		var equip_cfg := ConfigManager.equip_by_id(int(entry.get("id", -1)))
		if item_name == "":
			item_name = str(equip_cfg.get("name", "法宝"))
		icon = BattleInitDataScript._resolve_icon_texture(equip_cfg)
		if quality == "":
			quality = _quality_label_from_int(int(equip_cfg.get("quality", 1)))
	else:
		var item_id := str(entry.get("id", ""))
		if item_name == "" and ConfigManager != null:
			item_name = str(ConfigManager.get_item_display_name(item_id))
		if ConfigManager != null:
			var def := ConfigManager.item_def_by_id(item_id)
			if def != null:
				icon = ItemDefScript.resolve_icon_texture(def.icon_path, null)
				if quality == "":
					quality = def.rarity
	var learn_blocked := false
	if kind == "item" and ConfigManager != null:
		var item_def := ConfigManager.item_def_by_id(str(entry.get("id", "")))
		learn_blocked = ItemInfoPayloadBuilderScript.learning_book_condition_unmet(item_def)
	view.apply_display(icon, item_name, count, Color.WHITE, quality, learn_blocked)
	view.show_info_on_click = show_info_on_click
	if show_info_on_click:
		view.set_info_entry(entry)
	else:
		view.clear_info_entry()
	view.set_click_enabled(true)
	_bind_hover_tip(view, entry)
	view.clicked.connect(_on_slot_clicked.bind(index))
	view.right_clicked.connect(_on_slot_right_clicked.bind(index))


func _disconnect_slot(view: ItemView) -> void:
	if view == null:
		return
	for conn in view.clicked.get_connections():
		view.clicked.disconnect(conn["callable"])
	for conn in view.right_clicked.get_connections():
		view.right_clicked.disconnect(conn["callable"])


func _on_slot_clicked(index: int) -> void:
	if index < 0 or index >= _filtered_cache.size():
		return
	entry_clicked.emit((_filtered_cache[index] as Dictionary).duplicate(true))


func _on_slot_right_clicked(index: int) -> void:
	if index < 0 or index >= _filtered_cache.size():
		return
	entry_right_clicked.emit((_filtered_cache[index] as Dictionary).duplicate(true))


func _on_filter_selected(index: int) -> void:
	_set_active_tab(index as TabFilter)
	_scroll.scroll_vertical = 0
	_refresh()


func _on_sort_pressed() -> void:
	_entries.sort_custom(_compare_entries)
	_scroll.scroll_vertical = 0
	_refresh()
	sort_requested.emit(_entries.duplicate(true))


func _set_active_tab(tab: TabFilter) -> void:
	_active_tab = tab
	if _filter_option != null and _filter_option.selected != int(tab):
		_filter_option.select(int(tab))


func _bind_option_menu(option: OptionButton) -> void:
	var panel_theme := theme
	if panel_theme == null or option == null:
		return
	var popup := option.get_popup()
	if popup != null:
		popup.theme = panel_theme


func _filtered_entries() -> Array:
	var out: Array = []
	for entry_v in _entries:
		if not entry_v is Dictionary:
			continue
		var entry := entry_v as Dictionary
		if not _matches_picker_filter(entry, _picker_filter):
			continue
		if _picker_filter != PickerFilter.NONE or _matches_tab(entry, _active_tab):
			out.append(entry)
	return out


func _set_picker_chrome(show_chrome: bool) -> void:
	if _tabs_row != null:
		_tabs_row.visible = show_chrome
	if _sort_button != null:
		_sort_button.visible = show_chrome


func _ensure_hover_tip(view: ItemView) -> HoverTipSource:
	var tip := view.get_node_or_null("BagHoverTip") as HoverTipSource
	if tip == null:
		tip = HoverTipSourceScript.new()
		tip.name = "BagHoverTip"
		tip.target_path = NodePath("..")
		view.add_child(tip)
	return tip


func _bind_hover_tip(view: ItemView, entry: Dictionary) -> void:
	var tip := _ensure_hover_tip(view)
	var payload := _hover_payload_for_entry(entry)
	tip.enabled = not HoverTipPayloadScript.is_empty(payload)
	if tip.enabled:
		tip.set_payload(payload)
	else:
		tip.clear_payload()


func _clear_hover_tip(view: ItemView) -> void:
	var tip := view.get_node_or_null("BagHoverTip") as HoverTipSource
	if tip != null:
		tip.clear_payload()
		tip.enabled = false


func _hover_payload_for_entry(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "item")) == "equip":
		return EquipHoverTipBuilderScript.build(int(entry.get("id", -1)))
	var item_id := str(entry.get("id", "")).strip_edges()
	var def := _item_def(item_id)
	if def != null and def.has_fight_config():
		return ItemHoverTipBuilderScript.build(
			def.fight_id, null, maxi(1, int(entry.get("count", 1)))
		)
	var info := ItemInfoPayloadBuilderScript.from_entry(entry)
	if info.is_empty():
		return {}
	var lines: PackedStringArray = PackedStringArray()
	var desc := str(info.get("desc", "")).strip_edges()
	if desc != "":
		lines.append(desc)
	for line_v in info.get("detail_lines", []) as Array:
		var line := str(line_v).strip_edges()
		if line != "":
			lines.append(line)
	return HoverTipPayloadScript.make({
		"title": str(info.get("title", "")),
		"title_color": info.get("title_color", Color.WHITE),
		"lines": lines,
		"icon": info.get("icon"),
		"footer": str(info.get("footer", "")).strip_edges(),
	})


static func _matches_picker_filter(entry: Dictionary, filter: PickerFilter) -> bool:
	match filter:
		PickerFilter.NONE:
			return true
		PickerFilter.EQUIP:
			var kind := str(entry.get("kind", "item"))
			if kind == "equip":
				return true
			return kind == "item" and str(entry.get("item_type", "")) == EnumItemTypeScript.LABEL_TREASURE
		PickerFilter.BATTLE_ITEM:
			if str(entry.get("kind", "item")) != "item":
				return false
			var def := _item_def(str(entry.get("id", "")))
			return def != null and def.has_fight_config()
		PickerFilter.CULTIVATION_PILL:
			if str(entry.get("kind", "item")) != "item":
				return false
			var pill_def := _item_def(str(entry.get("id", "")))
			return pill_def != null and pill_def.is_cultivation_pill()
	return true


static func _matches_tab(entry: Dictionary, tab: TabFilter) -> bool:
	match tab:
		TabFilter.ALL:
			return true
		TabFilter.MATERIAL:
			return str(entry.get("kind", "item")) == "item" and EnumItemTypeScript.is_material_label(str(entry.get("item_type", "")))
		TabFilter.PILL:
			return str(entry.get("kind", "item")) == "item" and str(entry.get("item_type", "")) == EnumItemTypeScript.LABEL_PILL
		TabFilter.EQUIP:
			var kind := str(entry.get("kind", "item"))
			return kind == "equip" or (kind == "item" and str(entry.get("item_type", "")) == EnumItemTypeScript.LABEL_TREASURE)
	return true


static func _normalize_entries(entries: Array) -> Array:
	var out: Array = []
	for row_v in entries:
		if not row_v is Dictionary:
			continue
		var row := (row_v as Dictionary).duplicate(true)
		var kind := str(row.get("kind", "item"))
		if kind == "equip":
			row["kind"] = "equip"
			row["count"] = 1
			if not row.has("sort_name"):
				row["sort_name"] = str(ConfigManager.equip_by_id(int(row.get("id", -1))).get("name", "法宝"))
			if not row.has("item_type"):
				row["item_type"] = EnumItemTypeScript.LABEL_EQUIP
		else:
			row["kind"] = "item"
			var item_id := str(row.get("id", "")).strip_edges()
			row["id"] = item_id
			row["count"] = maxi(1, int(row.get("count", 1)))
			var def := _item_def(item_id)
			if def != null:
				if not row.has("item_type"):
					row["item_type"] = def.item_type
				if not row.has("name"):
					row["name"] = def.name
				if not row.has("quality"):
					row["quality"] = def.rarity
			if not row.has("sort_name"):
				row["sort_name"] = str(row.get("name", item_id))
			if not row.has("item_type"):
				row["item_type"] = ""
		out.append(row)
	return out


static func _entry_from_item(item_id: String, count: int) -> Dictionary:
	var iid := item_id.strip_edges()
	if iid == "" or count <= 0:
		return {}
	var def := _item_def(iid)
	return {
		"kind": "item",
		"id": iid,
		"count": count,
		"item_type": def.item_type if def != null else "",
		"name": def.name if def != null else iid,
		"quality": def.rarity if def != null else "",
		"sort_name": def.name if def != null else iid,
	}


static func _entry_from_equip(equip_id: int) -> Dictionary:
	if equip_id <= 0:
		return {}
	var cfg := ConfigManager.equip_by_id(equip_id)
	var equip_name := str(cfg.get("name", "法宝"))
	return {
		"kind": "equip",
		"id": equip_id,
		"count": 1,
		"item_type": EnumItemTypeScript.LABEL_EQUIP,
		"name": equip_name,
		"quality": _quality_label_from_int(int(cfg.get("quality", 1))),
		"sort_name": equip_name,
	}


static func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var order_a := _entry_sort_order(a)
	var order_b := _entry_sort_order(b)
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("sort_name", "")) < str(b.get("sort_name", ""))


static func _entry_sort_order(entry: Dictionary) -> int:
	return EnumItemTypeScript.sort_order_for_entry(
		str(entry.get("kind", "item")),
		str(entry.get("item_type", ""))
	)


static func _item_def(item_id: String) -> ItemDef:
	if ConfigManager != null:
		return ConfigManager.item_def_by_id(item_id)
	return null


static func _quality_label_from_int(quality: int) -> String:
	if quality >= 5:
		return "传说"
	if quality >= 3:
		return "稀有"
	return ""
