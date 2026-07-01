class_name EnumItemTier
extends RefCounted

## 道具阶位。阶代表大境界层级，负责道具格底盘颜色。

enum Type {
	QI = 1,
	FOUNDATION = 2,
	CORE = 3,
	NASCENT = 4,
	TRANSFORM = 5,
	VOID = 6,
	MERGE = 7,
	GREAT = 8,
	TRIBULATION = 9,
}

const LABEL_QI := "一阶"
const LABEL_FOUNDATION := "二阶"
const LABEL_CORE := "三阶"
const LABEL_NASCENT := "四阶"
const LABEL_TRANSFORM := "五阶"
const LABEL_VOID := "六阶"
const LABEL_MERGE := "七阶"
const LABEL_GREAT := "八阶"
const LABEL_TRIBULATION := "九阶"

const TIER_LABELS: Dictionary = {
	Type.QI: LABEL_QI,
	Type.FOUNDATION: LABEL_FOUNDATION,
	Type.CORE: LABEL_CORE,
	Type.NASCENT: LABEL_NASCENT,
	Type.TRANSFORM: LABEL_TRANSFORM,
	Type.VOID: LABEL_VOID,
	Type.MERGE: LABEL_MERGE,
	Type.GREAT: LABEL_GREAT,
	Type.TRIBULATION: LABEL_TRIBULATION,
}

const TIER_COLORS: Dictionary = {
	Type.QI: Color(0.40, 0.58, 0.36, 1.0),
	Type.FOUNDATION: Color(0.34, 0.53, 0.70, 1.0),
	Type.CORE: Color(0.66, 0.48, 0.22, 1.0),
	Type.NASCENT: Color(0.48, 0.40, 0.70, 1.0),
	Type.TRANSFORM: Color(0.68, 0.36, 0.28, 1.0),
	Type.VOID: Color(0.36, 0.45, 0.58, 1.0),
	Type.MERGE: Color(0.46, 0.58, 0.56, 1.0),
	Type.GREAT: Color(0.70, 0.62, 0.42, 1.0),
	Type.TRIBULATION: Color(0.76, 0.72, 0.62, 1.0),
}

## 阶位与大境界 id 一一对应（与 dao_tree.realms.order 一致）。
const REALM_IDS_BY_TIER: Array[String] = [
	"qi",
	"foundation",
	"core",
	"nascent",
	"transform",
	"void",
	"merge",
	"great",
	"tribulation",
]


static func clamp_tier(tier: int) -> int:
	return clampi(tier, Type.QI, Type.TRIBULATION)


## 阶位 → 大境界 id（如 1 → qi）。
static func realm_id_for_tier(tier: int) -> String:
	var index := clamp_tier(tier) - 1
	if index < 0 or index >= REALM_IDS_BY_TIER.size():
		return REALM_IDS_BY_TIER[0]
	return REALM_IDS_BY_TIER[index]


## 大境界 id → 阶位（如 foundation → 2）；未知 id 回落为一阶。
static func tier_for_realm_id(realm_id: String) -> int:
	var rid := realm_id.strip_edges().to_lower()
	var index := REALM_IDS_BY_TIER.find(rid)
	if index < 0:
		return Type.QI
	return index + 1


static func is_valid_tier(tier: int) -> bool:
	return tier >= Type.QI and tier <= Type.TRIBULATION


static func label(tier: int) -> String:
	return str(TIER_LABELS.get(clamp_tier(tier), LABEL_QI))


static func get_color(tier: int) -> Color:
	var color_v: Variant = TIER_COLORS.get(clamp_tier(tier), TIER_COLORS[Type.QI])
	return color_v as Color


static func tint_alpha(tier: int) -> float:
	var t := clamp_tier(tier)
	if t >= Type.GREAT:
		return 1
	if t >= Type.TRANSFORM:
		return 1
	if t >= Type.CORE:
		return 1
	return 1
