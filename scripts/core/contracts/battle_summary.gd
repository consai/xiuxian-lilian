class_name BattleSummary
extends RefCounted

const OUTCOME_WIN := BattleRecordTypes.OUTCOME_WIN
const OUTCOME_LOSS := BattleRecordTypes.OUTCOME_LOSS
const OUTCOME_DRAW := BattleRecordTypes.OUTCOME_DRAW
const OUTCOME_ESCAPED := BattleRecordTypes.OUTCOME_ESCAPED
const VALID_OUTCOMES := [OUTCOME_WIN, OUTCOME_LOSS, OUTCOME_DRAW, OUTCOME_ESCAPED]


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func to_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func validate(data: Dictionary) -> bool:
	return collect_errors(data).is_empty()


static func collect_errors(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		errors.append("battle summary 不能为空")
		return errors
	var outcome := str(data.get("outcome", ""))
	if outcome not in VALID_OUTCOMES:
		errors.append("battle summary.outcome 无效: %s" % outcome)
	var runtime_v: Variant = data.get("player_runtime", {})
	if runtime_v is Dictionary and not (runtime_v as Dictionary).is_empty():
		if not (runtime_v as Dictionary).has("hp"):
			errors.append("player_runtime 缺少 hp")
		if not (runtime_v as Dictionary).has("mp"):
			errors.append("player_runtime 缺少 mp")
		if not (runtime_v as Dictionary).get("items", []) is Array:
			errors.append("player_runtime.items 必须是 Array")
	return errors
