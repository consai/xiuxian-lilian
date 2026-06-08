class_name BagBaseView
extends Control

## 储物/背包公用组件：视口内仅保留 [member max_slots_show] 个格子，滚动时动态换绑数据。

const ItemScene := preload("res://scenes/items/item.tscn")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")
const EnumItemTypeScript := preload("res://scripts/enum/enum_itemtype.gd")

enum TabFilter { ALL, MATERIAL, PILL, EQUIP }

const TAB_THEME_ACTIVE := &"TabActive"
const TAB_THEME_IDLE := &"TabIdle"

signal entry_clicked(entry: Dictionary)
signal entry_right_clicked(entry: Dictionary)
signal sort_requested(entries: Array)

@export var max_slots_show: int = 25
@export var grid_columns: int = 5
@export var title_text: String = "背包"

@onready var _title: Label = %Title
@onready var _content: Control = %BagContent
@onready var _grid: GridContainer = %BagGrid
@onready var _scroll: ScrollContainer = %Scroll
@onready var _tab_all: Button = %BagTabAll
@onready var _tab_material: Button = %BagTabMaterial
@onready var _tab_pill: Button = %BagTabPill
@onready var _tab_equip: Button = %BagTabEquip
@onready var _sort_button: Button = %BagSort

var _entries: Array = []
var _filtered_cache: Array = []
var _active_tab: TabFilter = TabFilter.ALL
var _selected_index: int = -1
var _window_start: int = -1
var _slot_pool: Array[ItemView] = []
var _row_height: float = 96.0
var _tabs: Array[Button] = []


func _ready() -> void:
	_grid.columns = maxi(1, grid_columns)
	_title.text = title_text
	_tabs = [_tab_all, _tab_material, _tab_pill, _tab_equip]
	_tab_all.pressed.connect(_on_tab_pressed.bind(TabFilter.ALL))
	_tab_material.pressed.connect(_on_tab_pressed.bind(TabFilter.MATERIAL))
	_tab_pill.pressed.connect(_on_tab_pressed.bind(TabFilter.PILL))
	_tab_equip.pressed.connect(_on_tab_pressed.bind(TabFilter.EQUIP))
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
	_selected_index = -1
	if is_node_ready():
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
	var viewport_rows := _visible_row_count()
	var data_rows := ceili(float(item_count) / float(cols)) if item_count > 0 else 0
	var total_rows := maxi(viewport_rows, data_rows)
	var content_h := maxf(_row_height, total_rows * _row_height)
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
	var cols := maxi(1, grid_columns)
	var start_row := mini(_max_window_start_row(), maxi(0, int(floor(float(_scroll.scroll_vertical) / _row_height))))
	var new_start := start_row * cols
	if not force and new_start == _window_start:
		return
	_window_start = new_start
	_grid.position = Vector2(0.0, start_row * _row_height)
	for i in _slot_pool.size():
		var data_index := _window_start + i
		if data_index < _filtered_cache.size():
			_bind_entry(_slot_pool[i], _filtered_cache[data_index] as Dictionary, data_index)
		else:
			_bind_empty(_slot_pool[i])


func _create_slot_view() -> ItemView:
	var node := ItemScene.instantiate()
	if not node is ItemView:
		node.queue_free()
		return null
	var view := node as ItemView
	view.show_name_label = false
	view.click_enabled = true
	_grid.add_child(view)
	return view


func _bind_empty(view: ItemView) -> void:
	if view == null:
		return
	_disconnect_slot(view)
	view.apply_empty(null, Color(1, 1, 1, 0))
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
		var equip_cfg := _equip_cfg(int(entry.get("id", -1)))
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
	view.apply_display(icon, item_name, count, Color.WHITE, quality)
	view.set_click_enabled(true)
	_set_selected(view, index == _selected_index, entry)
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
	_selected_index = index
	for i in _slot_pool.size():
		var data_index := _window_start + i
		if data_index >= _filtered_cache.size():
			break
		_set_selected(_slot_pool[i], data_index == _selected_index, _filtered_cache[data_index] as Dictionary)
	entry_clicked.emit((_filtered_cache[index] as Dictionary).duplicate(true))


func _on_slot_right_clicked(index: int) -> void:
	if index < 0 or index >= _filtered_cache.size():
		return
	entry_right_clicked.emit((_filtered_cache[index] as Dictionary).duplicate(true))


func _set_selected(view: ItemView, selected: bool, entry: Dictionary = {}) -> void:
	if view == null:
		return
	var highlight := view.get_node_or_null("%GcItemHighlight") as Panel
	if highlight == null:
		return
	if selected:
		highlight.visible = true
		highlight.self_modulate = Color(0.109804, 0.596078, 1.0)
		return
	match str(entry.get("quality", "")).strip_edges():
		"稀有":
			highlight.visible = true
			highlight.self_modulate = Color(0.45, 0.72, 1.0)
		"传说":
			highlight.visible = true
			highlight.self_modulate = Color(1.0, 0.82, 0.35)
		_:
			highlight.visible = false


func _on_tab_pressed(tab: TabFilter) -> void:
	_set_active_tab(tab)
	_selected_index = -1
	_scroll.scroll_vertical = 0
	_refresh()


func _on_sort_pressed() -> void:
	_entries.sort_custom(_compare_entries)
	_selected_index = -1
	_scroll.scroll_vertical = 0
	_refresh()
	sort_requested.emit(_entries.duplicate(true))


func _set_active_tab(tab: TabFilter) -> void:
	_active_tab = tab
	var tab_nodes := [
		[_tab_all, TabFilter.ALL],
		[_tab_material, TabFilter.MATERIAL],
		[_tab_pill, TabFilter.PILL],
		[_tab_equip, TabFilter.EQUIP],
	]
	for pair in tab_nodes:
		var btn := pair[0] as Button
		if btn == null:
			continue
		btn.theme_type_variation = TAB_THEME_ACTIVE if pair[1] == tab else TAB_THEME_IDLE


func _filtered_entries() -> Array:
	var out: Array = []
	for entry_v in _entries:
		if not entry_v is Dictionary:
			continue
		var entry := entry_v as Dictionary
		if _matches_tab(entry, _active_tab):
			out.append(entry)
	return out


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
				row["sort_name"] = str(_equip_cfg(int(row.get("id", -1))).get("name", "法宝"))
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
	var cfg := _equip_cfg(equip_id)
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


static func _equip_cfg(equip_id: int) -> Dictionary:
	if ConfigManager != null and ConfigManager.has_method("equip_by_id"):
		return ConfigManager.equip_by_id(equip_id) as Dictionary
	return {}


static func _quality_label_from_int(quality: int) -> String:
	if quality >= 5:
		return "传说"
	if quality >= 3:
		return "稀有"
	return ""
