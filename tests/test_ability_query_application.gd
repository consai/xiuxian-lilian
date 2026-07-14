extends SceneTree

const AbilityQueryApplicationScript := preload(
	"res://scripts/features/ability/application/ability_query_application.gd"
)
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var definitions := AbilityQueryApplicationScript.all_definitions()
	_check(definitions.size() == 39, "query must expose all 39 exported definitions")
	_check(str((definitions[0] as Dictionary).get("id", "")) == "skill_lq_001", "query definition order changed")
	(definitions[0] as Dictionary)["name"] = "mutated definition"
	_check(str((AbilityQueryApplicationScript.all_definitions()[0] as Dictionary).get("name", "")) == "引火诀", "all_definitions must deep-copy rows")
	var combat_ids_before_reload: Dictionary = {}
	for definition_v in definitions:
		var definition := definition_v as Dictionary
		var ability_id := str(definition.get("id", ""))
		if AbilityServiceScript.uses_combat_skill_slot(str(definition.get("type", ""))):
			var combat_id := AbilityQueryApplicationScript.combat_id_for(ability_id)
			_check(combat_id > 0, "slot ability must have a positive combat id: %s" % ability_id)
			combat_ids_before_reload[ability_id] = combat_id
	_check(AbilityQueryApplicationScript.combat_id_for("passive_0001") == -1, "always-active passive must not receive a combat id")
	AbilityServiceScript.reload()
	for ability_id_v in combat_ids_before_reload.keys():
		var ability_id := str(ability_id_v)
		_check(
			AbilityQueryApplicationScript.combat_id_for(ability_id) == int(combat_ids_before_reload[ability_id_v]),
			"combat id changed after reload: %s" % ability_id
		)
	var skill_cfg := AbilityServiceScript.build_skill_cfg({})
	var skills := skill_cfg.get("skills", {}) as Dictionary
	_check(bool((skills.get("0", {}) as Dictionary).get("is_tiaoxi", false)), "skill config id 0 must remain tiaoxi")
	_check(skills.size() == combat_ids_before_reload.size() + 1, "skill config must contain every slot ability plus tiaoxi")
	for combat_id_v in combat_ids_before_reload.values():
		var combat_id := int(combat_id_v)
		_check(skills.has(str(combat_id)), "skill config missing combat id %d" % combat_id)
		_check(not (skills.get(str(combat_id), {}) as Dictionary).is_empty(), "skill config runtime is empty for combat id %d" % combat_id)
	var known_id := _first_known_combat_id()
	_check(known_id > 0, "expected at least one configured combat skill")

	var known := AbilityQueryApplicationScript.runtime_by_combat_id(known_id)
	var tiaoxi := AbilityQueryApplicationScript.runtime_by_combat_id(0)
	var unknown := AbilityQueryApplicationScript.runtime_by_combat_id(2147483647)

	_check(not known.is_empty(), "known combat skill must return a runtime dictionary")
	_check(int(tiaoxi.get("id", -1)) == 0, "combat id 0 must remain tiaoxi")
	_check(unknown.is_empty(), "unknown combat id must return an empty dictionary")
	_check(AbilityQueryApplicationScript.combat_id_for("ability.combat.tiaoxi") == 0, "tiaoxi combat id must remain zero")
	_check(AbilityQueryApplicationScript.combat_id_for("skill_lq_001") == 1, "first active combat id changed")

	var original_name := str(known.get("name", ""))
	known["name"] = "mutated by test"
	var fresh := AbilityQueryApplicationScript.runtime_by_combat_id(known_id)
	_check(str(fresh.get("name", "")) == original_name, "query result must not mutate cached ability data")

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("test_ability_query_application: PASS")
	quit(0)


func _first_known_combat_id() -> int:
	for combat_id in range(1, 1024):
		if not AbilityQueryApplicationScript.runtime_by_combat_id(combat_id).is_empty():
			return combat_id
	return -1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
