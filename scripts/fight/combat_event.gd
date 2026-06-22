class_name CombatEvent
extends RefCounted

const TYPE_BUFF_TICK_DAMAGE := EnumCombatEventType.LABEL_BUFF_TICK_DAMAGE
const TYPE_BUFF_EXPIRED := EnumCombatEventType.LABEL_BUFF_EXPIRED

const KEY_TYPE := "type"
const KEY_UNIT_ID := "unit_id"
const KEY_REPORT := "report"
const KEY_BUFF_ID := "buff_id"


static func buff_tick_damage(unit_id: String, report: Dictionary) -> Dictionary:
	return {
		KEY_TYPE: TYPE_BUFF_TICK_DAMAGE,
		KEY_UNIT_ID: unit_id,
		KEY_REPORT: report.duplicate(true),
	}


static func buff_expired(unit_id: String, buff_id: String) -> Dictionary:
	return {
		KEY_TYPE: TYPE_BUFF_EXPIRED,
		KEY_UNIT_ID: unit_id,
		KEY_BUFF_ID: buff_id,
	}
