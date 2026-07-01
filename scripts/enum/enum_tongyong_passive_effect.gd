class_name EnumTongyongPassiveEffect
extends RefCounted

## 通用被动技能 effects[].effectId 枚举。

enum Effect {
	CULTIVATION_SPEED, # 修炼速度
	INJURY_DIAGNOSIS, # 伤势诊断
	APPRAISAL_ACCURACY, # 鉴定精度
	HERB_YIELD, # 灵植产量
	CRAFT_QUALITY, # 炼制品质
	MATERIAL_EFFICIENCY, # 材料效率
	PILL_QUALITY, # 丹药品质
	ALCHEMY_SUCCESS, # 炼丹成功率
	FORMATION_POWER, # 阵法威能
	FORMATION_SETUP_SPEED, # 布阵速度
	TALISMAN_QUALITY, # 符箓品质
	TALISMAN_ACTIVATION_SPEED, # 符箓激活速度
	BEAST_GROWTH, # 灵兽成长
	BEAST_CAPACITY, # 御兽上限
	SPIRIT_VEIN_DETECTION, # 灵脉探查
	RARE_FIND_CHANCE, # 稀有发现概率
	VOID_SURVIVAL, # 虚空生存
	VOID_TRAVEL_SPEED, # 虚空遁行速度
	SETTLEMENT_OUTPUT, # 聚落产出
	GOVERNANCE_EFFICIENCY, # 治理效率
	TRIBULATION_FORECAST, # 天劫预报
	ASCENSION_SUCCESS, # 飞升成功率
}

const LABEL_CULTIVATION_SPEED := "cultivation_speed"
const LABEL_INJURY_DIAGNOSIS := "injury_diagnosis"
const LABEL_APPRAISAL_ACCURACY := "appraisal_accuracy"
const LABEL_HERB_YIELD := "herb_yield"
const LABEL_CRAFT_QUALITY := "craft_quality"
const LABEL_MATERIAL_EFFICIENCY := "material_efficiency"
const LABEL_PILL_QUALITY := "pill_quality"
const LABEL_ALCHEMY_SUCCESS := "alchemy_success"
const LABEL_FORMATION_POWER := "formation_power"
const LABEL_FORMATION_SETUP_SPEED := "formation_setup_speed"
const LABEL_TALISMAN_QUALITY := "talisman_quality"
const LABEL_TALISMAN_ACTIVATION_SPEED := "talisman_activation_speed"
const LABEL_BEAST_GROWTH := "beast_growth"
const LABEL_BEAST_CAPACITY := "beast_capacity"
const LABEL_SPIRIT_VEIN_DETECTION := "spirit_vein_detection"
const LABEL_RARE_FIND_CHANCE := "rare_find_chance"
const LABEL_VOID_SURVIVAL := "void_survival"
const LABEL_VOID_TRAVEL_SPEED := "void_travel_speed"
const LABEL_SETTLEMENT_OUTPUT := "settlement_output"
const LABEL_GOVERNANCE_EFFICIENCY := "governance_efficiency"
const LABEL_TRIBULATION_FORECAST := "tribulation_forecast"
const LABEL_ASCENSION_SUCCESS := "ascension_success"

const ALL_LABELS: Array[String] = [
	LABEL_CULTIVATION_SPEED,
	LABEL_INJURY_DIAGNOSIS,
	LABEL_APPRAISAL_ACCURACY,
	LABEL_HERB_YIELD,
	LABEL_CRAFT_QUALITY,
	LABEL_MATERIAL_EFFICIENCY,
	LABEL_PILL_QUALITY,
	LABEL_ALCHEMY_SUCCESS,
	LABEL_FORMATION_POWER,
	LABEL_FORMATION_SETUP_SPEED,
	LABEL_TALISMAN_QUALITY,
	LABEL_TALISMAN_ACTIVATION_SPEED,
	LABEL_BEAST_GROWTH,
	LABEL_BEAST_CAPACITY,
	LABEL_SPIRIT_VEIN_DETECTION,
	LABEL_RARE_FIND_CHANCE,
	LABEL_VOID_SURVIVAL,
	LABEL_VOID_TRAVEL_SPEED,
	LABEL_SETTLEMENT_OUTPUT,
	LABEL_GOVERNANCE_EFFICIENCY,
	LABEL_TRIBULATION_FORECAST,
	LABEL_ASCENSION_SUCCESS,
]


static func is_valid_label(text: String) -> bool:
	return text.strip_edges() in ALL_LABELS


static func label(effect_id: String) -> String:
	match effect_id.strip_edges():
		LABEL_CULTIVATION_SPEED:
			return "修炼速度"
		LABEL_INJURY_DIAGNOSIS:
			return "伤势诊断"
		LABEL_APPRAISAL_ACCURACY:
			return "鉴定精度"
		LABEL_HERB_YIELD:
			return "灵植产量"
		LABEL_CRAFT_QUALITY:
			return "炼制品质"
		LABEL_MATERIAL_EFFICIENCY:
			return "材料效率"
		LABEL_PILL_QUALITY:
			return "丹药品质"
		LABEL_ALCHEMY_SUCCESS:
			return "炼丹成功率"
		LABEL_FORMATION_POWER:
			return "阵法威能"
		LABEL_FORMATION_SETUP_SPEED:
			return "布阵速度"
		LABEL_TALISMAN_QUALITY:
			return "符箓品质"
		LABEL_TALISMAN_ACTIVATION_SPEED:
			return "符箓激活速度"
		LABEL_BEAST_GROWTH:
			return "灵兽成长"
		LABEL_BEAST_CAPACITY:
			return "御兽上限"
		LABEL_SPIRIT_VEIN_DETECTION:
			return "灵脉探查"
		LABEL_RARE_FIND_CHANCE:
			return "稀有发现概率"
		LABEL_VOID_SURVIVAL:
			return "虚空生存"
		LABEL_VOID_TRAVEL_SPEED:
			return "虚空遁行速度"
		LABEL_SETTLEMENT_OUTPUT:
			return "聚落产出"
		LABEL_GOVERNANCE_EFFICIENCY:
			return "治理效率"
		LABEL_TRIBULATION_FORECAST:
			return "天劫预报"
		LABEL_ASCENSION_SUCCESS:
			return "飞升成功率"
		_:
			return ""
