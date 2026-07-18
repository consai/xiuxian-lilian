extends SceneTree

const SaveRepositoryScript := preload("res://scripts/core/save_repository.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(SaveRepositoryScript.SLOT_COUNT == 3, "three save slots remain available")
	_check(SaveRepositoryScript.AUTO_SAVE_SLOT == 1, "automatic slot remains slot one")
	var game := {"day": 7, "realm_name": "炼气", "cultivation": 42, "nested": {"value": 1}}
	_check(bool(SaveRepositoryScript.save_slot(2, game).get("ok", false)), "slot two saves")
	game["nested"] = {"value": 2}
	var loaded := SaveRepositoryScript.load_slot(2)
	_check(bool(loaded.get("ok", false)), "slot two loads")
	_check(int(((loaded.get("game", {}) as Dictionary).get("nested", {}) as Dictionary).get("value", 0)) == 1, "save envelope deep clones")
	var info := SaveRepositoryScript.slot_info(2)
	_check(bool(info.get("ok", false)) and int(info.get("day", 0)) == 7, "slot info preserves existing fields")
	_check(not bool(SaveRepositoryScript.save_slot(4, {}).get("ok", true)), "invalid slot rejects")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: save repository slots")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
