extends SceneTree

const WeituoCatalogScript := preload(
	"res://scripts/features/commission/infrastructure/weituo_catalog.gd"
)
const ExportTableReaderScript := preload("res://scripts/core/config/export_table_reader.gd")


func _init() -> void:
	var errors: PackedStringArray = []
	_test_independent_raw_tables(errors)
	_test_deep_copy_boundaries(errors)
	_test_validation_error_contract(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: weituo catalog")
	quit(0)


func _test_independent_raw_tables(errors: PackedStringArray) -> void:
	var expected_schema := ExportTableReaderScript.read_settings(WeituoCatalogScript.SCHEMA_PATH)
	var expected_rules := ExportTableReaderScript.read_settings(WeituoCatalogScript.RULES_PATH)
	var expected_commissions := ExportTableReaderScript.read_keyed_rows(
		WeituoCatalogScript.COMMISSIONS_PATH
	)
	_expect(errors, WeituoCatalogScript.schema() == expected_schema, "schema table remains in exported shape")
	_expect(errors, WeituoCatalogScript.rules() == expected_rules, "rules table remains in exported shape")
	_expect(
		errors,
		WeituoCatalogScript.commissions() == expected_commissions,
		"commission rows remain in exported shape"
	)
	_expect(errors, int(WeituoCatalogScript.rules().get("active_limit", 0)) == 3, "typed active limit")
	_expect(errors, int(WeituoCatalogScript.rules().get("refresh_days", 0)) == 30, "typed refresh days")


func _test_deep_copy_boundaries(errors: PackedStringArray) -> void:
	var rules := WeituoCatalogScript.rules()
	rules["active_limit"] = 999
	_expect(errors, int(WeituoCatalogScript.rules()["active_limit"]) == 3, "rules return a deep copy")
	var commissions := WeituoCatalogScript.commissions()
	var row := commissions["qingxin_herb_delivery_001"] as Dictionary
	(row["ui"] as Dictionary)["badge"] = "mutated"
	var fresh := WeituoCatalogScript.commission_by_id("qingxin_herb_delivery_001")
	_expect(errors, str((fresh["ui"] as Dictionary)["badge"]) == "可接受", "rows return a deep copy")
	_expect(errors, WeituoCatalogScript.commission_by_id("missing_business_id").is_empty(), "unknown id is query-safe")


func _test_validation_error_contract(errors: PackedStringArray) -> void:
	var rule_errors := WeituoCatalogScript.validate_rules(
		{"active_limit": 3, "refresh_days": "30", "board_offer_count": 3},
		"fixture://weituo_rules.json"
	)
	_expect(errors, rule_errors.size() == 1, "invalid rule has one precise error")
	_expect(
		errors,
		str(rule_errors[0]).begins_with("[weituo_catalog:rule_type]"),
		"rule error has stable code"
	)
	_expect(errors, "file=fixture://weituo_rules.json" in str(rule_errors[0]), "rule error has file")
	_expect(errors, "field=refresh_days" in str(rule_errors[0]), "rule error has field")

	var invalid_rows := {
		"row_a": {
			"id": "other_id",
			"title": "Title",
			"issuer": "Issuer",
			"desc": "Description",
			"repeatable": true,
			"ui": {"portrait": "portrait.png", "badge": "available"},
			"requirements": [{"kind": "lilian", "location_id": "place", "min_steps": 0}],
			"rewards": [{"kind": "mystery", "id": "x", "count": 1}],
		},
	}
	var row_errors := WeituoCatalogScript.validate_commissions(
		invalid_rows,
		"fixture://weituo_weituo.json"
	)
	_expect(errors, _has_code(row_errors, "row_id_mismatch"), "row key/id mismatch is rejected")
	_expect(errors, _has_code(row_errors, "requirement_min_steps"), "requirement branch is validated")
	_expect(errors, _has_code(row_errors, "requirement_not_defeated"), "requirement bool is required")
	_expect(errors, _has_code(row_errors, "reward_kind_unknown"), "reward branch is validated")
	for message in row_errors:
		_expect(errors, "file=fixture://weituo_weituo.json" in message, "row error has file")
		_expect(errors, "field=" in message, "row error has field")


func _has_code(errors: PackedStringArray, code: String) -> bool:
	var prefix := "[weituo_catalog:%s]" % code
	for message in errors:
		if message.begins_with(prefix):
			return true
	return false


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
