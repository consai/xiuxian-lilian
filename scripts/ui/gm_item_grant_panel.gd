extends Control

## GM 道具发放面板：模糊搜索配置表道具并经 GameState.grant_rewards 发放。

const GmItemSearchScript := preload("res://scripts/ui/gm_item_search.gd")

signal closed

@onready var _search_input: LineEdit = %SearchInput
@onready var _result_list: ItemList = %ResultList
@onready var _count_input: SpinBox = %CountInput
@onready var _message_label: Label = %MessageLabel
@onready var _close_button: TextureButton = %CloseButton

var _catalog: Array = []
var _filtered: Array = []


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(_on_close_pressed)
	%GrantButton.pressed.connect(_grant_selected)
	%GrantAllVisibleButton.pressed.connect(_grant_all_visible)
	_search_input.text_changed.connect(_on_search_changed)
	_result_list.item_activated.connect(func(_index: int) -> void: _grant_selected())
	_count_input.min_value = 1
	_count_input.max_value = 999
	_count_input.value = 10
	_build_catalog()
	_apply_filter("")


func refresh() -> void:
	_message_label.text = ""
	_apply_filter(_search_input.text)


func _build_catalog() -> void:
	_catalog.clear()
	for def_v in ConfigManager.items():
		if not def_v is ItemDef:
			continue
		var def := def_v as ItemDef
		_catalog.append({
			"id": def.id,
			"name": def.name,
			"type": def.item_type,
			"rarity": def.rarity,
		})
	_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)


func _on_search_changed(text: String) -> void:
	_apply_filter(text)


func _apply_filter(query: String) -> void:
	_filtered = GmItemSearchScript.filter_entries(_catalog, query)
	_rebuild_result_list()


func _rebuild_result_list() -> void:
	_result_list.clear()
	for row_v in _filtered:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var item_id := str(row.get("id", ""))
		var label := "%s · %s" % [str(row.get("name", item_id)), item_id]
		var meta_parts: PackedStringArray = []
		var item_type := str(row.get("type", ""))
		var rarity := str(row.get("rarity", ""))
		if item_type != "":
			meta_parts.append(item_type)
		if rarity != "":
			meta_parts.append(rarity)
		if not meta_parts.is_empty():
			label += " · " + " / ".join(meta_parts)
		var index := _result_list.add_item(label)
		_result_list.set_item_metadata(index, item_id)
	if _result_list.item_count > 0:
		_result_list.select(0)


func _selected_item_id() -> String:
	var selected := _result_list.get_selected_items()
	if selected.is_empty():
		return ""
	var index := int(selected[0])
	return str(_result_list.get_item_metadata(index))


func _grant_selected() -> void:
	var item_id := _selected_item_id()
	if item_id == "":
		_flash("请先选择道具")
		return
	_grant_item(item_id, int(_count_input.value))


func _grant_all_visible() -> void:
	if _filtered.is_empty():
		_flash("当前列表为空")
		return
	var count := int(_count_input.value)
	var granted := 0
	for row_v in _filtered:
		if not row_v is Dictionary:
			continue
		if _grant_item(str((row_v as Dictionary).get("id", "")), count, false):
			granted += 1
	_flash("已向背包发放可见列表中的 %d 种道具（各 x%d）" % [granted, count])


func _grant_item(item_id: String, count: int, announce_single: bool = true) -> bool:
	var applied: Array = GameState.grant_rewards([
		{"kind": "item", "id": item_id, "count": count},
	])
	if applied.is_empty():
		if announce_single:
			_flash("发放失败：未知道具或已达堆叠上限（%s）" % item_id)
		return false
	if announce_single:
		var row := applied[0] as Dictionary
		var display_name := ConfigManager.get_item_display_name(str(row.get("id", item_id)))
		_flash("已获得 %s x%d" % [display_name, int(row.get("count", 0))])
	return true


func _flash(message: String) -> void:
	_message_label.text = message


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
