extends SceneTree

const BattleConfigQueryApplicationScript := preload(
	"res://scripts/features/battle/application/battle_config_query_application.gd"
)

var _failures: PackedStringArray = []


func _init() -> void:
	var ids := BattleConfigQueryApplicationScript.all_buff_ids()
	_check(ids.size() == 14, "expected all 14 exported Buff ids")
	_check(ids == _sorted_copy(ids), "Buff ids must have deterministic order")
	_check(_unique_count(ids) == ids.size(), "Buff ids must be unique")
	_check(BattleConfigQueryApplicationScript.buff_by_id("").is_empty(), "blank Buff id must return empty")
	_check(BattleConfigQueryApplicationScript.buff_by_id("missing_buff").is_empty(), "unknown Buff id must return empty")

	var first := BattleConfigQueryApplicationScript.buff_by_id("buff_0001")
	_check(str(first.get("name", "")) == "流风护身", "known Buff name changed")
	_check(float(first.get("ticktime", -1.0)) == 0.0, "ticktime -1 must normalize to no periodic tick")
	_check(first.get("modifiers") is Dictionary, "Buff modifiers must normalize to Dictionary")
	_check(first.get("tags") is Array, "Buff type must normalize to tags Array")
	(first["modifiers"] as Dictionary)[EnumPlayerAttr.SPD] = 999.0
	(first["tags"] as Array).append("mutated")
	var fresh := BattleConfigQueryApplicationScript.buff_by_id("buff_0001")
	_check(float((fresh.get("modifiers", {}) as Dictionary).get(EnumPlayerAttr.SPD, 0.0)) == 20.0, "query must deep-copy modifiers")
	_check(not (fresh.get("tags", []) as Array).has("mutated"), "query must deep-copy tags")

	var burning := BattleConfigQueryApplicationScript.buff_by_id("buff_0014")
	_check(float(burning.get("ticktime", 0.0)) == 0.5, "periodic Buff ticktime changed")
	_check(not (burning.get("tick_effects", []) as Array).is_empty(), "periodic Buff effects must remain available")
	var snapshot := BattleConfigQueryApplicationScript.all_buffs_snapshot()
	(snapshot["buff_0001"] as Dictionary)["name"] = "mutated snapshot"
	_check(str(BattleConfigQueryApplicationScript.buff_by_id("buff_0001").get("name", "")) == "流风护身", "snapshot must not mutate Catalog cache")

	var monster_ids := BattleConfigQueryApplicationScript.all_monster_ids()
	_check(monster_ids.size() == 10, "expected all 10 exported monster ids")
	_check(monster_ids == _sorted_copy(monster_ids), "monster ids must have deterministic order")
	_check(BattleConfigQueryApplicationScript.monster_by_id("").is_empty(), "blank monster id must return empty")
	_check(BattleConfigQueryApplicationScript.monster_by_id("missing_monster").is_empty(), "unknown monster id must return empty")
	var wolf := BattleConfigQueryApplicationScript.monster_by_id("qinglan_wolf")
	_check(str(wolf.get("species", "")) == "beast", "monster type must map to runtime species")
	_check(str(wolf.get("icon", "")) == "characters/003_cutout_407x512.png", "monster headicon must map to runtime icon")
	_check((wolf.get("skills", []) as Array) == [1, 0], "monster skills must preserve order and append tiaoxi")
	var wolf_attrs := wolf.get("attrs", {}) as Dictionary
	_check(float(wolf_attrs.get(EnumPlayerAttr.HP_MAX, 0.0)) == 75.0, "flat monster hp_max must map to attrs")
	_check(float(wolf_attrs.get(EnumPlayerAttr.CONTROL_POWER, 0.0)) == 100.0, "monster attrs must preserve old combat defaults")
	var drops := BattleConfigQueryApplicationScript.monster_drop_entries(wolf)
	_check(drops[0] == {"kind": "item", "id": "items_LingCao", "min": 1, "max": 3, "weight": 5}, "monster five-cell drops must keep runtime shape")
	(wolf["attrs"] as Dictionary)[EnumPlayerAttr.HP_MAX] = 999.0
	(wolf["skills"] as Array).append(999)
	var fresh_wolf := BattleConfigQueryApplicationScript.monster_by_id("qinglan_wolf")
	_check(float((fresh_wolf.get("attrs", {}) as Dictionary).get(EnumPlayerAttr.HP_MAX, 0.0)) == 75.0, "monster query must deep-copy attrs")
	_check(not (fresh_wolf.get("skills", []) as Array).has(999), "monster query must deep-copy skills")
	var monster_snapshot := BattleConfigQueryApplicationScript.all_monsters_snapshot()
	(monster_snapshot["qinglan_wolf"] as Dictionary)["name"] = "mutated monster"
	_check(str(BattleConfigQueryApplicationScript.monster_by_id("qinglan_wolf").get("name", "")) == "青牙狼", "monster snapshot must not mutate Catalog cache")

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("test_battle_config_query_application: PASS")
	quit(0)


func _sorted_copy(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out


func _unique_count(values: Array) -> int:
	var seen: Dictionary = {}
	for value in values:
		seen[value] = true
	return seen.size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
