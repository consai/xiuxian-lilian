extends SceneTree

const BattleConfigQueryApplicationScript := preload(
	"res://scripts/features/battle/application/battle_config_query_application.gd"
)

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_characterize_seeded_lilian_map()
	_characterize_battle_init()
	_characterize_active_skill_and_summary()
	_characterize_runtime_buff()
	_characterize_configured_buff_snapshot()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("test_lilian_battle_skill_characterization: PASS")
	quit(0)


func _characterize_seeded_lilian_map() -> void:
	var location := {"id": "characterization_valley", "min_difficulty": 2, "max_difficulty": 6, "event_pool": []}
	var first := LilianMapService.generate(location, 20260712)
	var second := LilianMapService.generate(location, 20260712)
	_check(first == second, "same seed must generate the same lilian map")
	_check(LilianMapService.is_reachable_to_exit(first), "generated lilian map must reach exit")
	_check((first.get("nodes", []) as Array).size() == 26, "generated lilian map node count changed")


func _characterize_battle_init() -> void:
	var init := ZhandouInitData.sample_for_editor()
	init["spd_jitter_ratio"] = 0.0
	_check(ZhandouInitData.collect_errors(init).is_empty(), "sample BattleInit must validate")
	var setup := ZhandouInitData.resolve(init, false)
	_check(setup != null, "valid BattleInit must resolve")
	if setup != null:
		_check(setup.player != null and setup.enemy != null, "resolved BattleInit must create both combatants")
		_check(not setup.skill_cfg.is_empty(), "resolved BattleInit must carry skill config")


func _characterize_active_skill_and_summary() -> void:
	var actor := ZhandouObj.new({
		"hp": 100.0,
		"mp": 30.0,
		"attrs": ZhandouAttr.from_stat_block({EnumPlayerAttr.PHYSICAL_ATK: 40.0}),
		"skills": [{"id": 1, "cd": 0.0}],
	})
	var target := ZhandouObj.new({
		"hp": 100.0,
		"mp": 0.0,
		"attrs": ZhandouAttr.from_stat_block({}),
		"skills": [],
	})
	var result := actor.use_skill(1, {1: {
		"id": 1,
		"mp_cost": 5.0,
		"cd": 2.0,
		"effects": [{"type": "damage", "value": 10.0, "target": "enemy"}],
	}}, target)
	_check(bool(result.get("ok", false)), "active skill must execute")
	_check(actor.mp == 25.0, "active skill must consume configured mana")
	_check(target.hp < 100.0, "active skill must change target state")
	_check(ZhandouSummary.validate({
		"outcome": ZhandouSummary.OUTCOME_WIN,
		"player_runtime": {"hp": actor.hp, "mp": actor.mp, "items": []},
	}), "battle summary contract must accept current minimal result")


func _characterize_runtime_buff() -> void:
	var first := _buff_trace()
	var second := _buff_trace()
	_check(first == second, "runtime buff rule must be repeatable")
	_check(first == [40.0, 50.0, 40.0], "runtime buff must apply and restore its modifier")


func _buff_trace() -> Array:
	var actor := ZhandouObj.new({
		"hp": 100.0,
		"mp": 20.0,
		"attrs": ZhandouAttr.from_stat_block({EnumPlayerAttr.PHYSICAL_ATK: 40.0}),
		"skills": [],
	})
	var before := actor.get_attr(EnumPlayerAttr.PHYSICAL_ATK)
	var applied := actor.add_runtime_modifier_buff("characterization_power", 2.0, {EnumPlayerAttr.PHYSICAL_ATK: 10.0})
	_check(applied, "runtime buff must apply")
	var during := actor.get_attr(EnumPlayerAttr.PHYSICAL_ATK)
	actor.tick_buffs(2.1)
	return [before, during, actor.get_attr(EnumPlayerAttr.PHYSICAL_ATK)]


func _characterize_configured_buff_snapshot() -> void:
	var definitions := BattleConfigQueryApplicationScript.all_buffs_snapshot()
	var actor := ZhandouObj.new({
		"hp": 100.0,
		"mp": 20.0,
		"attrs": ZhandouAttr.from_stat_block({EnumPlayerAttr.SPD: 100.0}),
		"skills": [],
	}, definitions)
	var applied := actor.add_buff("buff_0001")
	_check(applied == 1, "configured buff must be resolved from the injected snapshot")
	_check(actor.get_attr(EnumPlayerAttr.SPD) == 120.0, "configured buff modifier behavior changed")
	_check(not actor.to_dict().has("buff_definitions"), "static buff definitions must not enter runtime state")
	var projected := ZhandouObj.duplicate_with_advancing_projection(actor, 0.1)
	_check(projected != null, "buffed combatant projection must be created")
	if projected != null:
		_check(projected.add_buff("buff_0002") == 1, "projection must retain injected buff definitions")
	actor.tick_buffs(4.1)
	_check(actor.get_attr(EnumPlayerAttr.SPD) == 100.0, "configured buff expiry must restore modifiers")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
