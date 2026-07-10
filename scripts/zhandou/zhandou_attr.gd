class_name ZhandouAttr
extends RefCounted
## 战斗属性：键名约定、面板初始化/合并、Buff 修正与伤害公式。
## [ZhandouObj] 持有运行时 [member ZhandouObj.attrs] 字典；本类负责生成与演算。
## 属性键常量委托给 [EnumPlayerAttr] 统一管理。

const HP_MAX := EnumPlayerAttr.HP_MAX
const MP_MAX := EnumPlayerAttr.MP_MAX
const SHIELD := EnumPlayerAttr.SHIELD
const SPD := EnumPlayerAttr.SPD
const PHYSICAL_ATK := EnumPlayerAttr.PHYSICAL_ATK
const MAGIC_ATK := EnumPlayerAttr.MAGIC_ATK
const PHYSICAL_DEF := EnumPlayerAttr.PHYSICAL_DEF
const MAGIC_DEF := EnumPlayerAttr.MAGIC_DEF
const CONTROL_POWER := EnumPlayerAttr.CONTROL_POWER
const CONTROL_RESIST := EnumPlayerAttr.CONTROL_RESIST
const HP_REGEN := EnumPlayerAttr.HP_REGEN
const MP_REGEN := EnumPlayerAttr.MP_REGEN
const CARRY := EnumPlayerAttr.CARRY
const DAMAGE_BONUS := EnumPlayerAttr.DAMAGE_BONUS
const DAMAGE_TAKEN := EnumPlayerAttr.DAMAGE_TAKEN
const COMBAT_MP_RESTORE_2S := EnumPlayerAttr.COMBAT_MP_RESTORE_2S

const DAMAGE_PHYSICAL := EnumPlayerAttr.DAMAGE_PHYSICAL
const DAMAGE_MAGIC := EnumPlayerAttr.DAMAGE_MAGIC
const DAMAGE_TRUE := EnumPlayerAttr.DAMAGE_TRUE

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
	return heti(base, block)


## 叠加一层属性；[param overlay] 中非数值键也会被写入（与 [ZhandouObj._merge_attrs] 一致）。
static func heti(base: Dictionary, overlay: Dictionary) -> Dictionary:
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


## 按 Buff [code]modifiers[/code] 叠层修正（加法）。
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


static func damage_after_attack_defense(raw_damage: float, attack: float, defense: float) -> float:
	var safe_attack := maxf(0.0, attack)
	var safe_defense := maxf(0.0, defense)
	if safe_attack <= 0.0:
		return 0.0
	return maxf(1.0, raw_damage * safe_attack / maxf(1.0, safe_attack + safe_defense))


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
	var attack := attack_for(attacker, DAMAGE_PHYSICAL)
	var dmg := damage_after_attack_defense(attack, attack, defense_for(defender, DAMAGE_PHYSICAL))
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	return {"damage": dmg, "damage_type": DAMAGE_PHYSICAL}


## 技能伤害段：伤害值 × 攻击 / (攻击 + 防御)。
static func calc_skill_damage(
		attacker: Dictionary,
		defender: Dictionary,
		effect_value: float,
		damage_type: String = DAMAGE_MAGIC,
		armor_pierce: float = 0.0
) -> Dictionary:
	var resolved_type := resolve_damage_type(damage_type)
	var raw := effect_value
	var dmg := maxf(1.0, raw)
	if resolved_type != DAMAGE_TRUE:
		var attack := attack_for(attacker, resolved_type)
		var effective_defense := defense_for(defender, resolved_type) * (1.0 - clampf(armor_pierce, 0.0, 0.7))
		dmg = damage_after_attack_defense(raw, attack, effective_defense)
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	dmg *= 1.0 + maxf(-0.75, get_attr(defender, DAMAGE_TAKEN, 0.0))
	return {"damage": dmg, "damage_type": resolved_type}

static func control_duration_after_resist(base_duration: float, control_power: float, control_resist: float) -> float:
	var power := maxf(0.0, control_power)
	if power <= 0.0:
		return 0.0
	return maxf(0.0, base_duration) * power / maxf(1.0, power + maxf(0.0, control_resist))

static func calc_tiaoxi_mp_restore(attrs: Dictionary) -> float:
	var regen: float = maxf(0.0, get_attr(attrs, MP_REGEN, 0.0))
	return regen * ZhandouBalance.TIAOXI_MP_REGEN_MULTIPLIER


static func estimate_tiaoxi_mp_restore(attrs: Dictionary) -> float:
	return calc_tiaoxi_mp_restore(attrs)


## 意图预览：按期望伤害估算，避免随机波动。
static func estimate_basic_damage(attacker: Dictionary, defender: Dictionary) -> float:
	var attack := attack_for(attacker, DAMAGE_PHYSICAL)
	var dmg := damage_after_attack_defense(attack, attack, defense_for(defender, DAMAGE_PHYSICAL))
	dmg *= 1.0 + maxf(0.0, get_attr(attacker, DAMAGE_BONUS, 0.0))
	return maxf(0.0, dmg)


static func estimate_skill_damage(
		attacker: Dictionary,
		defender: Dictionary,
		effect_value: float,
		damage_type: String = DAMAGE_MAGIC,
		armor_pierce: float = 0.0
) -> float:
	var resolved_type := resolve_damage_type(damage_type)
	var raw := effect_value
	var dmg := maxf(1.0, raw)
	if resolved_type != DAMAGE_TRUE:
		var attack := attack_for(attacker, resolved_type)
		var effective_defense := defense_for(defender, resolved_type) * (1.0 - clampf(armor_pierce, 0.0, 0.7))
		dmg = damage_after_attack_defense(raw, attack, effective_defense)
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
