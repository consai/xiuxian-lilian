extends SceneTree

const LilianRulesCatalogScript := preload("res://scripts/lilian/lilian_rules_catalog.gd")
const LilianRulesServiceScript := preload("res://scripts/lilian/lilian_rules_service.gd")
const LilianRewardServiceScript := preload("res://scripts/lilian/lilian_reward_service.gd")
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_test_separate_tables_and_deep_copy(errors)
	_test_validation_contract(errors)
	_test_service_boundary_and_behavior(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: lilian rules catalog")
	quit(0)


func _test_separate_tables_and_deep_copy(errors: PackedStringArray) -> void:
	var rules := LilianRulesCatalogScript.rules()
	var budget := LilianRulesCatalogScript.reward_budget()
	_expect(errors, rules == ExportTableReaderScript.read_settings(
		LilianRulesCatalogScript.RULES_PATH
	), "rules preserve exported shape")
	_expect(errors, budget == ExportTableReaderScript.read_settings(
		LilianRulesCatalogScript.REWARD_BUDGET_PATH
	), "budget preserves exported shape")
	_expect(errors, int(rules["schema_version"]) == 1, "rules schema")
	_expect(errors, int(rules["max_idle_days"]) == 2, "configured max idle days")
	_expect(errors, not rules.has("reward_budget"), "rules table remains separate")
	_expect(errors, not budget.has("schema_version"), "budget table remains separate")
	_expect(errors, is_equal_approx(float(budget["daily_base_value"]), 14.0), "budget base value")
	rules["max_idle_days"] = 99
	(budget["unit_values"] as Dictionary)["item"] = 99
	_expect(errors, int(LilianRulesCatalogScript.rules()["max_idle_days"]) == 2, "rules cache protected")
	_expect(errors, is_equal_approx(
		float((LilianRulesCatalogScript.reward_budget()["unit_values"] as Dictionary)["item"]),
		10.0
	), "budget cache protected")


func _test_validation_contract(errors: PackedStringArray) -> void:
	var invalid_rules := LilianRulesCatalogScript.rules()
	invalid_rules["schema_version"] = "1"
	invalid_rules["event_day_chance"] = 2.0
	invalid_rules["max_idle_days"] = 1.5
	var rule_errors := LilianRulesCatalogScript.validate_rules(
		invalid_rules, "fixture://lilian_rules.json"
	)
	_expect(errors, _has_code(rule_errors, "required_integer"), "integer text rejected")
	_expect(errors, _has_code(rule_errors, "number_range"), "ratio range validated")
	_expect(errors, _all_have_context(rule_errors, "fixture://lilian_rules.json"), "rules error context")

	var invalid_budget := LilianRulesCatalogScript.reward_budget()
	invalid_budget["enabled"] = "true"
	invalid_budget["min_scale"] = 2.0
	invalid_budget["max_scale"] = 1.0
	(invalid_budget["unit_values"] as Dictionary).erase("equip")
	(invalid_budget["material_grade_multipliers"] as Dictionary)["2"] = "2.2"
	var budget_errors := LilianRulesCatalogScript.validate_reward_budget(
		invalid_budget, "fixture://lilian_rules_reward_budget.json"
	)
	_expect(errors, _has_code(budget_errors, "required_bool"), "bool text rejected")
	_expect(errors, _has_code(budget_errors, "scale_order"), "scale ordering validated")
	_expect(errors, _has_field(budget_errors, "unit_values.equip"), "nested required key")
	_expect(errors, _has_field(budget_errors, "material_grade_multipliers.2"), "nested numeric text rejected")
	_expect(errors, _all_have_context(
		budget_errors, "fixture://lilian_rules_reward_budget.json"
	), "budget error context")
	var zero_base_budget := LilianRulesCatalogScript.reward_budget()
	zero_base_budget["daily_base_value"] = 0
	_expect(errors, LilianRulesCatalogScript.validate_reward_budget(
		zero_base_budget, "fixture://zero_daily_base_value.json"
	).is_empty(), "zero daily base value is valid")


func _test_service_boundary_and_behavior(errors: PackedStringArray) -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lilian/lilian_rules_service.gd")
	_expect(errors, "Engine" not in source, "rules service has no Engine dependency")
	_expect(errors, "SceneTree" not in source, "rules service has no SceneTree dependency")
	_expect(errors, "ConfigManager" not in source, "rules service has no ConfigManager dependency")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_expect(errors, LilianRulesServiceScript.should_trigger_event_today(2, rng), "max idle days forces event")
	var event := {"type": "gather", "difficulty": 1, "duration_days": 1}
	_expect(errors, is_equal_approx(
		LilianRewardServiceScript.reward_budget_value_for_event(event), 14.0
	), "gather difficulty one duration one budget")
	var loot: Array = [{"kind": "item", "id": "item.a", "count": 10}]
	var outcome := LilianRewardServiceScript.apply_loot_loss_on_defeat(loot)
	_expect(errors, int((loot[0] as Dictionary)["count"]) == 8, "defeat removes two of ten")
	_expect(errors, int((outcome["lost"][0] as Dictionary)["count"]) == 2, "defeat reports two lost")


func _has_code(errors: PackedStringArray, code: String) -> bool:
	var prefix := "[lilian_rules_catalog:%s]" % code
	for message in errors:
		if message.begins_with(prefix):
			return true
	return false


func _has_field(errors: PackedStringArray, field: String) -> bool:
	for message in errors:
		if "field=%s " % field in message:
			return true
	return false


func _all_have_context(errors: PackedStringArray, path: String) -> bool:
	if errors.is_empty():
		return false
	for message in errors:
		if "file=%s" % path not in message or " field=" not in message or " value=" not in message:
			return false
	return true


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
