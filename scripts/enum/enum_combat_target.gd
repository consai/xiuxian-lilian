class_name EnumCombatTarget
extends RefCounted

## 战斗效果配置 target/defaultTarget 字段。

enum Target {
	SELF,
	ENEMY,
}

const LABEL_SELF := "self"
const LABEL_ENEMY := "enemy"

const VALID_LABELS: Array[String] = [
	LABEL_SELF,
	LABEL_ENEMY,
]


static func label(target: Target) -> String:
	match target:
		Target.ENEMY:
			return LABEL_ENEMY
		_:
			return LABEL_SELF


static func from_label(text: String) -> Target:
	match text.strip_edges().to_lower():
		LABEL_ENEMY:
			return Target.ENEMY
		_:
			return Target.SELF


static func is_valid_label(text: String) -> bool:
	return text.strip_edges().to_lower() in VALID_LABELS
