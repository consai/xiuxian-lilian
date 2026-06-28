class_name EnumLilianNodeType
extends RefCounted

enum Type {
	START,
	TRAVEL,
	GATHER,
	RECOVER,
	HAZARD,
	BATTLE,
	ELITE,
	BOSS,
	DECISION,
	REST,
	TREASURE,
}

const ID_START := "start"
const ID_TRAVEL := "travel"
const ID_GATHER := "gather"
const ID_RECOVER := "recover"
const ID_HAZARD := "hazard"
const ID_BATTLE := "battle"
const ID_ELITE := "elite"
const ID_BOSS := "boss"
const ID_DECISION := "decision"
const ID_REST := "rest"
const ID_TREASURE := "treasure"


static func id(type: Type) -> String:
	match type:
		Type.START:
			return ID_START
		Type.TRAVEL:
			return ID_TRAVEL
		Type.GATHER:
			return ID_GATHER
		Type.RECOVER:
			return ID_RECOVER
		Type.HAZARD:
			return ID_HAZARD
		Type.BATTLE:
			return ID_BATTLE
		Type.ELITE:
			return ID_ELITE
		Type.BOSS:
			return ID_BOSS
		Type.DECISION:
			return ID_DECISION
		Type.REST:
			return ID_REST
		Type.TREASURE:
			return ID_TREASURE
		_:
			return ID_TRAVEL


static func label(type_id: String) -> String:
	match type_id:
		ID_START:
			return "启程"
		ID_TRAVEL:
			return "行路"
		ID_GATHER:
			return "采集"
		ID_RECOVER:
			return "休整"
		ID_HAZARD:
			return "险地"
		ID_BATTLE:
			return "战斗"
		ID_ELITE:
			return "精英"
		ID_BOSS:
			return "首领"
		ID_DECISION:
			return "奇遇"
		ID_REST:
			return "休憩"
		ID_TREASURE:
			return "宝藏"
		_:
			return "未知"


static func from_event(event: Dictionary) -> String:
	var event_type := str(event.get("type", "")).strip_edges()
	if str(event.get("mode", "auto")).strip_edges() == "decision":
		return ID_DECISION
	match event_type:
		"gather":
			if bool(event.get("once_per_lilian", false)):
				return ID_TREASURE
			return ID_GATHER
		"recover":
			return ID_RECOVER
		"hazard":
			return ID_HAZARD
		"battle":
			return ID_BATTLE
		"elite":
			return ID_ELITE
		"boss":
			return ID_BOSS
		_:
			return ID_TRAVEL


static func event_types_for(type_id: String) -> PackedStringArray:
	match type_id:
		ID_GATHER, ID_TREASURE:
			return PackedStringArray(["gather"])
		ID_RECOVER, ID_REST:
			return PackedStringArray(["recover"])
		ID_HAZARD:
			return PackedStringArray(["hazard"])
		ID_BATTLE:
			return PackedStringArray(["battle"])
		ID_ELITE:
			return PackedStringArray(["elite"])
		ID_BOSS:
			return PackedStringArray(["boss"])
		ID_DECISION:
			return PackedStringArray(["decision"])
		_:
			return PackedStringArray(["travel"])
