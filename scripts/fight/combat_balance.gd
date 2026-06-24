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


## 战中逃跑：同速基准成功率；玩家 spd 相对场上最快敌人越高越容易脱身。
const ESCAPE_BASE_AT_PARITY := 0.20
const ESCAPE_RATIO_SLOPE := 0.50
const ESCAPE_MIN := 0.08
const ESCAPE_MAX := 0.75
const ESCAPE_ABSOLUTE_MIN := 0.05
const ESCAPE_ABSOLUTE_MAX := 0.92
const ESCAPE_FAIL_PENALTY_PER_TRY := 0.08
const ESCAPE_FAIL_PENALTY_CAP := 0.24
const ESCAPE_CHASE_ATK_RATIO := 0.15


## 由双方速度比与养成加成、连续失败惩罚计算最终成功率。
static func escape_success_chance(
		player_spd: float,
		max_enemy_spd: float,
		bonus_flat: float = 0.0,
		fail_count: int = 0
) -> float:
	var safe_enemy := maxf(SPD_FLOOR, max_enemy_spd)
	var ratio := player_spd / safe_enemy
	var base := clampf(
		ESCAPE_BASE_AT_PARITY + ESCAPE_RATIO_SLOPE * (ratio - 1.0),
		ESCAPE_MIN,
		ESCAPE_MAX
	)
	var retry_penalty := mini(ESCAPE_FAIL_PENALTY_CAP, maxi(0, fail_count) * ESCAPE_FAIL_PENALTY_PER_TRY)
	return clampf(base + bonus_flat - retry_penalty, ESCAPE_ABSOLUTE_MIN, ESCAPE_ABSOLUTE_MAX)


## 逃跑失败时由最快敌人造成的追击伤害（物理攻与法术攻取高）。
static func escape_chase_damage(fastest_enemy_atk: float) -> float:
	return maxf(1.0, floor(maxf(0.0, fastest_enemy_atk) * ESCAPE_CHASE_ATK_RATIO))
