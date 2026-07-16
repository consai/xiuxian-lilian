class_name CharacterSavedataState
extends RefCounted

const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")

const FOUNDATIONS := "foundations"
const APTITUDES := "aptitudes"
const CHARACTER_ORIGIN_ID := "character_origin_id"
const CHARACTER_ROOT_ID := "character_root_id"
const CHARACTER_TALENT_ID := "character_talent_id"

const PROFILE_ID_FIELDS := [
	CHARACTER_ORIGIN_ID,
	CHARACTER_ROOT_ID,
	CHARACTER_TALENT_ID,
]


static func default_slice() -> Dictionary:
	return {
		CHARACTER_ORIGIN_ID: "",
		CHARACTER_ROOT_ID: "",
		CHARACTER_TALENT_ID: "",
		FOUNDATIONS: CharacterStatsScript.default_foundations(),
		APTITUDES: CharacterStatsScript.default_aptitudes(),
	}


static func coalesce_slice(raw_snapshot: Dictionary) -> Dictionary:
	var errors := collect_errors(raw_snapshot)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		return {}
	var out := default_slice()
	for field in PROFILE_ID_FIELDS:
		if raw_snapshot.has(field):
			out[field] = raw_snapshot[field]
	if raw_snapshot.has(FOUNDATIONS):
		out[FOUNDATIONS] = CharacterStatsScript.normalize_foundations(
			raw_snapshot.get(FOUNDATIONS)
		)
	if raw_snapshot.has(APTITUDES):
		out[APTITUDES] = CharacterStatsScript.normalize_aptitudes(
			raw_snapshot.get(APTITUDES)
		)
	return out.duplicate(true)


static func apply_to_snapshot(raw_snapshot: Dictionary) -> Dictionary:
	var character_slice := coalesce_slice(raw_snapshot)
	if character_slice.is_empty():
		return {}
	var out := raw_snapshot.duplicate(true)
	for field in PROFILE_ID_FIELDS:
		out[field] = str(character_slice[field])
	out[FOUNDATIONS] = (character_slice[FOUNDATIONS] as Dictionary).duplicate(true)
	out[APTITUDES] = (character_slice[APTITUDES] as Dictionary).duplicate(true)
	return out


static func collect_errors(raw_snapshot: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for field in PROFILE_ID_FIELDS:
		if raw_snapshot.has(field) and not raw_snapshot[field] is String:
			errors.append(
				"[character_savedata_state:invalid_field_type] field=%s expected=String actual=%s"
				% [field, type_string(typeof(raw_snapshot[field]))]
			)
	return errors
