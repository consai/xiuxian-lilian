extends SceneTree

const BreakthroughServiceScript := preload("res://scripts/sim/breakthrough_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var blocked := _breakdown(870, 1200)
	_expect_contains(BreakthroughServiceScript.major_gap_hint(blocked), "还差 330", "reports missing total")
	_expect_contains(BreakthroughServiceScript.major_gap_hint(blocked), "优先补", "reports main gaps")
	var next_quality := _breakdown(1250, 1200)
	_expect_contains(BreakthroughServiceScript.major_gap_hint(next_quality), "中品筑基", "reports nearest next tier")
	_expect_contains(BreakthroughServiceScript.major_gap_hint(next_quality), "250", "reports nearest tier gap")
	var knowledge_blocked := _breakdown(1300, 1200)
	knowledge_blocked["knowledge_error"] = "知识点不足，需要 20 点（当前 10）"
	_expect_contains(BreakthroughServiceScript.major_gap_hint(knowledge_blocked), "知识点不足", "reports knowledge gate first")
	if _failures.is_empty():
		print("PASS: PM-205 breakthrough feedback")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _breakdown(total: int, min_total: int) -> Dictionary:
	return {
		"ok": true,
		"total": total,
		"min_total": min_total,
		"transition_id": "qi_to_foundation",
		"knowledge_error": "",
		"components": {
			"cultivation": 400,
			"pills": 0,
			"mind": 80,
			"aptitude": 20,
			"fortune": 40,
			"special_method": 0,
			"other": 0,
		},
	}


func _expect_contains(actual: String, expected: String, message: String) -> void:
	if not actual.contains(expected):
		_failures.append("%s: expected '%s' in '%s'" % [message, expected, actual])
