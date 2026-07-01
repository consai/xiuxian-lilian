class_name EnumZhandouTargetArg
extends RefCounted

## 战斗目标选中参数，与 [EnumZhandouTarget] 的 side（self/enemy）组合使用。

enum Arg {
	DEFAULT,
	LOWEST_HP,
	ALL,
	MAX_HP,
	FASTEST,
	FRONT,
	PRIORITY,
	LINE,
	CONTROLLED_ENTITY,
}

const LABEL_LOWEST_HP := "lowest_hp"
const LABEL_ALL := "all"
const LABEL_MAX_HP := "max_hp"
const LABEL_FASTEST := "fastest"
const LABEL_FRONT := "front"
const LABEL_PRIORITY := "priority"
const LABEL_LINE := "line"
const LABEL_CONTROLLED_ENTITY := "controlled_entity"
const LABEL_ENEMY := "enemy"
const LABEL_SELF := "self"

const VALID_LABELS: Array[String] = [
	LABEL_LOWEST_HP,
	LABEL_ALL,
	LABEL_MAX_HP,
	LABEL_FASTEST,
	LABEL_FRONT,
	LABEL_PRIORITY,
	LABEL_LINE,
	LABEL_CONTROLLED_ENTITY,
]

## 旧版复合 target 字段 → {target, target_arg}
const LEGACY_TARGET_TO_PAIR: Dictionary = {
	"enemy_lowest_hp": {
		"target": "enemy",
		"target_arg": LABEL_LOWEST_HP,
	},
	"enemy_front": {
		"target": "enemy",
		"target_arg": LABEL_FRONT,
	},
	"enemies_all": {
		"target": "enemy",
		"target_arg": LABEL_ALL,
	},
	"enemy_priority": {
		"target": "enemy",
		"target_arg": LABEL_PRIORITY,
	},
	"area": {
		"target": "enemy",
		"target_arg": LABEL_ALL,
	},
	"line": {
		"target": "enemy",
		"target_arg": LABEL_LINE,
	},
	"position": {
		"target": "self",
		"target_arg": "",
	},
	"controlled_entity": {
		"target": "self",
		"target_arg": LABEL_CONTROLLED_ENTITY,
	},
}


static func label(arg: Arg) -> String:
	match arg:
		Arg.LOWEST_HP:
			return LABEL_LOWEST_HP
		Arg.ALL:
			return LABEL_ALL
		Arg.MAX_HP:
			return LABEL_MAX_HP
		Arg.FASTEST:
			return LABEL_FASTEST
		Arg.FRONT:
			return LABEL_FRONT
		Arg.PRIORITY:
			return LABEL_PRIORITY
		Arg.LINE:
			return LABEL_LINE
		Arg.CONTROLLED_ENTITY:
			return LABEL_CONTROLLED_ENTITY
		_:
			return ""


static func from_label(text: String) -> Arg:
	match text.strip_edges().to_lower():
		LABEL_LOWEST_HP:
			return Arg.LOWEST_HP
		LABEL_ALL:
			return Arg.ALL
		LABEL_MAX_HP:
			return Arg.MAX_HP
		LABEL_FASTEST:
			return Arg.FASTEST
		LABEL_FRONT:
			return Arg.FRONT
		LABEL_PRIORITY:
			return Arg.PRIORITY
		LABEL_LINE:
			return Arg.LINE
		LABEL_CONTROLLED_ENTITY:
			return Arg.CONTROLLED_ENTITY
		_:
			return Arg.DEFAULT


static func is_valid_label(text: String) -> bool:
	var key := text.strip_edges().to_lower()
	return key == "" or key in VALID_LABELS


## 将配置中的 target / targetArg（或旧复合 target）规范为 side + arg。
static func normalize_pair(target: Variant, target_arg: Variant = "") -> Dictionary:
	var raw_target := str(target).strip_edges().to_lower()
	var raw_arg := str(target_arg).strip_edges().to_lower()
	if raw_target in LEGACY_TARGET_TO_PAIR:
		var legacy: Dictionary = LEGACY_TARGET_TO_PAIR[raw_target]
		return {
			"target": str(legacy.get("target", LABEL_ENEMY)),
			"target_arg": str(legacy.get("target_arg", "")),
		}
	if raw_target in ["self", "enemy"]:
		return {
			"target": raw_target,
			"target_arg": raw_arg if is_valid_label(raw_arg) else "",
		}
	if raw_target == "":
		return {"target": LABEL_ENEMY, "target_arg": ""}
	return {"target": LABEL_ENEMY, "target_arg": ""}


static func display_label(target: String, target_arg: String = "") -> String:
	var pair := normalize_pair(target, target_arg)
	var side := str(pair.get("target", ""))
	var arg := str(pair.get("target_arg", ""))
	if side == LABEL_SELF:
		if arg == LABEL_CONTROLLED_ENTITY:
			return "控制对象"
		return "自身"
	if arg == "":
		return "敌人"
	match arg:
		LABEL_LOWEST_HP:
			return "低血敌人"
		LABEL_ALL:
			return "全体敌人"
		LABEL_MAX_HP:
			return "高血敌人"
		LABEL_FASTEST:
			return "最快敌人"
		LABEL_FRONT:
			return "前排敌人"
		LABEL_PRIORITY:
			return "高威胁敌人"
		LABEL_LINE:
			return "直线范围内敌人"
		_:
			return "敌人"


static func is_hostile_pair(target: String, target_arg: String = "") -> bool:
	var pair := normalize_pair(target, target_arg)
	return str(pair.get("target", "")) == LABEL_ENEMY
