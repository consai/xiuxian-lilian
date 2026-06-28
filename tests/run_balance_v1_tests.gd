extends SceneTree

const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const RealmBalanceServiceScript := preload("res://scripts/sim/realm_balance_service.gd")

const RUNS := 200
const STEP := 0.05
const TIME_LIMIT := 60.0

var _failures: Array[String] = []


func _initialize() -> void:
	AbilityServiceScript.reload()
	RealmBalanceServiceScript.reload()
	var config := RealmBalanceServiceScript.bundle()
	var acceptance := config.get("acceptance", {}) as Dictionary
	var qi_normal := _run_scenario(config, "qi_early", "qi_normal")
	var qi_elite := _run_scenario(config, "qi_early", "qi_elite")
	var cross_realm := _run_scenario(config, "qi_mature", "foundation_normal")
	_print_result("qi_early_vs_normal", qi_normal)
	_print_result("qi_early_vs_elite", qi_elite)
	_print_result("qi_mature_vs_foundation_normal", cross_realm)
	_expect_between(
		float(qi_normal["win_rate"]),
		float(acceptance["normal_win_rate_min"]),
		float(acceptance["normal_win_rate_max"]),
		"normal win rate"
	)
	_expect_between(
		float(qi_normal["duration"]),
		float(acceptance["normal_duration_sec_min"]),
		float(acceptance["normal_duration_sec_max"]),
		"normal duration"
	)
	_expect_between(
		float(qi_elite["win_rate"]),
		float(acceptance["elite_win_rate_min"]),
		float(acceptance["elite_win_rate_max"]),
		"elite win rate"
	)
	_expect_between(
		float(qi_normal["winning_hp_ratio"]),
		float(acceptance["resource_remaining_ratio_min"]),
		float(acceptance["resource_remaining_ratio_max"]),
		"normal winning hp ratio"
	)
	if float(cross_realm["win_rate"]) >= float(acceptance["qi_mature_vs_foundation_normal_win_rate_max"]):
		_failures.append("cross-realm win rate must stay below %.2f" % acceptance["qi_mature_vs_foundation_normal_win_rate_max"])
	if _failures.is_empty():
		print("PASS: balance_v1 deterministic benchmarks")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _run_scenario(config: Dictionary, player_id: String, enemy_id: String) -> Dictionary:
	var player_row := (config.get("standard_players", {}) as Dictionary).get(player_id, {}) as Dictionary
	var enemy_row := ((config.get("benchmark_enemies", {}) as Dictionary).get(enemy_id, {}) as Dictionary).duplicate(true)
	var enemy_attrs := (enemy_row.get("attrs", {}) as Dictionary).duplicate(true)
	var wins := 0
	var total_duration := 0.0
	var total_hp_ratio := 0.0
	var total_mp_ratio := 0.0
	var winning_hp_ratio := 0.0
	var winning_mp_ratio := 0.0
	for run_index in RUNS:
		seed(20260612 + run_index)
		var player_attrs := CharacterStatsScript.build_combat_attrs(player_row.get("foundations", {}))
		var result := _simulate(player_attrs, enemy_attrs)
		if bool(result["win"]):
			wins += 1
			winning_hp_ratio += float(result["hp_ratio"])
			winning_mp_ratio += float(result["mp_ratio"])
		total_duration += float(result["duration"])
		total_hp_ratio += float(result["hp_ratio"])
		total_mp_ratio += float(result["mp_ratio"])
	return {
		"win_rate": float(wins) / float(RUNS),
		"duration": total_duration / float(RUNS),
		"hp_ratio": total_hp_ratio / float(RUNS),
		"mp_ratio": total_mp_ratio / float(RUNS),
		"winning_hp_ratio": winning_hp_ratio / float(maxi(1, wins)),
		"winning_mp_ratio": winning_mp_ratio / float(maxi(1, wins)),
	}


func _simulate(player_attrs: Dictionary, enemy_attrs: Dictionary) -> Dictionary:
	var player_hp := float(player_attrs[ZhandouAttr.HP_MAX])
	var player_mp := float(player_attrs[ZhandouAttr.MP_MAX])
	var enemy_hp := float(enemy_attrs["hp_max"])
	var player_progress := 0.0
	var enemy_progress := 0.0
	var skill_cd := 0.0
	var skill := AbilityServiceScript.to_runtime_dict("ability.combat.qi_bolt", {"knowledge": {}})
	var elapsed := 0.0
	while elapsed < TIME_LIMIT and player_hp > 0.0 and enemy_hp > 0.0:
		elapsed += STEP
		skill_cd = maxf(0.0, skill_cd - STEP)
		player_progress += ZhandouBalance.action_progress_rate_from_spd(float(player_attrs[ZhandouAttr.SPD])) * STEP
		enemy_progress += ZhandouBalance.action_progress_rate_from_spd(float(enemy_attrs["spd"])) * STEP
		if player_progress >= ZhandouBalance.ACTION_PROGRESS_MAX:
			player_progress -= ZhandouBalance.ACTION_PROGRESS_MAX
			var use_skill := skill_cd <= 0.0 and player_mp >= float(skill["mp_cost"])
			var hit := ZhandouAttr.calc_skill_damage(
				player_attrs,
				enemy_attrs,
				float(skill["power"]) / 1000.0 if use_skill else 1.0,
				float(((skill["effects"] as Array)[0] as Dictionary)["value"]) if use_skill else 0.0,
				ZhandouAttr.DAMAGE_MAGIC if use_skill else ZhandouAttr.DAMAGE_PHYSICAL
			)
			enemy_hp -= float(hit["damage"])
			if use_skill:
				player_mp -= float(skill["mp_cost"])
				skill_cd = float(skill["cd"])
		if enemy_hp <= 0.0:
			break
		if enemy_progress >= ZhandouBalance.ACTION_PROGRESS_MAX:
			enemy_progress -= ZhandouBalance.ACTION_PROGRESS_MAX
			player_hp -= float(ZhandouAttr.calc_basic_damage(enemy_attrs, player_attrs)["damage"])
	return {
		"win": enemy_hp <= 0.0 and player_hp > 0.0,
		"duration": elapsed,
		"hp_ratio": maxf(0.0, player_hp) / float(player_attrs[ZhandouAttr.HP_MAX]),
		"mp_ratio": maxf(0.0, player_mp) / float(player_attrs[ZhandouAttr.MP_MAX]),
	}


func _print_result(label: String, result: Dictionary) -> void:
	print("%s: win=%.3f duration=%.2f hp=%.3f mp=%.3f win_hp=%.3f win_mp=%.3f" % [
		label, result["win_rate"], result["duration"], result["hp_ratio"], result["mp_ratio"],
		result["winning_hp_ratio"], result["winning_mp_ratio"],
	])


func _expect_between(actual: float, minimum: float, maximum: float, label: String) -> void:
	if actual < minimum or actual > maximum:
		_failures.append("%s expected %.3f..%.3f, got %.3f" % [label, minimum, maximum, actual])
