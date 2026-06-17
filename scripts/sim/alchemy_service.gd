class_name AlchemyService
extends RefCounted

const DATA_PATH := "res://data/alchemy.json"
const QUALITY_NAMES := {
	"none": "无产物",
	"waste": "废丹",
	"low": "下品",
	"medium": "中品",
	"high": "上品",
	"supreme": "极品",
}
const MAX_RECIPE_MASTERY := 1000
const MASTERY_SCORE_MAX := 20.0
const MASTERY_EXTRA_PILL_CHANCE_MAX := 0.75
const MASTERY_SECOND_EXTRA_PILL_CHANCE_MAX := 0.30
const MASTERY_COST_SAVE_CHANCE_MAX := 0.35
const FAILURE_MASTERY_MULTIPLIER := 1.5


static func default_state() -> Dictionary:
	return {
		"level": 1,
		"xp": 0,
		"known_recipes": ["recipe.huiqi", "recipe.huiling", "recipe.liaoshang", "recipe.juqi"],
		"owned_furnaces": {"furnace.old_copper": {"durability": 30}},
		"equipped_furnace": "furnace.old_copper",
		"last_recipe": "recipe.huiqi",
		"last_strategy": "standard",
		"total_batches": 0,
		"recipe_mastery": {},
	}


static func normalize_state(raw: Variant) -> Dictionary:
	var out := default_state()
	if raw is Dictionary:
		var src := raw as Dictionary
		out["level"] = clampi(int(src.get("level", 1)), 1, 10)
		out["xp"] = maxi(0, int(src.get("xp", 0)))
		if src.get("known_recipes") is Array:
			out["known_recipes"] = (src.get("known_recipes") as Array).duplicate()
		if src.get("owned_furnaces") is Dictionary:
			out["owned_furnaces"] = (src.get("owned_furnaces") as Dictionary).duplicate(true)
		out["equipped_furnace"] = str(src.get("equipped_furnace", out["equipped_furnace"]))
		out["last_recipe"] = str(src.get("last_recipe", out["last_recipe"]))
		out["last_strategy"] = str(src.get("last_strategy", out["last_strategy"]))
		out["total_batches"] = maxi(0, int(src.get("total_batches", 0)))
		if src.get("recipe_mastery") is Dictionary:
			var mastery: Dictionary = {}
			for recipe_id_v in (src.get("recipe_mastery") as Dictionary).keys():
				var recipe_id := str(recipe_id_v)
				mastery[recipe_id] = clampi(
					int((src.get("recipe_mastery") as Dictionary).get(recipe_id_v, 0)),
					0,
					MAX_RECIPE_MASTERY
				)
			out["recipe_mastery"] = mastery
	return out


static func all_recipes() -> Array:
	return (_root().get("recipes", []) as Array).duplicate(true)


static func all_strategies() -> Array:
	return (_root().get("strategies", []) as Array).duplicate(true)


static func recipe_by_id(recipe_id: String) -> Dictionary:
	return _by_id(all_recipes(), recipe_id)


static func strategy_by_id(strategy_id: String) -> Dictionary:
	return _by_id(all_strategies(), strategy_id)


static func furnace_by_id(furnace_id: String) -> Dictionary:
	return _by_id((_root().get("furnaces", []) as Array), furnace_id)


static func preview(
	recipe_id: String,
	strategy_id: String,
	selection_mode: String,
	alchemy_state: Dictionary,
	inventory: Dictionary,
	foundations: Dictionary,
	aptitudes: Dictionary
) -> Dictionary:
	var recipe := recipe_by_id(recipe_id)
	var strategy := strategy_by_id(strategy_id)
	if recipe.is_empty() or strategy.is_empty():
		return {"ok": false, "error": "未知丹方或炼制策略"}
	var state := normalize_state(alchemy_state)
	if not (state.get("known_recipes", []) as Array).has(recipe_id):
		return {"ok": false, "error": "尚未掌握该丹方"}
	if int(state.get("level", 1)) < int(recipe.get("minimum_level", 1)):
		return {"ok": false, "error": "炼丹术等级不足"}
	var furnace_id := str(state.get("equipped_furnace", ""))
	var furnace := furnace_by_id(furnace_id)
	var owned := state.get("owned_furnaces", {}) as Dictionary
	var furnace_state_v: Variant = owned.get(furnace_id, {})
	var furnace_state := furnace_state_v as Dictionary if furnace_state_v is Dictionary else {}
	if furnace.is_empty() or int(furnace_state.get("durability", 0)) <= 0:
		return {"ok": false, "error": "当前丹炉不可用"}
	var selection := _select_ingredients(recipe, inventory, selection_mode)
	if not bool(selection.get("ok", false)):
		return selection
	var ingredient_score := float(selection.get("average_quality", 1.0)) * 8.0 - 8.0
	var attribute_score := _attribute_score(foundations, aptitudes)
	var recipe_mastery := mastery_for(state, recipe_id)
	var mastery_percent := float(recipe_mastery) / float(MAX_RECIPE_MASTERY)
	var mastery_score := mastery_percent * MASTERY_SCORE_MAX
	var extra_pill_chance := mastery_percent * MASTERY_EXTRA_PILL_CHANCE_MAX
	var second_extra_pill_chance := mastery_percent * MASTERY_SECOND_EXTRA_PILL_CHANCE_MAX
	var cost_save_chance := mastery_percent * MASTERY_COST_SAVE_CHANCE_MAX
	var base_score := (
		50.0
		- float(recipe.get("difficulty", 0))
		+ ingredient_score
		+ float(furnace.get("control", 0))
		+ float(state.get("level", 1)) * 3.0
		+ float(strategy.get("score", 0))
		+ attribute_score
		+ mastery_score
	)
	var probabilities := _probabilities(
		base_score,
		int(strategy.get("spread", 12)),
		clampf(float(furnace.get("safety", 0.0)) + float(strategy.get("safety", 0.0)), 0.0, 1.0)
	)
	var days := maxi(1, int(recipe.get("base_days", 1)) + int(strategy.get("days", 0)))
	var product_count := maxi(1, int(round(
		float(recipe.get("base_yield", 1))
		* (1.0 + float(furnace.get("refinement", 0.0)) + float(strategy.get("yield", 0.0)))
	)))
	return {
		"ok": true,
		"recipe": recipe,
		"strategy": strategy,
		"furnace": furnace,
		"furnace_durability": int(furnace_state.get("durability", 0)),
		"selection_mode": selection_mode,
		"ingredients": selection.get("ingredients", []),
		"average_quality": float(selection.get("average_quality", 1.0)),
		"ingredient_score": ingredient_score,
		"attribute_score": attribute_score,
		"recipe_mastery": recipe_mastery,
		"recipe_mastery_percent": mastery_percent,
		"mastery_score": mastery_score,
		"extra_pill_chance": extra_pill_chance,
		"second_extra_pill_chance": second_extra_pill_chance,
		"max_extra_pills": 2,
		"cost_save_chance": cost_save_chance,
		"base_score": base_score,
		"probabilities": probabilities,
		"success_probability": _success_probability(probabilities),
		"high_quality_probability": _high_quality_probability(probabilities),
		"days": days,
		"product_count": product_count,
		"alchemy_level": int(state.get("level", 1)),
	}


static func roll(preview_data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not bool(preview_data.get("ok", false)):
		return {"ok": false, "error": str(preview_data.get("error", "炼制条件不足"))}
	var strategy := preview_data.get("strategy", {}) as Dictionary
	var furnace := preview_data.get("furnace", {}) as Dictionary
	var spread := int(strategy.get("spread", 12))
	var score := float(preview_data.get("base_score", 0.0))
	score += rng.randi_range(-spread, spread) + rng.randi_range(-spread, spread)
	var quality := _quality_for_score(score)
	var safety := clampf(float(furnace.get("safety", 0.0)) + float(strategy.get("safety", 0.0)), 0.0, 1.0)
	if quality == "none" and rng.randf() < safety:
		quality = "waste"
	var recipe := preview_data.get("recipe", {}) as Dictionary
	var product_id := ""
	var count := 0
	var extra_pills := 0
	if quality == "waste":
		product_id = "items_WasteDan"
		count = 1
	elif quality not in ["none", "waste"]:
		product_id = str((recipe.get("products", {}) as Dictionary).get(quality, ""))
		count = int(preview_data.get("product_count", 1))
		if rng.randf() < float(preview_data.get("extra_pill_chance", 0.0)):
			extra_pills += 1
			if rng.randf() < float(preview_data.get("second_extra_pill_chance", 0.0)):
				extra_pills += 1
		count += extra_pills
	var consumed_ingredients := _roll_consumed_ingredients(
		preview_data.get("ingredients", []) as Array,
		float(preview_data.get("cost_save_chance", 0.0)),
		rng
	)
	var saved_material_count := (
		_ingredient_count(preview_data.get("ingredients", []) as Array)
		- _ingredient_count(consumed_ingredients)
	)
	var xp := maxi(2, int(recipe.get("difficulty", 0)) - int(preview_data.get("alchemy_level", 1)) * 4)
	var xp_scale := {"none": 0.7, "waste": 0.9, "low": 1.0, "medium": 1.1, "high": 1.2, "supreme": 1.4}
	xp = maxi(1, int(round(float(xp) * float(xp_scale.get(quality, 1.0)))))
	var succeeded := quality in ["low", "medium", "high", "supreme"]
	var mastery_gain := maxi(4, int(round(float(recipe.get("difficulty", 0)) * 0.25)))
	if not succeeded:
		mastery_gain = maxi(mastery_gain + 1, int(round(float(mastery_gain) * FAILURE_MASTERY_MULTIPLIER)))
	return {
		"ok": true,
		"quality": quality,
		"quality_name": str(QUALITY_NAMES.get(quality, quality)),
		"succeeded": succeeded,
		"outcome_name": "炼制成功" if succeeded else "炼制失败",
		"score": score,
		"product_id": product_id,
		"count": count,
		"extra_pills": extra_pills,
		"saved_material_count": saved_material_count,
		"days": int(preview_data.get("days", 1)),
		"xp": xp,
		"mastery_gain": mastery_gain,
		"recipe_mastery_before": int(preview_data.get("recipe_mastery", 0)),
		"ingredients": consumed_ingredients,
		"recipe_id": str(recipe.get("id", "")),
		"recipe_name": str(recipe.get("name", "")),
		"pill_name": str(recipe.get("pill_name", "丹药")),
		"strategy_id": str(strategy.get("id", "")),
	}


static func apply_xp(alchemy_state: Dictionary, gained: int) -> Dictionary:
	var state := normalize_state(alchemy_state)
	state["xp"] = int(state.get("xp", 0)) + maxi(0, gained)
	while int(state.get("level", 1)) < 10:
		var needed := int(state.get("level", 1)) * 100
		if int(state.get("xp", 0)) < needed:
			break
		state["xp"] = int(state.get("xp", 0)) - needed
		state["level"] = int(state.get("level", 1)) + 1
	return state


static func mastery_for(alchemy_state: Dictionary, recipe_id: String) -> int:
	var state := normalize_state(alchemy_state)
	return clampi(
		int((state.get("recipe_mastery", {}) as Dictionary).get(recipe_id, 0)),
		0,
		MAX_RECIPE_MASTERY
	)


static func apply_recipe_mastery(alchemy_state: Dictionary, recipe_id: String, gained: int) -> Dictionary:
	var state := normalize_state(alchemy_state)
	var mastery := state.get("recipe_mastery", {}) as Dictionary
	mastery[recipe_id] = clampi(
		int(mastery.get(recipe_id, 0)) + maxi(0, gained),
		0,
		MAX_RECIPE_MASTERY
	)
	state["recipe_mastery"] = mastery
	return state


static func _select_ingredients(recipe: Dictionary, inventory: Dictionary, selection_mode: String) -> Dictionary:
	var chosen: Array = []
	var total_quality := 0.0
	var total_weight := 0.0
	for ingredient_v in recipe.get("ingredients", []) as Array:
		var ingredient := ingredient_v as Dictionary
		var options := (ingredient.get("options", []) as Array).duplicate(true)
		options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("quality", 1)) < int(b.get("quality", 1))
		)
		if selection_mode == "highest":
			options.reverse()
		var count := maxi(1, int(ingredient.get("count", 1)))
		var selected: Dictionary = {}
		for option_v in options:
			var option := option_v as Dictionary
			if int(inventory.get(str(option.get("id", "")), 0)) >= count:
				selected = option
				break
		if selected.is_empty():
			return {"ok": false, "error": "缺少%s x%d" % [str(ingredient.get("family", "药材")), count]}
		var weight := float(ingredient.get("weight", 1))
		chosen.append({
			"id": str(selected.get("id", "")),
			"family": str(ingredient.get("family", "药材")),
			"count": count,
			"quality": int(selected.get("quality", 1)),
		})
		total_quality += float(selected.get("quality", 1)) * weight
		total_weight += weight
	return {
		"ok": true,
		"ingredients": chosen,
		"average_quality": total_quality / maxf(1.0, total_weight),
	}


static func _attribute_score(foundations: Dictionary, aptitudes: Dictionary) -> float:
	var sense := float(foundations.get("sense", 10))
	var comprehension := float(aptitudes.get("comprehension", 10))
	var roots_v: Variant = aptitudes.get("roots", {})
	var roots := roots_v as Dictionary if roots_v is Dictionary else {}
	var root_fit := maxf(float(roots.get("fire", 0)), float(roots.get("wood", 0))) / 100.0 * 3.0
	return minf(10.0, clampf((sense - 10.0) * 0.25, 0.0, 5.0) + clampf((comprehension - 10.0) * 0.2, 0.0, 4.0) + root_fit)


static func _probabilities(base_score: float, spread: int, safety: float) -> Dictionary:
	var counts := {"none": 0.0, "waste": 0.0, "low": 0.0, "medium": 0.0, "high": 0.0, "supreme": 0.0}
	var total := float((spread * 2 + 1) * (spread * 2 + 1))
	for first in range(-spread, spread + 1):
		for second in range(-spread, spread + 1):
			var quality := _quality_for_score(base_score + first + second)
			counts[quality] = float(counts[quality]) + 1.0
	var convertible := float(counts["none"]) * clampf(safety, 0.0, 1.0)
	counts["none"] = float(counts["none"]) - convertible
	counts["waste"] = float(counts["waste"]) + convertible
	for key in counts.keys():
		counts[key] = float(counts[key]) / total
	return counts


static func _success_probability(probabilities: Dictionary) -> float:
	return (
		float(probabilities.get("low", 0.0))
		+ float(probabilities.get("medium", 0.0))
		+ float(probabilities.get("high", 0.0))
		+ float(probabilities.get("supreme", 0.0))
	)


static func _high_quality_probability(probabilities: Dictionary) -> float:
	return (
		float(probabilities.get("high", 0.0))
		+ float(probabilities.get("supreme", 0.0))
	)


static func _roll_consumed_ingredients(ingredients: Array, save_chance: float, rng: RandomNumberGenerator) -> Array:
	var consumed: Array = []
	for ingredient_v in ingredients:
		var ingredient := (ingredient_v as Dictionary).duplicate(true)
		var consumed_count := 0
		for unit in range(maxi(0, int(ingredient.get("count", 0)))):
			if rng.randf() >= save_chance:
				consumed_count += 1
		ingredient["count"] = consumed_count
		consumed.append(ingredient)
	return consumed


static func _ingredient_count(ingredients: Array) -> int:
	var total := 0
	for ingredient_v in ingredients:
		total += maxi(0, int((ingredient_v as Dictionary).get("count", 0)))
	return total


static func _quality_for_score(score: float) -> String:
	if score < 15.0:
		return "none"
	if score < 35.0:
		return "waste"
	if score < 55.0:
		return "low"
	if score < 70.0:
		return "medium"
	if score < 85.0:
		return "high"
	return "supreme"


static func _by_id(rows: Array, target_id: String) -> Dictionary:
	for row_v in rows:
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == target_id:
			return (row_v as Dictionary).duplicate(true)
	return {}


static func _root() -> Dictionary:
	return JsonLoader._read_json_root_object(DATA_PATH)
