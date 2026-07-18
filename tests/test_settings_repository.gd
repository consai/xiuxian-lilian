extends SceneTree

const SettingsRepositoryScript := preload("res://scripts/core/settings_repository.gd")
const SettingsApplicationScript := preload("res://scripts/core/settings_application.gd")
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var defaults := SettingsRepositoryScript.defaults()
	_check(str(defaults["display_mode"]) == "windowed", "defaults use windowed mode")
	for mode in SettingsRepositoryScript.DISPLAY_MODES:
		var candidate := defaults.duplicate(true)
		candidate["display_mode"] = mode
		_check(bool(SettingsRepositoryScript.validate(candidate).get("ok", false)), "display mode validates: " + mode)
	_check(not bool(SettingsRepositoryScript.validate({"display_mode": "invalid"}).get("ok", true)), "invalid mode rejected")
	var saved := SettingsApplicationScript.save_settings(defaults)
	_check(bool(saved.get("ok", false)), "settings save succeeds")
	var loaded := SettingsApplicationScript.load_settings()
	_check(bool(loaded.get("ok", false)), "settings load succeeds")
	_check(str((loaded.get("settings", {}) as Dictionary).get("display_mode", "")) == "windowed", "settings round trip")
	if not _failures.is_empty():
		for failure in _failures: push_error(failure)
		quit(1)
		return
	print("PASS: settings repository")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
