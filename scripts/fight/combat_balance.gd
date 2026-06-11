class_name CombatBalance
extends RefCounted
## 战斗速度：走条固定 100 进度，每帧按当前 spd 实时累计。
##
## T = clamp(T_base * SPD_ref / spd, T_min, T_max)
## 例：spd=100 → 约 1.2s/次；spd=150 → 约 0.8s；spd=50 → 约 2.4s。

const SPD_REF := 100.0
const INTERVAL_BASE_SEC := 1.2
const INTERVAL_MIN_SEC := 0.3
const INTERVAL_MAX_SEC := 12.0
const SPD_FLOOR := 1.0
const ACTION_PROGRESS_MAX := 100.0


static func interval_cap_from_spd(spd: float) -> float:
	var t := INTERVAL_BASE_SEC * SPD_REF / maxf(SPD_FLOOR, spd)
	return clampf(t, INTERVAL_MIN_SEC, INTERVAL_MAX_SEC)


static func interval_cap_for(unit: FightObj) -> float:
	if unit == null:
		return INTERVAL_BASE_SEC
	return interval_cap_from_spd(unit.get_attr(FightObj.ATTR_SPD))


## 每秒累计的行动进度；满条固定为 [constant ACTION_PROGRESS_MAX]。
static func action_progress_rate_from_spd(spd: float) -> float:
	var interval := interval_cap_from_spd(spd)
	return ACTION_PROGRESS_MAX / interval


static func action_progress_rate_for(unit: FightObj) -> float:
	if unit == null:
		return ACTION_PROGRESS_MAX / INTERVAL_BASE_SEC
	return action_progress_rate_from_spd(unit.get_attr(FightObj.ATTR_SPD))
