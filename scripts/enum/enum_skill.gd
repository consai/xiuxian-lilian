class_name EnumSkill
extends RefCounted

## 技能配置分表键，与 data/exportjson/*.json 一一对应。

enum Key {
	ZHANDOU_ACTIVE,
	PASSIVE,
}

const LABEL_ZHANDOU_ACTIVE := "zhandou_active"
const LABEL_PASSIVE := "passive"

const LOAD_ORDER: Array[String] = [
	LABEL_ZHANDOU_ACTIVE,
	LABEL_PASSIVE,
]

const DEFAULT_PATHS: Dictionary = {
	LABEL_ZHANDOU_ACTIVE: "exportjson/zhandou_active.json",
	LABEL_PASSIVE: "exportjson/passive.json",
}


static func is_valid_label(text: String) -> bool:
	return text.strip_edges().to_lower() in LOAD_ORDER


static func default_path(table_key: String) -> String:
	var key := table_key.strip_edges().to_lower()
	return str(DEFAULT_PATHS.get(key, "exportjson/%s.json" % key))
