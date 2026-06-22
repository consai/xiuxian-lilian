class_name EnumBattleFormationMode
extends RefCounted

## 敌方阵型配置中的 mode 字段。

enum Mode {
	COLUMNS,
	WAVES,
}

const LABEL_COLUMNS := "columns"
const LABEL_WAVES := "waves"

const VALID_LABELS: Array[String] = [
	LABEL_COLUMNS,
	LABEL_WAVES,
]


static func label(mode: Mode) -> String:
	match mode:
		Mode.WAVES:
			return LABEL_WAVES
		_:
			return LABEL_COLUMNS


static func from_label(text: String) -> Mode:
	match text.strip_edges():
		LABEL_WAVES:
			return Mode.WAVES
		_:
			return Mode.COLUMNS


static func normalize_label(text: Variant) -> String:
	return label(from_label(str(text)))


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in VALID_LABELS
