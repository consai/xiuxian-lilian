class_name BreakthroughPagePayload
extends RefCounted

const MODE_PANEL := "panel"
const MODE_RESULT := "result"


static func panel() -> Dictionary:
	return {"mode": MODE_PANEL}


static func result(summary: Dictionary) -> Dictionary:
	var payload := summary.duplicate(true)
	payload["mode"] = MODE_RESULT
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
	var mode := str(data.get("mode", "")).strip_edges()
	if mode == MODE_PANEL:
		return errors
	if mode != MODE_RESULT:
		errors.append("tupo_zongjie.mode 无效: %s" % mode)
		return errors
	if str(data.get("new_realm", "")).strip_edges() == "":
		errors.append("tupo_zongjie 缺少 new_realm")
	return errors
