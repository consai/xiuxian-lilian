class_name ScenePayload
extends RefCounted

const SCENE_LILIAN_JIESUAN := "lilian_jiesuan"
const SCENE_TUPO_ZONGJIE := "tupo_zongjie"


static func lilian_jiesuan(reason: String) -> Dictionary:
	var payload := {"reason": reason}
	var errors := collect_errors(SCENE_LILIAN_JIESUAN, payload)
	if not errors.is_empty():
		return {}
	return payload


static func tupo_zongjie(summary: Dictionary) -> Dictionary:
	var payload := summary.duplicate(true)
	var errors := collect_errors(SCENE_TUPO_ZONGJIE, payload)
	if not errors.is_empty():
		return {}
	return payload


static func from_dict(_scene_id: String, data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func to_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func validate(scene_id: String, data: Dictionary) -> bool:
	return collect_errors(scene_id, data).is_empty()


static func collect_errors(scene_id: String, data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	match scene_id:
		SCENE_LILIAN_JIESUAN:
			var reason := str(data.get("reason", LilianResult.EXIT_MANUAL))
			if reason not in LilianResult.VALID_EXIT_REASONS:
				errors.append("lilian_jiesuan.reason 无效: %s" % reason)
		SCENE_TUPO_ZONGJIE:
			var mode := str(data.get("mode", "result")).strip_edges()
			if mode == "panel":
				return errors
			if str(data.get("new_realm", "")).strip_edges() == "":
				errors.append("tupo_zongjie 缺少 new_realm")
	return errors
