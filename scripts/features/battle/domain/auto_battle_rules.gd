class_name AutoBattleRules
extends RefCounted

const POLICY := "player_auto"
const VERSION := 2


static func default_settings() -> Dictionary:
	return {
		"global_cooldown_sec": 1.0,
		"duplicate_skill_policy": "highest_priority",
		"cast_range": "in_range",
		"auto_pill": true,
		"opening_buff": true,
	}


static func default_rules() -> Dictionary:
	return {
		"version": VERSION,
		"policy": POLICY,
		"strategies": [],
		"settings": default_settings(),
	}


static func normalize_rules(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return default_rules()
	var source := raw as Dictionary
	if source.is_empty():
		return default_rules()
	var policy := str(source.get("policy", "")).strip_edges().to_lower()
	if policy == POLICY:
		return {
			"version": VERSION,
			"policy": POLICY,
			"strategies": normalize_strategies(source.get("strategies", [])),
			"settings": normalize_settings(source.get("settings", {})),
		}
	return default_rules()


static func normalize_strategies(raw: Variant) -> Array:
	if not raw is Array:
		return []
	var out: Array = []
	for entry_v in raw as Array:
		if not entry_v is Dictionary:
			continue
		var entry := (entry_v as Dictionary).duplicate(true)
		if not entry.get("action", {}) is Dictionary:
			continue
		out.append(entry)
	return out


static func normalize_settings(raw: Variant) -> Dictionary:
	var out := default_settings()
	if not raw is Dictionary:
		return out
	var source := raw as Dictionary
	if source.has("global_cooldown_sec"):
		out["global_cooldown_sec"] = maxf(0.0, float(source["global_cooldown_sec"]))
	if source.has("duplicate_skill_policy"):
		out["duplicate_skill_policy"] = str(source["duplicate_skill_policy"])
	if source.has("cast_range"):
		out["cast_range"] = str(source["cast_range"])
	if source.has("auto_pill"):
		out["auto_pill"] = bool(source["auto_pill"])
	if source.has("opening_buff"):
		out["opening_buff"] = bool(source["opening_buff"])
	return out


static func with_strategies(strategies: Array, settings: Dictionary = {}) -> Dictionary:
	return with_config("balanced", strategies, settings)


static func with_config(preset: String, strategies: Array, settings: Dictionary = {}) -> Dictionary:
	return {
		"version": VERSION,
		"policy": POLICY,
		"preset": preset.strip_edges().to_lower(),
		"strategies": normalize_strategies(strategies),
		"settings": normalize_settings(settings),
	}
