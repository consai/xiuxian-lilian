class_name EnumItemType
extends RefCounted

## 道具分类：统一维护一级/二级标签、旧 type 兼容映射、背包筛选与排序顺序。

const PRIMARY_ITEM := "道具"
const PRIMARY_BOOK := "书籍"
const PRIMARY_CONSUMABLE := "消耗品"
const PRIMARY_TREASURE := "法宝"
const PRIMARY_EQUIP := "equip"

const SECONDARY_HERB := "药材"
const SECONDARY_ORE := "矿石"
const SECONDARY_MISC := "其他"
const SECONDARY_NOTES := "心得"
const SECONDARY_MAP := "地图"
const SECONDARY_METHOD_BOOK := "功法书"
const SECONDARY_SKILL_BOOK := "技能书"
const SECONDARY_PILL := "丹药"
const SECONDARY_TALISMAN := "符箓"
const SECONDARY_ACTIVE_TREASURE := "主动法宝"
const SECONDARY_PASSIVE_TREASURE := "被动法宝"
const SECONDARY_MOVEMENT_TREASURE := "移动法宝"

const LEGACY_TYPE_MAP := {
	"材料": {"primary": PRIMARY_ITEM, "secondary": SECONDARY_HERB},
	"矿材": {"primary": PRIMARY_ITEM, "secondary": SECONDARY_ORE},
	"典籍": {"primary": PRIMARY_BOOK, "secondary": SECONDARY_NOTES},
	"技能书": {"primary": PRIMARY_BOOK, "secondary": SECONDARY_SKILL_BOOK},
	"功法书": {"primary": PRIMARY_BOOK, "secondary": SECONDARY_METHOD_BOOK},
	"丹药": {"primary": PRIMARY_CONSUMABLE, "secondary": SECONDARY_PILL},
	"符箓": {"primary": PRIMARY_CONSUMABLE, "secondary": SECONDARY_TALISMAN},
	"法宝": {"primary": PRIMARY_TREASURE, "secondary": SECONDARY_ACTIVE_TREASURE},
}

const PRIMARY_SORT_ORDER := {
	PRIMARY_ITEM: 0,
	PRIMARY_BOOK: 1,
	PRIMARY_CONSUMABLE: 2,
	PRIMARY_TREASURE: 3,
	PRIMARY_EQUIP: 4,
}

const SECONDARY_SORT_ORDER := {
	SECONDARY_HERB: 0,
	SECONDARY_ORE: 1,
	SECONDARY_MISC: 2,
	SECONDARY_NOTES: 10,
	SECONDARY_MAP: 11,
	SECONDARY_METHOD_BOOK: 12,
	SECONDARY_SKILL_BOOK: 13,
	SECONDARY_PILL: 20,
	SECONDARY_TALISMAN: 21,
	SECONDARY_ACTIVE_TREASURE: 30,
	SECONDARY_PASSIVE_TREASURE: 31,
	SECONDARY_MOVEMENT_TREASURE: 32,
}


static func resolve_primary_label(primary: String, secondary: String, legacy_type: String = "") -> String:
	var primary_label := primary.strip_edges()
	if primary_label != "":
		return primary_label
	var legacy := _legacy_mapping(legacy_type)
	if not legacy.is_empty():
		return str(legacy.get("primary", ""))
	return _primary_from_secondary(secondary)


static func resolve_secondary_label(primary: String, secondary: String, legacy_type: String = "") -> String:
	var secondary_label := secondary.strip_edges()
	if secondary_label != "":
		return secondary_label
	var legacy := _legacy_mapping(legacy_type)
	if not legacy.is_empty():
		return str(legacy.get("secondary", ""))
	return _default_secondary_for_primary(primary)


static func full_label(primary: String, secondary: String) -> String:
	var primary_label := primary.strip_edges()
	var secondary_label := secondary.strip_edges()
	if primary_label == "":
		return secondary_label
	if secondary_label == "":
		return primary_label
	return "%s(%s)" % [primary_label, secondary_label]


static func sort_order_for_entry(kind: String, primary_label: String, secondary_label: String) -> int:
	if str(kind).strip_edges() == EnumRewardKind.LABEL_EQUIP:
		return sort_order(PRIMARY_TREASURE, SECONDARY_ACTIVE_TREASURE)
	return sort_order(primary_label, secondary_label)


static func sort_order(primary_label: String, secondary_label: String = "") -> int:
	var primary_order := int(PRIMARY_SORT_ORDER.get(primary_label.strip_edges(), 99))
	var secondary_order := int(SECONDARY_SORT_ORDER.get(secondary_label.strip_edges(), 99))
	return primary_order * 100 + secondary_order


static func filter_sort_order_for_label(text: String) -> int:
	return int(PRIMARY_SORT_ORDER.get(text.strip_edges(), 100))


static func is_material_primary(primary_label: String) -> bool:
	return primary_label.strip_edges() == PRIMARY_ITEM


static func is_material_label(text: String) -> bool:
	return is_material_primary(resolve_primary_label("", text, text))


static func is_pill_secondary(secondary_label: String) -> bool:
	return secondary_label.strip_edges() == SECONDARY_PILL


static func is_treasure_primary(primary_label: String) -> bool:
	return primary_label.strip_edges() == PRIMARY_TREASURE


static func material_labels() -> PackedStringArray:
	return PackedStringArray([PRIMARY_ITEM])


static func _legacy_mapping(legacy_type: String) -> Dictionary:
	var found: Variant = LEGACY_TYPE_MAP.get(legacy_type.strip_edges(), {})
	if found is Dictionary:
		return (found as Dictionary).duplicate(true)
	return {}


static func _primary_from_secondary(secondary: String) -> String:
	match secondary.strip_edges():
		SECONDARY_HERB, SECONDARY_ORE, SECONDARY_MISC:
			return PRIMARY_ITEM
		SECONDARY_NOTES, SECONDARY_MAP, SECONDARY_METHOD_BOOK, SECONDARY_SKILL_BOOK:
			return PRIMARY_BOOK
		SECONDARY_PILL, SECONDARY_TALISMAN:
			return PRIMARY_CONSUMABLE
		SECONDARY_ACTIVE_TREASURE, SECONDARY_PASSIVE_TREASURE, SECONDARY_MOVEMENT_TREASURE:
			return PRIMARY_TREASURE
		_:
			return ""


static func _default_secondary_for_primary(primary: String) -> String:
	match primary.strip_edges():
		PRIMARY_ITEM:
			return SECONDARY_MISC
		PRIMARY_BOOK:
			return SECONDARY_NOTES
		PRIMARY_CONSUMABLE:
			return SECONDARY_PILL
		PRIMARY_TREASURE:
			return SECONDARY_ACTIVE_TREASURE
		_:
			return ""
