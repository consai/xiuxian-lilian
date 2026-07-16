class_name KnowledgeApplication
extends RefCounted

const KnowledgeStateScript := preload(
	"res://scripts/features/dao/domain/knowledge_state.gd"
)

const STATE_KEY := "knowledge"


static func prepare_candidate(candidate: Variant) -> Dictionary:
	var prepared := KnowledgeStateScript.prepare(candidate)
	return _result(
		bool(prepared.get("ok", false)),
		(prepared.get("value", {}) as Dictionary).duplicate(true),
		str(prepared.get("error", ""))
	)


static func snapshot(savedata: Dictionary) -> Dictionary:
	if not savedata.has(STATE_KEY):
		var message := "[knowledge_application:missing_state_slice] field=knowledge"
		push_error(message)
		return _result(false, {}, message)
	var prepared := prepare_candidate(savedata[STATE_KEY])
	if not bool(prepared["ok"]):
		return prepared
	return _result(true, (prepared["value"] as Dictionary).duplicate(true), "")


static func commit(savedata: Dictionary, candidate: Variant) -> Dictionary:
	var prepared := prepare_candidate(candidate)
	if not bool(prepared["ok"]):
		return prepared
	var working_copy := savedata.duplicate(true)
	working_copy[STATE_KEY] = (prepared["value"] as Dictionary).duplicate(true)
	var verified := snapshot(working_copy)
	if not bool(verified["ok"]):
		return verified
	savedata[STATE_KEY] = (verified["value"] as Dictionary).duplicate(true)
	return _result(true, (verified["value"] as Dictionary).duplicate(true), "")


static func initialize_default(savedata: Dictionary) -> Dictionary:
	if savedata.has(STATE_KEY):
		return snapshot(savedata)
	return commit(savedata, KnowledgeStateScript.default_state())


static func _result(ok: bool, value: Dictionary, error: String) -> Dictionary:
	return {
		"ok": ok,
		"value": value.duplicate(true),
		"error": error,
	}
