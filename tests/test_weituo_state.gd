extends SceneTree

const WeituoStateScript := preload(
	"res://scripts/features/commission/domain/weituo_state.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var expected := {
		"active": {},
		"completed_once": [],
		"completed_count": {},
		"board": {"refresh_day": 1, "offer_ids": []},
	}
	var first := WeituoStateScript.default_state()
	var second := WeituoStateScript.default_state()
	assert(first == expected)
	(first["board"]["offer_ids"] as Array).append("mutated")
	assert(second == expected)

	var valid := expected.duplicate(true)
	valid["active"] = {
		"instance_1": {
			"weituo_id": "commission.a",
			"accepted_day": 3,
			"progress": {
				"lilian_steps": 8,
				"not_defeated": true,
				"settlement_ids": ["settlement.1"],
				"future_progress": {"kept": true},
			},
			"future_record": "kept",
		},
	}
	valid["completed_once"] = ["commission.a"]
	valid["completed_count"] = {"commission.a": 1}
	valid["board"] = {"refresh_day": 3, "offer_ids": ["commission.b"]}
	valid["future_state"] = ["kept"]
	var before := valid.duplicate(true)
	var prepared := WeituoStateScript.prepare(valid)
	assert(prepared == valid)
	(prepared["active"]["instance_1"]["progress"]["settlement_ids"] as Array).append("copy")
	assert(valid == before)

	Engine.print_error_messages = false
	assert(not WeituoStateScript.validate([]))
	var missing := expected.duplicate(true)
	missing.erase("board")
	assert(not WeituoStateScript.validate(missing))
	var wrong_type := expected.duplicate(true)
	wrong_type["completed_count"] = []
	assert(not WeituoStateScript.validate(wrong_type))
	var invalid_record := valid.duplicate(true)
	invalid_record["active"]["instance_1"]["accepted_day"] = 0
	assert(not WeituoStateScript.validate(invalid_record))
	var invalid_progress := valid.duplicate(true)
	invalid_progress["active"]["instance_1"]["progress"]["not_defeated"] = 1
	assert(not WeituoStateScript.validate(invalid_progress))
	var duplicate_settlement := valid.duplicate(true)
	duplicate_settlement["active"]["instance_1"]["progress"]["settlement_ids"] = ["a", "a"]
	assert(not WeituoStateScript.validate(duplicate_settlement))
	var duplicate_offer := expected.duplicate(true)
	duplicate_offer["board"]["offer_ids"] = ["commission.a", "commission.a"]
	assert(not WeituoStateScript.validate(duplicate_offer))
	var old_root := expected.duplicate(true)
	old_root.erase("active")
	old_root["commissions"] = {}
	assert(not WeituoStateScript.validate(old_root))
	var old_record := valid.duplicate(true)
	old_record["active"]["instance_1"].erase("weituo_id")
	old_record["active"]["instance_1"]["commission_id"] = "commission.a"
	assert(not WeituoStateScript.validate(old_record))
	Engine.print_error_messages = true

	print("PASS: weituo current-schema state contract")
	quit(0)
