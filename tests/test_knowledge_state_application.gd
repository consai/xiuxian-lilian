extends SceneTree

const KnowledgeStateScript := preload(
	"res://scripts/features/dao/domain/knowledge_state.gd"
)
const KnowledgeApplicationScript := preload(
	"res://scripts/features/dao/application/knowledge_application.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(KnowledgeStateScript.default_state() == {}, "default knowledge state is empty")
	var candidate := {
		"foundation.breathing": {
			"level": 2,
			"xp": 12.5,
			"marked": true,
			"growth_source": "self_study",
			"extension": {"tags": ["fixture"]},
		},
	}
	var before := candidate.duplicate(true)
	var prepared_result := KnowledgeStateScript.prepare(candidate)
	_check(bool(prepared_result.get("ok", false)), "valid state prepares successfully")
	var prepared := prepared_result.get("value", {}) as Dictionary
	_check(prepared == candidate, "valid state prepares without changing values")
	_check(candidate == before, "prepare leaves input unchanged")
	(prepared["foundation.breathing"] as Dictionary)["level"] = 4
	((prepared["foundation.breathing"] as Dictionary)["extension"] as Dictionary)["tags"] = []
	_check(candidate == before, "prepare returns a deep clone including unknown fields")
	var prepared_empty := KnowledgeStateScript.prepare({})
	_check(bool(prepared_empty.get("ok", false)), "empty state prepare is distinguishable from failure")
	_check(prepared_empty.get("value") == {}, "empty state prepare keeps the legal empty value")

	_check_error([], "invalid_root_type", "[knowledge_state:invalid_root_type] field=knowledge expected=Dictionary actual=Array")
	_check_error({1: {}}, "invalid_key", "[knowledge_state:invalid_key] field=knowledge.1 expected=non_empty_string actual=int")
	_check_error({"": {}}, "empty_key", "[knowledge_state:invalid_key] field=knowledge. expected=non_empty_string actual=String")
	_check_error({"a": []}, "invalid_entry", "[knowledge_state:invalid_entry_type] field=knowledge.a expected=Dictionary actual=Array")
	_check_error({"a": {"level": 1.0}}, "level_type", "[knowledge_state:invalid_field_type] field=knowledge.a.level expected=int actual=float")
	_check_error({"a": {"level": 6}}, "level_range", "[knowledge_state:out_of_range] field=knowledge.a.level range=0..5 actual=6")
	_check_error({"a": {"xp": "1"}}, "xp_type", "[knowledge_state:invalid_field_type] field=knowledge.a.xp expected=int_or_float actual=String")
	_check_error({"a": {"xp": -0.5}}, "xp_range", "[knowledge_state:out_of_range] field=knowledge.a.xp range=>=0 actual=-0.5")
	_check_error({"a": {"marked": 1}}, "marked_type", "[knowledge_state:invalid_field_type] field=knowledge.a.marked expected=bool actual=int")
	_check_error({"a": {"growth_source": 1}}, "source_type", "[knowledge_state:invalid_field_type] field=knowledge.a.growth_source expected=String actual=int")
	var ordered_errors := KnowledgeStateScript.collect_errors({
		"z": {"xp": -1},
		"a": {"level": 6},
	})
	_check(ordered_errors.size() == 2, "multiple invalid entries report every error")
	if ordered_errors.size() == 2:
		_check("knowledge.a.level" in ordered_errors[0], "errors are stable by knowledge id")
		_check("knowledge.z.xp" in ordered_errors[1], "stable ordering keeps later knowledge id second")

	var store := {}
	var initialized := KnowledgeApplicationScript.initialize_default(store)
	_check(bool(initialized.get("ok", false)), "initialize default succeeds")
	_check(store == {"knowledge": {}}, "initialize default writes the missing slice")
	var empty_snapshot := KnowledgeApplicationScript.snapshot(store)
	_check(bool(empty_snapshot.get("ok", false)), "empty snapshot is distinguishable from failure")
	_check(empty_snapshot.get("value") == {}, "empty snapshot returns the legal empty value")

	Engine.print_error_messages = false
	var missing_snapshot := KnowledgeApplicationScript.snapshot({})
	Engine.print_error_messages = true
	_check(not bool(missing_snapshot.get("ok", true)), "missing snapshot fails explicitly")
	_check(str(missing_snapshot.get("error", "")) == "[knowledge_application:missing_state_slice] field=knowledge", "missing snapshot returns a stable error")

	var committed_input := candidate.duplicate(true)
	var committed := KnowledgeApplicationScript.commit(store, committed_input)
	_check(bool(committed.get("ok", false)), "valid commit succeeds")
	(committed_input["foundation.breathing"] as Dictionary)["level"] = 5
	_check(int((store["knowledge"] as Dictionary)["foundation.breathing"]["level"]) == 2, "commit stores a deep clone")
	var returned := committed.get("value", {}) as Dictionary
	(returned["foundation.breathing"] as Dictionary)["level"] = 3
	_check(int((store["knowledge"] as Dictionary)["foundation.breathing"]["level"]) == 2, "commit result is a deep clone")

	var before_failed_commit := store.duplicate(true)
	Engine.print_error_messages = false
	var failed := KnowledgeApplicationScript.commit(store, {"bad": {"level": -1}})
	Engine.print_error_messages = true
	_check(not bool(failed.get("ok", true)), "invalid commit fails")
	_check(store == before_failed_commit, "invalid commit leaves savedata unchanged")
	var existing := KnowledgeApplicationScript.initialize_default(store)
	_check(bool(existing.get("ok", false)), "initialize validates an existing slice")
	_check(store == before_failed_commit, "initialize does not overwrite an existing slice")
	var invalid_existing := {"knowledge": {"bad": {"marked": 1}}}
	var invalid_existing_before := invalid_existing.duplicate(true)
	Engine.print_error_messages = false
	var invalid_initialize := KnowledgeApplicationScript.initialize_default(invalid_existing)
	Engine.print_error_messages = true
	_check(not bool(invalid_initialize.get("ok", true)), "initialize rejects an invalid existing slice")
	_check(invalid_existing == invalid_existing_before, "failed initialize does not overwrite an existing slice")

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: knowledge state and application ownership")
	quit(0)


func _check_error(candidate: Variant, label: String, expected: String) -> void:
	var errors := KnowledgeStateScript.collect_errors(candidate)
	_check(errors.size() == 1, "%s returns one error" % label)
	if errors.size() == 1:
		_check(errors[0] == expected, "%s returns stable error text" % label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
