class_name LilianSettlementPayload
extends RefCounted

const LilianResultContract := preload("res://scripts/features/lilian/contracts/lilian_result.gd")


static func create(reason: String) -> Dictionary:
	var payload := {"reason": reason}
	if not validate(payload):
		return {}
	return payload


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func to_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func validate(data: Dictionary) -> bool:
	return collect_errors(data).is_empty()


static func collect_errors(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var reason := str(data.get("reason", "")).strip_edges()
	if reason not in LilianResultContract.VALID_EXIT_REASONS:
		errors.append("lilian_jiesuan.reason 无效: %s" % reason)
	return errors
