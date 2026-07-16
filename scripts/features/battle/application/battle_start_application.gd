class_name BattleStartApplication
extends RefCounted

const BattlePendingSessionScript := preload(
	"res://scripts/features/battle/contracts/battle_pending_session.gd"
)
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")


static func start_battle(
		data: Dictionary,
		source: String,
		scene_manager: Node,
		prefer_overlay: bool
) -> Dictionary:
	var merged := ZhandouInitDataScript.merge_skill_cfg_from_tables(data)
	var errors := ZhandouInitDataScript.collect_errors(merged)
	if not errors.is_empty():
		return {"ok": false, "error": errors[0]}
	var session_id := _new_battle_session_id()
	var created_unix := int(Time.get_unix_time_from_system())
	merged["battle_session_id"] = session_id
	var pending: Dictionary = BattlePendingSessionScript.create(
		session_id,
		source,
		created_unix,
		merged
	)
	if pending.is_empty():
		var envelope := {
			"schema": BattlePendingSessionScript.SCHEMA,
			"battle_session_id": session_id,
			"source": source,
			"created_unix": created_unix,
			"payload": merged,
		}
		var contract_errors := BattlePendingSessionScript.collect_errors(envelope)
		return {
			"ok": false,
			"error": contract_errors[0] if not contract_errors.is_empty() else "invalid_battle_pending_envelope",
		}
	return scene_manager.open_zhandou(
		prefer_overlay,
		BattlePendingSessionScript.to_dict(pending)
	)


static func _new_battle_session_id() -> String:
	return "battle_%d_%d" % [Time.get_ticks_usec(), randi()]
