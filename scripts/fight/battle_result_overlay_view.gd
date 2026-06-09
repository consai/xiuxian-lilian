class_name BattleResultOverlayView
extends Control

signal close_requested

const BattleRecordTypesScript := preload("res://scripts/fight/battle_record_types.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")
const ItemDefScript := preload("res://scripts/core/item_def.gd")

@onready var _body: RichTextLabel = %BattleResultBody
@onready var _btn_close: Button = %BattleResultClose
@onready var _btn_log: Button = %BattleResultLog
@onready var _log_popup: Control = %BattleLogPopup
@onready var _log_popup_scroll: ScrollContainer = %BattleLogPopupScroll
@onready var _log_popup_body: RichTextLabel = %BattleLogPopupBody
@onready var _btn_log_popup_close: Button = %BattleLogPopupClose
@onready var _img_suc: TextureRect = %img_suc
@onready var _img_fail: TextureRect = %img_fail
@onready var _rewards: HBoxContainer = %rewards
@onready var _reward_template = _rewards.get_child(0) if _rewards != null and _rewards.get_child_count() > 0 else null

var _log_formatter = null
var _log_entries: Array = []
var _log_names: Dictionary = {}


func _ready() -> void:
	_sync_outcome_visual("")
	_prepare_reward_template()
	_hide_log_popup()
	if _btn_close != null:
		_btn_close.pressed.connect(func() -> void:
			close_requested.emit()
		)
	if _btn_log != null:
		_btn_log.pressed.connect(_on_log_button_pressed)
	if _btn_log_popup_close != null:
		_btn_log_popup_close.pressed.connect(_hide_log_popup)


func apply_summary(summary: Dictionary, formatter, entries_tail: Array = [], names: Dictionary = {}) -> void:
	_sync_outcome_visual(str(summary.get("outcome", "")).strip_edges())

	if _body == null:
		_sync_rewards(_loot_rewards(summary.get("rewards", [])))
		return

	_log_formatter = formatter
	_log_entries = entries_tail.duplicate()
	_log_names = names.duplicate()
	_hide_log_popup()
	_sync_log_button()

	_body.bbcode_enabled = false
	_body.text = _format_gain_body(summary.get("rewards", []))
	_sync_rewards(_loot_rewards(summary.get("rewards", [])))


func _sync_log_button() -> void:
	if _btn_log == null:
		return
	_btn_log.visible = _log_formatter != null and not _log_entries.is_empty()


func _on_log_button_pressed() -> void:
	if _log_popup == null or _log_popup_body == null:
		return
	var text := _format_log_text()
	if text == "":
		return
	_log_popup_body.bbcode_enabled = true
	_log_popup_body.text = text
	_log_popup.visible = true
	_scroll_log_to_end()


func _format_log_text() -> String:
	if _log_formatter == null or _log_entries.is_empty():
		return ""
	var blocks: PackedStringArray = PackedStringArray()
	for ev_v in _log_entries:
		if not ev_v is Dictionary:
			continue
		var line := str(_log_formatter.format_entry(ev_v as Dictionary, _log_names)).strip_edges()
		if line == "":
			continue
		blocks.append(line)
	return "\n".join(blocks).strip_edges()


func _hide_log_popup() -> void:
	if _log_popup != null:
		_log_popup.visible = false


func _scroll_log_to_end() -> void:
	if _log_popup_scroll == null:
		return
	await get_tree().process_frame
	_log_popup_scroll.scroll_vertical = int(_log_popup_scroll.get_v_scroll_bar().max_value)


func _sync_outcome_visual(outcome: String) -> void:
	var o := outcome.strip_edges()
	var is_win := o == BattleRecordTypesScript.OUTCOME_WIN
	var is_loss := o == BattleRecordTypesScript.OUTCOME_LOSS
	var is_draw := o == BattleRecordTypesScript.OUTCOME_DRAW
	if _img_suc != null:
		_img_suc.visible = is_win or is_draw
	if _img_fail != null:
		_img_fail.visible = is_loss


func _prepare_reward_template() -> void:
	if _reward_template == null:
		return
	_reward_template.visible = false
	if _reward_template is ItemView:
		(_reward_template as ItemView).set_click_enabled(false)
		(_reward_template as ItemView).show_info_on_click = false


func _format_gain_body(rewards_v: Variant) -> String:
	var cultivation_gain := 0
	var ling_stones_gain := 0
	var rewards: Array = rewards_v as Array if rewards_v is Array else []
	for row_v in rewards:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var kind := str(row.get("kind", "item"))
		var count := maxi(0, int(row.get("count", 0)))
		if kind == "currency" and str(row.get("id", "")) == "ling_stones":
			ling_stones_gain += count
		elif kind == "cultivation":
			cultivation_gain += count
	return "修为 +%d\t\t灵石 +%d" % [cultivation_gain, ling_stones_gain]


func _loot_rewards(rewards_v: Variant) -> Array:
	var rewards: Array = rewards_v as Array if rewards_v is Array else []
	var out: Array = []
	for row_v in rewards:
		if not row_v is Dictionary:
			continue
		var kind := str((row_v as Dictionary).get("kind", "item"))
		if kind == "item" or kind == "equip":
			out.append(row_v)
	return out


func _sync_rewards(rewards_v: Variant) -> void:
	if _rewards == null:
		return
	_clear_generated_rewards()
	var rewards: Array = rewards_v as Array if rewards_v is Array else []
	if rewards.is_empty():
		_rewards.visible = false
		return
	var shown := 0
	for row_v in rewards:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var view := _make_reward_item()
		if view == null:
			continue
		_apply_reward_row(view, row)
		shown += 1
	_rewards.visible = shown > 0


func _clear_generated_rewards() -> void:
	if _rewards == null:
		return
	var keep: Array[Node] = []
	if _reward_template != null and _reward_template.get_parent() == _rewards:
		keep.append(_reward_template)
	for child in _rewards.get_children():
		if keep.has(child):
			child.visible = false
			continue
		child.queue_free()


func _make_reward_item() -> ItemView:
	if _rewards == null or _reward_template == null:
		return null
	var copy_v := _reward_template.duplicate()
	if not copy_v is ItemView:
		return null
	var copy := copy_v as ItemView
	copy.visible = true
	copy.set_click_enabled(true)
	copy.show_info_on_click = true
	_rewards.add_child(copy)
	return copy


func _apply_reward_row(view: ItemView, row: Dictionary) -> void:
	if view == null:
		return
	var kind := str(row.get("kind", "item"))
	var count := maxi(1, int(row.get("count", row.get("amount", 1))))
	var item_name := str(row.get("name", row.get("item_name", ""))).strip_edges()
	var quality := str(row.get("quality", row.get("pin_zhi", ""))).strip_edges()
	var icon: Texture2D = null
	var icon_v: Variant = row.get("icon")
	if icon_v is Texture2D:
		icon = icon_v
	elif kind == "equip":
		var equip_cfg := ConfigManager.equip_by_id(int(row.get("id", -1)))
		if item_name == "":
			item_name = str(equip_cfg.get("name", "法宝"))
		icon = BattleInitDataScript._resolve_icon_texture(equip_cfg)
		if quality == "":
			quality = _quality_label_from_int(int(equip_cfg.get("quality", 1)))
	elif kind == "item":
		var item_id := str(row.get("id", ""))
		if item_name == "" and ConfigManager != null:
			item_name = str(ConfigManager.get_item_display_name(item_id))
		if ConfigManager != null:
			var def := ConfigManager.item_def_by_id(item_id)
			if def != null:
				icon = ItemDefScript.resolve_icon_texture(def.icon_path, null)
				if quality == "":
					quality = def.rarity
	else:
		if item_name == "":
			item_name = str(row.get("id", "奖励"))
		var path := str(row.get("icon_path", row.get("icon", ""))).strip_edges()
		if path != "":
			icon = ItemDefScript.resolve_icon_texture(path, null)
	view.apply_display(icon, item_name, count, Color.WHITE, quality)
	view.show_name_label = true
	view.set_info_entry(ItemView.entry_from_reward_row(row))


func _quality_label_from_int(quality: int) -> String:
	if quality >= 5:
		return "传说"
	if quality >= 3:
		return "稀有"
	return ""
