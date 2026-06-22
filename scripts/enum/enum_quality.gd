class_name EnumQuality
extends RefCounted

## 道具/法宝/技能通用品质档位。
## 品质只表示同阶内成色，阶位底盘颜色由 EnumItemTier 负责。

enum Type {
	LOW = 1,
	MEDIUM = 2,
	HIGH = 3,
	SUPREME = 4,
}

const LABEL_LOW := "下品"
const LABEL_MEDIUM := "中品"
const LABEL_HIGH := "上品"
const LABEL_SUPREME := "极品"

const ALL_QUALITIES: Array[int] = [
	Type.LOW,
	Type.MEDIUM,
	Type.HIGH,
	Type.SUPREME,
]

const QUALITY_LABELS: Dictionary = {
	Type.LOW: LABEL_LOW,
	Type.MEDIUM: LABEL_MEDIUM,
	Type.HIGH: LABEL_HIGH,
	Type.SUPREME: LABEL_SUPREME,
}

const QUALITY_COLORS: Dictionary = {
	Type.LOW: Color(0.58, 0.42, 0.28, 1.0),
	Type.MEDIUM: Color(0.32, 0.66, 0.28, 1.0),
	Type.HIGH: Color(0.12, 0.55, 0.86, 1.0),
	Type.SUPREME: Color(0.86, 0.18, 0.14, 1.0),
}


static func clamp_quality(quality: int) -> int:
	return clampi(quality, Type.LOW, Type.SUPREME)


static func is_valid_quality(quality: int) -> bool:
	return quality >= Type.LOW and quality <= Type.SUPREME


static func label(quality: int) -> String:
	return str(QUALITY_LABELS.get(clamp_quality(quality), LABEL_LOW))


static func display_label(quality: int) -> String:
	return label(quality)


static func broad_label(quality: int) -> String:
	return label(quality)


static func from_label(text: String, default_quality: int = Type.LOW) -> int:
	var key := text.strip_edges()
	if key == "":
		return clamp_quality(default_quality)
	if key.is_valid_int():
		var parsed := int(key)
		if is_valid_quality(parsed):
			return parsed
		push_error("EnumQuality.from_label: invalid quality %s" % key)
		return clamp_quality(default_quality)
	match key.to_lower():
		"下品":
			return Type.LOW
		"中品":
			return Type.MEDIUM
		"上品":
			return Type.HIGH
		"极品":
			return Type.SUPREME
		_:
			push_error("EnumQuality.from_label: invalid quality label %s" % key)
			return clamp_quality(default_quality)


static func border_color_from_label(text: String) -> Color:
	return get_color(from_label(text, Type.LOW))


static func should_show_gem(text: String) -> bool:
	return text.strip_edges() != ""


static func get_color(quality: int) -> Color:
	var color_v: Variant = QUALITY_COLORS.get(clamp_quality(quality), QUALITY_COLORS[Type.LOW])
	return color_v as Color
