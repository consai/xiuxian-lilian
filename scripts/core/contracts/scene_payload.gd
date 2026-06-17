class_name ScenePayload
extends RefCounted

const SCENE_EXPEDITION_RESULT := "expedition_result"
const SCENE_BREAKTHROUGH_SUMMARY := "breakthrough_summary"


static func expedition_result(reason: String) -> Dictionary:
	var payload := {"reason": reason}
	var errors := collect_errors(SCENE_EXPEDITION_RESULT, payload)
	if not errors.is_empty():
		return {}
	return payload


static func breakthrough_summary(summary: Dictionary) -> Dictionary:
	var payload := summary.duplicate(true)
	var errors := collect_errors(SCENE_BREAKTHROUGH_SUMMARY, payload)
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
		SCENE_EXPEDITION_RESULT:
			var reason := str(data.get("reason", ExpeditionResult.EXIT_MANUAL))
			if reason not in ExpeditionResult.VALID_EXIT_REASONS:
				errors.append("expedition_result.reason 无效: %s" % reason)
		SCENE_BREAKTHROUGH_SUMMARY:
			var mode := str(data.get("mode", "result")).strip_edges()
			if mode == "panel":
				return errors
			if str(data.get("new_realm", "")).strip_edges() == "":
				errors.append("breakthrough_summary 缺少 new_realm")
	return errors
