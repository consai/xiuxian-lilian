class_name EnumAbilityTable
extends RefCounted

## 技能配置分表键，与 data/exportjson/*.json 一一对应。

enum Key {
	ZHANDOU_ACTIVE,
	ZHANDOU_PASSIVE,
	TONGYONG_PASSIVE,
}

const LABEL_ZHANDOU_ACTIVE := "zhandou_active"
const LABEL_ZHANDOU_PASSIVE := "zhandou_passive"
const LABEL_TONGYONG_PASSIVE := "tongyong_passive"

const LOAD_ORDER: Array[String] = [
	LABEL_ZHANDOU_ACTIVE,
	LABEL_ZHANDOU_PASSIVE,
	LABEL_TONGYONG_PASSIVE,
]

const DEFAULT_PATHS: Dictionary = {
	LABEL_ZHANDOU_ACTIVE: "exportjson/zhandou_active.json",
	LABEL_ZHANDOU_PASSIVE: "exportjson/zhandou_passive.json",
	LABEL_TONGYONG_PASSIVE: "exportjson/general_passive.json",
}


static func is_valid_label(text: String) -> bool:
	return text.strip_edges().to_lower() in LOAD_ORDER


static func default_path(table_key: String) -> String:
	var key := table_key.strip_edges().to_lower()
	return str(DEFAULT_PATHS.get(key, "exportjson/%s.json" % key))
