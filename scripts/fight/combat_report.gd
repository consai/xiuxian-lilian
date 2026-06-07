class_name CombatReport
extends RefCounted

const KEY_DAMAGE := "damage"
const KEY_RAW_DAMAGE := "raw_damage"
const KEY_HP_DAMAGE := "hp_damage"
const KEY_SHIELD_ABSORBED := "shield_absorbed"
const KEY_IS_CRIT := "is_crit"
const KEY_HEAL := "heal"
const KEY_MP_GAIN := "mp_gain"
const KEY_BUFF_NAMES := "buff_names"
const KEY_BUFF_NAME := "buff_name"


static func empty_fx_report() -> Dictionary:
	return {
		KEY_DAMAGE: 0.0,
		KEY_RAW_DAMAGE: 0.0,
		KEY_HP_DAMAGE: 0.0,
		KEY_IS_CRIT: false,
		KEY_HEAL: 0.0,
		KEY_MP_GAIN: 0.0,
		KEY_SHIELD_ABSORBED: 0.0,
		KEY_BUFF_NAMES: [],
		KEY_BUFF_NAME: "",
	}


static func normalize_report(raw: Dictionary) -> Dictionary:
	var out := empty_fx_report()
	out[KEY_DAMAGE] = float(raw.get(KEY_DAMAGE, raw.get(KEY_RAW_DAMAGE, 0.0)))
	out[KEY_RAW_DAMAGE] = float(raw.get(KEY_RAW_DAMAGE, out[KEY_DAMAGE]))
	out[KEY_HP_DAMAGE] = float(raw.get(KEY_HP_DAMAGE, maxf(0.0, out[KEY_RAW_DAMAGE] - float(raw.get(KEY_SHIELD_ABSORBED, 0.0))))
	)
	out[KEY_IS_CRIT] = bool(raw.get(KEY_IS_CRIT, false))
	out[KEY_HEAL] = float(raw.get(KEY_HEAL, 0.0))
	out[KEY_MP_GAIN] = float(raw.get(KEY_MP_GAIN, 0.0))
	out[KEY_SHIELD_ABSORBED] = float(raw.get(KEY_SHIELD_ABSORBED, 0.0))
	out[KEY_BUFF_NAMES] = raw.get(KEY_BUFF_NAMES, [])
	out[KEY_BUFF_NAME] = str(raw.get(KEY_BUFF_NAME, "")).strip_edges()
	return out
