class_name EnumCultivationMode
extends RefCounted

## 闭关修炼模式（运转周天 / 参悟 / 吐纳 / 丹药炼化）。

enum Mode {
	CYCLE,
	INSIGHT,
	BREATHING,
	PILL,
}

const LABEL_CYCLE := "cycle"
const LABEL_INSIGHT := "insight"
const LABEL_BREATHING := "breathing"
const LABEL_PILL := "pill"

const MODE_IDS: Array[String] = [
	LABEL_CYCLE, LABEL_INSIGHT, LABEL_BREATHING, LABEL_PILL,
]

const MODE_CONFIG: Dictionary = {
	LABEL_CYCLE: {
		"name": "运转周天",
		"description": "修为、功法与知识均衡增长。",
		"cultivation_multiplier": 1.0,
		"knowledge_multiplier": 1.0,
		"mastery_multiplier": 1.0,
	},
	LABEL_INSIGHT: {
		"name": "专心参悟",
		"description": "放缓修为积累，专注理解功法与其中知识。",
		"cultivation_multiplier": 0.6,
		"knowledge_multiplier": 1.6,
		"mastery_multiplier": 1.5,
	},
	LABEL_BREATHING: {
		"name": "吐纳积气",
		"description": "集中吸纳灵气，快速积累修为。",
		"cultivation_multiplier": 1.4,
		"knowledge_multiplier": 0.5,
		"mastery_multiplier": 0.6,
	},
	LABEL_PILL: {
		"name": "丹药炼化",
		"description": "服用修炼丹药后打坐炼化，获得丹药修为，但会使灵力驳杂。",
		"cultivation_multiplier": 1.0,
		"knowledge_multiplier": 0.8,
		"mastery_multiplier": 0.8,
	},
}


static func label(mode: Mode) -> String:
	match mode:
		Mode.INSIGHT:
			return LABEL_INSIGHT
		Mode.BREATHING:
			return LABEL_BREATHING
		Mode.PILL:
			return LABEL_PILL
		_:
			return LABEL_CYCLE


static func from_label(text: String) -> Mode:
	match text.strip_edges():
		LABEL_INSIGHT:
			return Mode.INSIGHT
		LABEL_BREATHING:
			return Mode.BREATHING
		LABEL_PILL:
			return Mode.PILL
		_:
			return Mode.CYCLE


static func config(mode_id: String) -> Dictionary:
	var row_v: Variant = MODE_CONFIG.get(mode_id.strip_edges(), MODE_CONFIG[LABEL_CYCLE])
	return (row_v as Dictionary).duplicate(true)


static func is_pill_mode(mode_id: String) -> bool:
	return mode_id.strip_edges() == LABEL_PILL
