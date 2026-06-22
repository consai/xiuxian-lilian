class_name EnumTipTone
extends RefCounted

## 统一提示协议中的 tone 字段。

enum Tone {
	NEUTRAL,
	GAIN,
	LOSS,
}

const LABEL_NEUTRAL := "neutral"
const LABEL_GAIN := "gain"
const LABEL_LOSS := "loss"

const VALID_LABELS: Array[String] = [
	LABEL_NEUTRAL,
	LABEL_GAIN,
	LABEL_LOSS,
]


static func label(tone: Tone) -> String:
	match tone:
		Tone.GAIN:
			return LABEL_GAIN
		Tone.LOSS:
			return LABEL_LOSS
		_:
			return LABEL_NEUTRAL


static func from_label(text: String) -> Tone:
	match text.strip_edges().to_lower():
		LABEL_GAIN, "green", "up":
			return Tone.GAIN
		LABEL_LOSS, "red", "down":
			return Tone.LOSS
		_:
			return Tone.NEUTRAL


static func normalize_label(text: Variant) -> String:
	return label(from_label(str(text)))


static func is_valid_label(text: String) -> bool:
	return text.strip_edges().to_lower() in VALID_LABELS
