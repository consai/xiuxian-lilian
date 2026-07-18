extends SceneTree

const StateScript := preload("res://scripts/features/ability/domain/ability_savedata_state.gd")
const ApplicationScript := preload(
	"res://scripts/features/ability/application/ability_savedata_application.gd"
)

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(StateScript.default_state() == {
		"unlocked_abilities": [], "equipped_abilities": ["", "", "", "", ""],
	}, "default state is explicit and legal")
	var store := {}
	var initialized := ApplicationScript.initialize_default(store)
	_check(bool(initialized.get("ok", false)), "default initialization succeeds")
	_check(store == StateScript.default_state(), "default initialization commits the owned fields")
	var snapshot := ApplicationScript.snapshot(store)
	_check(bool(snapshot.get("ok", false)), "legal empty unlocked state snapshots")
	var value := snapshot.get("value", {}) as Dictionary
	(value["equipped_abilities"] as Array)[0] = "changed"
	_check((store["equipped_abilities"] as Array)[0] == "", "snapshot is deeply cloned")
	var candidate := {
		"unlocked_abilities": ["skill.a", "skill.b"],
		"equipped_abilities": ["skill.a", "", "skill.b", "", ""],
	}
	var committed := ApplicationScript.commit(store, candidate)
	_check(bool(committed.get("ok", false)), "valid state commits")
	(candidate["unlocked_abilities"] as Array)[0] = "mutated"
	_check((store["unlocked_abilities"] as Array)[0] == "skill.a", "commit stores a deep clone")
	var before_invalid := store.duplicate(true)
	_check_invalid(store, {
		"unlocked_abilities": ["skill.a"], "equipped_abilities": ["skill.a"],
	}, "invalid slot count is rejected atomically")
	_check_invalid(store, {
		"unlocked_abilities": ["skill.a"], "equipped_abilities": ["skill.a", "skill.a", "", "", ""],
	}, "duplicate equipped id is rejected atomically")
	_check_invalid(store, {
		"unlocked_abilities": ["skill.a"], "equipped_abilities": ["skill.b", "", "", "", ""],
	}, "equipped locked id is rejected atomically")
	_check(store == before_invalid, "all invalid commits preserve savedata")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: ability savedata application ownership")
	quit(0)


func _check_invalid(store: Dictionary, candidate: Dictionary, message: String) -> void:
	Engine.print_error_messages = false
	var result := ApplicationScript.commit(store, candidate)
	Engine.print_error_messages = true
	_check(not bool(result.get("ok", true)), message)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
