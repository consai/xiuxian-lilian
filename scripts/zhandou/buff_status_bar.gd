extends Control
class_name BuffStatusBar

## 横向 Buff 状态栏：按运行时 buff 实例同步图标与剩余时间。

const BuffStatusItemScene := preload("res://scenes/zhandou/buff_status_item.tscn")

@export_enum("begin", "end", "center") var row_alignment: String = "begin"

@onready var _row: HBoxContainer = %Row

var _items: Array[BuffStatusItem] = []


func _ready() -> void:
	_apply_row_alignment()


func sync_buffs(buffs: Dictionary) -> void:
	var active: Array[Dictionary] = []
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
			"id": bid,
			"stacks": stacks,
			"duration_left": duration_left,
		})
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	while _items.size() < active.size():
		var item := BuffStatusItemScene.instantiate() as BuffStatusItem
		_row.add_child(item)
		_items.append(item)
	for i in active.size():
		var row := active[i]
		var item := _items[i]
		item.apply(
			str(row.get("id", "")),
			float(row.get("duration_left", 0.0)),
			int(row.get("stacks", 1))
		)
		item.visible = true
	for i in range(active.size(), _items.size()):
		_items[i].clear_item()
		_items[i].visible = false


func _apply_row_alignment() -> void:
	if _row == null:
		return
	match row_alignment:
		"end":
			_row.alignment = BoxContainer.ALIGNMENT_END
		"center":
			_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_:
			_row.alignment = BoxContainer.ALIGNMENT_BEGIN
