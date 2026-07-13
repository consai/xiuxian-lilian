extends Control

## GM 战斗调试面板：战斗中实时查看/修改单位属性、被动与 Buff。

signal closed

const ATTR_LABELS: Dictionary = {
	EnumPlayerAttr.HP_MAX: "气血上限",
	EnumPlayerAttr.MP_MAX: "法力上限",
	EnumPlayerAttr.SHIELD: "护盾",
	EnumPlayerAttr.SPD: "出手速度",
	EnumPlayerAttr.PHYSICAL_ATK: "物理攻击",
	EnumPlayerAttr.MAGIC_ATK: "法术攻击",
	EnumPlayerAttr.PHYSICAL_DEF: "物理防御",
	EnumPlayerAttr.MAGIC_DEF: "法术防御",
	EnumPlayerAttr.CONTROL_POWER: "控制强度",
	EnumPlayerAttr.CONTROL_RESIST: "控制抗性",
	EnumPlayerAttr.HP_REGEN: "气血回复",
	EnumPlayerAttr.MP_REGEN: "法力回复",
	EnumPlayerAttr.CARRY: "负重",
	EnumPlayerAttr.DAMAGE_BONUS: "伤害加成",
	EnumPlayerAttr.DAMAGE_TAKEN: "受伤加成",
	EnumPlayerAttr.COMBAT_MP_RESTORE_2S: "战斗回蓝/2秒",
}

@onready var _status_label: Label = %StatusLabel
@onready var _message_label: Label = %MessageLabel
@onready var _unit_option: OptionButton = %UnitOption
@onready var _hp_input: SpinBox = %HpInput
@onready var _mp_input: SpinBox = %MpInput
@onready var _attr_list: VBoxContainer = %AttrList
@onready var _passive_list: ItemList = %PassiveList
@onready var _passive_option: OptionButton = %PassiveOption
@onready var _buff_list: ItemList = %BuffList
@onready var _buff_option: OptionButton = %BuffOption
@onready var _buff_stacks_input: SpinBox = %BuffStacksInput
@onready var _buff_duration_input: SpinBox = %BuffDurationInput
@onready var _close_button: TextureButton = %CloseButton

var _attr_inputs: Dictionary = {}
var _suppress_attr_signal: bool = false
var _refresh_accum: float = 0.0
var _passive_catalog: Array = []
var _buff_catalog: Array = []


func _ready() -> void:
	visible = false
	set_process(false)
	_close_button.pressed.connect(_on_close_pressed)
	%RefreshButton.pressed.connect(refresh)
	%ApplyVitalsButton.pressed.connect(_apply_vitals)
	%AddPassiveButton.pressed.connect(_add_selected_passive)
	%RemovePassiveButton.pressed.connect(_remove_selected_passive)
	%AddBuffButton.pressed.connect(_add_selected_buff)
	%RemoveBuffButton.pressed.connect(_remove_selected_buff)
	_passive_list.item_activated.connect(func(_index: int) -> void: _remove_selected_passive())
	_buff_list.item_activated.connect(func(_index: int) -> void: _remove_selected_buff())
	_unit_option.item_selected.connect(func(_index: int) -> void: _on_unit_changed())
	_build_catalogs()
	_configure_spin_ranges()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_accum += delta
	if _refresh_accum < 0.4:
		return
	_refresh_accum = 0.0
	_refresh_live_values()


func refresh() -> void:
	_message_label.text = ""
	if not GmBattleAccess.is_in_battle():
		_status_label.text = "当前不在战斗中（请先进入战斗场景）"
		_unit_option.clear()
		_clear_dynamic_sections()
		set_process(false)
		return
	_status_label.text = "战斗中 · 修改会立即写入域层并刷新 HUD"
	set_process(true)
	_rebuild_unit_options()
	_rebuild_passive_catalog_option()
	_rebuild_buff_catalog_option()
	_on_unit_changed()


func _configure_spin_ranges() -> void:
	_hp_input.min_value = 0.0
	_hp_input.max_value = 999999.0
	_hp_input.step = 1.0
	_mp_input.min_value = 0.0
	_mp_input.max_value = 999999.0
	_mp_input.step = 1.0
	_buff_stacks_input.min_value = 1.0
	_buff_stacks_input.max_value = 99.0
	_buff_stacks_input.value = 1.0
	_buff_duration_input.min_value = -1.0
	_buff_duration_input.max_value = 9999.0
	_buff_duration_input.step = 0.5
	_buff_duration_input.value = -1.0


func _build_catalogs() -> void:
	_passive_catalog.clear()
	for row_v in AbilityService.passive_abilities():
		if row_v is Dictionary:
			_passive_catalog.append(row_v as Dictionary)
	_passive_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	_buff_catalog.clear()
	var cm: Node = _config_manager()
	if cm != null and cm.has_method("all_buff_ids"):
		for bid_v in cm.call("all_buff_ids") as Array:
			var bid: String = str(bid_v).strip_edges()
			if bid == "":
				continue
			var row: Dictionary = cm.call("buff_by_id", bid) as Dictionary
			if row.is_empty():
				continue
			_buff_catalog.append(row)
	_buff_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", a.get("id", ""))) < str(b.get("name", b.get("id", "")))
	)


func _rebuild_unit_options() -> void:
	var selected_meta: Variant = null
	if _unit_option.item_count > 0 and _unit_option.selected >= 0:
		selected_meta = _unit_option.get_item_metadata(_unit_option.selected)
	_unit_option.clear()
	var units: Array = GmBattleAccess.list_units()
	for i in units.size():
		var entry: Dictionary = units[i] as Dictionary
		var label: String = str(entry.get("label", "单位 %d" % (i + 1)))
		_unit_option.add_item(label, i)
		_unit_option.set_item_metadata(i, {"key": entry.get("key", ""), "index": int(entry.get("index", 0))})
	if _unit_option.item_count <= 0:
		return
	var restore_index: int = 0
	if selected_meta is Dictionary:
		var meta: Dictionary = selected_meta as Dictionary
		for i in _unit_option.item_count:
			var item_meta_v: Variant = _unit_option.get_item_metadata(i)
			if item_meta_v is Dictionary and (item_meta_v as Dictionary) == meta:
				restore_index = i
				break
	_unit_option.select(restore_index)


func _rebuild_passive_catalog_option() -> void:
	_passive_option.clear()
	for row_v in _passive_catalog:
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v as Dictionary
		var aid: String = str(row.get("id", ""))
		if aid == "":
			continue
		_passive_option.add_item("被动 · %s" % str(row.get("name", aid)))
		_passive_option.set_item_metadata(_passive_option.item_count - 1, aid)
	if _passive_option.item_count > 0:
		_passive_option.select(0)


func _rebuild_buff_catalog_option() -> void:
	_buff_option.clear()
	for row_v in _buff_catalog:
		if not row_v is Dictionary:
			continue
		var row: Dictionary = row_v as Dictionary
		var bid: String = str(row.get("id", "")).strip_edges()
		if bid == "":
			continue
		_buff_option.add_item("%s · %s" % [str(row.get("name", bid)), bid])
		_buff_option.set_item_metadata(_buff_option.item_count - 1, bid)
	if _buff_option.item_count > 0:
		_buff_option.select(0)


func _selected_entry() -> Dictionary:
	if _unit_option.item_count <= 0 or _unit_option.selected < 0:
		return {}
	return GmBattleAccess.entry_at(_unit_option.selected)


func _on_unit_changed() -> void:
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		_clear_dynamic_sections()
		return
	_rebuild_attr_inputs(entry)
	_rebuild_passive_list(entry)
	_rebuild_buff_list(entry)
	_refresh_live_values()


func _clear_dynamic_sections() -> void:
	for child in _attr_list.get_children():
		child.queue_free()
	_attr_inputs.clear()
	_passive_list.clear()
	_buff_list.clear()


func _rebuild_attr_inputs(entry: Dictionary) -> void:
	for child in _attr_list.get_children():
		child.queue_free()
	_attr_inputs.clear()
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		return
	for key in EnumPlayerAttr.ALL_COMBAT_KEYS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = str(ATTR_LABELS.get(key, key))
		name_label.custom_minimum_size.x = 120.0
		var spin := SpinBox.new()
		spin.min_value = -99999.0
		spin.max_value = 999999.0
		spin.step = 1.0 if key != EnumPlayerAttr.DAMAGE_BONUS and key != EnumPlayerAttr.DAMAGE_TAKEN else 0.01
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value = (unit_v as ZhandouObj).get_attr(key, 0.0)
		var attr_key: String = key
		spin.value_changed.connect(func(value: float) -> void: _on_attr_changed(attr_key, value))
		row.add_child(name_label)
		row.add_child(spin)
		_attr_list.add_child(row)
		_attr_inputs[key] = spin


func _rebuild_passive_list(entry: Dictionary) -> void:
	_passive_list.clear()
	for aid_v in GmBattleAccess.passive_ids_for_entry(entry):
		var aid: String = str(aid_v).strip_edges()
		if aid == "":
			continue
		var row: Dictionary = AbilityService.by_id(aid)
		var label: String = str(row.get("name", aid)) if not row.is_empty() else aid
		var index: int = _passive_list.add_item("%s · %s" % [label, aid])
		_passive_list.set_item_metadata(index, aid)


func _rebuild_buff_list(entry: Dictionary) -> void:
	_buff_list.clear()
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		return
	var unit: ZhandouObj = unit_v as ZhandouObj
	for bid_v in unit.buffs.keys():
		var bid: String = str(bid_v)
		var inst_v: Variant = unit.buffs.get(bid)
		if not inst_v is Dictionary:
			continue
		var inst: Dictionary = inst_v as Dictionary
		var stacks: int = int(inst.get("stacks", 0))
		var duration_left: float = float(inst.get("duration_left", 0.0))
		var cm: Node = _config_manager()
		var def: Dictionary = {}
		if cm != null and cm.has_method("buff_by_id"):
			def = cm.call("buff_by_id", bid) as Dictionary
		var name_text: String = str(def.get("name", bid))
		var label: String = "%s · 层数 %d · 剩余 %.1fs" % [name_text, stacks, duration_left]
		var index: int = _buff_list.add_item(label)
		_buff_list.set_item_metadata(index, bid)


func _refresh_live_values() -> void:
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		return
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		return
	var unit: ZhandouObj = unit_v as ZhandouObj
	_suppress_attr_signal = true
	_hp_input.value = unit.hp
	_mp_input.value = unit.mp
	for key in _attr_inputs.keys():
		var spin_v: Variant = _attr_inputs.get(key)
		if spin_v is SpinBox:
			(spin_v as SpinBox).value = unit.get_attr(str(key), 0.0)
	_suppress_attr_signal = false
	_rebuild_buff_list(entry)


func _on_attr_changed(key: String, value: float) -> void:
	if _suppress_attr_signal:
		return
	var entry: Dictionary = _selected_entry()
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		return
	var unit: ZhandouObj = unit_v as ZhandouObj
	unit.set_attr(key, value)
	if key == EnumPlayerAttr.HP_MAX:
		unit.clamp_vitals()
		_hp_input.value = unit.hp
	elif key == EnumPlayerAttr.MP_MAX:
		unit.clamp_vitals()
		_mp_input.value = unit.mp
	GmBattleAccess.sync_hud()


func _apply_vitals() -> void:
	var entry: Dictionary = _selected_entry()
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		_flash("未选中单位")
		return
	var unit: ZhandouObj = unit_v as ZhandouObj
	unit.hp = float(_hp_input.value)
	unit.mp = float(_mp_input.value)
	unit.clamp_vitals()
	GmBattleAccess.sync_hud()
	_flash("已更新当前气血/法力")


func _add_selected_passive() -> void:
	if _passive_option.item_count <= 0:
		_flash("无可用被动配置")
		return
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		_flash("未选中单位")
		return
	var aid: String = str(_passive_option.get_item_metadata(_passive_option.selected))
	var ids: Array = GmBattleAccess.passive_ids_for_entry(entry)
	if ids.has(aid):
		_flash("已拥有该被动")
		return
	ids.append(aid)
	GmBattleAccess.set_passive_ids_for_entry(entry, ids)
	_rebuild_passive_list(entry)
	GmBattleAccess.sync_hud()
	_flash("已添加被动 %s" % aid)


func _remove_selected_passive() -> void:
	var selected: PackedInt32Array = _passive_list.get_selected_items()
	if selected.is_empty():
		_flash("请先选择要移除的被动")
		return
	var aid: String = str(_passive_list.get_item_metadata(int(selected[0])))
	var entry: Dictionary = _selected_entry()
	if entry.is_empty():
		return
	var ids: Array = GmBattleAccess.passive_ids_for_entry(entry)
	ids.erase(aid)
	GmBattleAccess.set_passive_ids_for_entry(entry, ids)
	_rebuild_passive_list(entry)
	GmBattleAccess.sync_hud()
	_flash("已移除被动 %s" % aid)


func _add_selected_buff() -> void:
	if _buff_option.item_count <= 0:
		_flash("无可用 Buff 配置")
		return
	var entry: Dictionary = _selected_entry()
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		_flash("未选中单位")
		return
	var unit: ZhandouObj = unit_v as ZhandouObj
	var bid: String = str(_buff_option.get_item_metadata(_buff_option.selected))
	var stacks: int = int(_buff_stacks_input.value)
	var duration: float = float(_buff_duration_input.value)
	var applied: int = unit.add_buff(bid, stacks, duration)
	if applied <= 0:
		_flash("添加 Buff 失败：%s" % bid)
		return
	GmBattleAccess.sync_hud()
	_rebuild_buff_list(entry)
	_flash("已添加 Buff %s" % bid)


func _remove_selected_buff() -> void:
	var selected: PackedInt32Array = _buff_list.get_selected_items()
	if selected.is_empty():
		_flash("请先选择要移除的 Buff")
		return
	var entry: Dictionary = _selected_entry()
	var unit_v: Variant = entry.get("unit")
	if not unit_v is ZhandouObj:
		return
	var unit: ZhandouObj = unit_v as ZhandouObj
	var bid: String = str(_buff_list.get_item_metadata(int(selected[0])))
	unit.remove_buff(bid, 9999)
	GmBattleAccess.sync_hud()
	_rebuild_buff_list(entry)
	_flash("已移除 Buff %s" % bid)


func _flash(message: String) -> void:
	_message_label.text = message


func _on_close_pressed() -> void:
	visible = false
	set_process(false)
	closed.emit()
	get_tree().call_group("gm_panel_host", "show_panel")


func _config_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
