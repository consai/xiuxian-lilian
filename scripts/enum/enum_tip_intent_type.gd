class_name EnumTipIntentType
extends RefCounted

## 统一提示协议中的 intent.type 字段。

enum Type {
	TOAST,
	HINT,
	BLOCK_REASON,
}

const LABEL_TOAST := "toast"
const LABEL_HINT := "hint"
const LABEL_BLOCK_REASON := "block_reason"

const VALID_LABELS: Array[String] = [
	LABEL_TOAST,
	LABEL_HINT,
	LABEL_BLOCK_REASON,
]


static func label(type: Type) -> String:
	match type:
		Type.TOAST:
			return LABEL_TOAST
		Type.BLOCK_REASON:
			return LABEL_BLOCK_REASON
		_:
			return LABEL_HINT


static func from_label(text: String) -> Type:
	match text.strip_edges():
		LABEL_TOAST:
			return Type.TOAST
		LABEL_BLOCK_REASON:
			return Type.BLOCK_REASON
		_:
			return Type.HINT


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in VALID_LABELS
