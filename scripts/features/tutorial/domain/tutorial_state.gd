class_name TutorialState
extends RefCounted

const FIELDS := [
	"chapter", "step", "completed", "skipped", "flags", "seen_context_tips",
]
const EVENT_STEPS := {
	"tutorial.xiulian_mianban_opened": "T01",
	"tutorial.cultivation_started": "T01",
	"tutorial.cultivation_result_shown": "T02",
	"tutorial.cultivation_completed": "T02",
	"tutorial.pill_mode_selected": "T02",
	"tutorial.alchemy_opened": "T09",
	"tutorial.alchemy_recipe_selected": "T09",
	"tutorial.alchemy_preview_acknowledged": "T09",
	"tutorial.alchemy_started": "T09",
	"tutorial.alchemy_result_shown": "T09",
	"tutorial.alchemy_completed": "T10",
	"tutorial.attributes_opened": "T03",
	"tutorial.attributes_closed": "T03",
	"tutorial.world_map_opened": "T03",
	"tutorial.wolf_valley_selected": "T04",
	"tutorial.lilian_started": "T04",
	"tutorial.first_battle_won": "T05",
	"tutorial.lilian_returned": "T06",
	"tutorial.result_closed": "T07",
}


static func default_new_game() -> Dictionary:
	return {
		"chapter": "prologue_morning_practice",
		"step": "T00",
		"completed": false,
		"skipped": false,
		"flags": {},
		"seen_context_tips": [],
	}


static func default_inactive() -> Dictionary:
	var state := default_new_game()
	state["step"] = "T10"
	state["completed"] = true
	return state


static func collect_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append(_error("root_type", "$"))
		return errors
	var data := candidate as Dictionary
	for field in FIELDS:
		if not data.has(field):
			errors.append(_error("missing_field", str(field)))
	for field_v in data.keys():
		var field := str(field_v)
		if field not in FIELDS:
			errors.append(_error("unknown_field", field))
	_validate_type(data, "chapter", TYPE_STRING, errors)
	_validate_type(data, "step", TYPE_STRING, errors)
	_validate_type(data, "completed", TYPE_BOOL, errors)
	_validate_type(data, "skipped", TYPE_BOOL, errors)
	_validate_type(data, "flags", TYPE_DICTIONARY, errors)
	_validate_type(data, "seen_context_tips", TYPE_ARRAY, errors)
	if data.get("flags") is Dictionary:
		for flag_v in (data.get("flags") as Dictionary).keys():
			var flag := str(flag_v)
			if not flag_v is String:
				errors.append(_error("flag_key_type", "flags.%s" % flag))
			elif not (data.get("flags") as Dictionary).get(flag_v) is bool:
				errors.append(_error("flag_value_type", "flags.%s" % flag))
	if data.get("seen_context_tips") is Array:
		var tips := data.get("seen_context_tips") as Array
		for index in tips.size():
			if not tips[index] is String:
				errors.append(_error("seen_item_type", "seen_context_tips[%d]" % index))
	if data.get("completed") is bool and data.get("skipped") is bool:
		if bool(data.get("completed")) and bool(data.get("skipped")):
			errors.append(_error("terminal_conflict", "completed,skipped"))
	return errors


static func prepare(candidate: Variant) -> Dictionary:
	var errors := collect_errors(candidate)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return {}
	return (candidate as Dictionary).duplicate(true)


static func step_for_event(event_id: String) -> String:
	return str(EVENT_STEPS.get(event_id, ""))


static func _validate_type(
		data: Dictionary, field: String, expected: int, errors: PackedStringArray
) -> void:
	if data.has(field) and typeof(data.get(field)) != expected:
		errors.append(_error("field_type", field))


static func _error(code: String, field: String) -> String:
	return "[tutorial_state:%s] field=%s" % [code, field]
