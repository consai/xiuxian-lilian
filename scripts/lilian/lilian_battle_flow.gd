class_name LilianBattleFlow
extends RefCounted

## 探险战斗出口：由进战 source 驱动，战斗场景不直接判断 LilianState.phase。


static func is_lilian_source(source: String) -> bool:
	var trimmed := source.strip_edges()
	return trimmed == "lilian" or trimmed.begins_with("lilian_")


static func handle_battle_finished(lilian_session: Node, summary: Dictionary) -> void:
	if lilian_session != null:
		lilian_session.receive_battle_summary(summary)


static func handle_result_close(lilian_session: Node, game_session: Node, tutorial_coordinator: Node) -> void:
	if lilian_session == null:
		return
	var tutorial_was_active := false
	var grant_first_battle_reward := false
	if tutorial_coordinator == null:
		push_error("LilianBattleFlow: TutorialCoordinator 未绑定 action=handle_result_close")
	else:
		tutorial_was_active = tutorial_coordinator.is_active()
		grant_first_battle_reward = tutorial_coordinator.is_waiting_for_any([
			"tutorial.first_battle_won",
		])
	var settled: Dictionary = lilian_session.settle_pending_battle(grant_first_battle_reward)
	if bool(settled.get("ok", false)) and bool(settled.get("won", false)):
		if tutorial_was_active:
			lilian_session.auto_advance = false
		if tutorial_coordinator != null:
			tutorial_coordinator.game_event("tutorial.first_battle_won")
	if lilian_session.should_go_to_result():
		var reason: String = str(lilian_session.pending_exit_reason)
		if reason == "":
			reason = "defeated"
		LilianFlowService.open_settlement(reason, lilian_session, game_session, SceneManager)
	elif SceneManager.is_lilian_zhandou_overlay_active():
		SceneManager.dismiss_zhandou_overlay()
	else:
		LilianFlowService.open_active_lilian(lilian_session, SceneManager)
