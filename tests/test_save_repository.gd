extends SceneTree

const SaveRepositoryScript := preload("res://scripts/core/save_repository.gd")
const SaveApplicationScript := preload("res://scripts/core/save_application.gd")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var auto_one := {"day": 11, "nested": {"value": 10}}
	_check(bool(SaveRepositoryScript.save_auto(auto_one).get("ok", false)), "automatic save writes atomically")
	var auto_loaded := SaveRepositoryScript.load_auto()
	_check(bool(auto_loaded.get("ok", false)), "automatic save reloads")
	_check(int(((auto_loaded.get("payload", {}) as Dictionary).get("nested", {}) as Dictionary).get("value", 0)) == 10, "automatic save preserves snapshot")
	var auto_two := {"day": 12, "nested": {"value": 20}}
	_check(bool(SaveRepositoryScript.save_auto(auto_two).get("ok", false)), "automatic save rotates backup")
	var restored := SaveRepositoryScript.restore_auto_backup()
	_check(bool(restored.get("ok", false)), "automatic save backup restores")
	_check(int(((restored.get("payload", {}) as Dictionary).get("nested", {}) as Dictionary).get("value", 0)) == 10, "backup restores previous snapshot")
	_check(bool(SaveApplicationScript.auto_save({"day": 13}).get("ok", false)), "save application submits automatic snapshot")
	var app_loaded := SaveApplicationScript.load_auto()
	_check(bool(app_loaded.get("ok", false)) and int((app_loaded.get("game", {}) as Dictionary).get("day", 0)) == 13, "save application loads automatic snapshot")
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: save repository autosave")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
