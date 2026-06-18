class_name EnumRewardKind
extends RefCounted

## 奖励、背包条目、战利品等 [code]kind[/code] 字段。

enum Kind {
	ITEM,
	EQUIP,
	CURRENCY,
}

const LABEL_ITEM := "item"
const LABEL_EQUIP := "equip"
const LABEL_CURRENCY := "currency"

const VALID_LABELS: Array[String] = [LABEL_ITEM, LABEL_EQUIP, LABEL_CURRENCY]


static func label(kind: Kind) -> String:
	match kind:
		Kind.EQUIP:
			return LABEL_EQUIP
		Kind.CURRENCY:
			return LABEL_CURRENCY
		_:
			return LABEL_ITEM


static func from_label(text: String) -> Kind:
	match text.strip_edges():
		LABEL_EQUIP:
			return Kind.EQUIP
		LABEL_CURRENCY:
			return Kind.CURRENCY
		_:
			return Kind.ITEM


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in VALID_LABELS
