extends Control
class_name BuffStatusBar

## Buff/被动状态栏：被动恒靠左，每行最多 6 个自动换行。

const BuffStatusItemScene := preload("res://scenes/zhandou/buff_status_item.tscn")
const ITEMS_PER_ROW := 3
const ROW_SEPARATION := 4
const ROW_GAP := 2
const ITEM_WIDTH := 34
const ITEM_HEIGHT := 52

@export_enum("begin", "end", "center") var row_alignment: String = "begin"

@onready var _rows_root: VBoxContainer = %Rows

var _items: Array[BuffStatusItem] = []
var _row_boxes: Array[HBoxContainer] = []


func _ready() -> void:
	_apply_row_alignment()


func sync_buffs(buffs: Dictionary) -> void:
	var active: Array = []
	for bid_v in buffs.keys():
		var bid := str(bid_v).strip_edges()
		if bid == "":
			continue
		var inst_v: Variant = buffs[bid]
		if not inst_v is Dictionary:
			continue
		var inst := inst_v as Dictionary
		var stacks := int(inst.get("stacks", 0))
		var duration_left := float(inst.get("duration_left", 0.0))
		if stacks <= 0 or duration_left <= 0.0:
			continue
		active.append({
			"kind": "buff",
			"id": bid,
			"stacks": stacks,
			"duration_left": duration_left,
			"show_time": true,
		})
	sync_entries(active)


func sync_unit(unit: ZhandouObj) -> void:
	if unit == null:
		sync_entries([])
		return
	sync_entries(unit.build_status_bar_entries())


func sync_entries(entries: Array) -> void:
	var active: Array = _sorted_entries(entries)
	_ensure_layout(active.size())
	for i in active.size():
		var row := active[i] as Dictionary
		var item := _items[i]
		item.apply_status(row)
		item.visible = true
	for i in range(active.size(), _items.size()):
		_items[i].clear_item()
		_items[i].visible = false
	_update_bar_size(active.size())


## 被动排在 Buff 之前（始终靠左），同类按 id 稳定排序。
static func _sorted_entries(entries: Array) -> Array:
	var active: Array = entries.duplicate()
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var passive_a: bool = str(a.get("kind", "")) == "passive"
		var passive_b: bool = str(b.get("kind", "")) == "passive"
		if passive_a != passive_b:
			return passive_a
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return active


func _ensure_layout(entry_count: int) -> void:
	var row_count: int = 0
	if entry_count > 0:
		row_count = int(ceil(float(entry_count) / float(ITEMS_PER_ROW)))
	while _items.size() < entry_count:
		var item := BuffStatusItemScene.instantiate() as BuffStatusItem
		_items.append(item)
	while _row_boxes.size() < row_count:
		var row_box := HBoxContainer.new()
		row_box.add_theme_constant_override("separation", ROW_SEPARATION)
		_apply_alignment_to_row(row_box)
		_rows_root.add_child(row_box)
		_row_boxes.append(row_box)
	for i in row_count:
		_row_boxes[i].visible = true
	for i in range(row_count, _row_boxes.size()):
		_row_boxes[i].visible = false
	for i in entry_count:
		var row_index: int = i / ITEMS_PER_ROW
		var row_box: HBoxContainer = _row_boxes[row_index]
		var item: BuffStatusItem = _items[i]
		if item.get_parent() != row_box:
			if item.get_parent() != null:
				item.get_parent().remove_child(item)
			row_box.add_child(item)


func _update_bar_size(entry_count: int) -> void:
	if entry_count <= 0:
		custom_minimum_size = Vector2(120, 0)
		return
	var row_count: int = int(ceil(float(entry_count) / float(ITEMS_PER_ROW)))
	var cols: int = mini(entry_count, ITEMS_PER_ROW)
	var width: float = float(cols) * float(ITEM_WIDTH) + float(maxi(0, cols - 1)) * float(ROW_SEPARATION)
	var height: float = float(row_count) * float(ITEM_HEIGHT) + float(maxi(0, row_count - 1)) * float(ROW_GAP)
	custom_minimum_size = Vector2(maxi(120.0, width), height)


func _apply_row_alignment() -> void:
	for row_box in _row_boxes:
		_apply_alignment_to_row(row_box)


func _apply_alignment_to_row(row_box: HBoxContainer) -> void:
	match row_alignment:
		"end":
			row_box.alignment = BoxContainer.ALIGNMENT_END
		"center":
			row_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_:
			row_box.alignment = BoxContainer.ALIGNMENT_BEGIN
