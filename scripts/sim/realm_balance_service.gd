class_name RealmBalanceService
extends RefCounted

## 数值配置门面：境界系数、属性公式、标杆敌人与平衡验收统一从 data/realm_balance.json 读取。

const PATH := "res://data/realm_balance.json"

const DEFAULT_ATTRIBUTE_FORMULA := {
	FightAttr.HP_MAX: {"base": 50.0, "scale": {"body": 5.0}},
	FightAttr.MP_MAX: {"base": 50.0, "scale": {"spirit": 5.0}},
	FightAttr.PHYSICAL_ATK: {"base": 0.0, "scale": {"body": 3.0}},
	FightAttr.MAGIC_ATK: {"base": 0.0, "scale": {"spirit": 2.4, "sense": 0.8}},
	FightAttr.PHYSICAL_DEF: {"base": 0.0, "scale": {"body": 2.0}},
	FightAttr.MAGIC_DEF: {"base": 0.0, "scale": {"spirit": 1.2, "sense": 1.2}},
	FightAttr.SPD: {"base": 50.0, "scale": {"sense": 3.0, "body": 2.0}},
	FightAttr.ACCURACY: {"base": 50.0, "scale": {"sense": 3.0, "agility": 1.0}},
	FightAttr.EVASION: {"base": 50.0, "scale": {"agility": 3.0, "sense": 1.0}},
	FightAttr.CONTROL_POWER: {"base": 0.0, "scale": {"sense": 3.0, "spirit": 1.0}},
	FightAttr.CONTROL_RESIST: {"base": 0.0, "scale": {"sense": 2.0, "body": 1.0}},
	FightAttr.HP_REGEN: {"base": 0.5, "scale": {"body": 0.05}},
	FightAttr.MP_REGEN: {"base": 0.5, "scale": {"spirit": 0.04, "sense": 0.01}},
	FightAttr.CARRY: {"base": 20.0, "scale": {"body": 2.0}},
	FightAttr.SHIELD: {"base": 0.0, "scale": {}},
	FightAttr.CRIT: {"base": 10.0, "scale": {}},
	FightAttr.CRIT_DAMAGE: {"base": 150.0, "scale": {}},
}

const DEFAULT_REALM_FLAT_PER_LAYER := {
	FightAttr.HP_MAX: 6.0,
	FightAttr.MP_MAX: 6.0,
	FightAttr.PHYSICAL_ATK: 1.8,
	FightAttr.MAGIC_ATK: 1.92,
	FightAttr.PHYSICAL_DEF: 1.2,
	FightAttr.MAGIC_DEF: 1.44,
	FightAttr.SPD: 3.0,
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
		attrs[stat] = FightAttr.get_attr(attrs, stat) + float(flat[key])
	for key in FightAttr.ALL_KEYS:
		if not attrs.has(key):
			attrs[key] = FightAttr.get_attr(FightAttr.TEST_DEFAULTS, key, 0.0)
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
	for stat in [FightAttr.HP_MAX, FightAttr.MP_MAX, FightAttr.PHYSICAL_ATK, FightAttr.MAGIC_ATK, FightAttr.PHYSICAL_DEF, FightAttr.MAGIC_DEF, FightAttr.SPD]:
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
