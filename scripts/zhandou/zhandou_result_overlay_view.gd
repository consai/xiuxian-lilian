class_name ZhandouResultOverlayView
extends Control

signal close_requested

const ZhandouRecordTypesScript := preload("res://scripts/zhandou/zhandou_record_types.gd")
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")
const ItemIconResolverScript := preload(
	"res://scripts/features/inventory/presentation/item_icon_resolver.gd"
)
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)

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
var _log_popup_auto_follow := true


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
	if _log_popup_scroll != null and _log_popup_scroll.has_signal("user_scrolled"):
		var handler := Callable(self, "_on_log_popup_user_scrolled")
		if not _log_popup_scroll.is_connected("user_scrolled", handler):
			_log_popup_scroll.connect("user_scrolled", handler)


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
	_log_popup_auto_follow = true
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
	if _log_popup_scroll == null or not _log_popup_auto_follow:
		return
	await get_tree().process_frame
	if _log_popup_scroll.has_method("scroll_vertical_quiet"):
		_log_popup_scroll.scroll_vertical_quiet(int(_log_popup_scroll.get_v_scroll_bar().max_value))
	else:
		_log_popup_scroll.scroll_vertical = int(_log_popup_scroll.get_v_scroll_bar().max_value)


func _on_log_popup_user_scrolled() -> void:
	_log_popup_auto_follow = false


func _sync_outcome_visual(outcome: String) -> void:
	var o := outcome.strip_edges()
	var is_win := o == ZhandouRecordTypesScript.OUTCOME_WIN
	var is_loss := o == ZhandouRecordTypesScript.OUTCOME_LOSS
	var is_draw := o == ZhandouRecordTypesScript.OUTCOME_DRAW
	var is_escaped := o == ZhandouRecordTypesScript.OUTCOME_ESCAPED
	if _img_suc != null:
		_img_suc.visible = is_win or is_draw or is_escaped
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
	var tier := maxi(1, int(row.get("tier", 1)))
	var icon: Texture2D = null
	var icon_v: Variant = row.get("icon")
	if icon_v is Texture2D:
		icon = icon_v
	elif kind == "equip":
		var equip_cfg := ConfigManager.equip_by_id(int(row.get("id", -1)))
		if item_name == "":
			item_name = str(equip_cfg.get("name", "法宝"))
		icon = ZhandouInitDataScript._resolve_icon_texture(equip_cfg)
		if quality == "":
			quality = EnumQuality.display_label(int(equip_cfg.get("quality", 1)))
		tier = maxi(1, int(equip_cfg.get("tier", tier)))
	elif kind == "item":
		var item_id := str(row.get("id", ""))
		if item_name == "":
			item_name = InventoryQueryApplicationScript.display_name(item_id)
		var def := InventoryQueryApplicationScript.definition_by_id(item_id)
		if def != null:
			icon = ItemIconResolverScript.resolve(def.icon_path, null)
			if quality == "":
				quality = EnumQuality.display_label(def.quality)
			tier = def.tier
	else:
		if item_name == "":
			item_name = str(row.get("id", "奖励"))
		var path := str(row.get("icon_path", row.get("icon", ""))).strip_edges()
		if path != "":
			icon = ItemIconResolverScript.resolve(path, null)
	view.apply_display(icon, item_name, count, Color.WHITE, quality, false, tier)
	view.show_name_label = true
	view.set_info_entry(ItemView.entry_from_reward_row(row))
