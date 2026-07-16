extends SceneTree

const CatalogScript := preload("res://scripts/features/battle/infrastructure/battle_vfx_catalog.gd")
const QueryScript := preload("res://scripts/features/battle/application/battle_vfx_query_application.gd")
const LibraryScript := preload("res://scripts/zhandou/vfx/zhandou_vfx_preset_library.gd")
const ResolverScript := preload("res://scripts/zhandou/vfx/zhandou_vfx_sequence_resolver.gd")
const JsonReaderScript := preload("res://scripts/core/config/json_reader.gd")

var _errors: PackedStringArray = []


func _init() -> void:
	_test_production_snapshot()
	_test_normalization_and_runtime_characterization()
	_test_strict_atomic_contract()
	if not _errors.is_empty():
		for message in _errors:
			push_error(message)
		quit(1)
		return
	print("PASS: battle vfx catalog")
	quit(0)


func _test_production_snapshot() -> void:
	var catalog := CatalogScript.new()
	_check(catalog.reload(), "ten VFX/float files must load as one candidate")
	_check(catalog.preset_ids() == ["hit_default", "hit_only", "melee_default", "qi_bolt_projectile", "ranged_default", "status_cast", "sword_qi_projectile"], "preset ids must remain naturally sorted")
	var expected_counts := {
		"hit_default": 3,
		"hit_only": 1,
		"melee_default": 5,
		"qi_bolt_projectile": 3,
		"ranged_default": 4,
		"status_cast": 4,
		"sword_qi_projectile": 3,
	}
	for id_v in expected_counts.keys():
		var id := str(id_v)
		_check(catalog.sequence(id).size() == int(expected_counts[id]), "%s step count changed" % id)
	var float_bundle := catalog.float_styles()
	_check((float_bundle.get("styles", {}) as Dictionary).size() == 8, "eight float styles must remain available")
	_check(float(float_bundle.get("jitter_x", 0.0)) == 18.0, "float jitter anchor changed")
	_check(int(float_bundle.get("max_per_unit_per_frame", 0)) == 6, "float frame cap changed")
	_check(not float_bundle.has("jitter_y") and not float_bundle.has("lane_step_y"), "consumer defaults for jitter_y/lane_step_y must remain active")
	var melee := catalog.sequence("melee_default")
	_check(str((melee[1] as Dictionary).get("op", "")) == "parallel", "melee sequence decoding changed")
	_check(((melee[1] as Dictionary).get("steps", []) as Array).size() == 2, "JSON-string nested steps must decode")
	_check(not (melee[3] as Dictionary).has("actor"), "null cells must be removed")
	_check(not (((melee[3] as Dictionary).get("steps", []) as Array)[0] as Dictionary).has("_comment"), "nested comment metadata must be removed")
	melee[0] = {"op": "mutated"}
	_check(str((catalog.sequence("melee_default")[0] as Dictionary).get("op", "")) == "stop_idle", "sequence queries must deep clone")
	(float_bundle.get("styles", {}) as Dictionary).clear()
	_check((catalog.float_styles().get("styles", {}) as Dictionary).size() == 8, "float queries must deep clone")


func _test_normalization_and_runtime_characterization() -> void:
	_check(QueryScript.normalize_preset_id("fixtures/presets/melee_default.json") == "melee_default", "forward-slash preset normalization changed")
	_check(QueryScript.normalize_preset_id("presets\\hit_default.json") == "hit_default", "backslash preset normalization changed")
	_check(ResolverScript.normalize_vfx_binding(7).is_empty(), "unsupported binding type must stay empty")
	_check(ResolverScript.normalize_vfx_binding("").is_empty(), "empty string binding must stay empty")
	_check(ResolverScript.normalize_vfx_binding({"file": "presets/ranged_default.json"}).get("preset") == "ranged_default", "file binding normalization changed")
	var inline := [{"op": "impact", "nested": {"value": 1}}]
	var inline_result := ResolverScript.resolve_vfx_cfg({"vfx": {"sequence": inline}}, LibraryScript.load_default())
	((inline_result[0] as Dictionary).nested as Dictionary).value = 2
	_check(int(((inline[0] as Dictionary).nested as Dictionary).value) == 1, "inline sequences must be deep cloned")
	var library := LibraryScript.load_default()
	_check(library.get_default_preset_id() == "melee_default", "default preset changed")
	_check(library.get_impact_preset_id() == "hit_default", "impact preset changed")
	_check(library.get_sequence("unknown_runtime_preset") == library.get_sequence("melee_default"), "unknown runtime preset must fall back to default")
	var cached := library.get_sequence("hit_only")
	(cached[0] as Dictionary)["op"] = "mutated"
	_check((library.get_sequence("hit_only")[0] as Dictionary).get("op") == "mutated", "initial library load must retain its existing local cache identity semantics")
	library.reload_preset("hit_only.json")
	_check((library.get_sequence("hit_only")[0] as Dictionary).get("op") == "impact", "single-preset reload semantics changed")
	library.reload_all()
	_check(library.get_sequence("hit_only").size() == 1, "full local cache reload semantics changed")


func _test_strict_atomic_contract() -> void:
	var roots := _production_roots()
	var catalog := CatalogScript.new()
	_check(catalog.reload_from_roots(roots), "production raw roots must load")
	var original := catalog.sequence("melee_default")
	var bad_root := roots.duplicate(true)
	bad_root["preset:hit_only"] = []
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_root), "non-object root must reject")
	Engine.print_error_messages = true
	_check(_has_error(catalog.collect_errors(), "invalid_root"), "bad root must expose stable invalid_root")
	_check(catalog.sequence("melee_default") == original, "failed root reload must retain old snapshot")
	var bad_row := roots.duplicate(true)
	(bad_row["preset:hit_only"] as Dictionary)["1"] = "bad"
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_row), "non-object row must reject")
	Engine.print_error_messages = true
	_check(_has_error(catalog.collect_errors(), "invalid_row"), "bad row must expose invalid_row")
	var bad_reference := roots.duplicate(true)
	((bad_reference.index as Dictionary)["default"] as Dictionary)["value"] = "not_a_preset"
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_reference), "unknown index preset must reject")
	Engine.print_error_messages = true
	var first_errors := catalog.collect_errors()
	_check(_has_error(first_errors, "preset_reference_unknown"), "unknown reference must expose stable error")
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_reference), "repeated invalid reference must reject")
	Engine.print_error_messages = true
	_check(catalog.collect_errors() == first_errors, "repeated errors must be stable")
	_check(catalog.sequence("melee_default") == original, "all failed candidates must retain old snapshot")
	var bad_style_key := roots.duplicate(true)
	((bad_style_key.float_styles as Dictionary)["skill"] as Dictionary)["key"] = "damage"
	_expect_rejection_code(catalog, bad_style_key, "style_key_mismatch", "style row key mismatch must reject")
	var bad_preset_key := roots.duplicate(true)
	var bad_preset_root := bad_preset_key["preset:hit_only"] as Dictionary
	var bad_preset_row := (bad_preset_root["1"] as Dictionary).duplicate(true)
	bad_preset_root.erase("1")
	bad_preset_root["2"] = bad_preset_row
	_expect_rejection_code(catalog, bad_preset_key, "preset_key_mismatch", "top-level preset row key mismatch must reject")
	var unknown_op := roots.duplicate(true)
	((unknown_op["preset:hit_only"] as Dictionary)["1"] as Dictionary)["op"] = "not_an_op"
	_expect_rejection_code(catalog, unknown_op, "op_unknown", "unknown VFX operation must reject")
	var bad_index := roots.duplicate(true)
	((bad_index.index as Dictionary)["version"] as Dictionary)["value"] = 1.5
	((bad_index.index as Dictionary)["preset_dir"] as Dictionary)["value"] = ""
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_index), "invalid index contract must reject")
	Engine.print_error_messages = true
	var index_errors := catalog.collect_errors()
	_check(_has_error(index_errors, "index_version_invalid"), "index version must be an integer-valued number")
	_check(_has_error(index_errors, "preset_dir_invalid"), "index preset_dir must be a non-empty string")
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(bad_index), "repeated invalid index must reject")
	Engine.print_error_messages = true
	_check(catalog.collect_errors() == index_errors, "invalid index errors must be stable")
	_check(catalog.sequence("melee_default") == original, "new strict failures must retain old snapshot")
	var numeric_strings := roots.duplicate(true)
	((numeric_strings.float_settings as Dictionary)["jitter_x"] as Dictionary)["value"] = "18.5"
	((numeric_strings.float_styles as Dictionary)["skill"] as Dictionary)["duration"] = "1.25"
	_check(catalog.reload_from_roots(numeric_strings), "integer/float numeric strings must be accepted")
	_check(float(catalog.float_styles().jitter_x) == 18.5, "numeric setting string must coerce")
	var empty_catalog := CatalogScript.new()
	Engine.print_error_messages = false
	_check(not empty_catalog.reload_from_roots(bad_reference), "first invalid candidate must reject")
	Engine.print_error_messages = true
	_check(empty_catalog.sequence("melee_default").is_empty() and empty_catalog.float_styles().is_empty(), "first failure must expose no snapshot")


func _expect_rejection_code(catalog: RefCounted, roots: Dictionary, code: String, message: String) -> void:
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(roots), message)
	Engine.print_error_messages = true
	var errors: PackedStringArray = catalog.collect_errors()
	_check(_has_error(errors, code), "%s must expose %s" % [message, code])
	Engine.print_error_messages = false
	_check(not catalog.reload_from_roots(roots), "repeated %s" % message)
	Engine.print_error_messages = true
	_check(catalog.collect_errors() == errors, "%s errors must be stable" % message)


func _production_roots() -> Dictionary:
	var paths := CatalogScript.new()._paths as Dictionary
	var out: Dictionary = {}
	for table_v in paths.keys():
		out[str(table_v)] = JsonReaderScript.read_variant(str(paths[table_v]))
	return out


func _has_error(errors: PackedStringArray, code: String) -> bool:
	for message in errors:
		if message.contains(":" + code + "]"):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
