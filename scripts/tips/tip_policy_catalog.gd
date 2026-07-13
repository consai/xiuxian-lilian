class_name TipPolicyCatalog
extends RefCounted

const SETTINGS_PATH := "res://data/exportjson/yunxing_params/ui_tip_policy.json"
const CHANNELS_PATH := "res://data/exportjson/yunxing_params/ui_tip_policy_channels.json"
const REQUIRED_SETTINGS := ["default_dedupe_window_ms", "default_throttle_ms"]
const REQUIRED_CHANNELS := ["bar", "combat_block", "reward_item", "reward_growth", "reward_resource"]

static var _snapshot: Dictionary = {}


static func snapshot() -> Dictionary:
	if _snapshot.is_empty():
		_snapshot = _load_snapshot()
	return _snapshot.duplicate(true)


static func _load_snapshot() -> Dictionary:
	var settings_rows := JsonReader.read_object(SETTINGS_PATH)
	var channel_rows := JsonReader.read_object(CHANNELS_PATH)
	if settings_rows.is_empty() or channel_rows.is_empty():
		push_error("TipPolicyCatalog: 提示策略配置为空")
		return {}
	var out := {"channels": {}}
	for key in REQUIRED_SETTINGS:
		var row_v: Variant = settings_rows.get(key)
		if not row_v is Dictionary or not (row_v as Dictionary).get("value") is float:
			push_error("TipPolicyCatalog: %s.value 必须是数字" % key)
			return {}
		out[key] = int((row_v as Dictionary)["value"])
	for channel in REQUIRED_CHANNELS:
		var row_v: Variant = channel_rows.get(channel)
		if not row_v is Dictionary or int((row_v as Dictionary).get("max_inflight", 0)) <= 0:
			push_error("TipPolicyCatalog: %s.max_inflight 必须大于 0" % channel)
			return {}
		(out["channels"] as Dictionary)[channel] = (row_v as Dictionary).duplicate(true)
	return out
