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


## 效果 target 是否指向敌方（含 enemy_lowest_hp 等扩展选敌标签）。
static func is_hostile_label(text: String) -> bool:
	var key := text.strip_edges().to_lower()
	if key == LABEL_SELF:
		return false
	if key == "" or key == LABEL_ENEMY:
		return true
	if key.begins_with("enemy"):
		return true
	# 范围/落点类目标在 1v1 中仍落在 default_target（玩家）上。
	return key in ["area", "line", "position"]
