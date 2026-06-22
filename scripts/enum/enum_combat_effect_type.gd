class_name EnumCombatEffectType
extends RefCounted

## 战斗效果配置 effects[].type 字段。

enum Type {
	DAMAGE,
	HEAL,
	SHIELD,
	RESTORE_MP,
	BUFF,
	APPLY_BUFF,
	BUFF_ADD,
	TIMED_MODIFIER,
	CONTROL,
}

const LABEL_DAMAGE := "damage"
const LABEL_HEAL := "heal"
const LABEL_SHIELD := "shield"
const LABEL_RESTORE_MP := "restore_mp"
const LABEL_BUFF := "buff"
const LABEL_APPLY_BUFF := "apply_buff"
const LABEL_BUFF_ADD := "buff_add"
const LABEL_TIMED_MODIFIER := "timed_modifier"
const LABEL_CONTROL := "control"

const VALID_LABELS: Array[String] = [
	LABEL_DAMAGE,
	LABEL_HEAL,
	LABEL_SHIELD,
	LABEL_RESTORE_MP,
	LABEL_BUFF,
	LABEL_APPLY_BUFF,
	LABEL_BUFF_ADD,
]

const REQUIRES_VALUE_LABELS: Array[String] = [
	LABEL_DAMAGE,
	LABEL_HEAL,
	LABEL_SHIELD,
	LABEL_RESTORE_MP,
]


static func is_valid_label(text: String) -> bool:
	return text.strip_edges().to_lower() in VALID_LABELS


static func requires_value(text: String) -> bool:
	return text.strip_edges().to_lower() in REQUIRES_VALUE_LABELS
