class_name EnumZhandouActiveEffect
extends RefCounted

## 战斗主动技能 positional effects 效果类型（与导出效果说明表一致）。

enum Effect {
	DAMAGE,
	SHIELD,
	HEAL_HP,
	RESTORE_MANA,
	ATTRSCHANGE,
	BUFF,
}

const LABEL_DAMAGE := "damage"
const LABEL_SHIELD := "shield"
const LABEL_HEAL_HP := "heal_hp"
const LABEL_RESTORE_MANA := "restore_mana"
const LABEL_ATTRSCHANGE := "attrschange"
const LABEL_BUFF := "buff"

const ALL_LABELS: Array[String] = [
	LABEL_DAMAGE,
	LABEL_SHIELD,
	LABEL_HEAL_HP,
	LABEL_RESTORE_MANA,
	LABEL_ATTRSCHANGE,
	LABEL_BUFF,
]


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in ALL_LABELS


static func label(effect_id: String) -> String:
	match effect_id.strip_edges():
		LABEL_DAMAGE:
			return "伤害"
		LABEL_SHIELD:
			return "护盾"
		LABEL_HEAL_HP:
			return "回血"
		LABEL_RESTORE_MANA:
			return "回蓝"
		LABEL_ATTRSCHANGE:
			return "战斗属性改变"
		LABEL_BUFF:
			return "持续效果"
		_:
			return ""
