class_name EnemyAiTypes
extends RefCounted

const ACTION_SKILL := "skill"
const ACTION_BASIC := "basic"
const ACTION_ITEM := "item"
const ACTION_EQUIP := "equip"

const REASON_OK_SKILL := "ok_skill"
const REASON_OK_BASIC := "ok_basic"
const REASON_OK_ITEM := "ok_item"
const REASON_OK_EQUIP := "ok_equip"
const REASON_NO_SKILL_USABLE := "no_skill_usable"
const REASON_NO_BASIC_SLOT := "no_basic_slot"
const REASON_NO_RULE_MATCHED := "no_rule_matched"
const REASON_INVALID_AI_CONFIG := "invalid_ai_config"
const REASON_SKILL_CFG_MISSING := "skill_cfg_missing"


static func ok_skill(
		skill_id: int,
		slot_index: int,
		reason: String = REASON_OK_SKILL,
		phase_id: String = ""
) -> Dictionary:
	return _ok_decision(ACTION_SKILL, skill_id, slot_index, reason, phase_id)


static func ok_basic(slot_index: int, reason: String = REASON_OK_BASIC, phase_id: String = "") -> Dictionary:
	return _ok_decision(ACTION_BASIC, 0, slot_index, reason, phase_id)


static func ok_item(slot_index: int, reason: String = REASON_OK_ITEM, phase_id: String = "") -> Dictionary:
	return _ok_decision(ACTION_ITEM, -1, slot_index, reason, phase_id)


static func ok_equip(slot_index: int, reason: String = REASON_OK_EQUIP, phase_id: String = "") -> Dictionary:
	return _ok_decision(ACTION_EQUIP, -1, slot_index, reason, phase_id)


static func fail(reason: String, phase_id: String = "") -> Dictionary:
	var out := {
		"ok": false,
		"action_type": "",
		"skill_id": -1,
		"slot_index": -1,
		"reason": reason,
		"phase_id": phase_id,
	}
	return out


static func _ok_decision(
		action_type: String,
		skill_id: int,
		slot_index: int,
		reason: String,
		phase_id: String
) -> Dictionary:
	return {
		"ok": true,
		"action_type": action_type,
		"skill_id": skill_id,
		"slot_index": slot_index,
		"reason": reason,
		"phase_id": phase_id,
	}
