extends SceneTree

const BattleStartApplicationScript := preload(
	"res://scripts/features/battle/application/battle_start_application.gd"
)
const BattlePendingSessionScript := preload(
	"res://scripts/features/battle/contracts/battle_pending_session.gd"
)
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")


class FakeSceneManager:
	extends Node

	var open_calls := 0
	var last_prefer_overlay := false
	var last_payload: Dictionary = {}
	var navigation_result := {"ok": true}

	func open_zhandou(prefer_overlay: bool, payload: Dictionary) -> Dictionary:
		open_calls += 1
		last_prefer_overlay = prefer_overlay
		last_payload = payload.duplicate(true)
		return navigation_result.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := FakeSceneManager.new()
	var invalid := BattleStartApplicationScript.start_battle({}, "test", manager, false)
	assert(not bool(invalid.get("ok", false)))
	assert(manager.open_calls == 0)
	assert(manager.last_payload.is_empty())

	var valid := ZhandouInitDataScript.sample_for_editor()
	manager.navigation_result = {"ok": false, "error": "navigation_failed"}
	var failed := BattleStartApplicationScript.start_battle(valid, "lilian", manager, true)
	assert(not bool(failed.get("ok", false)))
	assert(manager.open_calls == 1)
	assert(manager.last_prefer_overlay)
	var failed_envelope := manager.last_payload.duplicate(true)
	assert(BattlePendingSessionScript.collect_errors(failed_envelope).is_empty())
	assert(str(failed_envelope.get("source", "")) == "lilian")
	assert(int(failed_envelope.get("schema", 0)) == 2)
	assert(int(failed_envelope.get("created_unix", 0)) > 0)
	assert(not str(failed_envelope.get("battle_session_id", "")).is_empty())

	manager.navigation_result = {"ok": true}
	var opened := BattleStartApplicationScript.start_battle(valid, "gm_panel", manager, false)
	assert(bool(opened.get("ok", false)))
	assert(manager.open_calls == 2)
	assert(not manager.last_prefer_overlay)
	assert(str(manager.last_payload.get("source", "")) == "gm_panel")
	var payload_before_source_mutation := manager.last_payload.duplicate(true)
	(valid["player"] as Dictionary)["name"] = "mutated after start"
	assert(manager.last_payload == payload_before_source_mutation)
	assert(
		str((manager.last_payload["payload"] as Dictionary).get("battle_session_id", ""))
		== str(manager.last_payload.get("battle_session_id", ""))
	)
	assert(
		str(failed_envelope.get("battle_session_id", ""))
		!= str(manager.last_payload.get("battle_session_id", ""))
	)

	manager.free()
	print("PASS: battle start application validation and navigation envelope")
	quit(0)
