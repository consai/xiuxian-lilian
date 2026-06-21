extends SceneTree

const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const KnowledgeStudyServiceScript := preload("res://scripts/dao/knowledge_study_service.gd")
const KnowledgeEffectServiceScript := preload("res://scripts/dao/knowledge_effect_service.gd")
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
	failed += _run("self_study", _test_self_study)
	failed += _run("cultivation_cycle", _test_cultivation_cycle)
	failed += _run("ability_learn_gate", _test_ability_learn)
	failed += _run("method_slot_weights", _test_method_slot_weights)
	failed += _run("knowledge_level_effects", _test_knowledge_level_effects)
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


func _test_self_study() -> void:
	var savedata := {
		"knowledge": {},
		"foundations": {"body": 16, "spirit": 16, "sense": 14, "agility": 14},
		"aptitudes": {"comprehension": 12, "fortune": 10},
	}
	var result := KnowledgeStudyServiceScript.apply_study(savedata, "foundation.breathing", 30, "qi")
	if float(result.get("xp", 0.0)) <= 0.0:
		push_error("self study should apply knowledge xp")
	if KnowledgeServiceScript.effective_level(savedata, "foundation.breathing") > 3.0:
		push_error("self study should not exceed default max level III")
	var slow := {
		"knowledge": {},
		"foundations": {"body": 10, "spirit": 10, "sense": 10, "agility": 10},
		"aptitudes": {"comprehension": 8, "will": 8, "fortune": 8},
	}
	var fast := {
		"knowledge": {},
		"foundations": {"body": 10, "spirit": 10, "sense": 10, "agility": 10},
		"aptitudes": {"comprehension": 20, "will": 20, "fortune": 8},
	}
	var slow_preview := KnowledgeStudyServiceScript.preview(slow, "foundation.breathing", 10, "qi")
	var fast_preview := KnowledgeStudyServiceScript.preview(fast, "foundation.breathing", 10, "qi")
	if float(fast_preview.get("xp", 0.0)) <= float(slow_preview.get("xp", 0.0)):
		push_error("higher learning attributes should increase self-study training points")


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


func _test_knowledge_level_effects() -> void:
	var rows := [
		{
			"skillId": "foundation.breathing",
			"level": 1,
			"effectId": "max_mana",
			"base": 5.0,
			"operation": "add_flat",
			"stackGroup": "test_breathing_mana",
			"stackPolicy": "add_capped",
			"cap": 50.0,
		},
		{
			"skillId": "foundation.breathing",
			"level": 2,
			"effectId": "max_mana",
			"base": 7.0,
			"operation": "add_flat",
			"stackGroup": "test_breathing_mana",
			"stackPolicy": "add_capped",
			"cap": 50.0,
		},
		{
			"skillId": "foundation.breathing",
			"level": 2,
			"effectId": "accuracy",
			"base": 0.1,
			"operation": "add_percent",
			"stackGroup": "test_breathing_accuracy",
			"stackPolicy": "add_capped",
			"cap": 0.5,
		},
		{
			"skillId": "foundation.breathing",
			"level": 1,
			"effectId": "unknown_effect",
			"base": 1.0,
		},
	]
	var partial := {"knowledge": {}}
	KnowledgeServiceScript.apply_xp(partial, "foundation.breathing", 10.0, "test")
	var partial_mods := KnowledgeEffectServiceScript.resolve_modifiers(partial, rows)
	if not (partial_mods.get("sources", []) as Array).is_empty():
		push_error("partial knowledge xp should not activate level effects")
	var savedata := {"knowledge": {}}
	KnowledgeServiceScript.grant_level(savedata, "foundation.breathing", 2)
	var mods := KnowledgeEffectServiceScript.resolve_modifiers(savedata, rows)
	var flat := mods.get("flat", {}) as Dictionary
	var percent := mods.get("percent", {}) as Dictionary
	if not is_equal_approx(float(flat.get(FightAttr.MP_MAX, 0.0)), 12.0):
		push_error("knowledge level effects should stack learned levels")
	if not is_equal_approx(float(percent.get(FightAttr.ACCURACY, 0.0)), 0.1):
		push_error("knowledge level percent effects should resolve")
	if (mods.get("unmapped", []) as Array).is_empty():
		push_error("unmapped knowledge effects should be reported")
