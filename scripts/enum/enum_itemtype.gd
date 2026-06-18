class_name EnumItemType
extends RefCounted

## 道具配置 [code]item.json[/code] 中的 [code]type[/code] 字段，以及背包里 [code]kind == "equip"[/code] 的排序分类。

enum Type {
	MATERIAL,
	ORE,
	PILL,
	TREASURE,
	EQUIP,
	UNKNOWN,
}

const LABEL_MATERIAL := "材料"
const LABEL_ORE := "矿材"
const LABEL_PILL := "丹药"
const LABEL_TREASURE := "法宝"
const LABEL_EQUIP := "equip"

const SORT_ORDER: Dictionary = {
	Type.MATERIAL: 0,
	Type.ORE: 1,
	Type.PILL: 2,
	Type.TREASURE: 3,
	Type.EQUIP: 4,
}


static func label(type: Type) -> String:
	match type:
		Type.MATERIAL:
			return LABEL_MATERIAL
		Type.ORE:
			return LABEL_ORE
		Type.PILL:
			return LABEL_PILL
		Type.TREASURE:
			return LABEL_TREASURE
		Type.EQUIP:
			return LABEL_EQUIP
		_:
			return ""


static func from_label(text: String) -> Type:
	match text.strip_edges():
		LABEL_MATERIAL:
			return Type.MATERIAL
		LABEL_ORE:
			return Type.ORE
		LABEL_PILL:
			return Type.PILL
		LABEL_TREASURE:
			return Type.TREASURE
		LABEL_EQUIP:
			return Type.EQUIP
		_:
			return Type.UNKNOWN


static func sort_order(type: Type) -> int:
	return int(SORT_ORDER.get(type, 99))


static func sort_order_for_entry(kind: String, item_type_label: String) -> int:
	if str(kind).strip_edges() == EnumRewardKind.LABEL_EQUIP:
		return sort_order(Type.EQUIP)
	return sort_order(from_label(item_type_label))


static func is_material(type: Type) -> bool:
	return type == Type.MATERIAL or type == Type.ORE


static func is_material_label(text: String) -> bool:
	return is_material(from_label(text))


static func material_labels() -> PackedStringArray:
	return PackedStringArray([LABEL_MATERIAL, LABEL_ORE])


static func filter_sort_order_for_label(text: String) -> int:
	var typed := from_label(text.strip_edges())
	if typed != Type.UNKNOWN:
		return sort_order(typed)
	return 100
