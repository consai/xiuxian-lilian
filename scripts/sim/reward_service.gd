class_name RewardService
extends RefCounted

const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")


static func roll_rewards(encounter: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	var random := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		random.randomize()
	var pool: Array = encounter.get("rewards", []) as Array
	var rolls := maxi(0, int(encounter.get("reward_rolls", 0)))
	var out: Array = []
	for _i in rolls:
		var row := _weighted_pick(pool, random)
		if row.is_empty():
			continue
		var reward := row.duplicate(true)
		reward["count"] = random.randi_range(
			maxi(1, int(row.get("min", 1))),
			maxi(1, int(row.get("max", 1)))
		)
		reward.erase("weight")
		reward.erase("min")
		reward.erase("max")
		out.append(reward)
	return merge_rewards(out)


static func apply_rewards(game_state: Node, rewards: Array) -> Array:
	var applied: Array = []
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var reward := reward_v as Dictionary
		var reward_errors := RewardEntry.collect_errors(reward)
		if not reward_errors.is_empty():
			push_error("RewardEntry: %s" % reward_errors[0])
			continue
		var kind := str(reward.get("kind", "item"))
		var count := maxi(1, int(reward.get("count", 1)))
		if kind == "equip":
			var eid := int(reward.get("id", -1))
			if InventoryServiceScript.add_equip(game_state.owned_equips, eid):
				applied.append({"kind": kind, "id": eid, "count": 1})
			else:
				var compensation := count * 30
				game_state.ling_stones += compensation
				applied.append({"kind": "currency", "id": "ling_stones", "count": compensation})
		elif kind == "currency":
			var currency_id := str(reward.get("id", "ling_stones"))
			if currency_id == "ling_stones":
				game_state.ling_stones += count
				applied.append({"kind": kind, "id": currency_id, "count": count})
		else:
			var iid := str(reward.get("id", ""))
			var added := InventoryServiceScript.add_item(game_state.inventory, iid, count)
			if added > 0:
				applied.append({"kind": "item", "id": iid, "count": added})
	return applied


static func _weighted_pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for row_v in pool:
		if row_v is Dictionary:
			total += maxi(0, int((row_v as Dictionary).get("weight", 1)))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for row_v in pool:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		roll -= maxi(0, int(row.get("weight", 1)))
		if roll <= 0:
			return row
	return {}


static func merge_rewards(rows: Array) -> Array:
	var merged: Dictionary = {}
	for row_v in rows:
		var row := row_v as Dictionary
		var key := "%s:%s" % [str(row.get("kind", "")), str(row.get("id", ""))]
		if merged.has(key):
			(merged[key] as Dictionary)["count"] = int((merged[key] as Dictionary)["count"]) + int(row["count"])
		else:
			merged[key] = row.duplicate(true)
	return merged.values()
