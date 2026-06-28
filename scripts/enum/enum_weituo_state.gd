class_name EnumWeituoState
extends RefCounted

enum State {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	READY,
	COMPLETED,
}

const LABEL_LOCKED := "未解锁"
const LABEL_AVAILABLE := "可接受"
const LABEL_ACTIVE := "进行中"
const LABEL_READY := "可提交"
const LABEL_COMPLETED := "已完成"


static func label(state: State) -> String:
	match state:
		State.LOCKED:
			return LABEL_LOCKED
		State.AVAILABLE:
			return LABEL_AVAILABLE
		State.ACTIVE:
			return LABEL_ACTIVE
		State.READY:
			return LABEL_READY
		State.COMPLETED:
			return LABEL_COMPLETED
		_:
			return ""


static func sort_order(state: State) -> int:
	match state:
		State.READY:
			return 0
		State.ACTIVE:
			return 1
		State.AVAILABLE:
			return 2
		State.COMPLETED:
			return 3
		State.LOCKED:
			return 4
		_:
			return 99


static func badge_color(state: State) -> Color:
	match state:
		State.AVAILABLE:
			return Color(0.55, 0.68, 0.36, 1.0)
		State.ACTIVE:
			return Color(0.78, 0.62, 0.28, 1.0)
		State.READY:
			return Color(0.45, 0.72, 0.34, 1.0)
		State.COMPLETED:
			return Color(0.52, 0.4, 0.28, 1.0)
		_:
			return Color(0.55, 0.45, 0.38, 1.0)
