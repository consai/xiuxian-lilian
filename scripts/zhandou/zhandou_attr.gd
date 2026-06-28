class_name ZhandouAttr
extends RefCounted
## 战斗属性：键名约定、面板初始化/合并、Buff 修正与伤害公式。
## [ZhandouObj] 持有运行时 [member ZhandouObj.attrs] 字典；本类负责生成与演算。

const HP_MAX := "hp_max"
const MP_MAX := "mp_max"
const SHIELD := "shield"
const SPD := "spd"
const PHYSICAL_ATK := "physical_atk"
const MAGIC_ATK := "magic_atk"
const PHYSICAL_DEF := "physical_def"
const MAGIC_DEF := "magic_def"
const CONTROL_POWER := "control_power"
const CONTROL_RESIST := "control_resist"
const HP_REGEN := "hp_regen"
const MP_REGEN := "mp_regen"
const CARRY := "carry"
const DAMAGE_BONUS := "damage_bonus"
const DAMAGE_TAKEN := "damage_taken"
const COMBAT_MP_RESTORE_2S := "combat_mp_restore_2s"

const DAMAGE_PHYSICAL := "physical"
const DAMAGE_MAGIC := "magic"
const DAMAGE_TRUE := "true"
const DEFENSE_CONSTANT := 100.0

## 进战校验必填（与 [ZhandouInitData] 一致）。
const CORE_KEYS: Array[String] = [
	HP_MAX, MP_MAX, PHYSICAL_ATK, MAGIC_ATK, PHYSICAL_DEF, MAGIC_DEF, SPD,
]

const ALL_KEYS: Array[String] = [
	HP_MAX, MP_MAX, SHIELD, SPD,
	PHYSICAL_ATK, MAGIC_ATK, PHYSICAL_DEF, MAGIC_DEF,
	CONTROL_POWER, CONTROL_RESIST, HP_REGEN, MP_REGEN, CARRY,
	DAMAGE_BONUS, COMBAT_MP_RESTORE_2S,
	DAMAGE_TAKEN,
]

const TEST_DEFAULTS: Dictionary = {
	HP_MAX: 100.0,
	MP_MAX: 100.0,
	SHIELD: 0.0,
	SPD: 100.0,
	PHYSICAL_ATK: 100.0,
	MAGIC_ATK: 100.0,
	PHYSICAL_DEF: 100.0,
	MAGIC_DEF: 100.0,
	CONTROL_POWER: 100.0,
	CONTROL_RESIST: 100.0,
	HP_REGEN: 0.0,
	MP_REGEN: 0.0,
	CARRY: 0.0,
	DAMAGE_BONUS: 0.0,
	DAMAGE_TAKEN: 0.0,
	COMBAT_MP_RESTORE_2S: 0.0,
}


static func test_defaults() -> Dictionary:
	return TEST_DEFAULTS.duplicate(true)


## 由显式数值块生成完整 attrs（缺省键用 [method test_defaults] 补齐）。
static func from_stat_block(block: Dictionary, fill_missing: bool = true) -> Dictionary:
	var base := test_defaults() if fill_missing else {}
	return merge(base, block)


## 叠加一层属性；[param overlay] 中非数值键也会被写入（与 [ZhandouObj._merge_attrs] 一致）。
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


## 按 Buff [code]modifiers[/code] 叠层修正（加法，与 [code]data/buff.yaml[/code] 示例一致）。
static func apply_modifiers(attrs: Dictionary, modifiers: Dictionary, stacks: int = 1) -> Dictionary:
	if modifiers.is_empty() or stacks == 0:
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
	attrs[SPD] = maxf(ZhandouBalance.SPD_FLOOR, base * factor)


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


static func damage_after_defense(raw_damage: float, defense: float) -> float:
	var safe_def := maxf(0.0, defense)
	var reduction := safe_def / (safe_def + DEFENSE_CONSTANT)
	return maxf(1.0, raw_damage * (1.0 - reduction))


static func attack_for(attrs: Dictionary, damage_type: String) -> float:
	if damage_type == DAMAGE_MAGIC:
		return get_attr(attrs, MAGIC_ATK)
	if damage_type == DAMAGE_TRUE:
		return maxf(get_attr(attrs, PHYSICAL_ATK), get_attr(attrs, MAGIC_ATK))
	return get_attr(attrs, PHYSICAL_ATK)


static func defense_for(attrs: Dictionary, damage_type: String) -> float:
	if damage_type == DAMAGE_MAGIC:
		return get_attr(attrs, MAGIC_DEF)
	if damage_type == DAMAGE_TRUE:
		return 0.0
	return get_attr(attrs, PHYSICAL_DEF)


## 普攻使用物理攻防与软减伤。
static func calc_basic_damage(attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var raw := attack_for(attacker, DAMAGE_PHYSICAL)
	var dmg := damage_after_defense(raw, defense_for(defender, DAMAGE_PHYSICAL))
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	return {"damage": dmg, "damage_type": DAMAGE_PHYSICAL}


## 技能伤害段： [code]max(1, atk * power_scale + flat - def)[/code]。
static func calc_skill_damage(
		attacker: Dictionary,
		defender: Dictionary,
		power_scale: float,
		flat_bonus: float,
		damage_type: String = DAMAGE_MAGIC,
		armor_pierce: float = 0.0
) -> Dictionary:
	var resolved_type := resolve_damage_type(damage_type)
	var raw := attack_for(attacker, resolved_type) * power_scale + flat_bonus
	var dmg := maxf(1.0, raw)
	if resolved_type != DAMAGE_TRUE:
		var effective_defense := defense_for(defender, resolved_type) * (1.0 - clampf(armor_pierce, 0.0, 0.7))
		dmg = damage_after_defense(raw, effective_defense)
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	dmg *= 1.0 + maxf(-0.75, get_attr(defender, DAMAGE_TAKEN, 0.0))
	return {"damage": dmg, "damage_type": resolved_type}


## 意图预览：按期望伤害估算，避免随机波动。
static func estimate_basic_damage(attacker: Dictionary, defender: Dictionary) -> float:
	var raw := attack_for(attacker, DAMAGE_PHYSICAL)
	var dmg := damage_after_defense(raw, defense_for(defender, DAMAGE_PHYSICAL))
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	return maxf(0.0, dmg)


static func estimate_skill_damage(
		attacker: Dictionary,
		defender: Dictionary,
		power_scale: float,
		flat_bonus: float,
		damage_type: String = DAMAGE_MAGIC,
		armor_pierce: float = 0.0
) -> float:
	var resolved_type := resolve_damage_type(damage_type)
	var raw := attack_for(attacker, resolved_type) * power_scale + flat_bonus
	var dmg := maxf(1.0, raw)
	if resolved_type != DAMAGE_TRUE:
		var effective_defense := defense_for(defender, resolved_type) * (1.0 - clampf(armor_pierce, 0.0, 0.7))
		dmg = damage_after_defense(raw, effective_defense)
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	dmg *= 1.0 + maxf(-0.75, get_attr(defender, DAMAGE_TAKEN, 0.0))
	return maxf(0.0, dmg)


static func resolve_damage_type(damage_type: String) -> String:
	var normalized := damage_type.strip_edges().to_lower()
	if normalized == DAMAGE_PHYSICAL:
		return DAMAGE_PHYSICAL
	if normalized == DAMAGE_TRUE:
		return DAMAGE_TRUE
	return DAMAGE_MAGIC
