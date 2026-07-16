extends Control

## GM 奖励发放面板：模糊搜索配置表道具 / 法宝并经 GameState.grant_rewards 发放。

const GmItemSearchScript := preload("res://scripts/ui/gm_item_search.gd")
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)

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
	var cm := _config_manager()
	var item_rows := InventoryQueryApplicationScript.all_definitions()
	for def_v in item_rows:
		if not def_v is ItemDef:
			continue
		var def := def_v as ItemDef
		_catalog.append({
			"kind": EnumRewardKind.LABEL_ITEM,
			"id": def.id,
			"name": def.name,
			"type": def.item_type,
			"primary_type": def.primary_type,
			"secondary_type": def.secondary_type,
			"quality": EnumQuality.display_label(def.quality),
			"tier": EnumItemTier.label(def.tier),
		})
	if cm == null:
		return
	var equip_ids := cm.call("all_equip_ids") as Array
	for equip_id_v in equip_ids:
		var equip_id := int(equip_id_v)
		var equip := cm.call("equip_by_id", equip_id) as Dictionary
		if equip.is_empty():
			continue
		_catalog.append({
			"kind": EnumRewardKind.LABEL_EQUIP,
			"id": equip_id,
			"name": str(equip.get("name", "法宝")),
			"type": "法宝",
			"primary_type": "法宝",
			"secondary_type": "战斗法宝",
			"quality": EnumQuality.display_label(int(equip.get("quality", 1))),
			"tier": EnumItemTier.label(maxi(1, int(equip.get("tier", 1)))),
		})
	_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var kind_order_a := 0 if str(a.get("kind", "")) == EnumRewardKind.LABEL_EQUIP else 1
		var kind_order_b := 0 if str(b.get("kind", "")) == EnumRewardKind.LABEL_EQUIP else 1
		if kind_order_a != kind_order_b:
			return kind_order_a < kind_order_b
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
		var reward_id := str(row.get("id", ""))
		var kind := str(row.get("kind", EnumRewardKind.LABEL_ITEM))
		var kind_label := "法宝" if kind == EnumRewardKind.LABEL_EQUIP else "道具"
		var label := "%s · %s · %s" % [kind_label, str(row.get("name", reward_id)), reward_id]
		var meta_parts: PackedStringArray = []
		var item_type := str(row.get("type", ""))
		var quality := str(row.get("quality", ""))
		var tier := str(row.get("tier", ""))
		if item_type != "":
			meta_parts.append(item_type)
		if tier != "":
			meta_parts.append(tier)
		if quality != "":
			meta_parts.append(quality)
		if not meta_parts.is_empty():
			label += " · " + " / ".join(meta_parts)
		var index := _result_list.add_item(label)
		_result_list.set_item_metadata(index, {
			"kind": kind,
			"id": row.get("id", ""),
		})
	if _result_list.item_count > 0:
		_result_list.select(0)


func _selected_entry() -> Dictionary:
	var selected := _result_list.get_selected_items()
	if selected.is_empty():
		return {}
	var index := int(selected[0])
	var meta_v: Variant = _result_list.get_item_metadata(index)
	if meta_v is Dictionary:
		return (meta_v as Dictionary).duplicate(true)
	return {}


func _grant_selected() -> void:
	var entry := _selected_entry()
	if entry.is_empty():
		_flash("请先选择道具或法宝")
		return
	_grant_entry(entry, int(_count_input.value))


func _grant_all_visible() -> void:
	if _filtered.is_empty():
		_flash("当前列表为空")
		return
	var count := int(_count_input.value)
	var granted := 0
	for row_v in _filtered:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if _grant_entry({"kind": row.get("kind", EnumRewardKind.LABEL_ITEM), "id": row.get("id", "")}, count, false):
			granted += 1
	_flash("已发放可见列表中的 %d 种奖励（道具各 x%d，法宝各 x1）" % [granted, count])


func _grant_entry(entry: Dictionary, count: int, announce_single: bool = true) -> bool:
	var game_state := _game_state()
	if game_state == null:
		if announce_single:
			_flash("发放失败：GameState 未初始化")
		return false
	var kind := str(entry.get("kind", EnumRewardKind.LABEL_ITEM))
	var reward_id: Variant = int(entry.get("id", -1)) if kind == EnumRewardKind.LABEL_EQUIP else str(entry.get("id", ""))
	var reward_count := 1 if kind == EnumRewardKind.LABEL_EQUIP else count
	var applied: Array = game_state.call("grant_rewards", [
		{"kind": kind, "id": reward_id, "count": reward_count},
	]) as Array
	if applied.is_empty():
		if announce_single:
			_flash("发放失败：未知奖励或已达上限（%s）" % str(reward_id))
		return false
	var data_events := _data_events()
	if data_events != null and data_events.has_method("emit_inventory_changed"):
		data_events.call("emit_inventory_changed")
	if announce_single:
		var cm := _config_manager()
		var row := applied[0] as Dictionary
		if str(row.get("kind", kind)) == EnumRewardKind.LABEL_EQUIP:
			var equip := {}
			if cm != null:
				equip = cm.call("equip_by_id", int(row.get("id", -1))) as Dictionary
			_flash("已获得法宝 %s" % str(equip.get("name", "法宝")))
		elif str(row.get("kind", kind)) == EnumRewardKind.LABEL_CURRENCY:
			_flash("已获得灵石 x%d" % int(row.get("count", 0)))
		else:
			var display_name := InventoryQueryApplicationScript.display_name(str(row.get("id", reward_id)))
			_flash("已获得 %s x%d" % [display_name, int(row.get("count", 0))])
	return true


func _flash(message: String) -> void:
	_message_label.text = message


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")


func _game_state() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("GameState")


func _data_events() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("DataEvents")
