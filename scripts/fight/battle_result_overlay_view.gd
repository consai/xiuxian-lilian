class_name BattleResultOverlayView
extends Control

signal close_requested

const BattleRecordTypesScript := preload("res://scripts/fight/battle_record_types.gd")

@onready var _body: RichTextLabel = %BattleResultBody
@onready var _btn_close: Button = %BattleResultClose
@onready var _img_suc: TextureRect = %img_suc
@onready var _img_fail: TextureRect = %img_fail
@onready var _rewards: HBoxContainer = %rewards
@onready var _reward_template = _rewards.get_child(0) if _rewards != null and _rewards.get_child_count() > 0 else null


func _ready() -> void:
	_sync_outcome_visual("")
	_prepare_reward_template()
	if _btn_close != null:
		_btn_close.pressed.connect(func() -> void:
			close_requested.emit()
		)


func apply_summary(summary: Dictionary, formatter, entries_tail: Array = [], names: Dictionary = {}) -> void:
	_sync_outcome_visual(str(summary.get("outcome", "")).strip_edges())

	if _body == null:
		_sync_rewards(summary.get("rewards", []))
		return

	_body.bbcode_enabled = true
	var blocks: PackedStringArray = PackedStringArray()
	if formatter != null:
		blocks.append(str(formatter.format_summary(summary)))

	if not entries_tail.is_empty() and formatter != null:
		blocks.append("")
		blocks.append("[b]最近战报[/b]")
		for ev_v in entries_tail:
			if not ev_v is Dictionary:
				continue
			var line := str(formatter.format_entry(ev_v as Dictionary, names)).strip_edges()
			if line == "":
				continue
			blocks.append(line)

	_body.text = "\n".join(blocks).strip_edges()
	_sync_rewards(summary.get("rewards", []))


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
	if _reward_template.has_method("set_click_enabled"):
		_reward_template.call("set_click_enabled", false)


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
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.set_click_enabled(false)
	_rewards.add_child(copy)
	return copy


func _apply_reward_row(view: ItemView, row: Dictionary) -> void:
	if view == null:
		return
	var item_name := str(row.get("name", row.get("item_name", row.get("id", "奖励")))).strip_edges()
	var count := int(row.get("count", row.get("amount", 1)))
	var icon: Texture2D = null
	var icon_v: Variant = row.get("icon")
	if icon_v is Texture2D:
		icon = icon_v
	else:
		var path := str(row.get("icon_path", row.get("icon", ""))).strip_edges()
		if path != "":
			var loaded := load(path)
			if loaded is Texture2D:
				icon = loaded as Texture2D
	var quality := str(row.get("quality", row.get("pin_zhi", ""))).strip_edges()
	view.apply_display(icon, item_name, maxi(1, count), Color.WHITE, quality)
	view.show_name_label = true

