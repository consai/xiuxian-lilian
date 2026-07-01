class_name EnumZhandouPassiveEffect
extends RefCounted

## 战斗被动技能 effects[].effectId 枚举。

enum Effect {
	PHYSICAL_DEF, # 物理防御
	MAGIC_DEF, # 法术防御
	ALL_RESISTANCE, # 全抗性
	DAMAGE_BONUS, # 伤害加成
	HP_REGEN, # 气血回复
	CONTROL_RESIST, # 控制抗性
	FATAL_RESISTANCE, # 濒死抗性
	WEAKNESS_DETECTION, # 弱点洞察
	WEAPON_DURABILITY, # 兵刃耐久
}

const LABEL_PHYSICAL_DEF := "physical_def"
const LABEL_MAGIC_DEF := "magic_def"
const LABEL_ALL_RESISTANCE := "all_resistance"
const LABEL_DAMAGE_BONUS := "damage_bonus"
const LABEL_HP_REGEN := "hp_regen"
const LABEL_CAST_SPEED := "cast_speed"
const LABEL_CONTROL_RESIST := "control_resist"
const LABEL_FATAL_RESISTANCE := "fatal_resistance"
const LABEL_WEAKNESS_DETECTION := "weakness_detection"
const LABEL_WEAPON_DURABILITY := "weapon_durability"

const ALL_LABELS: Array[String] = [
	LABEL_PHYSICAL_DEF,
	LABEL_MAGIC_DEF,
	LABEL_ALL_RESISTANCE,
	LABEL_DAMAGE_BONUS,
	LABEL_HP_REGEN,
	LABEL_CAST_SPEED,
	LABEL_CONTROL_RESIST,
	LABEL_FATAL_RESISTANCE,
	LABEL_WEAKNESS_DETECTION,
	LABEL_WEAPON_DURABILITY,
]


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in ALL_LABELS


static func label(effect_id: String) -> String:
	match effect_id.strip_edges():
		LABEL_PHYSICAL_DEF:
			return "物理防御"
		LABEL_MAGIC_DEF:
			return "法术防御"
		LABEL_ALL_RESISTANCE:
			return "全抗性"
		LABEL_DAMAGE_BONUS:
			return "伤害加成"
		LABEL_HP_REGEN:
			return "气血回复"
		LABEL_CAST_SPEED:
			return "出手速度"
		LABEL_CONTROL_RESIST:
			return "控制抗性"
		LABEL_FATAL_RESISTANCE:
			return "濒死抗性"
		LABEL_WEAKNESS_DETECTION:
			return "弱点洞察"
		LABEL_WEAPON_DURABILITY:
			return "兵刃耐久"
		_:
			return ""
