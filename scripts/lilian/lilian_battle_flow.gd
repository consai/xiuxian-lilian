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
	var grant_first_battle_reward := TutorialService.is_waiting_for_any([
		"tutorial.first_battle_won",
	])
	var settled: Dictionary = LilianState.settle_pending_battle(grant_first_battle_reward)
	if bool(settled.get("ok", false)) and bool(settled.get("won", false)):
		TutorialService.game_event("tutorial.first_battle_won")
	if LilianState.should_go_to_result():
		var reason := LilianState.pending_exit_reason
		if reason == "":
			reason = "defeated"
		LilianFlowService.open_settlement(reason, LilianState, GameState, SceneManager)
	elif SceneManager.is_lilian_zhandou_overlay_active():
		SceneManager.dismiss_zhandou_overlay()
	else:
		LilianFlowService.open_active_lilian(LilianState, SceneManager)
