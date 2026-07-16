extends SceneTree

const BattlePendingSessionScript := preload(
	"res://scripts/features/battle/contracts/battle_pending_session.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_payload := {
		"battle_session_id": "battle_contract_1",
		"nested": {"rows": [{"value": 1}]},
	}
	var pending: Dictionary = BattlePendingSessionScript.create(
		"battle_contract_1", "test", 123, source_payload
	)
	assert(not pending.is_empty())
	(source_payload["nested"]["rows"] as Array)[0]["value"] = 9
	assert((BattlePendingSessionScript.payload_snapshot(pending)["nested"]["rows"] as Array)[0]["value"] == 1)
	var encoded: Dictionary = BattlePendingSessionScript.to_dict(pending)
	assert(encoded["schema"] == 2)
	(encoded["payload"]["nested"]["rows"] as Array)[0]["value"] = 7
	assert((BattlePendingSessionScript.payload_snapshot(pending)["nested"]["rows"] as Array)[0]["value"] == 1)
	var decoded: Dictionary = BattlePendingSessionScript.from_dict(
		BattlePendingSessionScript.to_dict(pending)
	)
	assert(not decoded.is_empty())
	assert(decoded == BattlePendingSessionScript.to_dict(pending))

	assert(not BattlePendingSessionScript.collect_errors([]).is_empty())
	var missing: Dictionary = BattlePendingSessionScript.to_dict(pending)
	missing.erase("source")
	assert(BattlePendingSessionScript.collect_errors(missing).has(
		"battle pending envelope 缺少字段 'source'"
	))
	var unknown: Dictionary = BattlePendingSessionScript.to_dict(pending)
	unknown["extra"] = true
	assert(BattlePendingSessionScript.collect_errors(unknown).has(
		"battle pending envelope 含未知字段 'extra'"
	))
	var bad_schema: Dictionary = BattlePendingSessionScript.to_dict(pending)
	bad_schema["schema"] = 1
	assert(BattlePendingSessionScript.collect_errors(bad_schema).has(
		"battle pending envelope.schema 必须为 2"
	))
	var mismatch: Dictionary = BattlePendingSessionScript.to_dict(pending)
	mismatch["payload"]["battle_session_id"] = "other"
	assert(BattlePendingSessionScript.collect_errors(mismatch).has(
		"battle pending envelope.payload.battle_session_id 与 envelope 不一致"
	))
	var object_payload: Dictionary = BattlePendingSessionScript.to_dict(pending)
	var illegal_node := Node.new()
	object_payload["payload"]["nested_object"] = illegal_node
	assert(BattlePendingSessionScript.collect_errors(object_payload).has(
		"payload.nested_object 含不允许的 Object"
	))
	illegal_node.free()
	var callable_payload: Dictionary = BattlePendingSessionScript.to_dict(pending)
	callable_payload["payload"]["nested_callable"] = Callable(self, "_run")
	assert(BattlePendingSessionScript.collect_errors(callable_payload).has(
		"payload.nested_callable 含不允许的 Callable"
	))
	var invalid := {
		"schema": 2,
		"battle_session_id": "",
		"source": "",
		"created_unix": 0,
		"payload": {},
	}
	var first_errors := BattlePendingSessionScript.collect_errors(invalid)
	assert(first_errors == BattlePendingSessionScript.collect_errors(invalid))
	assert(BattlePendingSessionScript.from_dict(invalid).is_empty())
	print("PASS: battle pending session contract")
	quit(0)
