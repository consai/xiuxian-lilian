class_name StoryState
extends RefCounted

const SAVED_FIELDS := ["completed", "flags", "history", "active_snapshot"]
const SESSION_FIELDS := ["active_snapshot", "pending_event"]
const ACTIVE_FIELDS := [
	"story_file_id", "story_id", "current_node_id", "state", "history", "started",
]

var _savedata: Dictionary = default_savedata()
var _session: Dictionary = default_session()


static func default_savedata() -> Dictionary:
	return {"completed": [], "flags": {}, "history": [], "active_snapshot": {}}


static func default_session() -> Dictionary:
	return {"active_snapshot": {}, "pending_event": ""}


static func collect_savedata_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("saved_root_type", "$"))
		return errors
	var data := candidate as Dictionary
	_validate_exact_fields(data, SAVED_FIELDS, "saved", errors)
	_validate_string_array(data, "completed", "saved", errors)
	_validate_string_array(data, "history", "saved", errors)
	_validate_type(data, "flags", TYPE_DICTIONARY, "saved", errors)
	_validate_active(data.get("active_snapshot"), "saved.active_snapshot", errors)
	return errors


static func collect_session_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("session_root_type", "$"))
		return errors
	var data := candidate as Dictionary
	_validate_exact_fields(data, SESSION_FIELDS, "session", errors)
	_validate_active(data.get("active_snapshot"), "session.active_snapshot", errors)
	_validate_type(data, "pending_event", TYPE_STRING, "session", errors)
	return errors


static func prepare_savedata(candidate: Variant) -> Dictionary:
	var errors := collect_savedata_errors(candidate)
	if not errors.is_empty():
		_report(errors)
		return {}
	return (candidate as Dictionary).duplicate(true)


static func prepare_session(candidate: Variant) -> Dictionary:
	var errors := collect_session_errors(candidate)
	if not errors.is_empty():
		_report(errors)
		return {}
	return (candidate as Dictionary).duplicate(true)


func replace_candidate(saved_candidate: Variant, session_candidate: Variant) -> PackedStringArray:
	var errors := collect_savedata_errors(saved_candidate)
	errors.append_array(collect_session_errors(session_candidate))
	if errors.is_empty():
		_savedata = (saved_candidate as Dictionary).duplicate(true)
		_session = (session_candidate as Dictionary).duplicate(true)
	return errors


func savedata_snapshot() -> Dictionary:
	return _savedata.duplicate(true)


func session_snapshot() -> Dictionary:
	return _session.duplicate(true)


static func _validate_active(value: Variant, field: String, errors: PackedStringArray) -> void:
	if not value is Dictionary:
		errors.append(_error("active_type", field))
		return
	var active := value as Dictionary
	if active.is_empty():
		return
	_validate_exact_fields(active, ACTIVE_FIELDS, "active", errors, field)
	for key in ["story_file_id", "story_id", "current_node_id"]:
		_validate_type(active, key, TYPE_STRING, "active", errors, field)
	_validate_type(active, "state", TYPE_DICTIONARY, "active", errors, field)
	_validate_string_array(active, "history", "active", errors, field)
	_validate_type(active, "started", TYPE_BOOL, "active", errors, field)


static func _validate_exact_fields(
		data: Dictionary,
		expected: Array,
		prefix: String,
		errors: PackedStringArray,
		path_prefix: String = ""
) -> void:
	for key_v in expected:
		var key := str(key_v)
		if not data.has(key):
			errors.append(_error("%s_missing_field" % prefix, _path(path_prefix, key)))
	for key_v in data.keys():
		var key := str(key_v)
		if key not in expected:
			errors.append(_error("%s_unknown_field" % prefix, _path(path_prefix, key)))


static func _validate_type(
		data: Dictionary,
		key: String,
		expected_type: int,
		prefix: String,
		errors: PackedStringArray,
		path_prefix: String = ""
) -> void:
	if data.has(key) and typeof(data.get(key)) != expected_type:
		errors.append(_error("%s_type" % prefix, _path(path_prefix, key)))


static func _validate_string_array(
		data: Dictionary,
		key: String,
		prefix: String,
		errors: PackedStringArray,
		path_prefix: String = ""
) -> void:
	if not data.has(key):
		return
	var value: Variant = data.get(key)
	if not value is Array:
		errors.append(_error("%s_type" % prefix, _path(path_prefix, key)))
		return
	for index in (value as Array).size():
		if not (value as Array)[index] is String:
			errors.append(_error("%s_string_item" % prefix, "%s[%d]" % [_path(path_prefix, key), index]))


static func _path(prefix: String, field: String) -> String:
	return field if prefix == "" else "%s.%s" % [prefix, field]


static func _error(code: String, field: String) -> String:
	return "[story_state:%s] field=%s" % [code, field]


static func _report(errors: PackedStringArray) -> void:
	for message in errors:
		push_error(message)
