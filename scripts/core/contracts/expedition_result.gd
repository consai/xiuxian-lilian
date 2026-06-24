class_name ExpeditionResult
extends RefCounted

const EXIT_MANUAL := "manual"
const EXIT_DEFEATED := "defeated"
const EXIT_FLED := "fled"
const VALID_EXIT_REASONS := [EXIT_MANUAL, EXIT_DEFEATED, EXIT_FLED]


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func to_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func validate(data: Dictionary) -> bool:
	return collect_errors(data).is_empty()


static func collect_errors(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		errors.append("历练结算不能为空")
		return errors
	if str(data.get("settlement_id", "")).strip_edges() == "":
		errors.append("缺少 settlement_id")
	var exit_reason := str(data.get("exit_reason", ""))
	if exit_reason not in VALID_EXIT_REASONS:
		errors.append("exit_reason 无效: %s" % exit_reason)
	if int(data.get("elapsed_days", 0)) < 1:
		errors.append("elapsed_days 必须 >= 1")
	if not data.get("stats", {}) is Dictionary:
		errors.append("stats 必须是 Dictionary")
	if not data.get("loot", []) is Array:
		errors.append("loot 必须是 Array")
	else:
		for i in (data.get("loot", []) as Array).size():
			var reward_v: Variant = (data.get("loot", []) as Array)[i]
			if reward_v is Dictionary:
				errors.append_array(
					RewardEntry.collect_errors(reward_v as Dictionary, "loot[%d]" % i)
				)
	if not data.get("items", []) is Array:
		errors.append("items 必须是 Array")
	return errors
