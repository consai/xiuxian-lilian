extends SceneTree

const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const AbilityServiceScript := preload("res://scripts/dao/ability_service.gd")


func _initialize() -> void:
	DaoTreeServiceScript.reload()
	CultivationMethodServiceScript.reload()
	AbilityServiceScript.reload()
	var failed := 0
	failed += _run("prereqs_met", _test_prereqs)
	failed += _run("apply_xp", _test_apply_xp)
	failed += _run("cultivation_cycle", _test_cultivation_cycle)
	failed += _run("ability_learn_gate", _test_ability_learn)
	failed += _run("method_slot_weights", _test_method_slot_weights)
	quit(1 if failed > 0 else 0)


func _run(name: String, callable: Callable) -> int:
	callable.call()
	print("PASS %s" % name)
	return 0


func _test_prereqs() -> void:
	var savedata := {"knowledge": {}}
	KnowledgeServiceScript.grant_level(savedata, "foundation.breathing", 3)
	var ok := DaoTreeServiceScript.prereqs_met("foundation.control", KnowledgeServiceScript.effective_levels_map(savedata))
	if not ok:
		push_error("foundation.control prereqs should pass with breathing III")


func _test_apply_xp() -> void:
	var savedata := {"knowledge": {}}
	var result := KnowledgeServiceScript.apply_xp(savedata, "foundation.breathing", 500.0, "test")
	if int(result.get("levels_gained", 0)) <= 0:
		push_error("apply_xp should level up foundation.breathing")


func _test_cultivation_cycle() -> void:
	var savedata := {
		"knowledge": {},
		"method_mastery": {},
		"cultivation_method_slots": {"main": "method.hunyuan.1"},
	}
	var result := CultivationMethodServiceScript.apply_cultivation_cycle(savedata, 40.0)
	if (result.get("knowledge", []) as Array).is_empty():
		push_error("cultivation cycle should grant knowledge xp")


func _test_ability_learn() -> void:
	var savedata := {
		"knowledge": {},
		"method_mastery": {},
		"cultivation_method_slots": {"main": "method.hunyuan.1"},
	}
	KnowledgeServiceScript.grant_level(savedata, "spell.projectile", 1)
	KnowledgeServiceScript.grant_level(savedata, "foundation.control", 1)
	var ok := AbilityServiceScript.can_learn("ability.combat.qi_bolt", savedata, "qi")
	if not ok:
		push_error("ability.combat.qi_bolt should be learnable with starter knowledge")


func _test_method_slot_weights() -> void:
	var savedata := {"knowledge": {}, "method_mastery": {}}
	var result := CultivationMethodServiceScript.build_modifiers({
		"main": "method.hunyuan.1",
		"support_1": "method.basic_breathing.1",
		"support_2": "method.small_cycle.1",
		"movement": "method.hunyuan.1",
	}, savedata)
	var weights: Dictionary = {}
	for source_v in result.get("sources", []) as Array:
		var source := source_v as Dictionary
		weights[str(source.get("slot", ""))] = float(source.get("weight", 0.0))
	if not is_equal_approx(float(weights.get("main", 0.0)), 1.0):
		push_error("main method weight should be 1.0")
	if not is_equal_approx(float(weights.get("support_1", 0.0)), 0.4):
		push_error("support method weight should be 0.4")
	if not is_equal_approx(float(weights.get("movement", 0.0)), 0.5):
		push_error("movement method weight should be 0.5")
