class_name LilianSessionState
extends RefCounted

const VALID_PHASES := ["idle", "resolving", "choosing", "battle", "result"]
const REQUIRED_KEYS := [
	"active",
	"phase",
	"location_id",
	"auto_advance",
	"steps",
	"days",
	"days_without_event",
	"seed",
	"rng_state",
	"runtime",
	"loot",
	"current_choices",
	"pending_decision_event",
	"current_event_id",
	"pending_battle_event_id",
	"pending_battle_summary",
	"pending_battle_rewards",
	"visited_once_events",
	"map_nodes",
	"map_edges",
	"current_node_id",
	"available_node_ids",
	"visited_node_ids",
	"resolved_node_events",
	"generated_events",
	"stats",
	"event_log",
	"player_snapshot",
	"pending_exit_reason",
	"lilian_id",
	"start_day",
	"effective_location",
	"difficulty_override",
]

const _BOOL_FIELDS := ["active", "auto_advance"]
const _INT_FIELDS := ["steps", "days", "days_without_event", "seed", "rng_state", "start_day"]
const _NON_NEGATIVE_FIELDS := ["steps", "days", "days_without_event", "start_day"]
const _STRING_FIELDS := [
	"phase",
	"location_id",
	"current_event_id",
	"pending_battle_event_id",
	"current_node_id",
	"pending_exit_reason",
	"lilian_id",
]
const _DICTIONARY_FIELDS := [
	"runtime",
	"pending_decision_event",
	"pending_battle_summary",
	"resolved_node_events",
	"generated_events",
	"stats",
	"player_snapshot",
	"effective_location",
	"difficulty_override",
]
const _ARRAY_FIELDS := [
	"loot",
	"current_choices",
	"pending_battle_rewards",
	"visited_once_events",
	"map_nodes",
	"map_edges",
	"available_node_ids",
	"visited_node_ids",
	"event_log",
]

var _data: Dictionary = default_state()


static func default_state() -> Dictionary:
	return {
		"active": false,
		"phase": "idle",
		"location_id": "",
		"auto_advance": true,
		"steps": 0,
		"days": 0,
		"days_without_event": 0,
		"seed": 0,
		"rng_state": 0,
		"runtime": {"hp": 0.0, "mp": 0.0, "item_slots": ["", "", ""], "inventory": {}},
		"loot": [],
		"current_choices": [],
		"pending_decision_event": {},
		"current_event_id": "",
		"pending_battle_event_id": "",
		"pending_battle_summary": {},
		"pending_battle_rewards": [],
		"visited_once_events": [],
		"map_nodes": [],
		"map_edges": [],
		"current_node_id": "",
		"available_node_ids": [],
		"visited_node_ids": [],
		"resolved_node_events": {},
		"generated_events": {},
		"stats": {},
		"event_log": [],
		"player_snapshot": {},
		"pending_exit_reason": "",
		"lilian_id": "",
		"start_day": 0,
		"effective_location": {},
		"difficulty_override": {},
	}


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("root_type", "$"))
		return errors
	var data := candidate as Dictionary
	for key_v in REQUIRED_KEYS:
		var key := str(key_v)
		if not data.has(key):
			errors.append(_error("missing_field", key))
	for key_v in data.keys():
		var key := str(key_v)
		if key not in REQUIRED_KEYS:
			errors.append(_error("unknown_field", key))
	for key_v in _BOOL_FIELDS:
		_validate_type(data, str(key_v), TYPE_BOOL, "bool_type", errors)
	for key_v in _INT_FIELDS:
		_validate_type(data, str(key_v), TYPE_INT, "int_type", errors)
	for key_v in _STRING_FIELDS:
		_validate_type(data, str(key_v), TYPE_STRING, "string_type", errors)
	for key_v in _DICTIONARY_FIELDS:
		_validate_type(data, str(key_v), TYPE_DICTIONARY, "dictionary_type", errors)
	for key_v in _ARRAY_FIELDS:
		_validate_type(data, str(key_v), TYPE_ARRAY, "array_type", errors)
	if data.has("phase") and data.get("phase") is String and str(data.get("phase")) not in VALID_PHASES:
		errors.append(_error("phase_invalid", "phase"))
	for key_v in _NON_NEGATIVE_FIELDS:
		var key := str(key_v)
		if data.has(key) and typeof(data.get(key)) == TYPE_INT and int(data.get(key)) < 0:
			errors.append(_error("negative_value", key))
	if data.get("generated_events") is Dictionary:
		var generated := data.get("generated_events") as Dictionary
		for event_id_v in generated.keys():
			var event_id := str(event_id_v)
			var field := "generated_events.%s" % event_id
			if not event_id_v is String or event_id.strip_edges() == "":
				errors.append(_error("generated_key_invalid", field))
				continue
			var event_v: Variant = generated.get(event_id_v)
			if not event_v is Dictionary:
				errors.append(_error("generated_row_type", field))
				continue
			if str((event_v as Dictionary).get("id", "")).strip_edges() != event_id:
				errors.append(_error("generated_id_mismatch", "%s.id" % field))
	return errors


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func replace_candidate(candidate: Variant) -> PackedStringArray:
	var errors := collect_errors(candidate)
	if errors.is_empty():
		_data = (candidate as Dictionary).duplicate(true)
	return errors


func reset() -> void:
	_data = default_state()


func value_ref(key: String) -> Variant:
	assert(key in REQUIRED_KEYS, "Unknown lilian session field: %s" % key)
	return _data[key]


func set_value(key: String, value: Variant) -> void:
	assert(key in REQUIRED_KEYS, "Unknown lilian session field: %s" % key)
	_data[key] = value


static func _validate_type(
		data: Dictionary,
		key: String,
		expected_type: int,
		code: String,
		errors: PackedStringArray
) -> void:
	if data.has(key) and typeof(data.get(key)) != expected_type:
		errors.append(_error(code, key))


static func _error(code: String, field: String) -> String:
	return "[lilian_session_state:%s] field=%s" % [code, field]
