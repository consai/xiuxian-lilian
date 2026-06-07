class_name FightAttr
extends RefCounted
## 战斗属性：键名约定、面板初始化/合并、Buff 修正与伤害公式。
## [FightObj] 持有运行时 [member FightObj.attrs] 字典；本类负责生成与演算。

const HP_MAX := "hp_max"
const MP_MAX := "mp_max"
const SHIELD := "shield"
const ATK := "atk"
const DEF := "def"
const SPD := "spd"
const CRIT := "crit"
const CRIT_DAMAGE := "crit_damage"

## 进战校验必填（与 [BattleInitData] 一致）。
const CORE_KEYS: Array[String] = [HP_MAX, MP_MAX, ATK, DEF, SPD]

const ALL_KEYS: Array[String] = [
	HP_MAX, MP_MAX, SHIELD, ATK, DEF, SPD, CRIT, CRIT_DAMAGE,
]

const TEST_DEFAULTS: Dictionary = {
	HP_MAX: 100.0,
	MP_MAX: 100.0,
	SHIELD: 0.0,
	ATK: 100.0,
	DEF: 100.0,
	SPD: 100.0,
	CRIT: 100.0,
	CRIT_DAMAGE: 100.0,
}


static func test_defaults() -> Dictionary:
	return TEST_DEFAULTS.duplicate(true)


## 由显式数值块生成完整 attrs（缺省键用 [method test_defaults] 补齐）。
static func from_stat_block(block: Dictionary, fill_missing: bool = true) -> Dictionary:
	var base := test_defaults() if fill_missing else {}
	return merge(base, block)


## 叠加一层属性；[param overlay] 中非数值键也会被写入（与 [FightObj._merge_attrs] 一致）。
static func merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in overlay.keys():
		out[str(k)] = overlay[k]
	return out


## 读取单条属性为 float（勿命名为 [code]get[/code]，避免遮蔽 [Object.get]）。
static func get_attr(attrs: Dictionary, key: String, default_value: float = 0.0) -> float:
	var k := key.strip_edges()
	if k == "":
		return default_value
	var raw: Variant = attrs.get(k, default_value)
	if raw is int:
		return float(raw)
	if raw is float:
		return raw
	return float(raw)


## 校验是否包含 [member CORE_KEYS]。
static func validate_core(attrs: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	for ak in CORE_KEYS:
		if not attrs.has(ak):
			errors.append("attrs 缺少 '%s'" % ak)
	return errors


## 按 Buff [code]modifiers[/code] 叠层修正（加法，与 [code]data/buff.json[/code] 示例一致）。
static func apply_modifiers(attrs: Dictionary, modifiers: Dictionary, stacks: int = 1) -> Dictionary:
	if modifiers.is_empty() or stacks <= 0:
		return attrs.duplicate(true)
	var mult := float(stacks)
	var out := attrs.duplicate(true)
	for k in modifiers.keys():
		var key := str(k).strip_edges()
		if key == "":
			continue
		var delta_v: Variant = modifiers[k]
		if not (delta_v is int or delta_v is float):
			continue
		var cur := get_attr(out, key, 0.0)
		out[key] = cur + float(delta_v) * mult
	return out


## 进战速度浮动：在 [param ratio] 比例内随机（例 ratio=0.05 → 0.95~1.05）。
static func apply_spd_jitter(attrs: Dictionary, ratio: float) -> void:
	if ratio <= 0.0 or not attrs.has(SPD):
		return
	var base := get_attr(attrs, SPD)
	var factor := randf_range(1.0 - ratio, 1.0 + ratio)
	attrs[SPD] = maxf(CombatBalance.SPD_FLOOR, base * factor)


## 由 attrs 推导当前气血/法力初值（满血满蓝进战）。
static func vitals_from_attrs(attrs: Dictionary) -> Dictionary:
	return {
		"hp": maxf(1.0, get_attr(attrs, HP_MAX, 1.0)),
		"mp": maxf(0.0, get_attr(attrs, MP_MAX, 0.0)),
	}


## 构造一方进战 [code]player[/code]/[code]enemy[/code] 行（含 hp/mp/attrs/skills）。
static func build_combatant_row(
		attrs: Dictionary,
		skills: Dictionary = {},
		items: Dictionary = {},
		hp: float = -1.0,
		mp: float = -1.0
) -> Dictionary:
	var vitals := vitals_from_attrs(attrs)
	var row := {
		"hp": vitals["hp"] if hp < 0.0 else hp,
		"mp": vitals["mp"] if mp < 0.0 else mp,
		"attrs": attrs.duplicate(true),
		"skills": skills.duplicate(true),
	}
	if not items.is_empty():
		row["items"] = items.duplicate(true)
	return row


static func roll_crit(crit_rate_percent: float) -> bool:
	var rate := clampf(crit_rate_percent / 100.0, 0.0, 1.0)
	return randf() < rate


static func apply_crit_multiplier(damage: float, crit_damage_percent: float, is_crit: bool) -> float:
	if not is_crit:
		return damage
	return damage * maxf(1.0, crit_damage_percent / 100.0)


## 普攻： [code]max(1, atk - def)[/code]，可暴击。
static func calc_basic_damage(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var dmg := maxf(1.0, get_attr(attacker, ATK) - get_attr(defender, DEF))
	var crit := roll_crit(get_attr(attacker, CRIT))
	dmg = apply_crit_multiplier(dmg, get_attr(attacker, CRIT_DAMAGE), crit)
	return {"damage": dmg, "is_crit": crit}


## 技能伤害段： [code]max(1, atk * power_scale + flat - def)[/code]。
static func calc_skill_damage(
		attacker: Dictionary,
		defender: Dictionary,
		power_scale: float,
		flat_bonus: float
) -> Dictionary:
	var raw := get_attr(attacker, ATK) * power_scale + flat_bonus
	var dmg := maxf(1.0, raw - get_attr(defender, DEF))
	var crit := roll_crit(get_attr(attacker, CRIT))
	dmg = apply_crit_multiplier(dmg, get_attr(attacker, CRIT_DAMAGE), crit)
	return {"damage": dmg, "is_crit": crit}
