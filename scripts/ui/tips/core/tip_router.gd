extends RefCounted
class_name TipRouter

var _presenters: Dictionary = {}


func register_presenter(channel: String, presenter: Object) -> void:
	if channel == "" or presenter == null:
		return
	_presenters[channel] = presenter


func route(intent: Dictionary) -> Dictionary:
	var channel := str(intent.get("channel", TipIntent.CHANNEL_BAR))
	var presenter: Object = _presenters.get(channel, null)
	if presenter == null:
		presenter = _presenters.get(TipIntent.CHANNEL_BAR, null)
		if presenter == null:
			return {"ok": false, "reason_code": "missing_presenter"}
	if not presenter.has_method("present_tip"):
		return {"ok": false, "reason_code": "invalid_presenter"}
	var result :Dictionary= presenter.present_tip(intent)
	var out := result as Dictionary if result is Dictionary else {}
	if out.is_empty():
		out = {"ok": true}
	if not out.has("ok"):
		out["ok"] = true
	return out
