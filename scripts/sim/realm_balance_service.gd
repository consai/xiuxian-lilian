class_name RealmBalanceService
extends RefCounted

## 数值配置门面：境界系数、属性公式、标杆敌人与平衡验收统一从 data/jingjie_balance.yaml 读取。

const PATH := "res://data/jingjie_balance.yaml"

const DEFAULT_ATTRIBUTE_FORMULA := {
	ZhandouAttr.HP_MAX: {"base": 50.0, "scale": {"body": 5.0}},
	ZhandouAttr.MP_MAX: {"base": 50.0, "scale": {"spirit": 5.0}},
	ZhandouAttr.PHYSICAL_ATK: {"base": 0.0, "scale": {"body": 3.0}},
	ZhandouAttr.MAGIC_ATK: {"base": 0.0, "scale": {"spirit": 2.4, "sense": 0.8}},
	ZhandouAttr.PHYSICAL_DEF: {"base": 0.0, "scale": {"body": 2.0}},
	ZhandouAttr.MAGIC_DEF: {"base": 0.0, "scale": {"spirit": 1.2, "sense": 1.2}},
	ZhandouAttr.SPD: {"base": 50.0, "scale": {"sense": 3.0, "body": 2.0}},
	ZhandouAttr.CONTROL_POWER: {"base": 0.0, "scale": {"sense": 3.0, "spirit": 1.0}},
	ZhandouAttr.CONTROL_RESIST: {"base": 0.0, "scale": {"sense": 2.0, "body": 1.0}},
	ZhandouAttr.HP_REGEN: {"base": 0.5, "scale": {"body": 0.05}},
	ZhandouAttr.MP_REGEN: {"base": 0.5, "scale": {"spirit": 0.04, "sense": 0.01}},
	ZhandouAttr.CARRY: {"base": 20.0, "scale": {"body": 2.0}},
	ZhandouAttr.SHIELD: {"base": 0.0, "scale": {}},
}

const DEFAULT_REALM_FLAT_PER_LAYER := {
	ZhandouAttr.HP_MAX: 6.0,
	ZhandouAttr.MP_MAX: 6.0,
	ZhandouAttr.PHYSICAL_ATK: 1.8,
	ZhandouAttr.MAGIC_ATK: 1.92,
	ZhandouAttr.PHYSICAL_DEF: 1.2,
	ZhandouAttr.MAGIC_DEF: 1.44,
	ZhandouAttr.SPD: 3.0,
}

static var _bundle: Dictionary = {}


static func reload() -> void:
	_bundle = JsonLoader._read_json_root_object(PATH)


static func bundle() -> Dictionary:
	if _bundle.is_empty():
		reload()
	return _bundle


static func build_base_combat_attrs(foundations: Dictionary) -> Dictionary:
	var formula := _formula_table()
	var attrs: Dictionary = {}
	for stat_v in formula.keys():
		var stat := str(stat_v)
		var row_v: Variant = formula[stat_v]
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var value := float(row.get("base", 0.0))
		var scale_v: Variant = row.get("scale", {})
		if scale_v is Dictionary:
			for foundation_key_v in (scale_v as Dictionary).keys():
				var foundation_key := str(foundation_key_v)
				value += float(foundations.get(foundation_key, 0.0)) * float((scale_v as Dictionary)[foundation_key_v])
		attrs[stat] = value
	return attrs


static func realm_flat_modifiers(realm_index: int) -> Dictionary:
	var layer := float(maxi(0, realm_index))
	var out: Dictionary = {}
	var per_layer := _realm_flat_per_layer()
	for stat_v in per_layer.keys():
		out[str(stat_v)] = float(per_layer[stat_v]) * layer
	return out


static func major_realms() -> Array:
	var rows_v: Variant = bundle().get("major_realms", [])
	return (rows_v as Array).duplicate(true) if rows_v is Array else []


static func major_realm_by_id(major_id: String) -> Dictionary:
	var id := major_id.strip_edges()
	for row_v in major_realms():
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == id:
			return (row_v as Dictionary).duplicate(true)
	return {}


static func standard_player(profile_id: String) -> Dictionary:
	var rows := bundle().get("standard_players", {}) as Dictionary
	var row_v: Variant = rows.get(profile_id.strip_edges(), {})
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


static func benchmark_enemy(enemy_id: String) -> Dictionary:
	var rows := bundle().get("benchmark_enemies", {}) as Dictionary
	var row_v: Variant = rows.get(enemy_id.strip_edges(), {})
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


static func benchmark_enemy_attrs(enemy_id: String) -> Dictionary:
	var row := benchmark_enemy(enemy_id)
	var attrs_v: Variant = row.get("attrs", {})
	return (attrs_v as Dictionary).duplicate(true) if attrs_v is Dictionary else {}


## 相对配置表「月修为」换算为「日修为」的倍率（当前为原月增量的 1/10）。
const DAILY_CULTIVATION_GAIN_SCALE := 0.1


static func base_monthly_cultivation_gain(realm_row: Dictionary) -> int:
	var progression := bundle().get("cultivation_progression", {}) as Dictionary
	var table := progression.get("base_monthly_gain_by_realm", {}) as Dictionary
	var major_id := str(realm_row.get("major_realm", "")).strip_edges()
	if major_id == "":
		major_id = str(realm_row.get("id", "")).split("_", false, 1)[0]
	var major_table_v: Variant = table.get(major_id, {})
	if not major_table_v is Dictionary:
		return 20
	var phase := _realm_phase(realm_row)
	var major_table := major_table_v as Dictionary
	return maxi(1, int(major_table.get(phase, major_table.get("single", 20))))


## 闭关按天结算时的境界基础修为（由月配置 × DAILY_CULTIVATION_GAIN_SCALE）。
static func base_daily_cultivation_gain(realm_row: Dictionary) -> int:
	return maxi(1, int(round(float(base_monthly_cultivation_gain(realm_row)) * DAILY_CULTIVATION_GAIN_SCALE)))


static func cultivation_pill_balance() -> Dictionary:
	var progression := bundle().get("cultivation_progression", {}) as Dictionary
	var row_v: Variant = progression.get("cultivation_pill_balance", {})
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


## 道具阶位对应的大境界 id（与 EnumItemTier 一致，配置见 cultivation_pill_balance.tier_major_realm）。
static func major_realm_id_for_item_tier(tier: int) -> String:
	var table := cultivation_pill_balance().get("tier_major_realm", {}) as Dictionary
	var key := str(EnumItemTier.clamp_tier(tier))
	if table.has(key):
		return str(table[key]).strip_edges()
	var realms := major_realms()
	var index := EnumItemTier.clamp_tier(tier) - 1
	if index >= 0 and index < realms.size():
		return str((realms[index] as Dictionary).get("id", "qi")).strip_edges()
	return "qi"


## 修炼丹品质档位：炼丹产物以 id 后缀区分，中品无后缀（练气聚气丹中品 quality 仍为 1）。
static func cultivation_pill_quality_band(item_id: String) -> String:
	var id := item_id.strip_edges()
	if id.ends_with("_Low"):
		return "low"
	if id.ends_with("_High"):
		return "high"
	if id.ends_with("_Supreme"):
		return "supreme"
	return "medium"


static func cultivation_pill_quality_band_multiplier(band: String) -> float:
	var table := cultivation_pill_balance().get("quality_band_multiplier", {}) as Dictionary
	var key := band.strip_edges().to_lower()
	if key == "":
		key = "medium"
	return float(table.get(key, table.get("medium", 1.0)))


## 指定大境界、参考小境界（默认 early）下的修炼丹中品日修为。
static func cultivation_pill_medium_gain(major_realm_id: String, phase: String = "") -> int:
	var balance := cultivation_pill_balance()
	var anchor_realm := str(balance.get("anchor_realm", "qi")).strip_edges()
	var reference_phase := phase.strip_edges()
	if reference_phase == "":
		reference_phase = str(balance.get("reference_phase", "early")).strip_edges()
	var anchor_gain := _major_realm_monthly_gain(anchor_realm, reference_phase)
	var target_gain := _major_realm_monthly_gain(major_realm_id.strip_edges(), reference_phase)
	var anchor_medium := int(balance.get("medium_cultivation_gain", 100))
	if anchor_gain <= 0 or target_gain <= 0:
		return maxi(1, anchor_medium)
	return maxi(1, int(round(float(anchor_medium) * float(target_gain) / float(anchor_gain))))


## 按道具阶位与品质档位计算「丹药炼化」日修为（配置公式落地）。
static func cultivation_pill_gain_for_tier(tier: int, quality_band: String, phase: String = "") -> int:
	var major_id := major_realm_id_for_item_tier(tier)
	var medium := cultivation_pill_medium_gain(major_id, phase)
	var mult := cultivation_pill_quality_band_multiplier(quality_band)
	return maxi(1, int(round(float(medium) * mult)))


## 按物品 id 与阶位计算修炼丹日修为（品质档位由 id 后缀推断）。
static func cultivation_pill_gain_for_item(item_id: String, tier: int, phase: String = "") -> int:
	return cultivation_pill_gain_for_tier(tier, cultivation_pill_quality_band(item_id), phase)


static func acceptance() -> Dictionary:
	var row_v: Variant = bundle().get("acceptance", {})
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


static func encounter_band(band_id: String) -> Dictionary:
	var rows := bundle().get("encounter_bands", {}) as Dictionary
	var row_v: Variant = rows.get(band_id.strip_edges(), {})
	return (row_v as Dictionary).duplicate(true) if row_v is Dictionary else {}


static func build_standard_player_attrs(profile_id: String, include_realm: bool = false) -> Dictionary:
	var row := standard_player(profile_id)
	if row.is_empty():
		return {}
	var foundations_v: Variant = row.get("foundations", {})
	var foundations := foundations_v as Dictionary if foundations_v is Dictionary else {}
	var flat := realm_flat_modifiers(int(row.get("realm_index", 0))) if include_realm else {}
	var attrs := build_base_combat_attrs(foundations)
	for key in flat.keys():
		var stat := str(key)
		attrs[stat] = ZhandouAttr.get_attr(attrs, stat) + float(flat[key])
	for key in ZhandouAttr.ALL_KEYS:
		if not attrs.has(key):
			attrs[key] = ZhandouAttr.get_attr(ZhandouAttr.TEST_DEFAULTS, key, 0.0)
	return attrs


static func collect_config_errors(simulation_realms: Array = []) -> PackedStringArray:
	var errors: PackedStringArray = []
	var root := bundle()
	if root.is_empty():
		errors.append("境界数值配置为空: %s" % PATH)
		return errors
	var major_ids := {}
	for row_v in major_realms():
		if not row_v is Dictionary:
			errors.append("major_realms 包含非对象项")
			continue
		var row := row_v as Dictionary
		var id := str(row.get("id", "")).strip_edges()
		if id == "":
			errors.append("major_realms 存在空 id")
			continue
		if major_ids.has(id):
			errors.append("major_realms ID 重复: %s" % id)
		major_ids[id] = true
		if float(row.get("content_coefficient", 0.0)) <= 0.0:
			errors.append("境界 %s content_coefficient 必须大于 0" % id)
	for realm_v in simulation_realms:
		if not realm_v is Dictionary:
			continue
		var major := str((realm_v as Dictionary).get("major_realm", "")).strip_edges()
		if major != "" and not major_ids.has(major):
			errors.append("simulation.realm %s 引用了未配置的大境界 %s" % [
				str((realm_v as Dictionary).get("id", "")), major,
			])
	for stat in [ZhandouAttr.HP_MAX, ZhandouAttr.MP_MAX, ZhandouAttr.PHYSICAL_ATK, ZhandouAttr.MAGIC_ATK, ZhandouAttr.PHYSICAL_DEF, ZhandouAttr.MAGIC_DEF, ZhandouAttr.SPD]:
		if not _formula_table().has(stat):
			errors.append("combat_attribute_formula 缺少核心属性 %s" % stat)
	for key in ["normal", "elite", "boss"]:
		var band := encounter_band(key)
		if band.is_empty():
			errors.append("encounter_bands 缺少 %s" % key)
		elif float(band.get("strength_min", 0.0)) > float(band.get("strength_max", 0.0)):
			errors.append("encounter_bands.%s strength_min 不得大于 strength_max" % key)
	for profile_id in (root.get("standard_players", {}) as Dictionary).keys():
		var row := standard_player(str(profile_id))
		for foundation_key in ["body", "spirit", "sense", "agility"]:
			if not (row.get("foundations", {}) as Dictionary).has(foundation_key):
				errors.append("standard_players.%s 缺少根基 %s" % [profile_id, foundation_key])
	var pill_balance := cultivation_pill_balance()
	if pill_balance.is_empty():
		errors.append("cultivation_progression 缺少 cultivation_pill_balance")
	elif int(pill_balance.get("medium_cultivation_gain", 0)) <= 0:
		errors.append("cultivation_pill_balance.medium_cultivation_gain 必须大于 0")
	return errors


static func _formula_table() -> Dictionary:
	var table_v: Variant = bundle().get("combat_attribute_formula", {})
	if table_v is Dictionary and not (table_v as Dictionary).is_empty():
		return table_v as Dictionary
	return DEFAULT_ATTRIBUTE_FORMULA.duplicate(true)


static func _realm_flat_per_layer() -> Dictionary:
	var table_v: Variant = bundle().get("realm_flat_per_layer", {})
	if table_v is Dictionary and not (table_v as Dictionary).is_empty():
		return table_v as Dictionary
	return DEFAULT_REALM_FLAT_PER_LAYER.duplicate(true)


static func _realm_phase(realm_row: Dictionary) -> String:
	var id := str(realm_row.get("id", "")).strip_edges()
	if id.ends_with("_early"):
		return "early"
	if id.ends_with("_mid"):
		return "mid"
	if id.ends_with("_late"):
		return "late"
	var parts := id.split("_", false)
	if parts.size() >= 2 and parts[1].is_valid_int():
		var layer := int(parts[1])
		if layer <= 3:
			return "early"
		if layer <= 6:
			return "mid"
		return "late"
	return "single"


static func _major_realm_monthly_gain(major_realm_id: String, phase: String) -> int:
	return base_monthly_cultivation_gain({
		"major_realm": major_realm_id.strip_edges(),
		"id": "%s_%s" % [major_realm_id.strip_edges(), phase.strip_edges()],
	})
