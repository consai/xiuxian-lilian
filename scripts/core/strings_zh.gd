class_name StringsZh
extends RefCounted

## 战斗中文文案：[code]res://data/ui/strings_zh.json[/code]。

const DATA_PATH := "res://data/ui/strings_zh.json"

static var _root: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		push_error("StringsZh: 缺少文件 %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed == null:
		push_error("StringsZh: JSON 解析失败 %s" % DATA_PATH)
		return
	if not parsed is Dictionary:
		push_error("StringsZh: 根须为 JSON 对象 %s" % DATA_PATH)
		return
	_root = parsed as Dictionary


static func _traverse(path: String) -> Variant:
	_ensure_loaded()
	var cur: Variant = _root
	for seg in path.split("."):
		if seg == "":
			continue
		if not cur is Dictionary:
			return null
		var d := cur as Dictionary
		if not d.has(seg):
			return null
		cur = d[seg]
	return cur


static func getp(path: String, default_if_missing: String = "") -> String:
	var v: Variant = _traverse(path)
	if v == null:
		return default_if_missing
	return str(v)


static func format_template(template: String, vars: Dictionary) -> String:
	var out := template
	for k in vars.keys():
		out = out.replace("{" + str(k) + "}", str(vars[k]))
	return out
