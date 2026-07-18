extends SceneTree

const CatalogScript := preload("res://scripts/features/cultivation/infrastructure/realm_balance_catalog.gd")
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _errors: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.print_error_messages = false
	_normal_snapshot_and_formula_anchor()
	_deep_copy_and_atomic_rejection()
	_invalid_roots_rows_and_references()
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		quit(1)
		return
	print("PASS: realm balance catalog")
	quit(0)


func _normal_snapshot_and_formula_anchor() -> void:
	var catalog := CatalogScript.new()
	_check(catalog.reload(), "catalog must load the eight balance tables")
	var bundle := catalog.bundle()
	_check((bundle.get("major_realms", []) as Array).size() == 9, "major realm count changed")
	_check((bundle.get("standard_players", {}) as Dictionary).size() == 3, "standard player count changed")
	_check((bundle.get("benchmark_enemies", {}) as Dictionary).size() == 3, "benchmark enemy count changed")
	_check((bundle.get("encounter_bands", {}) as Dictionary).size() == 3, "encounter band count changed")
	_check((bundle.get("combat_attribute_formula", {}) as Dictionary).size() == 13, "combat formula count changed")
	var progression := bundle.get("cultivation_progression", {}) as Dictionary
	_check((progression.get("base_monthly_gain_by_realm", {}) as Dictionary).get("lianqi", {}) is Dictionary,
		"nested monthly gains must decode")
	_check((progression.get("cultivation_pill_balance", {}) as Dictionary).get("tier_major_realm", {}) is Dictionary,
		"nested pill tiers must decode")
	_check(RealmBalanceServiceScript.base_monthly_cultivation_gain({"major_realm": "lianqi", "level": 1}) == 30,
		"lianqi early monthly gain anchor changed")
	_check(RealmBalanceServiceScript.cultivation_pill_gain_for_tier(1, "medium") == 100,
		"lianqi medium pill anchor changed")


func _deep_copy_and_atomic_rejection() -> void:
	var catalog := CatalogScript.new()
	_check(catalog.reload(), "catalog must load before copy test")
	var valid := catalog.bundle()
	((valid.get("combat_attribute_formula", {}) as Dictionary).get("hp_max", {}) as Dictionary)["base"] = -1
	_check(float(((catalog.bundle().get("combat_attribute_formula", {}) as Dictionary).get("hp_max", {}) as Dictionary).get("base", -1)) == 50.0,
		"bundle query must return a deep copy")
	var realm_rows := catalog.major_realms()
	(realm_rows[0] as Dictionary)["name"] = "mutated"
	_check(str((catalog.major_realms()[0] as Dictionary).get("name", "")) != "mutated",
		"major realm query must return a deep copy")
	valid = catalog.bundle()
	var invalid: Dictionary = _copy_bundle(valid)
	invalid["cultivation_progression"] = {}
	_check(not catalog.reload_from_bundle(invalid), "invalid candidate must be rejected")
	var first_errors := catalog.collect_errors()
	_check(not first_errors.is_empty(), "rejection must expose stable errors")
	_check(not catalog.reload_from_bundle(invalid), "repeated invalid candidate must fail")
	_check(catalog.collect_errors() == first_errors, "repeated rejection errors must be stable")
	_check(catalog.major_realms().size() == 9, "failed reload must retain old valid snapshot")
	var empty_catalog := CatalogScript.new()
	_check(not empty_catalog.reload_from_raw_roots({}), "first invalid raw roots must fail")
	_check(empty_catalog.bundle().is_empty(), "first failure must expose no snapshot")


func _invalid_roots_rows_and_references() -> void:
	var catalog := CatalogScript.new()
	var raw_roots := _load_raw_roots()
	_check(catalog.reload_from_raw_roots(raw_roots), "raw roots fixture must decode and validate")
	var valid := catalog.bundle()
	var bad_root: Dictionary = _copy_bundle(raw_roots)
	bad_root["major_realms"] = []
	_check(not catalog.reload_from_raw_roots(bad_root), "raw table non-object root must fail")
	var bad_row: Dictionary = _copy_bundle(raw_roots)
	(bad_row.get("combat_attribute_formula", {}) as Dictionary)["hp_max"] = "invalid"
	_check(not catalog.reload_from_raw_roots(bad_row), "invalid raw row must fail")
	var bad_reference: Dictionary = _copy_bundle(valid)
	var tier_realms := ((bad_reference.get("cultivation_progression", {}) as Dictionary) \
		.get("cultivation_pill_balance", {}) as Dictionary).get("tier_major_realm", {}) as Dictionary
	tier_realms["1"] = "unknown"
	_check(not catalog.reload_from_bundle(bad_reference), "pill tier realm reference must fail")
	var bad_contract: Dictionary = _copy_bundle(valid)
	(bad_contract.get("acceptance", {}) as Dictionary).erase("normal_win_rate_min")
	var foundations := ((bad_contract.get("standard_players", {}) as Dictionary) \
		.get("lianqi_early", {}) as Dictionary).get("foundations", {}) as Dictionary
	foundations["body"] = "not-a-number"
	_check(not catalog.reload_from_bundle(bad_contract), "missing required key and non-number must fail")
	var contract_errors := catalog.collect_errors()
	_check(_contains_error(contract_errors, "required_key_missing"), "missing required key error must be explicit")
	_check(_contains_error(contract_errors, "nested_number_invalid"), "nested non-number error must be explicit")
	_check(not catalog.reload_from_bundle(bad_contract), "repeated contract failure must fail")
	_check(catalog.collect_errors() == contract_errors, "contract validation errors must be stable")
	_check(catalog.bundle() == valid, "all failed candidates must retain the prior snapshot")


func _load_raw_roots() -> Dictionary:
	return {
		"acceptance": JsonReaderScript.read_variant(CatalogScript.ACCEPTANCE_PATH),
		"benchmark_enemies": JsonReaderScript.read_variant(CatalogScript.BENCHMARK_ENEMIES_PATH),
		"budgets": JsonReaderScript.read_variant(CatalogScript.BUDGETS_PATH),
		"combat_attribute_formula": JsonReaderScript.read_variant(CatalogScript.COMBAT_ATTRIBUTE_FORMULA_PATH),
		"cultivation_progression": JsonReaderScript.read_variant(CatalogScript.CULTIVATION_PROGRESSION_PATH),
		"encounter_bands": JsonReaderScript.read_variant(CatalogScript.ENCOUNTER_BANDS_PATH),
		"major_realms": JsonReaderScript.read_variant(CatalogScript.MAJOR_REALMS_PATH),
		"standard_players": JsonReaderScript.read_variant(CatalogScript.STANDARD_PLAYERS_PATH),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)


func _contains_error(errors: PackedStringArray, code: String) -> bool:
	for message in errors:
		if message.contains(":" + code + "]"):
			return true
	return false


func _copy_bundle(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key_v in (value as Dictionary).keys():
			out[key_v] = _copy_bundle((value as Dictionary)[key_v])
		return out
	if value is Array:
		var out: Array = []
		for item in value as Array:
			out.append(_copy_bundle(item))
		return out
	return value
