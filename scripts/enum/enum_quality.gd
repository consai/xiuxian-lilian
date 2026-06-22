class_name EnumQuality
extends RefCounted

## 道具/法宝/技能通用品质档位。
## 配置可继续使用数字、中文三段品质、英文 rarity 或炼丹品质标签，UI 统一经本类取色和显示名。

enum Type {
	COMMON = 1,
	FINE = 2,
	RARE = 3,
	SUPREME = 4,
	EPIC = 5,
	LEGENDARY = 6,
	IMMORTAL = 7,
	MYTHIC = 8,
}

const LABEL_COMMON := "普通"
const LABEL_FINE := "良品"
const LABEL_RARE := "稀有"
const LABEL_SUPREME := "极品"
const LABEL_EPIC := "史诗"
const LABEL_LEGENDARY := "传说"
const LABEL_IMMORTAL := "仙品"
const LABEL_MYTHIC := "神品"

const ALL_QUALITIES: Array[int] = [
	Type.COMMON,
	Type.FINE,
	Type.RARE,
	Type.SUPREME,
	Type.EPIC,
	Type.LEGENDARY,
	Type.IMMORTAL,
	Type.MYTHIC,
]

const QUALITY_LABELS: Dictionary = {
	Type.COMMON: LABEL_COMMON,
	Type.FINE: LABEL_FINE,
	Type.RARE: LABEL_RARE,
	Type.SUPREME: LABEL_SUPREME,
	Type.EPIC: LABEL_EPIC,
	Type.LEGENDARY: LABEL_LEGENDARY,
	Type.IMMORTAL: LABEL_IMMORTAL,
	Type.MYTHIC: LABEL_MYTHIC,
}

const QUALITY_COLORS: Dictionary = {
	Type.COMMON: Color(0.62, 0.43, 0.24, 1.0),
	Type.FINE: Color(0.32, 0.66, 0.28, 1.0),
	Type.RARE: Color(0.12, 0.55, 0.86, 1.0),
	Type.SUPREME: Color(0.62, 0.28, 0.86, 1.0),
	Type.EPIC: Color(0.86, 0.28, 0.18, 1.0),
	Type.LEGENDARY: Color(0.92, 0.60, 0.08, 1.0),
	Type.IMMORTAL: Color(0.18, 0.78, 0.62, 1.0),
	Type.MYTHIC: Color(0.95, 0.82, 0.22, 1.0),
}


static func clamp_quality(quality: int) -> int:
	return clampi(quality, Type.COMMON, Type.MYTHIC)


static func label(quality: int) -> String:
	return str(QUALITY_LABELS.get(clamp_quality(quality), LABEL_COMMON))


static func display_label(quality: int) -> String:
	return label(quality)


static func broad_label(quality: int) -> String:
	var q := clamp_quality(quality)
	if q >= Type.LEGENDARY:
		return LABEL_LEGENDARY
	if q >= Type.RARE:
		return LABEL_RARE
	return LABEL_COMMON


static func from_label(text: String, default_quality: int = Type.COMMON) -> int:
	var key := text.strip_edges()
	if key == "":
		return clamp_quality(default_quality)
	if key.is_valid_int():
		return clamp_quality(int(key))
	if key.begins_with("品质"):
		var tail := key.trim_prefix("品质").strip_edges()
		if tail.is_valid_int():
			return clamp_quality(int(tail))
	match key.to_lower():
		"common", "普通", "凡品", "下品", "low":
			return Type.COMMON
		"uncommon", "良品", "中品", "medium":
			return Type.FINE
		"rare", "稀有", "上品", "high":
			return Type.RARE
		"supreme", "极品":
			return Type.SUPREME
		"epic", "史诗":
			return Type.EPIC
		"legendary", "传说":
			return Type.LEGENDARY
		"immortal", "仙品":
			return Type.IMMORTAL
		"mythic", "神品":
			return Type.MYTHIC
		_:
			return clamp_quality(default_quality)


static func border_color_from_label(text: String) -> Color:
	return get_color(from_label(text, Type.COMMON))


static func should_show_border(text: String) -> bool:
	return text.strip_edges() != ""


static func should_show_gem(text: String) -> bool:
	return text.strip_edges() != ""


static func tint_alpha_from_label(text: String) -> float:
	var q := from_label(text, Type.COMMON)
	if text.strip_edges() == "":
		return 0.0
	if q >= Type.LEGENDARY:
		return 0.34
	if q >= Type.SUPREME:
		return 0.28
	if q >= Type.RARE:
		return 0.24
	if q >= Type.FINE:
		return 0.20
	return 0.16


static func get_color(quality: int) -> Color:
	var color_v: Variant = QUALITY_COLORS.get(clamp_quality(quality), QUALITY_COLORS[Type.COMMON])
	return color_v as Color
