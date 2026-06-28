extends Control

const LilianFlowService := preload("res://scripts/lilian/lilian_flow_service.gd")
const RewardServiceScript := preload("res://scripts/sim/reward_service.gd")

var _result: Dictionary = {}

@onready var _loot_items: GridContainer = %LootItems
@onready var _loot_item_template: ItemView = (
	_loot_items.get_child(0) as ItemView if _loot_items != null and _loot_items.get_child_count() > 0 else null
)
@onready var _loot_lost_items: GridContainer = %LootLostItems
@onready var _loot_lost_item_template: ItemView = (
	_loot_lost_items.get_child(0) as ItemView
	if _loot_lost_items != null and _loot_lost_items.get_child_count() > 0
	else null
)


func _ready() -> void:
	var payload: Dictionary = SceneManager.peek_payload(SceneManager.LILIAN_JIESUAN)
	var reason: String = str(payload.get("reason", "manual"))
	if LilianState.active:
		_result = LilianFlowService.settle_active_lilian(reason)
	elif not GameState.last_lilian_summary.is_empty():
		_result = GameState.last_lilian_summary.duplicate(true)
	else:
		SceneManager.go_hub()
		return
	(%ReturnButton as Button).pressed.connect(_on_return_pressed)
	(%LogButton as Button).pressed.connect(_on_log_pressed)
	_prepare_loot_template(_loot_item_template)
	_prepare_loot_template(_loot_lost_item_template)
	_render()


func _prepare_loot_template(template: ItemView) -> void:
	if template == null:
		return
	template.visible = false
	template.set_click_enabled(false)
	template.show_info_on_click = false


func _render() -> void:
	var title := %Title as Label
	var body := %Body as RichTextLabel
	var log_button := %LogButton as Button
	var reason := str(_result.get("exit_reason", "manual"))
	var reason_text := "主动返程"
	if reason == "defeated":
		reason_text = "战败撤退"
	elif reason == "fled":
		reason_text = "战中遁走"
	title.text = "历练结算 · %s" % reason_text
	var stats := _result.get("stats", {}) as Dictionary
	var lines: PackedStringArray = [
		"最高难度 %d，事件 %d 个，耗时 %s" % [
			maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0))),
			int(stats.get("steps", 0)),
			str(_result.get("duration_label", GameState.time_duration_label(int(_result.get("elapsed_days", 1))))),
		],
		"战斗 %d 场，胜 %d，负 %d" % [
			int(stats.get("battles", 0)),
			int(stats.get("wins", 0)),
			int(stats.get("losses", 0)),
		],
		"最终气血 %.0f，法力 %.0f" % [float(_result.get("hp", 0.0)), float(_result.get("mp", 0.0))],
		"突破准备：历练战斗可压实灵力虚浮，带回药材可炼聚气丹补修为项。",
	]
	body.text = "\n".join(lines)
	var log_entries := _event_log_entries()
	log_button.disabled = log_entries.is_empty()
	_render_loot_items()
	_render_lost_loot_items()
	_render_outcome_summary(reason)
	_render_rule_hint(reason)


func _kept_loot_rows() -> Array:
	return (_result.get("loot", []) as Array).duplicate(true)


func _loot_lost_rows() -> Array:
	var out: Array = []
	for row_v in _result.get("loot_lost", []) as Array:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if int(row.get("count", 0)) <= 0:
			continue
		out.append(row.duplicate(true))
	return RewardServiceScript.merge_rewards(out)


func _render_loot_items() -> void:
	var rewards := _kept_loot_rows()
	_render_reward_grid(
		_loot_items,
		_loot_item_template,
		rewards,
		%LootHeading as Label,
		%LootEmpty as Label,
		Color.WHITE,
	)


func _render_lost_loot_items() -> void:
	var rewards := _loot_lost_rows()
	_render_reward_grid(
		_loot_lost_items,
		_loot_lost_item_template,
		rewards,
		%LootLostHeading as Label,
		null,
		Color(0.82, 0.62, 0.62, 1.0),
	)


func _render_reward_grid(
	container: GridContainer,
	template: ItemView,
	rewards: Array,
	heading: Label,
	empty_label: Label,
	tint: Color,
) -> void:
	if container == null:
		return
	_clear_generated_loot_items(container, template)
	if rewards.is_empty():
		container.visible = false
		if heading != null:
			heading.visible = false
		if empty_label != null:
			empty_label.visible = true
		return
	var shown := 0
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var view := _make_loot_item(container, template)
		if view == null:
			continue
		ItemView.apply_reward_row(view, reward_v as Dictionary)
		view.modulate = tint
		shown += 1
	container.visible = shown > 0
	if heading != null:
		heading.visible = shown > 0
	if empty_label != null:
		empty_label.visible = shown <= 0


func _clear_generated_loot_items(container: GridContainer, template: ItemView) -> void:
	if container == null:
		return
	var keep: Array[Node] = []
	if template != null and template.get_parent() == container:
		keep.append(template)
	for child in container.get_children():
		if keep.has(child):
			child.visible = false
			continue
		child.queue_free()


func _make_loot_item(container: GridContainer, template: ItemView) -> ItemView:
	if container == null or template == null:
		return null
	var copy_v := template.duplicate()
	if not copy_v is ItemView:
		return null
	var copy := copy_v as ItemView
	copy.visible = true
	container.add_child(copy)
	return copy


func _render_outcome_summary(reason: String) -> void:
	var message := %ResultMessage as Label
	var lines: PackedStringArray = []
	if reason == "defeated":
		var lost := _loot_lost_rows()
		if not lost.is_empty():
			lines.append("战败途中遗失部分战利品，其余收获已保留。")
		else:
			lines.append("本次无额外战利品遗失。")
		lines.append("伤势加重：回观中「休息」可减轻伤势（每次约减 2 日）。")
		lines.append("先休息，再去「研读」典籍或配置「技能」；缺丹药去「炼丹」。")
	elif reason == "fled":
		lines.append("战中遁走，略感气息紊乱；回观中「休息」可快速调息。")
	elif reason == "manual":
		lines.append("平安返程，所得已清点入库。")
	if int(_result.get("instability_reduced", 0)) > 0:
		lines.append("战斗压实境界：虚浮 -%d，当前 %d。" % [
			int(_result.get("instability_reduced", 0)),
			int(_result.get("cultivation_instability", 0)),
		])
	if lines.is_empty():
		message.text = "此行山高路远，所得皆已带回观中。"
	else:
		message.text = "\n".join(lines)


## PM-401：按返程原因展示下一步恢复指引（战败 / 遁走 / 主动返程文案不同）。
func _render_rule_hint(reason: String) -> void:
	var rule := %RuleLabel as Label
	if rule == null:
		return
	match reason:
		"defeated":
			rule.text = (
				"战败只遗失本次部分战利品；回观中点「休息」恢复气血法力并减轻伤势。"
				+ "缺丹药去「炼丹」，典籍在底部「研读」，战术调整点「技能」。"
			)
		"fled":
			rule.text = "战中遁走代价较轻；回观中「休息」调息后再出发，必要时「炼丹」补给。"
		_:
			rule.text = "平安返程：所得已入库。可在洞府「炼丹」「研读」或配置「技能」后再出门。"


func _event_log_entries() -> Array:
	var entries := _result.get("event_log", []) as Array
	if not entries.is_empty():
		return entries
	return []


func _on_log_pressed() -> void:
	var panel := %LilianRizhiMianban as LilianRizhiMianbanView
	panel.show_log(_event_log_entries())


func _on_return_pressed() -> void:
	TutorialService.game_event("tutorial.result_closed")
	SceneManager.take_payload(SceneManager.LILIAN_JIESUAN)
	SceneManager.go_hub()
