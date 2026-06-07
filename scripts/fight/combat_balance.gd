class_name CombatBalance
extends RefCounted
## 战斗数值常数（欧美式面板：atk/def/spd 同量级，spd 映射出手间隔秒数）。
##
## T = clamp(T_base * SPD_ref / spd, T_min, T_max)
## 例：spd=100 → 约 3.0s/刀；spd=150 → 约 2.0s；spd=50 → 约 6.0s。

const SPD_REF := 100.0
const INTERVAL_BASE_SEC := 3.0
const INTERVAL_MIN_SEC := 0.8
const INTERVAL_MAX_SEC := 12.0
const SPD_FLOOR := 1.0


static func interval_cap_from_spd(spd: float) -> float:
	var t := INTERVAL_BASE_SEC * SPD_REF / maxf(SPD_FLOOR, spd)
	return clampf(t, INTERVAL_MIN_SEC, INTERVAL_MAX_SEC)


static func interval_cap_for(unit: FightObj) -> float:
	if unit == null:
		return INTERVAL_BASE_SEC
	return interval_cap_from_spd(unit.get_attr(FightObj.ATTR_SPD))
