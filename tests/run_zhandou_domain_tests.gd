extends SceneTree

const ZhandouDomainServiceScript := preload("res://scripts/zhandou/zhandou_domain_service.gd")
const ZhandouObjScript := preload("res://scripts/zhandou/zhandou_obj.gd")
const ZhandouReportScript := preload("res://scripts/zhandou/zhandou_report.gd")
const ZhandouEventScript := preload("res://scripts/zhandou/zhandou_event.gd")
const EffectResolverScript := preload("res://scripts/dao/effect_resolver.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")
const EnemyIntentPreviewScript := preload("res://scripts/zhandou/enemy_intent_preview.gd")
const ZhandouActorVfxScript := preload("res://scripts/zhandou/zhandou_actor_vfx.gd")
const ZhandouVfxSettingsScript := preload("res://scripts/zhandou/zhandou_vfx_settings.gd")
const ZhandouFloatPresenterScript := preload("res://scripts/zhandou/zhandou_float_presenter.gd")
const BuffStatusBarScript := preload("res://scripts/zhandou/buff_status_bar.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	ZhandouDebugLog.enabled = false
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
	_run("tiaoxi restores mp from regen rate", _test_tiaoxi_restores_mp)
	_run("control effects always apply", _test_control_effects_always_apply)
	_run("effect scaling uses combat attributes", _test_effect_scaling)
	_run("action progress advances from current speed", _test_action_progress_uses_current_speed)
	_run("one player can fight multiple enemies", _test_one_player_can_fight_multiple_enemies)
	_run("enemy formation defaults to five rows and centers small groups", _test_enemy_formation_centers_small_groups)
	_run("enemy formation only advances active column", _test_enemy_formation_only_advances_active_column)
	_run("enemy formation compacts rows and reserves", _test_enemy_formation_compacts_rows_and_reserves)
	_run("enemy formation supports limited rank size", _test_enemy_formation_limited_rank_size)
	_run("enemy wave formation advances after current row dies", _test_enemy_wave_formation_advances_after_current_row_dies)
	_run("cultivation method restores mp every two seconds", _test_method_mp_recovery)
	_run("skill damage supports pierce and vulnerability", _test_pierce_and_vulnerability)
	_run("runtime modifier expires cleanly", _test_runtime_modifier_expires)
	_run("buff reapply stacks and refreshes duration", _test_buff_reapply_stacks_and_refreshes_duration)
	_run("self buff float targets caster", _test_self_buff_float_targets_caster)
	_run("qi and foundation active abilities resolve effects", _test_v1_abilities_resolve_effects)
	_run("PM-206 projectile presets are bound", _test_pm206_projectile_presets_are_bound)
	_run("melee strike point works across formation slot parents", _test_melee_strike_across_formation_slots)
	_run("intent preview subtracts defender shield", _test_intent_preview_subtracts_shield)
	_run("intent preview matches use_skill damage", _test_intent_preview_matches_use_skill_damage)
	_run("intent preview enemy_lowest_hp shows damage", _test_intent_preview_enemy_lowest_hp_shows_damage)
	_run("escape chance rises with player speed over max enemy", _test_escape_chance_speed_ratio)
	_run("escape success ends battle", _test_escape_success_ends_battle)
	_run("escape failure consumes player turn", _test_escape_failure_consumes_turn)
	_run("passive status bar shows cooldown after trigger", _test_passive_status_bar_shows_cooldown_after_trigger)
	_run("passive status entries sort before buffs", _test_passive_status_entries_sort_before_buffs)

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
	var ready_time := ZhandouBalance.interval_cap_for(domain.player)

	_expect_near(cap, domain.interval_T_enemy, "test units should have equal action intervals")
	_expect_eq(
		domain.tick_advancing(ready_time),
		ZhandouDomainServiceScript.SIGNAL_PLAYER_READY,
		"player should win simultaneous ready"
	)


func _test_action_resets_actor_and_preserves_opponent_progress() -> void:
	var domain := _start_domain(_make_unit(), _make_unit())
	var cap := domain.interval_T_player
	var ready_time := ZhandouBalance.interval_cap_for(domain.player)
	_expect_eq(domain.tick_advancing(ready_time), ZhandouDomainServiceScript.SIGNAL_PLAYER_READY, "player ready")
	domain.enter_paused(EnumBattleSide.PLAYER)
	var payload := domain.resolve_player_tiaoxi()
	_expect_true(bool(payload.get("ok", false)), "player tiaoxi should resolve")
	domain.begin_presentation(EnumBattleSide.PLAYER)
	domain.finish_presentation()

	_expect_near(domain.interval_elapsed_player, 0.0, "actor action bar reset")
	_expect_near(domain.interval_elapsed_enemy, cap, "opponent action bar preserved")
	_expect_eq(
		domain.tick_advancing(0.01),
		ZhandouDomainServiceScript.SIGNAL_ENEMY_READY,
		"preserved opponent should act next"
	)


func _test_dot_death_ends_battle_during_advancing() -> void:
	var enemy := _make_unit(5.0)
	enemy.buffs["fatal_dot"] = _runtime_dot(2.0, 1.0, 10.0)
	var domain := _start_domain(_make_unit(), enemy)

	_expect_eq(
		domain.tick_advancing(1.0),
		ZhandouDomainServiceScript.SIGNAL_ENEMY_DEAD,
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
		ZhandouDomainServiceScript.SIGNAL_TIME_LIMIT,
		"time limit should count advancing time"
	)
	_expect_eq(domain.state, EnumBattleState.State.END, "time limit end state")


func _test_damage_types_use_matching_defense() -> void:
	var attacker := {
		ZhandouAttr.PHYSICAL_ATK: 100.0,
		ZhandouAttr.MAGIC_ATK: 100.0,
	}
	var defender := {
		ZhandouAttr.PHYSICAL_DEF: 100.0,
		ZhandouAttr.MAGIC_DEF: 300.0,
	}
	var physical := ZhandouAttr.calc_basic_damage(attacker, defender)
	var magic := ZhandouAttr.calc_skill_damage(attacker, defender, 1.0, 0.0, ZhandouAttr.DAMAGE_MAGIC)
	_expect_near(float(physical["damage"]), 50.0, "physical soft mitigation")
	_expect_near(float(magic["damage"]), 25.0, "magic soft mitigation")


func _test_true_damage_bypasses_defense() -> void:
	var attacker := {
		ZhandouAttr.PHYSICAL_ATK: 100.0,
		ZhandouAttr.MAGIC_ATK: 80.0,
	}
	var defender := {
		ZhandouAttr.PHYSICAL_DEF: 999.0,
		ZhandouAttr.MAGIC_DEF: 999.0,
	}
	var hit := ZhandouAttr.calc_skill_damage(attacker, defender, 1.0, 20.0, ZhandouAttr.DAMAGE_TRUE)
	_expect_near(float(hit["damage"]), 120.0, "true damage ignores defense but keeps attack scaling")


func _test_non_mana_ability_costs_are_paid() -> void:
	AbilityServiceScript.reload()
	var skill := AbilityServiceScript.to_runtime_dict("ability.combat.blood_strike", {"knowledge": {}})
	_expect_near(float(skill.get("mp_cost", 0.0)), 18.0, "stamina costs enter runtime resource budget")
	var player := _make_unit(100.0, 100.0)
	player.mp = 20.0
	player.skills = [{"id": int(skill.get("id", -1)), "cd": 0.0, "cd_total": float(skill.get("cd", 0.0))}]
	var enemy := _make_unit(100.0, 100.0)
	var used := player.use_skill(int(skill.get("id", -1)), {int(skill.get("id", -1)): skill}, enemy)
	_expect_true(bool(used.get("ok", false)), "stamina-cost skill resolves")
	_expect_near(player.mp, 2.0, "stamina-cost skill consumes shared combat resource")


func _test_tiaoxi_restores_mp() -> void:
	var actor := _make_unit(100.0, 100.0)
	actor.attrs[ZhandouAttr.MP_REGEN] = 2.0
	actor.mp = 40.0
	var expected: float = 2.0 * ZhandouBalance.TIAOXI_MP_REGEN_MULTIPLIER
	var report := ZhandouObjScript.resolve_tiaoxi(actor)
	_expect_near(float(report.get(ZhandouReportScript.KEY_MP_GAIN, 0.0)), expected, "tiaoxi mp gain")
	_expect_near(actor.mp, 40.0 + expected, "tiaoxi restores mp on actor")
	var attacker := _make_unit(100.0, 100.0)
	var defender := _make_unit(100.0, 100.0)
	attacker.skills = [{"id": 1, "cd": 0.0}]
	var cfg := {
		1: {
			"mp_cost": 0.0,
			"cd": 0.0,
			"effects": [{"type": "damage", "value": 10.0, "target": "enemy"}],
		},
	}
	var used := attacker.use_skill(1, cfg, defender)
	_expect_true(bool(used.get("ok", false)), "damage skill resolves")
	_expect_false(bool(used.get(ZhandouReportScript.KEY_MISSED, false)), "damage skill should not miss")


func _test_control_effects_always_apply() -> void:
	var attacker := _make_unit(100.0, 100.0)
	var defender := _make_unit(100.0, 100.0)
	defender.attrs[ZhandouAttr.CONTROL_RESIST] = 9999.0
	attacker.skills = [{"id": 1, "cd": 0.0}]
	var cfg := {
		1: {
			"mp_cost": 0.0,
			"cd": 0.0,
			"effects": [
				{
					"type": "control",
					"id": "test_seal",
					"name": "封印",
					"duration": 2.0,
					"target": "enemy",
				},
			],
		},
	}
	var used := attacker.use_skill(1, cfg, defender)
	_expect_true(bool(used.get("ok", false)), "control skill resolves")
	_expect_false(
		bool(used.get(ZhandouReportScript.KEY_CONTROL_RESISTED, false)),
		"control should not be resisted"
	)
	_expect_true(defender.buffs.has("test_seal"), "control buff should apply")


func _test_effect_scaling() -> void:
	var unit := _make_unit()
	unit.attrs[ZhandouAttr.MAGIC_ATK] = 40.0
	unit.mp = 100.0
	var cfg := {
		1: {
			"mp_cost": 0.0,
			"cd": 0.0,
			"effects": [
				{
					"type": EnumCombatEffectType.LABEL_SHIELD,
					"value": 10.0,
					"scaling": {ZhandouAttr.MAGIC_ATK: 1.5},
					"target": EnumZhandouTarget.LABEL_SELF,
				},
			],
		},
	}
	var used := unit.use_skill(1, cfg)
	_expect_true(bool(used.get("ok", false)), "scaled shield skill should resolve")
	_expect_near(unit.get_attr(ZhandouAttr.SHIELD), 70.0, "scaled shield amount")


func _test_action_progress_uses_current_speed() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemy := _make_unit(100.0, 1.0)
	var domain := _start_domain(player, enemy)
	_expect_eq(domain.tick_advancing(0.6), "", "half interval should not ready")
	_expect_near(domain.interval_elapsed_player, 50.0, "half progress at speed 100")
	player.set_attr(ZhandouObjScript.ATTR_SPD, 50.0)
	var snapshot := domain.get_ui_snapshot().get("intervals", {}) as Dictionary
	var left := snapshot.get("left", {}) as Dictionary
	_expect_near(float(left.get("elapsed", 0.0)), 50.0, "speed change preserves accumulated progress")
	_expect_near(float(left.get("cap", 0.0)), 100.0, "progress cap stays fixed")
	_expect_eq(domain.tick_advancing(0.6), "", "slowed unit should not ready")
	_expect_near(domain.interval_elapsed_player, 75.0, "slow speed advances less per second")
	player.set_attr(ZhandouObjScript.ATTR_SPD, 200.0)
	_expect_eq(
		domain.tick_advancing(0.15),
		ZhandouDomainServiceScript.SIGNAL_PLAYER_READY,
		"speeding up should immediately accelerate progress"
	)


func _test_one_player_can_fight_multiple_enemies() -> void:
	var player := _make_unit(100.0, 100.0)
	var first := _make_unit(1.0, 80.0)
	var second := _make_unit(40.0, 80.0)
	var domain := ZhandouDomainServiceScript.new()
	var skill_cfg := {
		1: {
			"mp_cost": 0.0,
			"cd": 0.0,
			"effects": [{"type": "damage", "value": 999.0, "target": "enemy"}],
		},
	}
	domain.start_battle_many(player, [first, second], skill_cfg, 200.0)
	domain.enter_paused(EnumBattleSide.PLAYER)
	var payload := domain.resolve_player_skill(1)
	_expect_true(bool(payload.get("ok", false)), "player should hit first enemy with skill")
	_expect_true(first.is_dead(), "first enemy should die")
	_expect_eq(domain.check_end_after_resolve(), "", "battle should continue while another enemy is alive")
	_expect_eq(domain.active_enemy_index, 1, "active target should move to second enemy")
	_expect_true(domain.enemy == second, "legacy enemy pointer should point to active enemy")

	second.change_hp(-999.0)
	_expect_eq(
		domain.check_end_after_resolve(),
		ZhandouDomainServiceScript.SIGNAL_ENEMY_DEAD,
		"battle should end after all enemies die"
	)


func _test_enemy_formation_centers_small_groups() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemies: Array = []
	for i in 4:
		enemies.append(_make_unit(100.0, 100.0))
	var domain := ZhandouDomainServiceScript.new()
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
	var domain := ZhandouDomainServiceScript.new()
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
	var domain := ZhandouDomainServiceScript.new()
	domain.start_battle_many(player, enemies, {}, 200.0, {}, {}, {
		"columns": 3,
		"rows": 4,
		"active_columns": 1,
	})
	(enemies[0] as ZhandouObj).change_hp(-999.0)
	_expect_eq(domain.check_end_after_resolve(), "", "battle should continue with reserves alive")
	var partial := domain.get_formation_snapshot()
	var partial_slots := partial.get("slots", []) as Array
	_expect_true(bool((partial_slots[0] as Dictionary).get("empty", false)), "front slot stays empty until whole column clears")
	_expect_eq(int((partial_slots[4] as Dictionary).get("enemy_index", -1)), 4, "second column waits while front column still has enemies")

	for idx in [1, 2, 3]:
		(enemies[idx] as ZhandouObj).change_hp(-999.0)
	_expect_eq(domain.check_end_after_resolve(), "", "battle should continue after front column dies")
	var formation := domain.get_formation_snapshot()
	var slots := formation.get("slots", []) as Array
	_expect_eq(int((slots[0] as Dictionary).get("enemy_index", -1)), 4, "row 0 column 1 should move to front after column wave")
	_expect_eq(int((slots[4] as Dictionary).get("enemy_index", -1)), 8, "row 0 column 2 should move to column 1")
	_expect_eq(int((slots[8] as Dictionary).get("enemy_index", -1)), 12, "reserve should fill row 0 back slot")
	_expect_true(domain.enemy == enemies[4], "legacy enemy pointer should follow new front target")
	_expect_near(float(domain.interval_elapsed_enemies[4]), 0.0, "replacement keeps own progress")


func _test_enemy_formation_limited_rank_size() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemies: Array = []
	for i in 5:
		enemies.append(_make_unit(100.0, 100.0))
	var domain := ZhandouDomainServiceScript.new()
	domain.start_battle_many(player, enemies, {}, 200.0, {}, {}, {
		"columns": 3,
		"rows": 5,
		"active_columns": 1,
		"rank_size": 2,
	})
	var formation := domain.get_formation_snapshot()
	_expect_eq(int(formation.get("rank_size", 0)), 2, "formation should expose rank size")
	var slots := formation.get("slots", []) as Array
	_expect_eq(int((slots[2] as Dictionary).get("enemy_index", -1)), 0, "first rank center slot")
	_expect_eq(int((slots[7] as Dictionary).get("enemy_index", -1)), 1, "first rank second slot")
	_expect_eq(int((slots[1] as Dictionary).get("enemy_index", -1)), 2, "second rank center slot")
	_expect_eq(int((slots[6] as Dictionary).get("enemy_index", -1)), 3, "second rank second slot")
	_expect_eq(int((slots[3] as Dictionary).get("enemy_index", -1)), 4, "third rank center slot")
	_expect_true(bool((slots[12] as Dictionary).get("empty", false)), "third column center slot stays empty")

	(enemies[0] as ZhandouObj).change_hp(-999.0)
	_expect_eq(domain.check_end_after_resolve(), "", "battle should continue after first limited-rank enemy dies")
	var compacted := domain.get_formation_snapshot().get("slots", []) as Array
	_expect_eq(int((compacted[2] as Dictionary).get("enemy_index", -1)), 1, "same row moves forward from second slot")
	_expect_true(bool((compacted[7] as Dictionary).get("empty", false)), "same row second slot becomes empty")

	var boss_enemies: Array = []
	for i in 3:
		boss_enemies.append(_make_unit(100.0, 100.0))
	var boss_domain := ZhandouDomainServiceScript.new()
	boss_domain.start_battle_many(player, boss_enemies, {}, 200.0, {}, {}, {
		"columns": 3,
		"rows": 5,
		"active_columns": 1,
		"rank_size": 1,
	})
	var boss_slots := boss_domain.get_formation_snapshot().get("slots", []) as Array
	_expect_eq(int((boss_slots[2] as Dictionary).get("enemy_index", -1)), 0, "first boss center row")
	_expect_eq(int((boss_slots[1] as Dictionary).get("enemy_index", -1)), 1, "second boss uses another row")
	_expect_eq(int((boss_slots[3] as Dictionary).get("enemy_index", -1)), 2, "third boss uses another row")
	_expect_true(bool((boss_slots[7] as Dictionary).get("empty", false)), "bosses do not share center row")


func _test_enemy_wave_formation_advances_after_current_row_dies() -> void:
	var player := _make_unit(100.0, 100.0)
	var enemies: Array = []
	for i in 4:
		enemies.append(_make_unit(100.0, 100.0))
	var domain := ZhandouDomainServiceScript.new()
	domain.start_battle_many(player, enemies, {}, 200.0, {}, {}, {
		"mode": EnumBattleFormationMode.LABEL_WAVES,
		"columns": 3,
		"rows": 5,
		"active_columns": 1,
		"waves": [[0, 1], [2], [3]],
	})

	_expect_eq(str(domain.get_formation_snapshot().get("mode", "")), EnumBattleFormationMode.LABEL_WAVES, "wave mode active")
	_expect_eq(domain.tick_advancing(0.5), "", "half tick should not ready")
	_expect_true(float(domain.interval_elapsed_enemies[0]) > 0.0, "front row enemy 0 advances")
	_expect_true(float(domain.interval_elapsed_enemies[1]) > 0.0, "front row enemy 1 advances")
	_expect_near(float(domain.interval_elapsed_enemies[2]), 0.0, "next row enemy waits")
	_expect_near(float(domain.interval_elapsed_enemies[3]), 0.0, "later row enemy waits")

	(enemies[0] as ZhandouObj).change_hp(-999.0)
	_expect_eq(domain.check_end_after_resolve(), "", "battle continues while one front row enemy lives")
	_expect_eq(domain.active_enemy_index, 1, "same row remains active")
	_expect_near(float(domain.interval_elapsed_enemies[2]), 0.0, "next row still waits before row clear")

	(enemies[1] as ZhandouObj).change_hp(-999.0)
	_expect_eq(domain.check_end_after_resolve(), "", "battle continues with next wave")
	_expect_eq(domain.active_enemy_index, 2, "next row advances after current row dies")
	var formation := domain.get_formation_snapshot()
	_expect_eq(int(formation.get("current_wave", -1)), 1, "current wave index advances")
	_expect_true(domain.enemy == enemies[2], "legacy enemy pointer follows next wave")


func _test_method_mp_recovery() -> void:
	var player := _make_unit()
	player.mp = 10.0
	player.attrs[ZhandouAttr.COMBAT_MP_RESTORE_2S] = 6.0
	var domain := _start_domain(player, _make_unit())
	domain.tick_advancing(1.9)
	_expect_near(player.mp, 10.0, "method recovery waits for two seconds")
	domain.tick_advancing(0.1)
	_expect_near(player.mp, 16.0, "method recovery restores configured mp")


func _test_pierce_and_vulnerability() -> void:
	var attacker := {ZhandouAttr.MAGIC_ATK: 100.0}
	var defender := {ZhandouAttr.MAGIC_DEF: 100.0, ZhandouAttr.DAMAGE_TAKEN: 0.2}
	var normal := ZhandouAttr.calc_skill_damage(attacker, defender, 1.0, 0.0, ZhandouAttr.DAMAGE_MAGIC)
	var pierced := ZhandouAttr.calc_skill_damage(attacker, defender, 1.0, 0.0, ZhandouAttr.DAMAGE_MAGIC, 0.5)
	_expect_near(float(normal["damage"]), 60.0, "vulnerability increases post-defense damage")
	_expect_true(float(pierced["damage"]) > float(normal["damage"]), "pierce increases damage")


func _test_runtime_modifier_expires() -> void:
	var unit := _make_unit()
	var before := unit.get_attr(ZhandouAttr.CONTROL_POWER)
	_expect_true(
		unit.add_runtime_modifier_buff("test_control_power", 1.0, {ZhandouAttr.CONTROL_POWER: 20.0}),
		"runtime modifier applies"
	)
	_expect_near(unit.get_attr(ZhandouAttr.CONTROL_POWER), before + 20.0, "runtime modifier changes stat")
	unit.tick_buffs(1.0)
	_expect_near(unit.get_attr(ZhandouAttr.CONTROL_POWER), before, "runtime modifier expires")


func _test_buff_reapply_stacks_and_refreshes_duration() -> void:
	ZhandouObjScript.set_test_buff_defs({
		"test_stack": {
			"id": "test_stack",
			"name": "测试叠层",
			"duration": 3.0,
			"max_stacks": 5,
			"ticktime": 0.0,
			"modifiers": {},
			"tick_effects": [],
		},
	})
	var unit := _make_unit()
	_expect_eq(unit.add_buff("test_stack", 1), 1, "first buff stack")
	var inst := unit.buffs["test_stack"] as Dictionary
	_expect_eq(int(inst.get("stacks", 0)), 1, "one stack after first apply")
	inst["duration_left"] = 1.0
	_expect_eq(unit.add_buff("test_stack", 1), 1, "second stack applied")
	_expect_eq(int((unit.buffs["test_stack"] as Dictionary).get("stacks", 0)), 2, "two stacks after reapply")
	_expect_near(float((unit.buffs["test_stack"] as Dictionary).get("duration_left", 0.0)), 3.0, "duration refreshed on stack")
	for _i in 3:
		unit.add_buff("test_stack", 1)
	_expect_eq(int((unit.buffs["test_stack"] as Dictionary).get("stacks", 0)), 5, "capped at max stacks")
	(unit.buffs["test_stack"] as Dictionary)["duration_left"] = 0.5
	_expect_eq(unit.add_buff("test_stack", 1), 1, "max stack refresh still succeeds")
	_expect_eq(int((unit.buffs["test_stack"] as Dictionary).get("stacks", 0)), 5, "stacks unchanged at cap")
	_expect_near(float((unit.buffs["test_stack"] as Dictionary).get("duration_left", 0.0)), 3.0, "duration refreshed at cap")
	ZhandouObjScript.clear_test_buff_defs()


func _test_self_buff_float_targets_caster() -> void:
	var spawns: Array = ZhandouFloatPresenterScript.build_spawns(
		"player",
		"enemy",
		{"buff_names": ["流风护身"]},
		{"name": "流风步", "target": "self"},
	)
	var found := false
	for spawn_v in spawns:
		if not spawn_v is Dictionary:
			continue
		var spawn := spawn_v as Dictionary
		if str(spawn.get("tone", "")) != "buff_add":
			continue
		found = true
		_expect_eq(str(spawn.get("unit_id", "")), "player", "self buff float on caster")
		break
	_expect_true(found, "buff float spawn exists")


func _test_v1_abilities_resolve_effects() -> void:
	AbilityServiceScript.reload()
	# exportjson 多数技能 effects 待策划补表；仅校验已有数据的代表技能
	for ability_id in [
		"ability.combat.qi_bolt",
		"ability.combat.wind_step",
	]:
		var runtime := AbilityServiceScript.to_runtime_dict(ability_id, {"knowledge": {}})
		_expect_true(not (runtime.get("effects", []) as Array).is_empty(), "%s has runtime effects" % ability_id)


func _test_melee_strike_across_formation_slots() -> void:
	# 阵型槽位下施法者与目标父节点不同，冲锋终点须在施法者本地坐标系内。
	var world := Node2D.new()
	root.add_child(world)
	var caster_slot := Node2D.new()
	caster_slot.position = Vector2(-300, 0)
	var target_slot := Node2D.new()
	target_slot.position = Vector2(200, 40)
	var caster := Sprite2D.new()
	var target := Sprite2D.new()
	world.add_child(caster_slot)
	world.add_child(target_slot)
	caster_slot.add_child(caster)
	target_slot.add_child(target)
	var vfx := ZhandouActorVfxScript.new()
	vfx.settings = ZhandouVfxSettingsScript.new()
	caster.add_child(vfx)
	vfx.bind_actor(caster)
	vfx.rebaseline_rest_pose()
	var strike := vfx.strike_point_in_front(target, 40.0)
	_expect_true(strike.x > vfx.get_rest_position().x + 100.0, "strike point advances toward target")
	_expect_true(strike != target.position, "strike point must not reuse target local position")
	var tiaoxi := AbilityServiceScript.to_runtime_dict("ability.combat.tiaoxi", {})
	_expect_eq(str(tiaoxi.get("vfx_type", "")), "buff", "tiaoxi uses buff vfx type")
	_expect_eq(str(tiaoxi.get("vfx", "")), "status_cast", "tiaoxi uses status cast preset")
	world.queue_free()


func _test_pm206_projectile_presets_are_bound() -> void:
	AbilityServiceScript.reload()
	var qi := AbilityServiceScript.to_runtime_dict("ability.combat.qi_bolt", {})
	var sword := AbilityServiceScript.to_runtime_dict("ability.combat.sword_qi", {})
	_expect_eq(str(qi.get("vfx", "")), "qi_bolt_projectile", "qi bolt vfx preset")
	_expect_eq(str(sword.get("vfx", "")), "sword_qi_projectile", "sword qi vfx preset")
	var lib := ZhandouVfxPresetLibrary.load_default()
	_expect_true(_has_projectile_texture(lib.get_sequence("qi_bolt_projectile")), "qi bolt projectile texture")
	_expect_true(_has_projectile_texture(lib.get_sequence("sword_qi_projectile")), "sword qi projectile texture")
	_expect_eq(ZhandouVfxPresetLibrary.legacy_preset_for_vfx_type("shield"), "status_cast", "shield fallback")
	_expect_eq(EnumBattleVfxSkillType.from_label("shield"), EnumBattleVfxSkillType.Type.BUFF, "shield skill type")


func _test_intent_preview_subtracts_shield() -> void:
	AbilityServiceScript.reload()
	var attacker := _make_unit()
	attacker.attrs[ZhandouObjScript.ATTR_MAGIC_ATK] = 30.0
	var defender := _make_unit()
	defender.set_attr(ZhandouObjScript.ATTR_SHIELD, 24.0)
	var skill_cfg := AbilityServiceScript.to_runtime_dict("ability.combat.qi_bolt", {"knowledge": {}})
	var row := EnemyIntentPreviewScript.enrich_skill_row(
		{},
		attacker,
		defender,
		skill_cfg,
		int(skill_cfg.get("id", -1)),
	)
	var estimated := int(row.get("estimated_damage", -1))
	var raw := ZhandouAttr.estimate_skill_damage(
		attacker.attrs,
		defender.attrs,
		float(skill_cfg.get("power", 1000.0)) / 1000.0,
		float(((skill_cfg.get("effects", []) as Array)[0] as Dictionary).get("value", 0.0)),
		ZhandouAttr.DAMAGE_MAGIC,
	)
	var expected_hp_damage := maxi(0, int(roundf(float(raw) - 24.0)))
	_expect_eq(estimated, expected_hp_damage, "intent preview shows hp damage after shield")
	_expect_true(estimated < int(roundf(float(raw))), "shielded preview is lower than raw damage")


func _test_intent_preview_enemy_lowest_hp_shows_damage() -> void:
	AbilityServiceScript.reload()
	var attacker := _make_unit()
	attacker.attrs[ZhandouObjScript.ATTR_MAGIC_ATK] = 40.0
	var defender := _make_unit()
	var skill_cfg := AbilityServiceScript.to_runtime_dict("ability.combat.qi_bolt", {"knowledge": {}})
	var row := EnemyIntentPreviewScript.enrich_skill_row(
		{},
		attacker,
		defender,
		skill_cfg,
		int(skill_cfg.get("id", -1)),
	)
	_expect_eq(str(row.get("intent_overlay", "")), "damage", "enemy_lowest_hp shows damage overlay")
	_expect_true(int(row.get("estimated_damage", 0)) > 0, "enemy_lowest_hp estimates positive damage")


func _test_intent_preview_matches_use_skill_damage() -> void:
	var attacker := _make_unit()
	attacker.skills = [{"id": 1, "cd": 0.0}]
	attacker.attrs[ZhandouObjScript.ATTR_MAGIC_ATK] = 30.0
	var defender := _make_unit()
	defender.attrs[ZhandouObjScript.ATTR_MAGIC_DEF] = 20.0
	var cfg := {
		"power": 1000.0,
		"effects": [
			{
				"type": EnumCombatEffectType.LABEL_DAMAGE,
				"value": 40.0,
				"damage_type": ZhandouAttr.DAMAGE_MAGIC,
				"target": EnumZhandouTarget.LABEL_ENEMY,
				"can_miss": false,
			},
		],
	}
	var row := EnemyIntentPreviewScript.enrich_skill_row({}, attacker, defender, cfg, 1)
	var estimated := int(row.get("estimated_damage", -1))
	var used := attacker.use_skill(1, {1: cfg}, defender)
	_expect_true(bool(used.get("ok", false)), "skill resolves for intent parity check")
	var actual := int(roundf(float(used.get("hp_damage", used.get("damage", 0.0)))))
	_expect_eq(estimated, actual, "intent preview matches use_skill hp damage")


func _test_escape_chance_speed_ratio() -> void:
	var slow := ZhandouBalance.escape_success_chance(80.0, 120.0, 0.0, 0)
	var fast := ZhandouBalance.escape_success_chance(150.0, 100.0, 0.0, 0)
	_expect_true(fast > slow, "faster player should escape more often")
	_expect_near(
		ZhandouBalance.escape_success_chance(100.0, 100.0, 0.0, 0),
		ZhandouBalance.ESCAPE_BASE_AT_PARITY,
		"parity escape base"
	)


func _test_escape_success_ends_battle() -> void:
	seed(4242)
	var domain := _start_domain(_make_unit(150.0, 100.0, 5.0), _make_unit(80.0, 100.0, 5.0))
	domain.enter_paused(EnumBattleSide.PLAYER)
	# ponytail: 确定性测试，极高速度差保证首次成功
	var result := domain.try_escape(0.5, 0)
	_expect_true(bool(result.get("success", false)), "escape should succeed with high bonus")
	_expect_eq(domain.end_reason, ZhandouDomainServiceScript.SIGNAL_PLAYER_ESCAPED, "escape end reason")
	_expect_eq(domain.state, EnumBattleState.State.END, "escape ends battle")


func _test_escape_failure_consumes_turn() -> void:
	seed(999001)
	var domain := _start_domain(_make_unit(50.0, 100.0, 5.0), _make_unit(200.0, 100.0, 5.0))
	domain.enter_paused(EnumBattleSide.PLAYER)
	var before_hp := domain.player.hp
	var result := domain.try_escape(-0.5, 0)
	_expect_true(bool(result.get("ok", false)), "escape attempt should resolve")
	_expect_true(not bool(result.get("success", false)), "escape should fail with slow player")
	_expect_eq(domain.state, EnumBattleState.State.ADVANCING, "failed escape resumes advancing")
	_expect_true(domain.player.hp < before_hp, "failed escape applies chase damage")


func _test_passive_status_bar_shows_cooldown_after_trigger() -> void:
	var unit := _make_unit()
	unit.init_passives_from_ids(["fpassive_0003"])
	var entries: Array = unit.build_status_bar_entries()
	_expect_eq(entries.size(), 1, "passive always visible in status bar")
	var idle_row: Dictionary = entries[0] as Dictionary
	_expect_false(bool(idle_row.get("show_time", true)), "idle passive hides countdown")
	unit.start_passive_cooldown("fpassive_0003")
	entries = unit.build_status_bar_entries()
	var cd_row: Dictionary = entries[0] as Dictionary
	_expect_true(bool(cd_row.get("show_time", false)), "triggered passive shows countdown")
	_expect_true(float(cd_row.get("duration_left", 0.0)) > 0.0, "triggered passive has remaining cd")


func _test_passive_status_entries_sort_before_buffs() -> void:
	var sorted: Array = BuffStatusBarScript._sorted_entries([
		{"kind": "buff", "id": "aaa"},
		{"kind": "passive", "id": "zzz"},
		{"kind": "buff", "id": "bbb"},
		{"kind": "passive", "id": "aaa"},
	])
	_expect_eq(str((sorted[0] as Dictionary).get("kind", "")), "passive", "passive sorts first")
	_expect_eq(str((sorted[2] as Dictionary).get("kind", "")), "buff", "buff follows passives")


func _make_unit(hp: float = 100.0, spd: float = 100.0, skill_cd: float = 0.0) -> ZhandouObj:
	return ZhandouObjScript.new({
		"hp": hp,
		"mp": 100.0,
		"attrs": {
			ZhandouObjScript.ATTR_HP_MAX: 100.0,
			ZhandouObjScript.ATTR_MP_MAX: 100.0,
			ZhandouObjScript.ATTR_SHIELD: 0.0,
			ZhandouObjScript.ATTR_PHYSICAL_ATK: 20.0,
			ZhandouObjScript.ATTR_MAGIC_ATK: 20.0,
			ZhandouObjScript.ATTR_PHYSICAL_DEF: 0.0,
			ZhandouObjScript.ATTR_MAGIC_DEF: 0.0,
			ZhandouObjScript.ATTR_SPD: spd,
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
		"tick_effects": [{"type": EnumCombatEffectType.LABEL_DAMAGE, "value": damage}],
		"stat_modifiers": {},
	}


func _start_domain(player: ZhandouObj, enemy: ZhandouObj, time_limit: float = 200.0) -> ZhandouDomainService:
	var domain := ZhandouDomainServiceScript.new()
	domain.start_battle(player, enemy, {}, time_limit)
	return domain


func _has_projectile_texture(steps: Array) -> bool:
	for step_v in steps:
		if not step_v is Dictionary:
			continue
		var step := step_v as Dictionary
		if str(step.get("op", "")) == "projectile" and str(step.get("texture", "")).begins_with("res://assets/art/effect/"):
			return true
		if step.has("steps") and step["steps"] is Array and _has_projectile_texture(step["steps"] as Array):
			return true
	return false


func _expect_true(actual: bool, message: String) -> void:
	if not actual:
		_fail("%s: expected true" % message)


func _expect_false(actual: bool, message: String) -> void:
	if actual:
		_fail("%s: expected false" % message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_near(actual: float, expected: float, message: String, epsilon: float = 0.0001) -> void:
	if not is_equal_approx(actual, expected) and absf(actual - expected) > epsilon:
		_fail("%s: expected %.4f, got %.4f" % [message, expected, actual])


func _fail(message: String) -> void:
	_failures.append(message)
