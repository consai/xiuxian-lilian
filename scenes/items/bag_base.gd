class_name BagBaseView
extends Control

## 储物/背包公用组件：无物品时不显示占位格；有物品时视口内最多 [member max_slots_show] 格，滚动时动态换绑数据。

const ItemScene := preload("res://scenes/items/item.tscn")
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
const ItemDefScript := preload("res://scripts/features/inventory/domain/item_def.gd")
const ItemIconResolverScript := preload(
	"res://scripts/features/inventory/presentation/item_icon_resolver.gd"
)
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)
const InventoryEquipQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_equip_query_application.gd"
)
const ItemInfoPayloadBuilderScript := preload("res://scripts/ui/item_info_payload_builder.gd")
const HoverTipSourceScript := preload("res://scripts/ui/hover/hover_tip_source.gd")
const HoverTipPayloadScript := preload("res://scripts/ui/hover/hover_tip_payload.gd")
const ItemHoverTipBuilderScript := preload("res://scripts/ui/hover/builders/item_hover_tip_builder.gd")
const EquipHoverTipBuilderScript := preload("res://scripts/ui/hover/builders/equip_hover_tip_builder.gd")

const FILTER_ALL := "全部"

enum PickerFilter { NONE, EQUIP, BATTLE_ITEM, CULTIVATION_PILL }

signal entry_clicked(entry: Dictionary)
signal entry_right_clicked(entry: Dictionary)
signal sort_requested(entries: Array)

enum SortField {
	QUALITY,
	TIER,
	TYPE,
}

const SORT_FIELD_LABELS := {
	SortField.QUALITY: "品质",
	SortField.TIER: "阶级",
	SortField.TYPE: "类型",
}

@export var max_slots_show: int = 25
@export var grid_columns: int = 5
@export var title_text: String = "背包"
@export var show_info_on_click: bool = true

@onready var _title: Label = %Title
@onready var _content: Control = %BagContent
@onready var _grid: GridContainer = %BagGrid
@onready var _scroll: ScrollContainer = %Scroll
@onready var _filter_bar: HBoxContainer = %FilterBar
@onready var _sort_bar: Control = %SortBar
@onready var _sort_field_option: OptionButton = %SortFieldOption

var _entries: Array = []
var _filtered_cache: Array = []
var _type_filters: PackedStringArray = PackedStringArray([FILTER_ALL])
var _active_filter: String = FILTER_ALL
var _picker_filter: PickerFilter = PickerFilter.NONE
var _saved_show_info_on_click := true
var _window_start: int = -1
var _slot_pool: Array[ItemView] = []
var _row_height: float = 96.0
var _entry_view_cache: Dictionary = {}
var _hover_payload_cache: Dictionary = {}
var _sort_field: SortField = SortField.TYPE # 默认按类型排序
var _sort_ascending: bool = true # 默认升序
var _game_session: Node


func bind_game_session(game_session: Node) -> void:
	if game_session == null:
		push_error("BagBaseView: GameSession 未注入")
		return
	_game_session = game_session


func _ready() -> void:
	_grid.columns = maxi(1, grid_columns)
	_title.text = title_text
	_setup_sort_options()
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	_ensure_slot_pool()
	call_deferred("_measure_row_height")
	call_deferred("_refresh")


func set_title(text: String) -> void:
	title_text = text.strip_edges()
	if is_node_ready() and _title != null:
		_title.text = title_text if title_text != "" else "背包"


func set_entries(entries: Array) -> void:
	_entries = _normalize_entries(entries)
	_entry_view_cache.clear()
	_hover_payload_cache.clear()
	_apply_sort(false)
	if is_node_ready():
		var saved_scroll := _scroll.scroll_vertical
		_refresh()
		_scroll.scroll_vertical = _clamp_scroll_vertical(saved_scroll)


func set_picker_mode(filter: PickerFilter) -> void:
	if filter != PickerFilter.NONE and _picker_filter == PickerFilter.NONE:
		_saved_show_info_on_click = show_info_on_click
	_picker_filter = filter
	var is_picker := filter != PickerFilter.NONE
	show_info_on_click = false if is_picker else _saved_show_info_on_click
	if is_picker:
		_active_filter = FILTER_ALL
	if is_node_ready():
		_set_picker_chrome(not is_picker)
		if is_picker:
			_set_active_filter(FILTER_ALL)
		_scroll.scroll_vertical = 0
		_refresh()


func bind_inventory(inventory: Dictionary, owned_equips: Array = [], game_session: Node = null) -> void:
	if game_session != null:
		bind_game_session(game_session)
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
	out.sort_custom(_compare_entries_default)
	return out


func _refresh() -> void:
	_rebuild_type_filters()
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


func _clamp_scroll_vertical(scroll: int) -> int:
	if _content == null or _scroll == null:
		return maxi(0, scroll)
	var max_scroll := int(
		maxf(0.0, _content.custom_minimum_size.y - float(_scroll.size.y))
	)
	return clampi(scroll, 0, max_scroll)


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
	view.clicked.connect(_on_slot_view_clicked.bind(view))
	view.right_clicked.connect(_on_slot_view_right_clicked.bind(view))
	_grid.add_child(view)
	return view


func _hide_slot(view: ItemView) -> void:
	if view == null:
		return
	view.name = "BagSlot"
	_clear_hover_tip(view)
	view.set_meta("bag_entry_index", -1)
	view.set_meta("bag_entry_cache_key", "")
	view.apply_empty(null)
	view.set_learn_blocked(false)
	view.visible = false
	view.show_info_on_click = false
	view.set_click_enabled(false)


func _bind_entry(view: ItemView, entry: Dictionary, index: int) -> void:
	if view == null:
		return
	view.name = _entry_node_name(entry)
	view.set_meta("bag_entry_index", index)
	var cache_key := _entry_cache_key(entry)
	var view_cache_key := str(view.get_meta("bag_entry_cache_key", ""))
	if cache_key == view_cache_key:
		view.show_info_on_click = show_info_on_click
		if show_info_on_click:
			view.set_info_entry(entry)
		else:
			view.clear_info_entry()
		view.set_click_enabled(true)
		return
	view.set_meta("bag_entry_cache_key", cache_key)
	var data := _entry_view_data(entry, cache_key)
	view.apply_display(
		data.get("icon") as Texture2D,
		str(data.get("name", "")),
		int(data.get("count", 1)),
		Color.WHITE,
		str(data.get("quality", "")),
		bool(data.get("learn_blocked", false)),
		int(data.get("tier", 1))
	)
	view.show_info_on_click = show_info_on_click
	if show_info_on_click:
		view.set_info_entry(entry)
	else:
		view.clear_info_entry()
	view.set_click_enabled(true)
	_bind_hover_tip(view, data.get("hover_payload", {}) as Dictionary)


func _entry_node_name(entry: Dictionary) -> String:
	var kind := str(entry.get("kind", EnumRewardKind.LABEL_ITEM))
	var id_text := str(entry.get("id", "")).strip_edges()
	if kind == EnumRewardKind.LABEL_ITEM and id_text != "":
		return "BagItem_%s" % id_text
	if kind == EnumRewardKind.LABEL_EQUIP and id_text != "":
		return "BagEquip_%s" % id_text
	return "BagEntry"


func _on_slot_view_clicked(view: ItemView) -> void:
	if not is_instance_valid(view):
		return
	_on_slot_clicked(int(view.get_meta("bag_entry_index", -1)))


func _on_slot_view_right_clicked(view: ItemView) -> void:
	if not is_instance_valid(view):
		return
	_on_slot_right_clicked(int(view.get_meta("bag_entry_index", -1)))


func _on_slot_clicked(index: int) -> void:
	if index < 0 or index >= _filtered_cache.size():
		return
	entry_clicked.emit((_filtered_cache[index] as Dictionary).duplicate(true))


func _on_slot_right_clicked(index: int) -> void:
	if index < 0 or index >= _filtered_cache.size():
		return
	entry_right_clicked.emit((_filtered_cache[index] as Dictionary).duplicate(true))


func _on_filter_button_pressed(filter_label: String) -> void:
	_set_active_filter(filter_label)
	_scroll.scroll_vertical = 0
	_refresh()


func _rebuild_type_filters() -> void:
	if _picker_filter != PickerFilter.NONE:
		return
	var previous := _active_filter
	var type_set := {}
	for entry_v in _entries:
		if not entry_v is Dictionary:
			continue
		var type_label := _entry_primary_type_label(entry_v as Dictionary)
		if type_label != "":
			type_set[type_label] = true
	var types: Array = type_set.keys()
	types.sort_custom(_compare_filter_labels)
	var filters := PackedStringArray([FILTER_ALL])
	for type_label_v in types:
		filters.append(str(type_label_v))
	if filters == _type_filters:
		if _filter_bar.get_child_count() == 0:
			_build_filter_buttons()
		_sync_filter_button_states()
		if previous in filters and _active_filter != previous:
			_set_active_filter(previous)
		return
	_type_filters = filters
	_build_filter_buttons()
	if previous in filters:
		_set_active_filter(previous)
	else:
		_set_active_filter(FILTER_ALL)


func _build_filter_buttons() -> void:
	_clear_container(_filter_bar)
	for filter_label in _type_filters:
		var button := Button.new()
		button.text = filter_label
		button.custom_minimum_size = Vector2(0, 40)
		button.theme_type_variation = "TabActive" if filter_label == _active_filter else "TabIdle"
		button.pressed.connect(_on_filter_button_pressed.bind(filter_label))
		_filter_bar.add_child(button)


func _sync_filter_button_states() -> void:
	if _filter_bar == null:
		return
	for child in _filter_bar.get_children():
		if child is Button:
			var button := child as Button
			button.theme_type_variation = "TabActive" if button.text == _active_filter else "TabIdle"


func _setup_sort_options() -> void:
	if _sort_field_option != null:
		_sort_field_option.clear()
		for field in [SortField.QUALITY, SortField.TIER, SortField.TYPE]:
			_sort_field_option.add_item(
				_sort_field_option_label(field, true),
				_sort_option_id(field, true)
			)
			_sort_field_option.add_item(
				_sort_field_option_label(field, false),
				_sort_option_id(field, false)
			)
		var sort_popup := _sort_field_option.get_popup()
		if sort_popup != null:
			sort_popup.id_pressed.connect(_on_sort_field_option_pressed)
			sort_popup.theme = theme
	_sync_sort_option_states()


func _on_sort_field_option_pressed(option_id: int) -> void:
	_sort_field = (option_id >> 1) as SortField
	_sort_ascending = (option_id & 1) == 0
	_apply_sort()




func _apply_sort(should_emit_sort_signal: bool = true) -> void:
	_entries.sort_custom(_compare_entries_active)
	_sync_sort_option_states()
	if not is_node_ready():
		return
	_scroll.scroll_vertical = 0
	_refresh()
	if should_emit_sort_signal:
		sort_requested.emit(_entries.duplicate(true))


func _sync_sort_option_states() -> void:
	if _sort_field_option != null:
		var option_id := _sort_option_id(_sort_field, _sort_ascending)
		var field_index := _sort_field_option.get_item_index(option_id)
		if field_index >= 0:
			_sort_field_option.select(field_index)


func _sort_option_id(field: SortField, ascending: bool) -> int:
	return int(field) * 2 + (0 if ascending else 1)


func _sort_field_option_label(field: SortField, ascending: bool) -> String:
	var base := str(SORT_FIELD_LABELS.get(field, ""))
	return "%s ▲" % base if ascending else "%s ▼" % base


func _compare_entries_active(a: Dictionary, b: Dictionary) -> bool:
	var cmp := _compare_entries_by_field(a, b, _sort_field)
	if cmp != 0:
		return cmp < 0 if _sort_ascending else cmp > 0

	return str(a.get("sort_name", "")) < str(b.get("sort_name", ""))


static func _compare_entries_by_field(a: Dictionary, b: Dictionary, field: SortField) -> int:
	match field:
		SortField.QUALITY:
			return _entry_quality_value(a) - _entry_quality_value(b)
		SortField.TIER:
			return _entry_tier_value(a) - _entry_tier_value(b)
		SortField.TYPE:
			return _entry_sort_order(a) - _entry_sort_order(b)
		_:
			return 0


static func _entry_quality_value(entry: Dictionary) -> int:
	return EnumQuality.from_label(str(entry.get("quality", "")), EnumQuality.Type.LOW)


static func _entry_tier_value(entry: Dictionary) -> int:
	return maxi(1, int(entry.get("tier", 1)))


func _set_active_filter(filter_label: String) -> void:
	_active_filter = filter_label if filter_label != "" else FILTER_ALL
	if _type_filters.find(_active_filter) < 0:
		_active_filter = FILTER_ALL
	_sync_filter_button_states()


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _filtered_entries() -> Array:
	var out: Array = []
	for entry_v in _entries:
		if not entry_v is Dictionary:
			continue
		var entry := entry_v as Dictionary
		if not _matches_picker_filter(entry, _picker_filter):
			continue
		if _picker_filter != PickerFilter.NONE or _matches_filter(entry, _active_filter):
			out.append(entry)
	return out


func _set_picker_chrome(show_chrome: bool) -> void:
	if _filter_bar != null:
		_filter_bar.visible = show_chrome
	if _sort_bar != null:
		_sort_bar.visible = show_chrome


func _ensure_hover_tip(view: ItemView) -> HoverTipSource:
	var tip := view.get_node_or_null("BagHoverTip") as HoverTipSource
	if tip == null:
		tip = HoverTipSourceScript.new()
		tip.name = "BagHoverTip"
		tip.target_path = NodePath("..")
		view.add_child(tip)
	return tip


func _bind_hover_tip(view: ItemView, payload: Dictionary) -> void:
	var tip := _ensure_hover_tip(view)
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
	var cache_key := _entry_cache_key(entry)
	if _hover_payload_cache.has(cache_key):
		return (_hover_payload_cache[cache_key] as Dictionary).duplicate(true)
	var payload := _build_hover_payload_for_entry(entry)
	_hover_payload_cache[cache_key] = payload.duplicate(true)
	return payload


func _build_hover_payload_for_entry(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", EnumRewardKind.LABEL_ITEM)) == EnumRewardKind.LABEL_EQUIP:
		return EquipHoverTipBuilderScript.build(int(entry.get("id", -1)))
	var item_id := str(entry.get("id", "")).strip_edges()
	var def := _item_def(item_id)
	if def != null and def.has_fight_config():
		return ItemHoverTipBuilderScript.build(
			def.fight_id, null, maxi(1, int(entry.get("count", 1)))
		)
	var info := ItemInfoPayloadBuilderScript.from_entry(
		entry, _game_session.to_dict(), _game_session.major_realm_id()
	)
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


func _entry_view_data(entry: Dictionary, cache_key: String = "") -> Dictionary:
	var key := cache_key if cache_key != "" else _entry_cache_key(entry)
	if _entry_view_cache.has(key):
		return _entry_view_cache[key] as Dictionary
	var icon: Texture2D = null
	var item_name := str(entry.get("name", "")).strip_edges()
	var quality := str(entry.get("quality", "")).strip_edges()
	var tier := maxi(1, int(entry.get("tier", 1)))
	var count := maxi(1, int(entry.get("count", 1)))
	var kind := str(entry.get("kind", EnumRewardKind.LABEL_ITEM))
	var learn_blocked := false
	if kind == EnumRewardKind.LABEL_EQUIP:
		var equip_cfg := InventoryEquipQueryApplicationScript.equip_by_id(int(entry.get("id", -1)))
		if item_name == "":
			item_name = str(equip_cfg.get("name", "法宝"))
		icon = ZhandouInitDataScript._resolve_icon_texture(equip_cfg)
		if quality == "":
			quality = EnumQuality.display_label(int(equip_cfg.get("quality", 1)))
		tier = maxi(1, int(equip_cfg.get("tier", tier)))
	else:
		var item_id := str(entry.get("id", ""))
		if item_name == "":
			item_name = InventoryQueryApplicationScript.display_name(item_id)
		var def := InventoryQueryApplicationScript.definition_by_id(item_id)
		if def != null:
			icon = ItemIconResolverScript.resolve(def.icon_path, null)
			if quality == "":
				quality = EnumQuality.display_label(def.quality)
			tier = def.tier
			learn_blocked = ItemInfoPayloadBuilderScript.learning_book_condition_unmet(
				def, _game_session.to_dict(), _game_session.major_realm_id()
			)
	var data := {
		"icon": icon,
		"name": item_name,
		"count": count,
		"quality": quality,
		"tier": tier,
		"learn_blocked": learn_blocked,
		"hover_payload": _hover_payload_for_entry(entry),
	}
	_entry_view_cache[key] = data
	return data


func _entry_cache_key(entry: Dictionary) -> String:
	return "%s:%s:%d:%s:%d" % [
		str(entry.get("kind", EnumRewardKind.LABEL_ITEM)),
		str(entry.get("id", "")),
		maxi(1, int(entry.get("count", 1))),
		str(entry.get("quality", "")),
		maxi(1, int(entry.get("tier", 1))),
	]


static func _matches_picker_filter(entry: Dictionary, filter: PickerFilter) -> bool:
	match filter:
		PickerFilter.NONE:
			return true
		PickerFilter.EQUIP:
			var kind := str(entry.get("kind", EnumRewardKind.LABEL_ITEM))
			if kind == EnumRewardKind.LABEL_EQUIP:
				return true
			return (
				kind == EnumRewardKind.LABEL_ITEM
				and EnumItemType.is_treasure_primary(str(entry.get("primary_type", "")))
			)
		PickerFilter.BATTLE_ITEM:
			if str(entry.get("kind", EnumRewardKind.LABEL_ITEM)) != EnumRewardKind.LABEL_ITEM:
				return false
			var def := _item_def(str(entry.get("id", "")))
			return def != null and def.has_fight_config()
		PickerFilter.CULTIVATION_PILL:
			if str(entry.get("kind", EnumRewardKind.LABEL_ITEM)) != EnumRewardKind.LABEL_ITEM:
				return false
			var pill_def := _item_def(str(entry.get("id", "")))
			return pill_def != null and pill_def.is_cultivation_pill()
	return true


static func _entry_type_label(entry: Dictionary) -> String:
	if str(entry.get("kind", EnumRewardKind.LABEL_ITEM)) == EnumRewardKind.LABEL_EQUIP:
		return EnumItemType.full_label(
			EnumItemType.PRIMARY_TREASURE,
			EnumItemType.SECONDARY_ACTIVE_TREASURE
		)
	var type_label := str(entry.get("item_type", "")).strip_edges()
	if type_label == "":
		return "其他"
	return type_label


static func _entry_primary_type_label(entry: Dictionary) -> String:
	if str(entry.get("kind", EnumRewardKind.LABEL_ITEM)) == EnumRewardKind.LABEL_EQUIP:
		return EnumItemType.PRIMARY_TREASURE
	var primary_label := str(entry.get("primary_type", "")).strip_edges()
	if primary_label == "":
		return "其他"
	return primary_label


static func _compare_filter_labels(a: String, b: String) -> bool:
	var order_a: int = EnumItemType.filter_sort_order_for_label(a)
	var order_b: int = EnumItemType.filter_sort_order_for_label(b)
	if order_a != order_b:
		return order_a < order_b
	return a < b


static func _matches_filter(entry: Dictionary, filter_label: String) -> bool:
	if filter_label == FILTER_ALL:
		return true
	return _entry_primary_type_label(entry) == filter_label


static func _normalize_entries(entries: Array) -> Array:
	var out: Array = []
	for row_v in entries:
		if not row_v is Dictionary:
			continue
		var row := (row_v as Dictionary).duplicate(true)
		var kind := str(row.get("kind", EnumRewardKind.LABEL_ITEM))
		if kind == EnumRewardKind.LABEL_EQUIP:
			row["kind"] = EnumRewardKind.LABEL_EQUIP
			row["count"] = 1
			if not row.has("sort_name"):
				row["sort_name"] = str(InventoryEquipQueryApplicationScript.equip_by_id(int(row.get("id", -1))).get("name", "法宝"))
			if not row.has("item_type"):
				row["item_type"] = EnumItemType.full_label(
					EnumItemType.PRIMARY_TREASURE,
					EnumItemType.SECONDARY_ACTIVE_TREASURE
				)
			row["primary_type"] = EnumItemType.PRIMARY_TREASURE
			row["secondary_type"] = EnumItemType.SECONDARY_ACTIVE_TREASURE
			if not row.has("tier"):
				var equip_cfg := InventoryEquipQueryApplicationScript.equip_by_id(int(row.get("id", -1)))
				row["tier"] = maxi(1, int(equip_cfg.get("tier", 1)))
		else:
			row["kind"] = EnumRewardKind.LABEL_ITEM
			var item_id := str(row.get("id", "")).strip_edges()
			row["id"] = item_id
			row["count"] = maxi(1, int(row.get("count", 1)))
			var def := _item_def(item_id)
			if def != null:
				if not row.has("item_type"):
					row["item_type"] = def.item_type
				if not row.has("primary_type"):
					row["primary_type"] = def.primary_type
				if not row.has("secondary_type"):
					row["secondary_type"] = def.secondary_type
				if not row.has("name"):
					row["name"] = def.name
				if not row.has("quality"):
					row["quality"] = EnumQuality.display_label(def.quality)
				if not row.has("tier"):
					row["tier"] = def.tier
			if not row.has("sort_name"):
				row["sort_name"] = str(row.get("name", item_id))
			if not row.has("item_type"):
				row["item_type"] = ""
			if not row.has("primary_type"):
				row["primary_type"] = ""
			if not row.has("secondary_type"):
				row["secondary_type"] = ""
		out.append(row)
	return out


static func _entry_from_item(item_id: String, count: int) -> Dictionary:
	var iid := item_id.strip_edges()
	if iid == "" or count <= 0:
		return {}
	var def := _item_def(iid)
	return {
		"kind": EnumRewardKind.LABEL_ITEM,
		"id": iid,
		"count": count,
		"item_type": def.item_type if def != null else "",
		"primary_type": def.primary_type if def != null else "",
		"secondary_type": def.secondary_type if def != null else "",
		"name": def.name if def != null else iid,
		"quality": EnumQuality.display_label(def.quality) if def != null else "",
		"tier": def.tier if def != null else 1,
		"sort_name": def.name if def != null else iid,
	}


static func _entry_from_equip(equip_id: int) -> Dictionary:
	if equip_id <= 0:
		return {}
	var cfg := InventoryEquipQueryApplicationScript.equip_by_id(equip_id)
	var equip_name := str(cfg.get("name", "法宝"))
	return {
		"kind": EnumRewardKind.LABEL_EQUIP,
		"id": equip_id,
		"count": 1,
		"item_type": EnumItemType.full_label(
			EnumItemType.PRIMARY_TREASURE,
			EnumItemType.SECONDARY_ACTIVE_TREASURE
		),
		"primary_type": EnumItemType.PRIMARY_TREASURE,
		"secondary_type": EnumItemType.SECONDARY_ACTIVE_TREASURE,
		"name": equip_name,
		"quality": EnumQuality.display_label(int(cfg.get("quality", 1))),
		"tier": maxi(1, int(cfg.get("tier", 1))),
		"sort_name": equip_name,
	}


static func _compare_entries_default(a: Dictionary, b: Dictionary) -> bool:
	var cmp := _compare_entries_by_field(a, b, SortField.TYPE)
	if cmp != 0:
		return cmp < 0
	return str(a.get("sort_name", "")) < str(b.get("sort_name", ""))


static func _entry_sort_order(entry: Dictionary) -> int:
	return EnumItemType.sort_order_for_entry(
		str(entry.get("kind", EnumRewardKind.LABEL_ITEM)),
		str(entry.get("primary_type", "")),
		str(entry.get("secondary_type", ""))
	)


static func _item_def(item_id: String) -> ItemDef:
	return InventoryQueryApplicationScript.definition_by_id(item_id)
