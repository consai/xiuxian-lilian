class_name XiulianJieguoTanchuang
extends Control

signal confirmed

@onready var _status_label: Label = %StatusLabel
@onready var _flavor_label: Label = %FlavorLabel
@onready var _result_label: Label = %ResultLabel
@onready var _knowledge_scroll: LongPressScrollContainer = %KnowledgeScroll
@onready var _knowledge_rows: VBoxContainer = %KnowledgeRows
@onready var _completed_days_label: Label = %CompletedDaysLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _plan_title: Label = %PlanTitle


func _ready() -> void:
	visible = false
	_plan_title.text = "闭关计划"
	_confirm_button.pressed.connect(_on_confirm_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()


func show_result(result: Dictionary) -> void:
	var days := int(result.get("days", 1))
	_completed_days_label.text = "闭关 %s" % str(result.get("duration_label", GameState.time_duration_label(days)))
	_status_label.text = "周天运转完毕"
	_flavor_label.text = _result_flavor(str(result.get("mode_id", "cycle")))
	_result_label.text = _format_summary(result)
	_clear_knowledge_rows()
	visible = true


func hide_popup() -> void:
	visible = false
	_completed_days_label.text = "闭关 1 日"
	_clear_knowledge_rows()


func _clear_knowledge_rows() -> void:
	for child in _knowledge_rows.get_children():
		child.queue_free()



static func _format_summary(result: Dictionary) -> String:
	var lines: PackedStringArray = [
		"修为 +%d    当前 %d / %d" % [
			int(result.get("cultivation_gained", 0)),
			int(result.get("cultivation", 0)),
			int(result.get("breakthrough_at", 0)),
		],
		"%s熟练度 +%d%%" % [
			str(result.get("method_name", "功法")),
			int(round(float(result.get("mastery_gained", 0.0)) * 100.0)),
		],
	]
	if int(result.get("layer_advances", 0)) > 0:
		lines.append("境界提升：%s → %s" % [
			str(result.get("realm_before", "")),
			str(result.get("realm_name", "")),
		])
	if int(result.get("instability_gained", 0)) > 0:
		lines.append("灵力驳杂 +%d    当前 %d（历练战斗可压实）" % [
			int(result.get("instability_gained", 0)),
			int(result.get("cultivation_instability", 0)),
		])
	lines.append(_breakthrough_feedback(result))
	return "\n".join(lines)


static func _breakthrough_feedback(result: Dictionary) -> String:
	var cultivation := int(result.get("cultivation", 0))
	var breakthrough_at := int(result.get("breakthrough_at", 0))
	if breakthrough_at <= 0:
		return "突破准备：修为项会随闭关进度提升。"
	var missing := maxi(0, breakthrough_at - cultivation)
	if missing == 0:
		return "突破准备：修为已满，去突破面板查看丹药、心境和根骨缺口。"
	return "突破准备：修为项还差 %d 修为到门槛。" % missing


static func _result_flavor(mode_id: String) -> String:
	match mode_id:
		"insight":
			return "心神沉入功法脉络，往日晦涩之处逐渐明朗。"
		"breathing":
			return "观中清气汇入丹田，气海比此前更加充盈。"
		"pill":
			return "药力如潮涌入经脉，修为骤增，气息却也多了几分虚浮。"
		_:
			return "灵气沿经脉运转周天，气息变得凝实平稳。"


func _on_confirm_pressed() -> void:
	hide_popup()
	confirmed.emit()
