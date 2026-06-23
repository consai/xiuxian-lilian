class_name ExpeditionBattleFlow
extends RefCounted

## 探险战斗出口：由进战 source 驱动，战斗场景不直接判断 ExpeditionState.phase。


static func is_expedition_source(source: String) -> bool:
	var trimmed := source.strip_edges()
	return trimmed == "expedition" or trimmed.begins_with("expedition_")


static func handle_battle_finished(summary: Dictionary) -> void:
	if ExpeditionState != null:
		ExpeditionState.receive_battle_summary(summary)


static func handle_result_close() -> void:
	if ExpeditionState == null:
		return
	ExpeditionState.settle_pending_battle()
	if ExpeditionState.should_go_to_result():
		var reason := ExpeditionState.pending_exit_reason
		if reason == "":
			reason = "defeated"
		SceneManager.end_expedition_fight_and_go_result(reason)
	else:
		SceneManager.resume_expedition_after_fight()
