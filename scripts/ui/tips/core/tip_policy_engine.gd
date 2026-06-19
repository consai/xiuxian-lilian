extends RefCounted
class_name TipPolicyEngine

const _DEFAULT_CHANNEL_LIMITS := {
	TipIntent.CHANNEL_BAR: 5,
	TipIntent.CHANNEL_COMBAT_BLOCK: 2,
	TipIntent.CHANNEL_REWARD_ITEM: 4,
	TipIntent.CHANNEL_REWARD_GROWTH: 6,
	TipIntent.CHANNEL_REWARD_RESOURCE: 3,
}

var _config: Dictionary = {}
var _dedupe_last_seen_ms: Dictionary = {}
var _throttle_last_seen_ms: Dictionary = {}
var _channel_inflight_count: Dictionary = {}


func setup(config: Dictionary = {}) -> void:
	_config = config.duplicate(true)


func decide(intent: Dictionary) -> Dictionary:
	var now := Time.get_ticks_msec()
	var ttl_ms := int(intent.get("ttl_ms", TipIntent.DEFAULT_TTL_MS))
	var created_at_ms := int(intent.get("created_at_ms", now))
	if ttl_ms > 0 and now - created_at_ms > ttl_ms:
		return {"accepted": false, "reason_code": "expired"}

	var dedupe_decision := _decide_dedupe(intent, now)
	if not bool(dedupe_decision.get("accepted", true)):
		return dedupe_decision
	var throttle_decision := _decide_throttle(intent, now)
	if not bool(throttle_decision.get("accepted", true)):
		return throttle_decision
	var capacity_decision := _decide_capacity(intent)
	if not bool(capacity_decision.get("accepted", true)):
		return capacity_decision
	return {"accepted": true}


func on_tip_started(intent: Dictionary) -> void:
	var channel := str(intent.get("channel", TipIntent.CHANNEL_BAR))
	_channel_inflight_count[channel] = int(_channel_inflight_count.get(channel, 0)) + 1


func on_tip_finished(intent: Dictionary) -> void:
	var channel := str(intent.get("channel", TipIntent.CHANNEL_BAR))
	_channel_inflight_count[channel] = maxi(0, int(_channel_inflight_count.get(channel, 0)) - 1)


func _decide_dedupe(intent: Dictionary, now_ms: int) -> Dictionary:
	var key := str(intent.get("dedupe_key", "")).strip_edges()
	if key == "":
		return {"accepted": true}
	var window_ms := _effective_int(intent, "dedupe_window_ms", "default_dedupe_window_ms", 450)
	var last_ms := int(_dedupe_last_seen_ms.get(key, -window_ms - 1))
	if now_ms - last_ms < window_ms:
		return {"accepted": false, "reason_code": "deduped"}
	_dedupe_last_seen_ms[key] = now_ms
	return {"accepted": true}


func _decide_throttle(intent: Dictionary, now_ms: int) -> Dictionary:
	var key := str(intent.get("throttle_key", "")).strip_edges()
	if key == "":
		return {"accepted": true}
	var throttle_ms := _effective_int(intent, "throttle_ms", "default_throttle_ms", 160)
	var last_ms := int(_throttle_last_seen_ms.get(key, -throttle_ms - 1))
	if now_ms - last_ms < throttle_ms:
		return {"accepted": false, "reason_code": "throttled"}
	_throttle_last_seen_ms[key] = now_ms
	return {"accepted": true}


func _decide_capacity(intent: Dictionary) -> Dictionary:
	var channel := str(intent.get("channel", TipIntent.CHANNEL_BAR))
	var limit := _channel_limit(channel)
	var inflight := int(_channel_inflight_count.get(channel, 0))
	if inflight >= limit:
		return {"accepted": false, "reason_code": "dropped_capacity"}
	return {"accepted": true}


func _channel_limit(channel: String) -> int:
	var channels : Dictionary= _config.get("channels", {})
	if channels is Dictionary:
		var cfg :Dictionary= channels.get(channel, {})
		if cfg is Dictionary:
			var m := int(cfg.get("max_inflight", -1))
			if m > 0:
				return m
	return int(_DEFAULT_CHANNEL_LIMITS.get(channel, 3))


func _effective_int(intent: Dictionary, intent_key: String, global_key: String, fallback: int) -> int:
	var iv := int(intent.get(intent_key, -1))
	if iv >= 0:
		return iv
	return int(_config.get(global_key, fallback))
