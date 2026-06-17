class_name KnowledgeProgressRow
extends HBoxContainer

const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")

@onready var _name_label: Label = %NameLabel
@onready var _gain_label: Label = %GainLabel
@onready var _progress: ProgressBar = %Progress
@onready var _before_progress: ProgressBar = %BeforeProgress


func apply_gain(row: Dictionary, animate: bool = true) -> void:
	var skill_id := str(row.get("skill_id", "")).strip_edges()
	var xp_gained := float(row.get("xp", 0.0))
	var levels_gained := int(row.get("levels_gained", 0))
	var skill := DaoTreeServiceScript.skill_by_id(skill_id)
	_name_label.text = str(skill.get("name", skill_id))
	var suffix := ""
	if levels_gained > 0:
		suffix = "  ↑%d级" % levels_gained
	_gain_label.text = "+%.1f 经验%s" % [xp_gained, suffix]
	var snapshot := KnowledgeServiceScript.gain_progress_snapshot(
		GameState.to_dict(),
		skill_id,
		xp_gained,
		levels_gained
	)
	var before_pct := float(snapshot.get("before", 0.0))
	var after_pct := float(snapshot.get("after", 0.0))
	var gain_pct := float(snapshot.get("gain", 0.0))
	if gain_pct > 0.0:
		_gain_label.text += "  (+%.0f%%)" % gain_pct
	_before_progress.max_value = 100.0
	_before_progress.value = before_pct
	_progress.max_value = 100.0
	_progress.value = after_pct if not animate else before_pct
	if not animate or is_equal_approx(before_pct, after_pct):
		return
	var tween := create_tween()
	tween.tween_property(_progress, "value", after_pct, 0.55)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
