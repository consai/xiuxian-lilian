extends SceneTree

const MoniCatalogScript := preload("res://scripts/sim/moni_catalog.gd")
const CultivationMethodQueryApplicationScript := preload(
	"res://scripts/features/cultivation/application/cultivation_method_query_application.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_test_tables_and_normalization(errors)
	_test_deep_copy_and_unknown_id(errors)
	_test_validation_contract(errors)
	_test_cross_table_references(errors)
	_test_rest_characterization(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: moni catalog")
	quit(0)


func _test_tables_and_normalization(errors: PackedStringArray) -> void:
	_expect(errors, int(MoniCatalogScript.schema().get("schema_version", 0)) == 1, "schema table")
	var activities := MoniCatalogScript.activities()
	_expect(errors, int((activities["cultivate"] as Dictionary)["days"]) == 30, "cultivate days")
	_expect(errors, (activities["rest"] as Dictionary)["injury_recovery"] is int, "rest recovery normalized to int")
	_expect(errors, int((activities["rest"] as Dictionary)["injury_recovery"]) == 2, "rest recovery value")
	var initial := MoniCatalogScript.initial_player()
	_expect(errors, initial["jineng"] == ["factive_lq_001", "factive_lq_002", "factive_lq_003"], "ability ids")
	_expect(errors, initial["jineng_use"] == initial["jineng"], "equipped ability ids")
	_expect(errors, initial["gongfa"] == ["method.hunyuan.1"], "method ids")
	_expect(errors, initial["equips"] == [], "empty equips normalize to array")
	_expect(errors, initial["item_slots"] == ["", "", ""], "item slots")
	_expect(errors, initial["equip_slots"] == [-1, -1, -1], "equip slots")


func _test_deep_copy_and_unknown_id(errors: PackedStringArray) -> void:
	var activities := MoniCatalogScript.activities()
	(activities["rest"] as Dictionary)["injury_recovery"] = 99
	_expect(errors, int(MoniCatalogScript.activity_by_id("rest")["injury_recovery"]) == 2, "activity cache is protected")
	var initial := MoniCatalogScript.initial_player()
	(initial["attrs"] as Dictionary)["mutated"] = true
	_expect(errors, not (MoniCatalogScript.initial_player()["attrs"] as Dictionary).has("mutated"), "initial cache is protected")
	_expect(errors, MoniCatalogScript.activity_by_id("missing").is_empty(), "unknown activity is query-safe")


func _test_validation_contract(errors: PackedStringArray) -> void:
	var schema_errors := MoniCatalogScript.validate_schema({"schema_version": 2}, "fixture://moni.json")
	_expect(errors, _has_code(schema_errors, "schema_version_unsupported"), "schema version error code")
	_expect(errors, "file=fixture://moni.json" in str(schema_errors[0]), "schema error file")
	var schema_text_errors := MoniCatalogScript.validate_schema({"schema_version": "1"}, "fixture://moni.json")
	_expect(errors, _has_code(schema_text_errors, "schema_version_type"), "schema version rejects integer text")
	var activity_errors := MoniCatalogScript.validate_activities({
		"cultivate": {"key": "wrong", "days": "30", "cultivation_gain": -1},
		"rest": {"key": "rest", "days": 1, "injury_recovery": "2"},
	}, "fixture://moni_activities.json")
	_expect(errors, _has_code(activity_errors, "activity_key_mismatch"), "activity row key mismatch")
	_expect(errors, _has_code(activity_errors, "activity_positive_integer"), "activity days rejects integer text")
	_expect(errors, _has_code(activity_errors, "activity_non_negative_integer"), "activity value range")
	var rest_text_errors := MoniCatalogScript.validate_activities({
		"cultivate": {"key": "cultivate", "days": 30, "cultivation_gain": 20},
		"rest": {"key": "rest", "days": 1, "injury_recovery": "2"},
	}, "fixture://moni_activities.json")
	_expect(errors, rest_text_errors.is_empty(), "rest injury recovery accepts integer text")
	var initial_errors := MoniCatalogScript.validate_initial_player({
		"name": "修士",
		"icon": "player.png",
		"attrs": {},
		"linggen": {},
		"items": {},
		"equips": {},
		"jineng": "ability.a",
		"jineng_use": "ability.missing",
		"gongfa": "method.a",
		"item_slots": "::",
		"equip_slots": "-1:x:-1",
	}, "fixture://moni_initial_player.json")
	_expect(errors, _has_code(initial_errors, "initial_jineng_use_unknown"), "equipped ability subset")
	_expect(errors, _has_code(initial_errors, "initial_equip_slot_type"), "equip slot type")
	for message in initial_errors:
		_expect(errors, "file=fixture://moni_initial_player.json" in message, "initial error file")
		_expect(errors, "field=" in message, "initial error field")


func _test_cross_table_references(errors: PackedStringArray) -> void:
	var initial := MoniCatalogScript.initial_player()
	var method_ids: Dictionary = {}
	for method_v in CultivationMethodQueryApplicationScript.all_definitions():
		if method_v is Dictionary:
			method_ids[str((method_v as Dictionary).get("id", ""))] = true
	for method_id_v in initial["gongfa"] as Array:
		_expect(errors, method_ids.has(str(method_id_v)), "unknown initial method %s" % method_id_v)


func _test_rest_characterization(errors: PackedStringArray) -> void:
	var game_state := root.get_node("GameState")
	game_state.new_game()
	game_state.injury_days = 5
	game_state.hp = 1.0
	game_state.mp = 1.0
	var day_before := int(game_state.day)
	game_state.rest()
	_expect(errors, int(game_state.injury_days) == 3, "rest uses configured injury recovery")
	_expect(errors, is_equal_approx(float(game_state.hp), float(game_state.attrs.get("hp_max", 0.0))), "rest restores hp")
	_expect(errors, is_equal_approx(float(game_state.mp), float(game_state.attrs.get("mp_max", 0.0))), "rest restores mp")
	_expect(errors, int(game_state.day) == day_before + 1, "rest advances one day")


func _has_code(errors: PackedStringArray, code: String) -> bool:
	var prefix := "[moni_catalog:%s]" % code
	for message in errors:
		if message.begins_with(prefix):
			return true
	return false


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
