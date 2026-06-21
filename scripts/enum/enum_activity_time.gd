class_name EnumActivityTime
extends RefCounted

enum Type {
	CULTIVATE,
	EXPEDITION,
	TRAVEL_SHORT,
	TRAVEL_MID,
	TRAVEL_LONG,
	INSIGHT,
	SKILL_BASIC,
	SKILL_ADVANCED,
	SELF_STUDY,
	ALCHEMY,
	CRAFTING,
	BREAKTHROUGH,
}

const LABEL_CULTIVATE := "cultivate"
const LABEL_EXPEDITION := "expedition"
const LABEL_TRAVEL_SHORT := "travel_short"
const LABEL_TRAVEL_MID := "travel_mid"
const LABEL_TRAVEL_LONG := "travel_long"
const LABEL_INSIGHT := "insight"
const LABEL_SKILL_BASIC := "skill_basic"
const LABEL_SKILL_ADVANCED := "skill_advanced"
const LABEL_SELF_STUDY := "self_study"
const LABEL_ALCHEMY := "alchemy"
const LABEL_CRAFTING := "crafting"
const LABEL_BREAKTHROUGH := "breakthrough"


static func label(type: Type) -> String:
	match type:
		Type.EXPEDITION:
			return LABEL_EXPEDITION
		Type.TRAVEL_SHORT:
			return LABEL_TRAVEL_SHORT
		Type.TRAVEL_MID:
			return LABEL_TRAVEL_MID
		Type.TRAVEL_LONG:
			return LABEL_TRAVEL_LONG
		Type.INSIGHT:
			return LABEL_INSIGHT
		Type.SKILL_BASIC:
			return LABEL_SKILL_BASIC
		Type.SKILL_ADVANCED:
			return LABEL_SKILL_ADVANCED
		Type.SELF_STUDY:
			return LABEL_SELF_STUDY
		Type.ALCHEMY:
			return LABEL_ALCHEMY
		Type.CRAFTING:
			return LABEL_CRAFTING
		Type.BREAKTHROUGH:
			return LABEL_BREAKTHROUGH
		_:
			return LABEL_CULTIVATE


static func display_name(activity_id: String) -> String:
	match activity_id.strip_edges():
		LABEL_EXPEDITION:
			return "历练"
		LABEL_TRAVEL_SHORT:
			return "短途赶路"
		LABEL_TRAVEL_MID:
			return "中途赶路"
		LABEL_TRAVEL_LONG:
			return "长途赶路"
		LABEL_INSIGHT:
			return "悟道"
		LABEL_SKILL_BASIC:
			return "学习普通技能"
		LABEL_SKILL_ADVANCED:
			return "学习高级技能"
		LABEL_SELF_STUDY:
			return "自主研读"
		LABEL_ALCHEMY:
			return "炼丹"
		LABEL_CRAFTING:
			return "炼器"
		LABEL_BREAKTHROUGH:
			return "突破"
		_:
			return "修炼"
