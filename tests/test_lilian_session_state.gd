extends SceneTree

const SessionState := preload(
	"res://scripts/features/lilian/domain/lilian_session_state.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults := SessionState.default_state()
	assert(SessionState.collect_errors(defaults).is_empty())
	assert(defaults.keys().size() == SessionState.REQUIRED_KEYS.size())

	var missing := defaults.duplicate(true)
	missing.erase("active")
	_expect_code(SessionState.collect_errors(missing), "missing_field", "active")
	var unknown := defaults.duplicate(true)
	unknown["unexpected"] = true
	_expect_code(SessionState.collect_errors(unknown), "unknown_field", "unexpected")
	var wrong_type := defaults.duplicate(true)
	wrong_type["active"] = 1
	_expect_code(SessionState.collect_errors(wrong_type), "bool_type", "active")
	wrong_type = defaults.duplicate(true)
	wrong_type["map_nodes"] = {}
	_expect_code(SessionState.collect_errors(wrong_type), "array_type", "map_nodes")
	wrong_type = defaults.duplicate(true)
	wrong_type["runtime"] = []
	_expect_code(SessionState.collect_errors(wrong_type), "dictionary_type", "runtime")
	var bad_phase := defaults.duplicate(true)
	bad_phase["phase"] = "paused"
	_expect_code(SessionState.collect_errors(bad_phase), "phase_invalid", "phase")
	for field in ["steps", "days", "days_without_event", "start_day"]:
		var negative := defaults.duplicate(true)
		negative[field] = -1
		_expect_code(SessionState.collect_errors(negative), "negative_value", field)

	var bad_generated := defaults.duplicate(true)
	bad_generated["generated_events"] = {"event.a": []}
	_expect_code(
		SessionState.collect_errors(bad_generated),
		"generated_row_type",
		"generated_events.event.a"
	)
	bad_generated = defaults.duplicate(true)
	bad_generated["generated_events"] = {"event.a": {"id": "event.b"}}
	_expect_code(
		SessionState.collect_errors(bad_generated),
		"generated_id_mismatch",
		"generated_events.event.a.id"
	)
	bad_generated = defaults.duplicate(true)
	bad_generated["generated_events"] = {1: {"id": "1"}}
	_expect_code(
		SessionState.collect_errors(bad_generated),
		"generated_key_invalid",
		"generated_events.1"
	)

	var stable_errors := SessionState.collect_errors(bad_generated)
	assert(stable_errors == SessionState.collect_errors(bad_generated))

	var state := SessionState.new()
	var candidate := defaults.duplicate(true)
	candidate["active"] = true
	candidate["generated_events"] = {
		"event.a": {"id": "event.a", "nested": {"value": 1}},
	}
	candidate["difficulty_override"] = {"min_difficulty": 2, "max_difficulty": 4}
	candidate["effective_location"] = {"id": "location.a", "nested": [1]}
	assert(state.replace_candidate(candidate).is_empty())
	(candidate["generated_events"]["event.a"] as Dictionary)["id"] = "mutated"
	(candidate["difficulty_override"] as Dictionary)["min_difficulty"] = 99
	assert(str((state.snapshot()["generated_events"]["event.a"] as Dictionary)["id"]) == "event.a")
	assert(int((state.snapshot()["difficulty_override"] as Dictionary)["min_difficulty"]) == 2)

	var snapshot := state.snapshot()
	(snapshot["generated_events"]["event.a"]["nested"] as Dictionary)["value"] = 99
	(snapshot["difficulty_override"] as Dictionary)["max_difficulty"] = 99
	(snapshot["effective_location"]["nested"] as Array).append(2)
	var untouched := state.snapshot()
	assert(int(untouched["generated_events"]["event.a"]["nested"]["value"]) == 1)
	assert(int(untouched["difficulty_override"]["max_difficulty"]) == 4)
	assert((untouched["effective_location"]["nested"] as Array) == [1])

	var owner_runtime := state.value_ref("runtime") as Dictionary
	owner_runtime["hp"] = 42.0
	assert(float((state.value_ref("runtime") as Dictionary)["hp"]) == 42.0)

	var before_bad := state.snapshot()
	var invalid_candidate := before_bad.duplicate(true)
	invalid_candidate["phase"] = "broken"
	assert(not state.replace_candidate(invalid_candidate).is_empty())
	assert(state.snapshot() == before_bad)

	state.reset()
	assert(state.snapshot() == SessionState.default_state())
	assert(SessionState.collect_errors(state.snapshot()).is_empty())
	assert((state.snapshot()["generated_events"] as Dictionary).is_empty())
	assert((state.snapshot()["effective_location"] as Dictionary).is_empty())
	assert((state.snapshot()["difficulty_override"] as Dictionary).is_empty())

	print("PASS: lilian session state")
	quit(0)


func _expect_code(errors: PackedStringArray, code: String, field: String) -> void:
	var expected := "[lilian_session_state:%s] field=%s" % [code, field]
	assert(expected in errors, "expected %s, got %s" % [expected, str(errors)])
