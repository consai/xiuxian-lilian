extends Node

## 唯一静态配置入口：按需读取原样导出的 JSON，不持有业务状态。

const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")


func read_json(path: String) -> Dictionary:
	var normalized := path.strip_edges()
	if normalized == "":
		return {"ok": false, "value": null, "error": "配置路径不能为空"}
	var value: Variant = JsonReaderScript.read_variant(normalized)
	if value == null:
		return {"ok": false, "value": null, "error": "配置读取失败: %s" % normalized}
	return {"ok": true, "value": value, "error": ""}
