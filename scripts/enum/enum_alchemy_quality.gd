class_name EnumAlchemyQuality
extends RefCounted

## 炼丹成丹品质档位（配置 [code]alchemy.json[/code] 产物键与结算 [code]quality[/code] 字段）。

enum Quality {
	NONE,
	WASTE,
	LOW,
	MEDIUM,
	HIGH,
	SUPREME,
}

const LABEL_NONE := "none"
const LABEL_WASTE := "waste"
const LABEL_LOW := "low"
const LABEL_MEDIUM := "medium"
const LABEL_HIGH := "high"
const LABEL_SUPREME := "supreme"

const ALL_LABELS: Array[String] = [
	LABEL_NONE, LABEL_WASTE, LABEL_LOW, LABEL_MEDIUM, LABEL_HIGH, LABEL_SUPREME,
]

const PRODUCT_SCAN_LABELS: Array[String] = [
	LABEL_MEDIUM, LABEL_HIGH, LABEL_LOW, LABEL_SUPREME,
]

const SUMMARY_LABELS: Array[String] = [
	LABEL_SUPREME, LABEL_HIGH, LABEL_MEDIUM, LABEL_LOW, LABEL_WASTE, LABEL_NONE,
]

const SUCCESS_LABELS: Array[String] = [
	LABEL_LOW, LABEL_MEDIUM, LABEL_HIGH, LABEL_SUPREME,
]

const DISPLAY_NAMES: Dictionary = {
	LABEL_NONE: "无产物",
	LABEL_WASTE: "废丹",
	LABEL_LOW: "下品",
	LABEL_MEDIUM: "中品",
	LABEL_HIGH: "上品",
	LABEL_SUPREME: "极品",
}

const RANK: Dictionary = {
	LABEL_NONE: 0,
	LABEL_WASTE: 1,
	LABEL_LOW: 2,
	LABEL_MEDIUM: 3,
	LABEL_HIGH: 4,
	LABEL_SUPREME: 5,
}

const XP_SCALE: Dictionary = {
	LABEL_NONE: 0.7,
	LABEL_WASTE: 0.9,
	LABEL_LOW: 1.0,
	LABEL_MEDIUM: 1.1,
	LABEL_HIGH: 1.2,
	LABEL_SUPREME: 1.4,
}

const RESULT_COLORS: Dictionary = {
	LABEL_NONE: Color(0.62, 0.62, 0.62),
	LABEL_WASTE: Color(0.55, 0.48, 0.42),
	LABEL_LOW: Color(0.72, 0.78, 0.62),
	LABEL_MEDIUM: Color(0.58, 0.68, 0.42),
	LABEL_HIGH: Color(0.45, 0.62, 0.38),
	LABEL_SUPREME: Color(0.82, 0.62, 0.18),
}


static func label(quality: Quality) -> String:
	match quality:
		Quality.WASTE:
			return LABEL_WASTE
		Quality.LOW:
			return LABEL_LOW
		Quality.MEDIUM:
			return LABEL_MEDIUM
		Quality.HIGH:
			return LABEL_HIGH
		Quality.SUPREME:
			return LABEL_SUPREME
		_:
			return LABEL_NONE


static func from_label(text: String) -> Quality:
	match text.strip_edges():
		LABEL_WASTE:
			return Quality.WASTE
		LABEL_LOW:
			return Quality.LOW
		LABEL_MEDIUM:
			return Quality.MEDIUM
		LABEL_HIGH:
			return Quality.HIGH
		LABEL_SUPREME:
			return Quality.SUPREME
		_:
			return Quality.NONE


static func display_name(quality_label: String) -> String:
	return str(DISPLAY_NAMES.get(quality_label.strip_edges(), quality_label))


static func rank(quality_label: String) -> int:
	return int(RANK.get(quality_label.strip_edges(), 0))


static func xp_scale(quality_label: String) -> float:
	return float(XP_SCALE.get(quality_label.strip_edges(), 1.0))


static func result_color(quality_label: String) -> Color:
	var key := quality_label.strip_edges()
	var color_v: Variant = RESULT_COLORS.get(key, RESULT_COLORS[LABEL_MEDIUM])
	return color_v as Color


static func is_success(quality_label: String) -> bool:
	return quality_label.strip_edges() in SUCCESS_LABELS


static func empty_probability_counts() -> Dictionary:
	return {
		LABEL_NONE: 0.0,
		LABEL_WASTE: 0.0,
		LABEL_LOW: 0.0,
		LABEL_MEDIUM: 0.0,
		LABEL_HIGH: 0.0,
		LABEL_SUPREME: 0.0,
	}


static func quality_for_score(score: float) -> String:
	if score < 15.0:
		return LABEL_NONE
	if score < 35.0:
		return LABEL_WASTE
	if score < 55.0:
		return LABEL_LOW
	if score < 70.0:
		return LABEL_MEDIUM
	if score < 85.0:
		return LABEL_HIGH
	return LABEL_SUPREME


static func failure_flavor(quality_label: String) -> String:
	match quality_label.strip_edges():
		LABEL_NONE:
			return "炉火熄灭，药材化为灰烬，未能凝丹。"
		LABEL_WASTE:
			return "丹形粗劣，药力涣散，仅可作废丹处理。"
		LABEL_LOW:
			return "丹色暗淡，药力勉强可用。"
		LABEL_MEDIUM:
			return "丹色均匀，药力稳定，可日常使用。"
		LABEL_HIGH:
			return "丹色莹润，药力充盈，效果出众。"
		LABEL_SUPREME:
			return "丹纹天成，药香四溢，堪称极品。"
		_:
			return "炉火渐熄，炼制告一段落。"
