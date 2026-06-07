class_name BattleRecordTypes
extends RefCounted

const SCHEMA_VERSION := 1

const UNIT_PLAYER := "player"
const UNIT_ENEMY := "enemy"

const ACTION_SKILL := "skill"
const ACTION_BASIC := "basic"
const ACTION_ITEM := "item"
const ACTION_EQUIP := "equip"
const ACTION_BUFF_TICK := "buff_tick"

const OUTCOME_WIN := "win"
const OUTCOME_LOSS := "loss"
const OUTCOME_DRAW := "draw"

static func opposite_unit(unit_id: String) -> String:
	match unit_id.strip_edges():
		UNIT_PLAYER:
			return UNIT_ENEMY
		UNIT_ENEMY:
			return UNIT_PLAYER
		_:
			return ""

