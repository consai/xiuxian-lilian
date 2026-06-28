class_name LilianBattleFlow
extends RefCounted

## 探险战斗出口：由进战 source 驱动，战斗场景不直接判断 LilianState.phase。


static func is_lilian_source(source: String) -> bool:
	var trimmed := source.strip_edges()
	return trimmed == "lilian" or trimmed.begins_with("lilian_")


static func handle_battle_finished(summary: Dictionary) -> void:
	if LilianState != null:
		LilianState.receive_battle_summary(summary)


static func handle_result_close() -> void:
	if LilianState == null:
		return
	LilianState.settle_pending_battle()
	if LilianState.should_go_to_result():
		var reason := LilianState.pending_exit_reason
		if reason == "":
			reason = "defeated"
		SceneManager.end_lilian_zhandou_and_go_jiesuan(reason)
	else:
		SceneManager.resume_lilian_after_zhandou()
