class_name SettingsApplication
extends RefCounted

const SettingsRepositoryScript := preload("res://scripts/core/settings_repository.gd")


static func load_settings() -> Dictionary:
	return SettingsRepositoryScript.load_settings()


static func save_settings(settings: Dictionary) -> Dictionary:
	return SettingsRepositoryScript.save_settings(settings)


static func apply(settings: Dictionary) -> Dictionary:
	var checked := SettingsRepositoryScript.validate(settings)
	if not bool(checked.get("ok", false)):
		return checked
	var value := checked["value"] as Dictionary
	var resolution := value["resolution"] as Dictionary
	DisplayServer.window_set_size(Vector2i(int(resolution["width"]), int(resolution["height"])))
	match str(value["display_mode"]):
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		"windowed":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	return {"ok": true, "settings": value.duplicate(true)}
