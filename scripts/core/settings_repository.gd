class_name SettingsRepository
extends RefCounted

const SCHEMA_VERSION := 1
const PATH := "user://settings.json"
const TEMP_PATH := "user://settings.json.tmp"
const DEFAULTS := {
	"master_volume": 1.0,
	"resolution": {"width": 1280, "height": 800},
	"display_mode": "windowed",
}
const DISPLAY_MODES := ["windowed", "borderless", "fullscreen"]


static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"ok": true, "settings": defaults()}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var checked := validate(parsed)
	if not bool(checked.get("ok", false)):
		return checked
	return {"ok": true, "settings": checked["value"]}


static func save_settings(settings: Dictionary) -> Dictionary:
	var checked := validate(settings)
	if not bool(checked.get("ok", false)):
		return checked
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入设置临时文件"}
	file.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "settings": checked["value"]}, "\t"))
	file.close()
	if DirAccess.rename_absolute(TEMP_PATH, PATH) != OK:
		DirAccess.remove_absolute(TEMP_PATH)
		return {"ok": false, "error": "无法替换设置文件"}
	return {"ok": true, "settings": (checked["value"] as Dictionary).duplicate(true)}


static func validate(candidate: Variant) -> Dictionary:
	var raw: Variant = candidate
	if candidate is Dictionary and (candidate as Dictionary).has("schema_version"):
		var envelope := candidate as Dictionary
		if int(envelope.get("schema_version", -1)) != SCHEMA_VERSION:
			return {"ok": false, "error": "设置版本不兼容"}
		raw = envelope.get("settings")
	if not raw is Dictionary:
		return {"ok": false, "error": "设置根节点无效"}
	var source := raw as Dictionary
	var volume := float(source.get("master_volume", -1.0))
	if volume < 0.0 or volume > 1.0:
		return {"ok": false, "error": "主音量必须在0到1之间"}
	var resolution: Variant = source.get("resolution")
	if not resolution is Dictionary:
		return {"ok": false, "error": "分辨率设置无效"}
	var width := int((resolution as Dictionary).get("width", 0))
	var height := int((resolution as Dictionary).get("height", 0))
	if width < 640 or height < 360:
		return {"ok": false, "error": "分辨率过小"}
	var mode := str(source.get("display_mode", ""))
	if not DISPLAY_MODES.has(mode):
		return {"ok": false, "error": "显示模式无效"}
	var normalized := source.duplicate(true)
	normalized["master_volume"] = volume
	normalized["resolution"] = {"width": width, "height": height}
	normalized["display_mode"] = mode
	return {"ok": true, "value": normalized}
