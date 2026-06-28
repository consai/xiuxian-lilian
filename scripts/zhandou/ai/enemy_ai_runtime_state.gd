class_name EnemyAiRuntimeState
extends RefCounted
## 单场战斗敌方 AI 运行时状态（阶段进入记录等）。

var entered_phases: Dictionary = {}
var last_phase_id: String = ""


func reset() -> void:
	entered_phases.clear()
	last_phase_id = ""
