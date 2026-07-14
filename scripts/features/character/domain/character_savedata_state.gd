class_name CharacterSavedataState
extends RefCounted

const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")

const FOUNDATIONS := "foundations"
const APTITUDES := "aptitudes"


static func default_slice() -> Dictionary:
	return {
		FOUNDATIONS: CharacterStatsScript.default_foundations(),
		APTITUDES: CharacterStatsScript.default_aptitudes(),
	}


static func coalesce_slice(raw_snapshot: Dictionary) -> Dictionary:
	var out := default_slice()
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
	var out := raw_snapshot.duplicate(true)
	var character_slice := coalesce_slice(raw_snapshot)
	out[FOUNDATIONS] = (character_slice[FOUNDATIONS] as Dictionary).duplicate(true)
	out[APTITUDES] = (character_slice[APTITUDES] as Dictionary).duplicate(true)
	return out
