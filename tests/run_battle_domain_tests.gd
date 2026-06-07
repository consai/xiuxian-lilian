extends SceneTree

const BattleDomainServiceScript := preload("res://scripts/fight/battle_domain_service.gd")
const FightObjScript := preload("res://scripts/fight/fightObj.gd")
const CombatEventScript := preload("res://scripts/fight/combat_event.gd")

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
	_expect_near(domain.interval_elapsed_player, 1.0, "player action bar")
	_expect_near(domain.interval_elapsed_enemy, 1.0, "enemy action bar")
	_expect_near(player.get_skill_cd(1), 4.0, "skill cooldown")
	_expect_near(float((player.buffs["test_dot"] as Dictionary)["duration_left"]), 2.0, "buff duration")
	_expect_near(player.hp, 90.0, "dot damage")


func _test_paused_freezes_simulation_clock() -> void:
	var player := _make_unit(100.0, 100.0, 5.0)
	var enemy := _make_unit()
	player.buffs["test_dot"] = _runtime_dot(3.0, 1.0, 10.0)
	var domain := _start_domain(player, enemy)
	domain.enter_paused(BattleDomainServiceScript.SIDE_PLAYER)

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
	domain.enter_paused(BattleDomainServiceScript.SIDE_PLAYER)
	domain.begin_presentation(BattleDomainServiceScript.SIDE_PLAYER)

	_expect_eq(domain.tick_advancing(10.0), "", "presentation tick should be ignored")
	_expect_near(domain.battle_elapsed_advancing, 0.0, "presentation advancing time")
	_expect_near(player.get_skill_cd(1), 5.0, "presentation cooldown")
	_expect_near(float((player.buffs["test_dot"] as Dictionary)["duration_left"]), 3.0, "presentation buff duration")
	_expect_near(player.hp, 100.0, "presentation dot damage")


func _test_simultaneous_ready_gives_player_priority() -> void:
	var domain := _start_domain(_make_unit(), _make_unit())
	var cap := domain.interval_T_player

	_expect_near(cap, domain.interval_T_enemy, "test units should have equal action intervals")
	_expect_eq(
		domain.tick_advancing(cap),
		BattleDomainServiceScript.SIGNAL_PLAYER_READY,
		"player should win simultaneous ready"
	)


func _test_action_resets_actor_and_preserves_opponent_progress() -> void:
	var domain := _start_domain(_make_unit(), _make_unit())
	var cap := domain.interval_T_player
	_expect_eq(domain.tick_advancing(cap), BattleDomainServiceScript.SIGNAL_PLAYER_READY, "player ready")
	domain.enter_paused(BattleDomainServiceScript.SIDE_PLAYER)
	var payload := domain.resolve_player_basic()
	_expect_true(bool(payload.get("ok", false)), "player basic attack should resolve")
	domain.begin_presentation(BattleDomainServiceScript.SIDE_PLAYER)
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
	_expect_eq(domain.state, BattleDomainServiceScript.BattleState.END, "fatal dot end state")


func _test_time_limit_counts_advancing_only() -> void:
	var domain := _start_domain(_make_unit(), _make_unit(), 2.0)
	domain.enter_paused(BattleDomainServiceScript.SIDE_PLAYER)
	domain.tick_advancing(100.0)
	_expect_near(domain.battle_elapsed_advancing, 0.0, "paused time limit")
	domain.begin_presentation(BattleDomainServiceScript.SIDE_PLAYER)
	domain.tick_advancing(100.0)
	_expect_near(domain.battle_elapsed_advancing, 0.0, "presentation time limit")
	domain.finish_presentation()

	_expect_eq(
		domain.tick_advancing(2.0),
		BattleDomainServiceScript.SIGNAL_TIME_LIMIT,
		"time limit should count advancing time"
	)
	_expect_eq(domain.state, BattleDomainServiceScript.BattleState.END, "time limit end state")


func _make_unit(hp: float = 100.0, spd: float = 100.0, skill_cd: float = 0.0) -> FightObj:
	return FightObjScript.new({
		"hp": hp,
		"mp": 100.0,
		"attrs": {
			FightObjScript.ATTR_HP_MAX: 100.0,
			FightObjScript.ATTR_MP_MAX: 100.0,
			FightObjScript.ATTR_SHIELD: 0.0,
			FightObjScript.ATTR_ATK: 20.0,
			FightObjScript.ATTR_DEF: 0.0,
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
