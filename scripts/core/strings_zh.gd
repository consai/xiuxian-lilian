class_name StringsZh
extends RefCounted

## 战斗中文文案：[code]res://data/exportjson/yunxing_params/ui_strings_zh.json[/code]。
## 配置为一级 dict，键为路径段用 `:` 拼接（如 `hover:skill:mp_cost`）。

const DATA_PATH := "res://data/exportjson/yunxing_params/ui_strings_zh.json"

static var _root: Dictionary = {}
static var _loaded: bool = false


## 加载扁平文案表；导出格式为 settings 行（key/value）。
static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		push_error("StringsZh: 缺少文件 %s" % DATA_PATH)
		return
	_root = JsonLoader._export_settings(DATA_PATH)


## 将调用方路径规范为配置键：`.` 与 `:` 均可，统一为 `:`。
static func _normalize_key(path: String) -> String:
	return path.strip_edges().replace(".", ":")


static func getp(path: String, default_if_missing: String = "") -> String:
	_ensure_loaded()
	var key: String = _normalize_key(path)
	if key == "" or not _root.has(key):
		return default_if_missing
	return str(_root[key])


static func format_template(template: String, vars: Dictionary) -> String:
	var out := template
	for k in vars.keys():
		out = out.replace("{" + str(k) + "}", str(vars[k]))
	return out
