class_name EnumPlayerAttr
extends RefCounted

## 玩家所有属性键统一枚举，汇总自 ZhandouAttr、CharacterStats、RealmBalanceService。
## 按层级分为：四维根基 → 资质 → 灵根元素 → 战斗面板 → 伤害类型。

# ============================================================
# 四维根基（战斗面板的输入源，由修炼/突破/装备加成）
# ============================================================

const BODY := "roushen"            ## 肉身 — 影响气血上限、物理攻击、物理防御、控制抗性、负重
const SPIRIT := "lingli"           ## 灵力 — 影响法力上限、法术攻击、法术防御、法力回复
const SENSE := "shenshi"           ## 神识 — 影响法术攻击、法术防御、出手速度、控制强度、控制抗性
const AGILITY := "shenfa"          ## 身法 — 影响出手速度

## 四维根基全部键列表
const ALL_FOUNDATION_KEYS: Array[String] = [
	BODY, SPIRIT, SENSE, AGILITY,
]

## 四维根基默认值
const DEFAULT_FOUNDATIONS: Dictionary = {
	BODY: 10.0,
	SPIRIT: 10.0,
	SENSE: 10.0,
	AGILITY: 10.0,
}

## 四维根基显示名
const FOUNDATION_LABELS: Dictionary = {
	BODY: "肉身",
	SPIRIT: "灵力",
	SENSE: "神识",
	AGILITY: "身法",
}

## 旧版兼容键映射（旧键 → 新键）
const LEGACY_FOUNDATION_KEYS: Dictionary = {
	"body": BODY,
	"spirit": SPIRIT,
	"sense": SENSE,
	"agility": AGILITY,
}


# ============================================================
# 资质属性（不直接参与战斗计算，影响修炼效率与事件结果）
# ============================================================

const COMPREHENSION := "comprehension"  ## 悟性 — 影响功法领悟速度、技能学习成功率
const WILL := "will"                    ## 心性 — 影响突破成功率、心魔抗性
const FORTUNE := "fortune"              ## 福缘 — 影响奇遇触发概率、掉落品质
const ROOTS := "roots"                  ## 灵根 — 值为字典 {元素key: 数值(0~100)}，决定功法匹配度

## 资质属性全部键列表
const ALL_APTITUDE_KEYS: Array[String] = [
	COMPREHENSION, WILL, FORTUNE, ROOTS,
]

## 资质属性默认值
const DEFAULT_APTITUDES: Dictionary = {
	COMPREHENSION: 10.0,
	WILL: 10.0,
	FORTUNE: 10.0,
	ROOTS: {"fire": 80.0},
}

## 资质属性显示名
const APTITUDE_LABELS: Dictionary = {
	COMPREHENSION: "悟性",
	WILL: "心性",
	FORTUNE: "福缘",
	ROOTS: "灵根",
}


# ============================================================
# 灵根元素（ROOTS 字典内的子键）
# ============================================================

const ROOT_METAL := "metal"           ## 金灵根
const ROOT_WOOD := "wood"             ## 木灵根
const ROOT_WATER := "water"           ## 水灵根
const ROOT_FIRE := "fire"             ## 火灵根
const ROOT_EARTH := "earth"           ## 土灵根

## 灵根元素全部键列表
const ALL_ROOT_ELEMENT_KEYS: Array[String] = [
	ROOT_METAL, ROOT_WOOD, ROOT_WATER, ROOT_FIRE, ROOT_EARTH,
]

## 灵根元素显示名
const ROOT_ELEMENT_LABELS: Dictionary = {
	ROOT_METAL: "金",
	ROOT_WOOD: "木",
	ROOT_WATER: "水",
	ROOT_FIRE: "火",
	ROOT_EARTH: "土",
}


# ============================================================
# 战斗面板属性（由根基经公式计算 + 装备/Buff 修正）
# ============================================================

const HP_MAX := "hp_max"                      ## 气血上限 — 肉身主导
const MP_MAX := "mp_max"                      ## 法力上限 — 灵力主导
const SHIELD := "shield"                      ## 护盾 — 吸收伤害的临时血量
const SPD := "spd"                            ## 出手速度 — 身法+神识主导，决定行动条速度
const PHYSICAL_ATK := "physical_atk"          ## 物理攻击 — 肉身主导
const MAGIC_ATK := "magic_atk"               ## 法术攻击 — 灵力+神识主导
const PHYSICAL_DEF := "physical_def"          ## 物理防御 — 肉身主导
const MAGIC_DEF := "magic_def"                ## 法术防御 — 灵力+神识主导
const CONTROL_POWER := "control_power"        ## 控制强度 — 神识+灵力主导，延长施加控制时间
const CONTROL_RESIST := "control_resist"      ## 控制抗性 — 肉身+神识主导，缩短被控时间
const HP_REGEN := "hp_regen"                  ## 气血回复 — 肉身主导，每回合自动回复
const MP_REGEN := "mp_regen"                  ## 法力回复 — 灵力+神识主导，每回合自动回复
const CARRY := "carry"                        ## 负重 — 肉身主导，决定背包容量
const DAMAGE_BONUS := "damage_bonus"          ## 伤害加成 — 百分比增伤（加法叠加）
const DAMAGE_TAKEN := "damage_taken"          ## 承受伤害修正 — 百分比易伤（加法叠加，下限-75%）
const COMBAT_MP_RESTORE_2S := "combat_mp_restore_2s"  ## 战斗回蓝/2秒 — 每2秒战斗内自动回蓝量

## 战斗核心必填键（进战校验）
const COMBAT_CORE_KEYS: Array[String] = [
	HP_MAX, MP_MAX,
	PHYSICAL_ATK, MAGIC_ATK, PHYSICAL_DEF, MAGIC_DEF,
	SPD,
]

## 战斗面板全部键列表
const ALL_COMBAT_KEYS: Array[String] = [
	HP_MAX, MP_MAX, SHIELD, SPD,
	PHYSICAL_ATK, MAGIC_ATK, PHYSICAL_DEF, MAGIC_DEF,
	CONTROL_POWER, CONTROL_RESIST, HP_REGEN, MP_REGEN, CARRY,
	DAMAGE_BONUS, COMBAT_MP_RESTORE_2S,
	DAMAGE_TAKEN,
]

## 战斗面板缺省值
const COMBAT_DEFAULTS: Dictionary = {
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

## 战斗面板属性显示名
const COMBAT_LABELS: Dictionary = {
	HP_MAX: "气血上限",
	MP_MAX: "法力上限",
	SHIELD: "护盾",
	SPD: "出手速度",
	PHYSICAL_ATK: "物理攻击",
	MAGIC_ATK: "法术攻击",
	PHYSICAL_DEF: "物理防御",
	MAGIC_DEF: "法术防御",
	CONTROL_POWER: "控制强度",
	CONTROL_RESIST: "控制抗性",
	HP_REGEN: "气血回复",
	MP_REGEN: "法力回复",
	CARRY: "负重",
	DAMAGE_BONUS: "伤害加成",
	DAMAGE_TAKEN: "承受伤害修正",
	COMBAT_MP_RESTORE_2S: "战斗回蓝",
}


# ============================================================
# 伤害类型
# ============================================================

const DAMAGE_PHYSICAL := "physical"   ## 物理伤害 — 受 physical_atk / physical_def 影响
const DAMAGE_MAGIC := "magic"         ## 法术伤害 — 受 magic_atk / magic_def 影响
const DAMAGE_TRUE := "true"           ## 真实伤害 — 无视防御，取物理/法术攻防较高者

## 伤害类型全部键列表
const ALL_DAMAGE_TYPE_KEYS: Array[String] = [
	DAMAGE_PHYSICAL, DAMAGE_MAGIC, DAMAGE_TRUE,
]

## 伤害类型显示名
const DAMAGE_TYPE_LABELS: Dictionary = {
	DAMAGE_PHYSICAL: "物理伤害",
	DAMAGE_MAGIC: "法术伤害",
	DAMAGE_TRUE: "真实伤害",
}


# ============================================================
# 汇总 — 全部玩家属性键（不含伤害类型、不含灵根子元素）
# ============================================================

## 玩家存档中所有顶层属性键（foundations + aptitudes + combat）
const ALL_PLAYER_ATTR_KEYS: Array[String] = (
	ALL_FOUNDATION_KEYS + ALL_APTITUDE_KEYS + ALL_COMBAT_KEYS
)

## 全部属性键 → 中文显示名 总字典
const ALL_LABELS: Dictionary = {
	BODY: "肉身",
	SPIRIT: "灵力",
	SENSE: "神识",
	AGILITY: "身法",
	COMPREHENSION: "悟性",
	WILL: "心性",
	FORTUNE: "福缘",
	ROOTS: "灵根",
	HP_MAX: "气血上限",
	MP_MAX: "法力上限",
	SHIELD: "护盾",
	SPD: "出手速度",
	PHYSICAL_ATK: "物理攻击",
	MAGIC_ATK: "法术攻击",
	PHYSICAL_DEF: "物理防御",
	MAGIC_DEF: "法术防御",
	CONTROL_POWER: "控制强度",
	CONTROL_RESIST: "控制抗性",
	HP_REGEN: "气血回复",
	MP_REGEN: "法力回复",
	CARRY: "负重",
	DAMAGE_BONUS: "伤害加成",
	DAMAGE_TAKEN: "承受伤害修正",
	COMBAT_MP_RESTORE_2S: "战斗回蓝",
}


# ============================================================
# 工具方法
# ============================================================

## 判断是否为四维根基键
static func is_foundation(key: String) -> bool:
	return key in ALL_FOUNDATION_KEYS


## 判断是否为资质键
static func is_aptitude(key: String) -> bool:
	return key in ALL_APTITUDE_KEYS


## 判断是否为战斗面板属性键
static func is_combat_attr(key: String) -> bool:
	return key in ALL_COMBAT_KEYS


## 判断是否为伤害类型键
static func is_damage_type(key: String) -> bool:
	return key in ALL_DAMAGE_TYPE_KEYS


## 获取任意属性键的中文显示名
static func label(key: String) -> String:
	return str(ALL_LABELS.get(key, key))


## 获取灵根元素的中文显示名
static func root_element_label(element_key: String) -> String:
	return str(ROOT_ELEMENT_LABELS.get(element_key, element_key))


## 旧版根基键兼容转换（body → roushen 等）
static func normalize_foundation_key(key: String) -> String:
	var k := key.strip_edges().to_lower()
	return str(LEGACY_FOUNDATION_KEYS.get(k, k))
