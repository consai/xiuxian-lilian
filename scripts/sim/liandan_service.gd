class_name LiandanService
extends RefCounted

const DATA_PATH := "res://data/exportjson/liandan.json"
const MAX_RECIPE_MASTERY := 1000
const MASTERY_SCORE_MAX := 20.0
const MASTERY_EXTRA_PILL_CHANCE_MAX := 0.75
const MASTERY_SECOND_EXTRA_PILL_CHANCE_MAX := 0.30
const MASTERY_COST_SAVE_CHANCE_MAX := 0.35
const FAILURE_MASTERY_MULTIPLIER := 1.5
const DEFAULT_BASE_YIELD := 2
const GameTimeServiceScript := preload("res://scripts/sim/game_time_service.gd")
const EnumActivityTimeScript := preload("res://scripts/enum/enum_activity_time.gd")
const LiandanStateScript := preload("res://scripts/features/alchemy/domain/liandan_state.gd")


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


static func recipe_preview_product_id(recipe: Dictionary) -> String:
	var products_v: Variant = recipe.get("products", {})
	if not products_v is Dictionary:
		return ""
	var products := products_v as Dictionary
	for quality in EnumLiandanQuality.PRODUCT_SCAN_LABELS:
		if products.has(quality):
			return str(products.get(quality, ""))
	return ""


static func preview(
	recipe_id: String,
	strategy_id: String,
	selection_mode: String,
	liandan_state: Dictionary,
	inventory: Dictionary,
	foundations: Dictionary,
	aptitudes: Dictionary,
	major_realm_id: String
) -> Dictionary:
	var recipe := recipe_by_id(recipe_id)
	var strategy := strategy_by_id(strategy_id)
	if recipe.is_empty() or strategy.is_empty():
		return {"ok": false, "error": "未知丹方或炼制策略"}
	var state := LiandanStateScript.prepare(liandan_state)
	if state.is_empty():
		return {"ok": false, "error": "炼丹状态不符合当前 schema"}
	if not (state.get("known_recipes", []) as Array).has(recipe_id):
		return {"ok": false, "error": "尚未掌握该丹方", "recipe": recipe}
	var selection := _select_ingredients(recipe, inventory, selection_mode)
	var ingredients := selection.get("ingredients", []) as Array
	if int(state.get("level", 1)) < int(recipe.get("minimum_level", 1)):
		return {
			"ok": false,
			"error": "炼丹术等级不足",
			"recipe": recipe,
			"ingredients": ingredients,
		}
	var furnace_id := str(state.get("equipped_furnace", ""))
	var furnace := furnace_by_id(furnace_id)
	var owned := state.get("owned_furnaces", {}) as Dictionary
	var furnace_state_v: Variant = owned.get(furnace_id, {})
	var furnace_state := furnace_state_v as Dictionary if furnace_state_v is Dictionary else {}
	if furnace.is_empty() or int(furnace_state.get("durability", 0)) <= 0:
		return {
			"ok": false,
			"error": "当前丹炉不可用",
			"recipe": recipe,
			"ingredients": ingredients,
		}
	if not bool(selection.get("ok", false)):
		return {
			"ok": false,
			"error": str(selection.get("error", "药材不足")),
			"recipe": recipe,
			"ingredients": ingredients,
		}
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
	var spread_bounds := _strategy_spread_bounds(strategy)
	var probabilities := _probabilities(
		base_score,
		spread_bounds[0],
		spread_bounds[1],
		clampf(float(furnace.get("safety", 0.0)) + float(strategy.get("safety", 0.0)), 0.0, 1.0)
	)
	var activity_days := GameTimeServiceScript.days_for_activity(
		EnumActivityTimeScript.LABEL_LIANDAN,
		major_realm_id,
		1.0,
		1.0
	)
	var days := maxi(1, activity_days + int(strategy.get("days", 0)))
	var product_count := maxi(1, int(round(
		float(recipe.get("base_yield", DEFAULT_BASE_YIELD))
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
		"duration_label": GameTimeServiceScript.duration_label(days),
		"product_count": product_count,
		"liandan_level": int(state.get("level", 1)),
	}


static func max_batch_count(preview_data: Dictionary, inventory: Dictionary, liandan_state: Dictionary) -> int:
	if not bool(preview_data.get("ok", false)):
		return 0
	var max_batches := 1_000_000
	for ingredient_v in preview_data.get("ingredients", []) as Array:
		var ingredient := ingredient_v as Dictionary
		var required := maxi(1, int(ingredient.get("count", 1)))
		var owned := int(inventory.get(str(ingredient.get("id", "")), 0))
		max_batches = mini(max_batches, owned / required)
	var state := LiandanStateScript.prepare(liandan_state)
	if state.is_empty():
		return 0
	var furnace_id := str(state.get("equipped_furnace", ""))
	var owned_furnaces := state.get("owned_furnaces", {}) as Dictionary
	var furnace_state_v: Variant = owned_furnaces.get(furnace_id, {})
	var furnace_state := furnace_state_v as Dictionary if furnace_state_v is Dictionary else {}
	max_batches = mini(max_batches, int(furnace_state.get("durability", 0)))
	return maxi(0, max_batches)


static func aggregate_batch_results(results: Array) -> Dictionary:
	if results.is_empty():
		return {"ok": false, "error": "没有炼丹结果"}
	var first := results[0] as Dictionary
	var quality_counts := {}
	var product_totals := {}
	var total_xp := 0
	var total_mastery := 0
	var total_days := 0
	var total_extra_pills := 0
	var total_saved := 0
	var total_score := 0.0
	var success_count := 0
	var best_quality := EnumLiandanQuality.LABEL_NONE
	var best_rank := -1
	var last := first
	for result_v in results:
		var result := result_v as Dictionary
		last = result
		var quality := str(result.get("quality", "none"))
		quality_counts[quality] = int(quality_counts.get(quality, 0)) + 1
		var rank := EnumLiandanQuality.rank(quality)
		if rank > best_rank:
			best_rank = rank
			best_quality = quality
		if bool(result.get("succeeded", false)):
			success_count += 1
		var product_id := str(result.get("product_id", ""))
		var count := int(result.get("added", result.get("count", 0)))
		if product_id != "" and count > 0:
			product_totals[product_id] = int(product_totals.get(product_id, 0)) + count
		total_xp += int(result.get("xp", 0))
		total_mastery += int(result.get("mastery_gain", 0))
		total_days += int(result.get("days", 0))
		total_extra_pills += int(result.get("extra_pills", 0))
		total_saved += int(result.get("saved_material_count", 0))
		total_score += float(result.get("score", 0.0))
	var summary_parts: PackedStringArray = []
	for quality_key in EnumLiandanQuality.SUMMARY_LABELS:
		var amount := int(quality_counts.get(quality_key, 0))
		if amount <= 0:
			continue
		summary_parts.append("%s×%d" % [EnumLiandanQuality.display_name(quality_key), amount])
	var showcase_product_id := ""
	var showcase_count := 0
	for product_id_v in product_totals.keys():
		var product_id := str(product_id_v)
		var amount := int(product_totals.get(product_id_v, 0))
		if amount > showcase_count:
			showcase_count = amount
			showcase_product_id = product_id
	return {
		"ok": true,
		"batch_count": results.size(),
		"quality": best_quality,
		"quality_name": EnumLiandanQuality.display_name(best_quality),
		"succeeded": success_count > 0,
		"outcome_name": "炼制成功" if success_count > 0 else "炼制失败",
		"success_count": success_count,
		"quality_summary": " · ".join(summary_parts),
		"product_totals": product_totals,
		"product_id": showcase_product_id,
		"count": showcase_count,
		"added": showcase_count,
		"score": total_score / float(results.size()),
		"xp": total_xp,
		"mastery_gain": total_mastery,
		"days": total_days,
		"extra_pills": total_extra_pills,
		"saved_material_count": total_saved,
		"ingredients": last.get("ingredients", []),
		"recipe_id": str(first.get("recipe_id", "")),
		"recipe_name": str(first.get("recipe_name", "")),
		"pill_name": str(first.get("pill_name", "丹药")),
		"strategy_id": str(first.get("strategy_id", "")),
		"recipe_mastery_before": int(first.get("recipe_mastery_before", 0)),
	}


static func roll(preview_data: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not bool(preview_data.get("ok", false)):
		return {"ok": false, "error": str(preview_data.get("error", "炼制条件不足"))}
	var strategy := preview_data.get("strategy", {}) as Dictionary
	var spread_bounds := _strategy_spread_bounds(strategy)
	var spread_down: int = spread_bounds[0]
	var spread_up: int = spread_bounds[1]
	var score := float(preview_data.get("base_score", 0.0))
	score += rng.randi_range(-spread_down, spread_up) + rng.randi_range(-spread_down, spread_up)
	var quality := _quality_for_score(score)
	# 必成丹：无产物与废丹统一降为下品，不再产出废丹
	if quality in [EnumLiandanQuality.LABEL_NONE, EnumLiandanQuality.LABEL_WASTE]:
		quality = EnumLiandanQuality.LABEL_LOW
	var recipe := preview_data.get("recipe", {}) as Dictionary
	var product_id := str((recipe.get("products", {}) as Dictionary).get(quality, ""))
	var extra_pills := 0
	var count := int(preview_data.get("product_count", DEFAULT_BASE_YIELD))
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
	var xp := maxi(2, int(recipe.get("difficulty", 0)) - int(preview_data.get("liandan_level", 1)) * 4)
	xp = maxi(1, int(round(float(xp) * EnumLiandanQuality.xp_scale(quality))))
	var succeeded := EnumLiandanQuality.is_success(quality)
	var mastery_gain := maxi(4, int(round(float(recipe.get("difficulty", 0)) * 0.25)))
	if not succeeded:
		mastery_gain = maxi(mastery_gain + 1, int(round(float(mastery_gain) * FAILURE_MASTERY_MULTIPLIER)))
	return {
		"ok": true,
		"quality": quality,
		"quality_name": EnumLiandanQuality.display_name(quality),
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


static func apply_xp(liandan_state: Dictionary, gained: int) -> Dictionary:
	var state := LiandanStateScript.prepare(liandan_state)
	if state.is_empty():
		return {}
	state["xp"] = int(state.get("xp", 0)) + maxi(0, gained)
	while int(state.get("level", 1)) < 10:
		var needed := int(state.get("level", 1)) * 100
		if int(state.get("xp", 0)) < needed:
			break
		state["xp"] = int(state.get("xp", 0)) - needed
		state["level"] = int(state.get("level", 1)) + 1
	return state


static func mastery_for(liandan_state: Dictionary, recipe_id: String) -> int:
	var state := LiandanStateScript.prepare(liandan_state)
	if state.is_empty():
		return 0
	return clampi(
		int((state.get("recipe_mastery", {}) as Dictionary).get(recipe_id, 0)),
		0,
		MAX_RECIPE_MASTERY
	)


static func apply_recipe_mastery(liandan_state: Dictionary, recipe_id: String, gained: int) -> Dictionary:
	var state := LiandanStateScript.prepare(liandan_state)
	if state.is_empty():
		return {}
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
	var first_error := ""
	var all_ok := true
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
		var sufficient := not selected.is_empty()
		if not sufficient:
			all_ok = false
			if first_error == "":
				first_error = "缺少%s x%d" % [str(ingredient.get("family", "药材")), count]
			if not options.is_empty():
				selected = options[0] as Dictionary
		chosen.append({
			"id": str(selected.get("id", "")),
			"family": str(ingredient.get("family", "药材")),
			"count": count,
			"quality": int(selected.get("quality", 1)),
			"sufficient": sufficient,
		})
		if sufficient:
			var weight := float(ingredient.get("weight", 1))
			total_quality += float(selected.get("quality", 1)) * weight
			total_weight += weight
	var result := {
		"ok": all_ok,
		"ingredients": chosen,
		"average_quality": total_quality / maxf(1.0, total_weight) if total_weight > 0.0 else 1.0,
	}
	if not all_ok:
		result["error"] = first_error
	return result


static func _attribute_score(foundations: Dictionary, aptitudes: Dictionary) -> float:
	var shenshi := float(foundations.get("shenshi", foundations.get("sense", 10)))
	var comprehension := float(aptitudes.get("comprehension", 10))
	var roots_v: Variant = aptitudes.get("roots", {})
	var roots := roots_v as Dictionary if roots_v is Dictionary else {}
	var root_fit := maxf(float(roots.get("fire", 0)), float(roots.get("wood", 0))) / 100.0 * 3.0
	return minf(10.0, clampf((shenshi - 10.0) * 0.25, 0.0, 5.0) + clampf((comprehension - 10.0) * 0.2, 0.0, 4.0) + root_fit)


static func _strategy_spread_bounds(strategy: Dictionary) -> Array:
	var spread := int(strategy.get("spread", 12))
	return [
		int(strategy.get("spread_down", spread)),
		int(strategy.get("spread_up", spread)),
	]


static func _probabilities(base_score: float, spread_down: int, spread_up: int, _safety: float) -> Dictionary:
	var counts := EnumLiandanQuality.empty_probability_counts()
	var span := spread_down + spread_up + 1
	var total := float(span * span)
	for first in range(-spread_down, spread_up + 1):
		for second in range(-spread_down, spread_up + 1):
			var quality := _quality_for_score(base_score + first + second)
			counts[quality] = float(counts[quality]) + 1.0
	# ponytail: 失败/废丹概率并入下品，预览与 roll 必成丹一致；safety 参数保留签名兼容
	var failure_mass := (
		float(counts[EnumLiandanQuality.LABEL_NONE])
		+ float(counts[EnumLiandanQuality.LABEL_WASTE])
	)
	counts[EnumLiandanQuality.LABEL_NONE] = 0.0
	counts[EnumLiandanQuality.LABEL_WASTE] = 0.0
	counts[EnumLiandanQuality.LABEL_LOW] = float(counts[EnumLiandanQuality.LABEL_LOW]) + failure_mass
	for key in counts.keys():
		counts[key] = float(counts[key]) / total
	return counts


static func _success_probability(probabilities: Dictionary) -> float:
	return (
		float(probabilities.get(EnumLiandanQuality.LABEL_LOW, 0.0))
		+ float(probabilities.get(EnumLiandanQuality.LABEL_MEDIUM, 0.0))
		+ float(probabilities.get(EnumLiandanQuality.LABEL_HIGH, 0.0))
		+ float(probabilities.get(EnumLiandanQuality.LABEL_SUPREME, 0.0))
	)


static func _high_quality_probability(probabilities: Dictionary) -> float:
	return (
		float(probabilities.get(EnumLiandanQuality.LABEL_HIGH, 0.0))
		+ float(probabilities.get(EnumLiandanQuality.LABEL_SUPREME, 0.0))
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
	return EnumLiandanQuality.quality_for_score(score)


static func _by_id(rows: Array, target_id: String) -> Dictionary:
	for row_v in rows:
		if row_v is Dictionary and str((row_v as Dictionary).get("id", "")) == target_id:
			return (row_v as Dictionary).duplicate(true)
	return {}


static func _root() -> Dictionary:
	return JsonLoader.load_liandan_bundle()
