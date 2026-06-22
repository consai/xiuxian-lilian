class_name EnumCombatEventType
extends RefCounted

## 战斗运行时事件载荷中的 type 字段。

enum Type {
	BUFF_TICK_DAMAGE,
	BUFF_EXPIRED,
}

const LABEL_BUFF_TICK_DAMAGE := "buff_tick_damage"
const LABEL_BUFF_EXPIRED := "buff_expired"

const VALID_LABELS: Array[String] = [
	LABEL_BUFF_TICK_DAMAGE,
	LABEL_BUFF_EXPIRED,
]


static func label(type: Type) -> String:
	match type:
		Type.BUFF_EXPIRED:
			return LABEL_BUFF_EXPIRED
		_:
			return LABEL_BUFF_TICK_DAMAGE


static func from_label(text: String) -> Type:
	match text.strip_edges():
		LABEL_BUFF_EXPIRED:
			return Type.BUFF_EXPIRED
		_:
			return Type.BUFF_TICK_DAMAGE


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in VALID_LABELS
