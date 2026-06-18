extends SceneTree

const BattleDomainServiceScript := preload("res://scripts/fight/battle_domain_service.gd")
const FightObjScript := preload("res://scripts/fight/fightObj.gd")
const CombatEventScript := preload("res://scripts/fight/combat_event.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const EnemyIntentPreviewScript := preload("res://scripts/fight/enemy_intent_preview.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	BattleDebugLog.enabled = false
	_run("advancing uses one simulation clock", _test_advancing_uses_one_simulation_clock)
	_run("paused freezes simulation clock", _test_paused_freezes_simulation_clock)
	_run("presentation freezes simulation clock", _test_presentation_freezes_simulation_clock)
	_run("simultaneous ready gives player priority", _test_simultaneous_ready_gives_player_priority)
	_run("action resets actor and preserves opponent progress", _test_action_resets_actor_and_preserves_opponent_progress)
	_run("dot death ends battle during advancing", _test_dot_death_ends_battle_during_advancing)
	_run("time limit counts advancing only", _test_time_limit_counts_advancing_only)
	_run("physical and magic damage use matching defense", _test_damage_types_use_matching_defense)
	_run("true damage bypasses defense", _test_true_damage_bypasses_defense)
	_run("non mana ability costs are paid", _test_non_mana_ability_costs_are_paid)
	_run("skill slot scales runtime effects", _test_skill_slot_scales_runtime_effects)
	_run("accuracy and evasion affect hit chance", _test_accuracy_evasion_hit_chance)
	_run("control attributes affect status chance", _test_control_attributes_status_chance)
	_run("effect scaling uses combat attributes", _test_effect_scaling)
	_run("action progress advances from current speed", _test_action_progress_uses_current_speed)
	_run("one player can fight multiple enemies", _test_one_player_can_fight_multiple_enemies)
	_run("enemy formation defaults to five rows and centers small groups", _test_enemy_formation_centers_small_groups)
	_run("enemy formation only advances active column", _test_enemy_formation_only_advances_active_column)
	_run("enemy formation compacts rows and reserves", _test_enemy_formation_compacts_rows_and_reserves)
	_run("cultivation method restores mp every two seconds", _test_method_mp_recovery)
	_run("skill damage supports pierce and vulnerability", _test_pierce_and_vulnerability)
	_run("runtime modifier expires cleanly", _test_runtime_modifier_expires)
	_run("qi and foundation active abilities resolve effects", _test_v1_abilities_resolve_effects)
	_run("knowledge growth interpolates from base to maximum", _test_knowledge_growth)
	_run("intent preview subtracts defender shield", _test_intent_preview_subtracts_shield)
	_run("intent preview honors slot effect scale", _test_intent_preview_honors_slot_effect_scale)

	if _failures.is_empty():
		print("PASS: %d battle domain tests" % _tests_run)
		quit(0)
		return

	printerr("FAIL: %d of %d battle domain tests failed" % [_failures.size(), _tests_run])
	for failure in _failures:
		printerr("  - %s" % failure)
	quit(1)


func _run(test_name: String, test: Callable) -> void:
	_tests_run += 1
	var before := _failures.size()
	test.call()
	if _failures.size() == before:
		print("PASS: %s" % test_name)


func _test_advancing_uses_one_simulation_clock() -> void:
	var player := _make_unit(100.0, 100.0, 5.0)
	var enemy := _make_unit()
	player.buffs["test_dot"] = _runtime_dot(3.0, 1.0, 10.0)
	var domain := _start_domain(player, enemy)

	_expect_eq(domain.tick_advancing(1.0), "", "one second should not fill an action bar")
	_expect_near(domain.battle_elapsed_advancing, 1.0, "advancing time")
	_expect_near(domain.interval_elapsed_player, 83.333333, "player action progress")
	_expect_near(domain.interval_elapsed_enemy, 83.333333, "enemy action progress")
	_expect_near(player.get_skill_cd(1), 4.0, "skill cooldown")
	_expect_near(float((player.buffs["test_dot"] as Dictionary)["duration_left"]), 2.0, "buff duration")
	_expect_near(player.hp, 90.0, "dot damage")


func _test_paused_freezes_simulation_clock() -> void:
	var player := _make_unit(100.0, 100.0, 5.0)
	var enemy := _make_unit()
	player.buffs["test_dot"] = _runtime_dot(3.0, 1.0, 10.0)
	var domain := _start_domain(player, enemy)
	domain.enter_paused(EnumBattleSide.PLAYER)

	_expect_eq(domain.tick_advancing(10.0), "", "paused tick should be ignored")
	_expect_near(domain.battle_elapsed_advancing, 0.0, "paused advancing time")
	_expect_near(player.get_skill_cd(1), 5.0, "paused cooldown")
	_expect_near(float((player.buffs["test_dot"] as Dictionary)["duration_left"]), 3.0, "paused buff duration")
	_expect_near(player.hp, 100.0, "paused dot damage")


func _test_presentation_freezes_simulation_clock() -> void:
	var player := _make_unit(100.0, 100.0, 5.0)
	var enemy := _make_unit()
	player.buffs["test_dot"] = _runtime_dot(3.0, 1.0, 10.0)
	var domain := _start_domain(player, enemy)
	domain.enter_paused(EnumBattleSide.PLAYER)
	domain.begin_presentation(EnumBattleSide.PLAYER)

	_expect_eq(domain.tick_advancing(10.0), "", "presentation tick should be ignored")
	_expect_near(domain.battle_elapsed_advancing, 0.0, "presentation advancing time")
	_expect_near(player.get_skill_cd(1), 5.0, "presentation cooldown")
	_expect_near(float((player.buffs["test_dot"] as Dictionary)["duration_left"]), 3.0, "presentation buff duration")
	_expect_near(player.hp, 100.0, "presentation dot damage")


func _test_simultaneous_ready_gives_player_priority() -> void:
	var domain := _start_domain(_make_unit(), _make_unit())
	var cap := domain.interval_T_player
	var ready_time := CombatBalance.interval_cap_for(domain.player)

	_expect_near(cap, domain.interval_T_enemy, "test units should have equal action intervals")
	_expect_eq(
		domain.tick_advancing(ready_time),
		BattleDomainServiceScript.SIGNAL_PLAYER_READY,
		"player should win simultaneous ready"
	)


func _test_action_resets_actor_and_preserves_opponent_progress() -> void:
	var domain := _start_domain(_make_unit(), _make_unit())
	var cap := domain.interval_T_player
	var ready_time := CombatBalance.interval_cap_for(domain.player)
	_expect_eq(domain.tick_advancing(ready_time), BattleDomainServiceScript.SIGNAL_PLAYER_READY, "player ready")
	domain.enter_paused(EnumBattleSide.PLAYER)
	var payload := domain.resolve_player_basic()
	_expect_true(bool(payload.get("ok", false)), "player basic attack should resolve")
	domain.begin_presentation(EnumBattleSide.PLAYER)
	domain.finish_presentation()

	_expect_near(domain.interval_elapsed_player, 0.0, "actor action bar reset")
	_expect_near(domain.interval_elapsed_enemy, cap, "opponent action bar preserved")
	_expect_eq(
		domain.tick_advancing(0.01),
		BattleDomainServiceScript.SIGNAL_ENEMY_READY,
		"preserved opponent should act next"
	)


func _test_dot_death_ends_battle_during_advancing() -> void:
	var enemy := _make_unit(5.0)
	enemy.buffs["fatal_dot"] = _runtime_dot(2.0, 1.0, 10.0)
	var domain := _start_domain(_make_unit(), enemy)

	_expect_eq(
		domain.tick_advancing(1.0),
		BattleDomainServiceScript.SIGNAL_ENEMY_DEAD,
		"fatal dot should end battle"
	)
	_expect_eq(domain.state, EnumBattleState.State.END, "fatal dot end state")


func _test_time_limit_counts_advancing_only() -> void:
	var domain := _start_domain(_make_unit(), _make_unit(), 2.0)
	domain.enter_paused(EnumBattleSide.PLAYER)
	domain.tick_advancing(100.0)
	_expect_near(domain.battle_elapsed_advancing, 0.0, "paused time limit")
	domain.begin_presentation(EnumBattleSide.PLAYER)
	domain.tick_advancing(100.0)
	_expect_near(domain.battle_elapsed_advancing, 0.0, "presentation time limit")
	domain.finish_presentation()

	_expect_eq(
		domain.tick_advancing(2.0),
		BattleDomainServiceScript.SIGNAL_TIME_LIMIT,
		"time limit should count advancing time"
	)
	_expect_eq(domain.state, EnumBattleState.State.END, "time limit end state")


func _test_damage_types_use_matching_defense() -> void:
	var attacker := {
		FightAttr.PHYSICAL_ATK: 100.0,
		FightAttr.MAGIC_ATK: 100.0,
		FightAttr.CRIT: 0.0,
		FightAttr.CRIT_DAMAGE: 150.0,
	}
	var defender := {
		FightAttr.PHYSICAL_DEF: 100.0,
		FightAttr.MAGIC_DEF: 300.0,
	}
	var physical := FightAttr.calc_basic_damage(attacker, defender)
	var magic := FightAttr.calc_skill_damage(attacker, defender, 1.0, 0.0, FightAttr.DAMAGE_MAGIC)
	_expect_near(float(physical["damage"]), 50.0, "physical soft mitigation")
	_expect_near(float(magic["damage"]), 25.0, "magic soft mitigation")


func _test_true_damage_bypasses_defense() -> void:
	var attacker := {
		FightAttr.PHYSICAL_ATK: 100.0,
		FightAttr.MAGIC_ATK: 80.0,
		FightAttr.CRIT: 0.0,
		FightAttr.CRIT_DAMAGE: 150.0,
	}
	var defender := {
		FightAttr.PHYSICAL_DEF: 999.0,
		FightAttr.MAGIC_DEF: 999.0,
	}
	var hit := FightAttr.calc_skill_damage(attacker, defender, 1.0, 20.0, FightAttr.DAMAGE_TRUE)
	_expect_near(float(hit["damage"]), 120.0, "true damage ignores defense but keeps attack scaling")


func _test_non_mana_ability_costs_are_paid() -> void:
	AbilityServiceScript.reload()
	var skill := AbilityServiceScript.to_runtime_dict("ability.combat.blood_strike", {"knowledge": {}})
	_expect_near(float(skill.get("mp_cost", 0.0)), 18.0, "stamina costs enter runtime resource budget")
	var player := _make_unit(100.0, 100.0)
	player.mp = 20.0
	player.skills = [{"id": int(skill.get("id", -1)), "cd": 0.0, "cd_total": float(skill.get("cd", 0.0))}]
	var enemy := _make_unit(100.0, 100.0)
	enemy.attrs[FightAttr.EVASION] = 0.0
	player.attrs[FightAttr.ACCURACY] = 999.0
	var used := player.use_skill(int(skill.get("id", -1)), {int(skill.get("id", -1)): skill}, enemy)
	_expect_true(bool(used.get("ok", false)), "stamina-cost skill resolves")
	_expect_near(player.mp, 2.0, "stamina-cost skill consumes shared combat resource")


func _test_skill_slot_scales_runtime_effects() -> void:
	var unscaled := _make_unit(100.0, 100.0)
	var scaled := _make_unit(100.0, 100.0)
	scaled.skills = [{"id": 1, "cd": 0.0, "effect_value_scale": 0.45}]
	for unit in [unscaled, scaled]:
		unit.attrs[FightAttr.MAGIC_ATK] = 10.0
		unit.attrs[FightAttr.ACCURACY] = 999.0
	var unscaled_target := _make_unit(200.0, 100.0)
	var scaled_target := _make_unit(200.0, 100.0)
	for target in [unscaled_target, scaled_target]:
		target.attrs[FightAttr.HP_MAX] = 200.0
		target.attrs[FightAttr.MAGIC_DEF] = 24.0
		target.attrs[FightAttr.EVASION] = 0.0
	var cfg := {
		1: {
			"mp_cost": 0.0,
			"cd": 0.0,
			"power": 1000.0,
			"effects": [
				{"type": "damage", "value": 40.0, "damage_type": FightAttr.DAMAGE_MAGIC, "can_miss": false},
			],
		},
	}
	var raw_hit := unscaled.use_skill(1, cfg, unscaled_target)
	var scaled_hit := scaled.use_skill(1, cfg, scaled_target)
	_expect_true(bool(raw_hit.get("ok", false)), "unscaled skill resolves")
	_expect_true(bool(scaled_hit.get("ok", false)), "scaled skill resolves")
	_expect_true(
		float(scaled_hit.get("damage", 0.0)) < float(raw_hit.get("damage", 0.0)) * 0.65,
		"slot effect scale lowers fixed damage"
	)


func _test_accuracy_evasion_hit_chance() -> void:
	var accurate := {FightAttr.ACCURACY: 300.0}
	var evasive := {FightAttr.EVASION: 300.0}
	var normal := {FightAttr.ACCURACY: 100.0, FightAttr.EVASION: 100.0}
	_expect_near(FightAttr.hit_chance(normal, normal), 0.85, "equal rating hit chance")
	_expect_true(
		FightAttr.hit_chance(accurate, {FightAttr.EVASION: 50.0})
		> FightAttr.hit_chance({FightAttr.ACCURACY: 50.0}, evasive),
		"accuracy should improve hit chance"
	)


func _test_control_attributes_status_chance() -> void:
	var strong := {FightAttr.CONTROL_POWER: 300.0}
	var weak_resist := {FightAttr.CONTROL_RESIST: 50.0}
	var weak := {FightAttr.CONTROL_POWER: 50.0}
	var strong_resist := {FightAttr.CONTROL_RESIST: 300.0}
	_expect_true(
		FightAttr.control_chance(strong, weak_resist, 0.6)
		> FightAttr.control_chance(weak, strong_resist, 0.6),
		"control power should improve status chance"
	)


func _test_effect_scaling() -> void:
	var unit := _make_unit()
	unit.attrs[FightAttr.MAGIC_ATK] = 40.0
	unit.mp = 100.0
	var cfg := {
		1: {
			"mp_cost": 0.0,
			"cd": 0.0,
			"effects": [
				{"type": "shield", "value": 10.0, "scaling": {FightAttr.MAGIC_ATK: 1.5}, "target": "self"},
			],
		},
	}
	var used := unit.use_skill(1, cfg)
	_expect_true(bool(used.get("ok", false)), "scaled shield skill should resolve")
	_expect_near(unit.get_attr(FightAttr.SHIELD), 70.0, "scaled shield amount")


func _test_action_progress_uses_current_speed() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemy := _make_unit(100.0, 1.0)
	var domain := _start_domain(player, enemy)
	_expect_eq(domain.tick_advancing(0.6), "", "half interval should not ready")
	_expect_near(domain.interval_elapsed_player, 50.0, "half progress at speed 100")
	player.set_attr(FightObjScript.ATTR_SPD, 50.0)
	var snapshot := domain.get_ui_snapshot().get("intervals", {}) as Dictionary
	var left := snapshot.get("left", {}) as Dictionary
	_expect_near(float(left.get("elapsed", 0.0)), 50.0, "speed change preserves accumulated progress")
	_expect_near(float(left.get("cap", 0.0)), 100.0, "progress cap stays fixed")
	_expect_eq(domain.tick_advancing(0.6), "", "slowed unit should not ready")
	_expect_near(domain.interval_elapsed_player, 75.0, "slow speed advances less per second")
	player.set_attr(FightObjScript.ATTR_SPD, 200.0)
	_expect_eq(
		domain.tick_advancing(0.15),
		BattleDomainServiceScript.SIGNAL_PLAYER_READY,
		"speeding up should immediately accelerate progress"
	)


func _test_one_player_can_fight_multiple_enemies() -> void:
	var player := _make_unit(100.0, 100.0)
	player.attrs[FightObjScript.ATTR_PHYSICAL_ATK] = 200.0
	player.attrs[FightAttr.ACCURACY] = 999.0
	var first := _make_unit(1.0, 80.0)
	first.attrs[FightAttr.EVASION] = 0.0
	var second := _make_unit(40.0, 80.0)
	second.attrs[FightAttr.EVASION] = 0.0
	var domain := BattleDomainServiceScript.new()
	domain.start_battle_many(player, [first, second], {}, 200.0)
	domain.enter_paused(EnumBattleSide.PLAYER)
	var payload := domain.resolve_player_basic()
	_expect_true(bool(payload.get("ok", false)), "player should hit first enemy")
	_expect_true(first.is_dead(), "first enemy should die")
	_expect_eq(domain.check_end_after_resolve(), "", "battle should continue while another enemy is alive")
	_expect_eq(domain.active_enemy_index, 1, "active target should move to second enemy")
	_expect_true(domain.enemy == second, "legacy enemy pointer should point to active enemy")

	second.change_hp(-999.0)
	_expect_eq(
		domain.check_end_after_resolve(),
		BattleDomainServiceScript.SIGNAL_ENEMY_DEAD,
		"battle should end after all enemies die"
	)


func _test_enemy_formation_centers_small_groups() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemies: Array = []
	for i in 4:
		enemies.append(_make_unit(100.0, 100.0))
	var domain := BattleDomainServiceScript.new()
	domain.start_battle_many(player, enemies, {}, 200.0)
	var formation := domain.get_formation_snapshot()
	_expect_eq(int(formation.get("rows", 0)), 5, "default formation should have five rows")
	var slots := formation.get("slots", []) as Array
	_expect_eq(int((slots[2] as Dictionary).get("enemy_index", -1)), 0, "first enemy should stand in center row")
	_expect_eq(int((slots[1] as Dictionary).get("enemy_index", -1)), 1, "second enemy should stand above center")
	_expect_eq(int((slots[3] as Dictionary).get("enemy_index", -1)), 2, "third enemy should stand below center")
	_expect_eq(int((slots[0] as Dictionary).get("enemy_index", -1)), 3, "fourth enemy should fill the outer top")
	_expect_true(bool((slots[4] as Dictionary).get("empty", false)), "fifth row should stay empty")
	_expect_eq(domain.active_enemy_index, 0, "default target should be the centered enemy")
	_expect_eq(domain.actor_id_for_enemy_index(0), "enemy_0_2", "centered enemy actor id")


func _test_enemy_formation_only_advances_active_column() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemies: Array = []
	for i in 13:
		enemies.append(_make_unit(100.0, 100.0))
	var domain := BattleDomainServiceScript.new()
	domain.start_battle_many(player, enemies, {}, 200.0, {}, {}, {
		"columns": 3,
		"rows": 4,
		"active_columns": 1,
	})

	_expect_eq(domain.tick_advancing(0.5), "", "half tick should not ready")
	for idx in [0, 1, 2, 3]:
		_expect_true(
			float(domain.interval_elapsed_enemies[idx]) > 0.0,
			"front column enemy %d should advance" % idx
		)
	for idx in [4, 5, 8, 11, 12]:
		_expect_near(
			float(domain.interval_elapsed_enemies[idx]),
			0.0,
			"reserve/back column enemy %d should not advance" % idx
		)


func _test_enemy_formation_compacts_rows_and_reserves() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemies: Array = []
	for i in 13:
		enemies.append(_make_unit(100.0, 100.0))
	var domain := BattleDomainServiceScript.new()
	domain.start_battle_many(player, enemies, {}, 200.0, {}, {}, {
		"columns": 3,
		"rows": 4,
		"active_columns": 1,
	})
	(enemies[0] as FightObj).change_hp(-999.0)
	_expect_eq(domain.check_end_after_resolve(), "", "battle should continue with reserves alive")
	var formation := domain.get_formation_snapshot()
	var slots := formation.get("slots", []) as Array
	_expect_eq(int((slots[0] as Dictionary).get("enemy_index", -1)), 4, "row 0 column 1 should move to front")
	_expect_eq(int((slots[4] as Dictionary).get("enemy_index", -1)), 8, "row 0 column 2 should move to column 1")
	_expect_eq(int((slots[8] as Dictionary).get("enemy_index", -1)), 12, "reserve should fill row 0 back slot")
	_expect_true(domain.enemy == enemies[4], "legacy enemy pointer should follow new front target")
	_expect_near(float(domain.interval_elapsed_enemies[4]), 0.0, "replacement keeps own progress")


func _test_method_mp_recovery() -> void:
	var player := _make_unit()
	player.mp = 10.0
	player.attrs[FightAttr.COMBAT_MP_RESTORE_2S] = 6.0
	var domain := _start_domain(player, _make_unit())
	domain.tick_advancing(1.9)
	_expect_near(player.mp, 10.0, "method recovery waits for two seconds")
	domain.tick_advancing(0.1)
	_expect_near(player.mp, 16.0, "method recovery restores configured mp")


func _test_pierce_and_vulnerability() -> void:
	var attacker := {FightAttr.MAGIC_ATK: 100.0, FightAttr.CRIT: 0.0}
	var defender := {FightAttr.MAGIC_DEF: 100.0, FightAttr.DAMAGE_TAKEN: 0.2}
	var normal := FightAttr.calc_skill_damage(attacker, defender, 1.0, 0.0, FightAttr.DAMAGE_MAGIC)
	var pierced := FightAttr.calc_skill_damage(attacker, defender, 1.0, 0.0, FightAttr.DAMAGE_MAGIC, 0.5)
	_expect_near(float(normal["damage"]), 60.0, "vulnerability increases post-defense damage")
	_expect_true(float(pierced["damage"]) > float(normal["damage"]), "pierce increases damage")


func _test_runtime_modifier_expires() -> void:
	var unit := _make_unit()
	var before := unit.get_attr(FightAttr.EVASION)
	_expect_true(
		unit.add_runtime_modifier_buff("test_evasion", 1.0, {FightAttr.EVASION: 20.0}),
		"runtime modifier applies"
	)
	_expect_near(unit.get_attr(FightAttr.EVASION), before + 20.0, "runtime modifier changes stat")
	unit.tick_buffs(1.0)
	_expect_near(unit.get_attr(FightAttr.EVASION), before, "runtime modifier expires")


func _test_v1_abilities_resolve_effects() -> void:
	AbilityServiceScript.reload()
	for ability_id in [
		"ability.combat.qi_bolt",
		"ability.combat.wind_step",
		"ability.combat.sword_qi",
		"ability.combat.blood_strike",
		"ability.combat.five_phase_burst",
		"ability.combat.seal_bind",
	]:
		var runtime := AbilityServiceScript.to_runtime_dict(ability_id, {"knowledge": {}})
		_expect_true(not (runtime.get("effects", []) as Array).is_empty(), "%s has runtime effects" % ability_id)


func _test_knowledge_growth() -> void:
	var rows := [{
		"effectId": "damage_spiritual",
		"base": 40.0,
		"knowledgeGrowth": 18.0,
		"target": "enemy",
	}]
	var base := EffectResolverScript.resolve_combat_effects(rows, 0.0)
	var full := EffectResolverScript.resolve_combat_effects(rows, 1.0)
	_expect_near(float((base[0] as Dictionary)["value"]), 40.0, "threshold knowledge uses base")
	_expect_near(float((full[0] as Dictionary)["value"]), 58.0, "full knowledge adds growth")


func _test_intent_preview_subtracts_shield() -> void:
	AbilityServiceScript.reload()
	var attacker := _make_unit()
	attacker.attrs[FightObjScript.ATTR_MAGIC_ATK] = 30.0
	var defender := _make_unit()
	defender.set_attr(FightObjScript.ATTR_SHIELD, 24.0)
	var skill_cfg := AbilityServiceScript.to_runtime_dict("ability.combat.qi_bolt", {"knowledge": {}})
	var row := EnemyIntentPreviewScript.enrich_skill_row(
		{},
		attacker,
		defender,
		skill_cfg,
		int(skill_cfg.get("id", -1)),
	)
	var estimated := int(row.get("estimated_damage", -1))
	var raw := FightAttr.estimate_skill_damage(
		attacker.attrs,
		defender.attrs,
		float(skill_cfg.get("power", 1000.0)) / 1000.0,
		float(((skill_cfg.get("effects", []) as Array)[0] as Dictionary).get("value", 0.0)),
		FightAttr.DAMAGE_MAGIC,
	)
	var expected_hp_damage := maxi(0, int(roundf(float(raw) - 24.0)))
	_expect_eq(estimated, expected_hp_damage, "intent preview shows hp damage after shield")
	_expect_true(estimated < int(roundf(float(raw))), "shielded preview is lower than raw damage")


func _test_intent_preview_honors_slot_effect_scale() -> void:
	var attacker := _make_unit()
	attacker.skills = [{"id": 1, "cd": 0.0, "effect_value_scale": 0.45}]
	attacker.attrs[FightObjScript.ATTR_MAGIC_ATK] = 10.0
	var defender := _make_unit()
	defender.attrs[FightObjScript.ATTR_MAGIC_DEF] = 24.0
	var cfg := {
		"power": 1000.0,
		"effects": [
			{
				"type": "damage",
				"value": 40.0,
				"damage_type": FightAttr.DAMAGE_MAGIC,
				"target": "enemy",
			},
		],
	}
	var row := EnemyIntentPreviewScript.enrich_skill_row({}, attacker, defender, cfg, 1)
	var estimated := int(row.get("estimated_damage", -1))
	var merged := FightObjScript.merged_slot_runtime_cfg(attacker.skills[0], cfg)
	var effect := (merged.get("effects", []) as Array)[0] as Dictionary
	var expected := int(roundf(FightAttr.estimate_skill_damage(
		attacker.attrs,
		defender.attrs,
		float(merged.get("power", 1000.0)) / 1000.0,
		float(effect.get("value", 0.0)),
		FightAttr.DAMAGE_MAGIC,
	)))
	_expect_eq(estimated, expected, "intent preview uses slot effect scale")
	var unscaled := int(roundf(FightAttr.estimate_skill_damage(
		attacker.attrs,
		defender.attrs,
		1.0,
		40.0,
		FightAttr.DAMAGE_MAGIC,
	)))
	_expect_true(estimated < unscaled, "scaled preview lower than base skill cfg")


func _make_unit(hp: float = 100.0, spd: float = 100.0, skill_cd: float = 0.0) -> FightObj:
	return FightObjScript.new({
		"hp": hp,
		"mp": 100.0,
		"attrs": {
			FightObjScript.ATTR_HP_MAX: 100.0,
			FightObjScript.ATTR_MP_MAX: 100.0,
			FightObjScript.ATTR_SHIELD: 0.0,
			FightObjScript.ATTR_PHYSICAL_ATK: 20.0,
			FightObjScript.ATTR_MAGIC_ATK: 20.0,
			FightObjScript.ATTR_PHYSICAL_DEF: 0.0,
			FightObjScript.ATTR_MAGIC_DEF: 0.0,
			FightObjScript.ATTR_SPD: spd,
			FightObjScript.ATTR_CRIT: 0.0,
			FightObjScript.ATTR_CRIT_DAMAGE: 150.0,
		},
		"skills": [{"id": 1, "cd": skill_cd, "cd_total": 5.0}],
		"equips": [],
		"items": [],
	})


func _runtime_dot(duration: float, ticktime: float, damage: float) -> Dictionary:
	return {
		"id": "test_dot",
		"stacks": 1,
		"duration_left": duration,
		"tick_accum": 0.0,
		"ticktime": ticktime,
		"tick_effects": [{"type": "damage", "value": damage}],
		"stat_modifiers": {},
	}


func _start_domain(player: FightObj, enemy: FightObj, time_limit: float = 200.0) -> BattleDomainService:
	var domain := BattleDomainServiceScript.new()
	domain.start_battle(player, enemy, {}, time_limit)
	return domain


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_fail("%s: expected true" % message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, message: String, epsilon: float = 0.0001) -> void:
	if not is_equal_approx(actual, expected) and absf(actual - expected) > epsilon:
		_fail("%s: expected %.4f, got %.4f" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
