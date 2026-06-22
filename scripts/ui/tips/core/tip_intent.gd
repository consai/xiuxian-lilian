extends RefCounted
class_name TipIntent

const SCHEMA_VERSION := 1

const CHANNEL_BAR := EnumTipChannel.LABEL_BAR
const CHANNEL_COMBAT_BLOCK := EnumTipChannel.LABEL_COMBAT_BLOCK
const CHANNEL_REWARD_ITEM := EnumTipChannel.LABEL_REWARD_ITEM
const CHANNEL_REWARD_GROWTH := EnumTipChannel.LABEL_REWARD_GROWTH
const CHANNEL_REWARD_RESOURCE := EnumTipChannel.LABEL_REWARD_RESOURCE

const TONE_NEUTRAL := EnumTipTone.LABEL_NEUTRAL
const TONE_GAIN := EnumTipTone.LABEL_GAIN
const TONE_LOSS := EnumTipTone.LABEL_LOSS

const TYPE_TOAST := EnumTipIntentType.LABEL_TOAST
const TYPE_HINT := EnumTipIntentType.LABEL_HINT
const TYPE_BLOCK_REASON := EnumTipIntentType.LABEL_BLOCK_REASON

const DEFAULT_TTL_MS := 2000


static func make(fields: Dictionary) -> Dictionary:
	var out := {
		"id": str(fields.get("id", "")),
		"schema_version": int(fields.get("schema_version", SCHEMA_VERSION)),
		"type": str(fields.get("type", TYPE_HINT)),
		"text": str(fields.get("text", "")),
		"tone": _normalize_tone(fields.get("tone", TONE_NEUTRAL)),
		"channel": _normalize_channel(fields.get("channel", CHANNEL_BAR)),
		"source": str(fields.get("source", "unknown")),
		"created_at_ms": int(fields.get("created_at_ms", Time.get_ticks_msec())),
		"priority": int(fields.get("priority", 0)),
		"ttl_ms": int(fields.get("ttl_ms", DEFAULT_TTL_MS)),
		"context": fields.get("context", {}),
	}
	var dedupe_key := str(fields.get("dedupe_key", "")).strip_edges()
	if dedupe_key != "":
		out["dedupe_key"] = dedupe_key
	var dedupe_window_ms := int(fields.get("dedupe_window_ms", -1))
	if dedupe_window_ms >= 0:
		out["dedupe_window_ms"] = dedupe_window_ms
	var throttle_key := str(fields.get("throttle_key", "")).strip_edges()
	if throttle_key != "":
		out["throttle_key"] = throttle_key
	var throttle_ms := int(fields.get("throttle_ms", -1))
	if throttle_ms >= 0:
		out["throttle_ms"] = throttle_ms
	return out


static func validate(intent: Dictionary) -> Dictionary:
	if int(intent.get("schema_version", SCHEMA_VERSION)) != SCHEMA_VERSION:
		return {"ok": false, "error": "schema_mismatch"}
	if str(intent.get("text", "")).strip_edges() == "":
		return {"ok": false, "error": "empty_text"}
	return {"ok": true}


static func safe(intent: Dictionary) -> Dictionary:
	var candidate := make(intent)
	var validation := validate(candidate)
	if bool(validation.get("ok", false)):
		return candidate
	# 安全降级：确保提示不丢
	candidate["schema_version"] = SCHEMA_VERSION
	candidate["channel"] = CHANNEL_BAR
	candidate["tone"] = TONE_NEUTRAL
	candidate["type"] = TYPE_HINT
	if str(candidate.get("text", "")).strip_edges() == "":
		candidate["text"] = "..."
	candidate["context"] = _safe_dict(candidate.get("context", {}))
	return candidate


static func _normalize_channel(v: Variant) -> String:
	var s := str(v).strip_edges()
	return s if EnumTipChannel.is_valid_label(s) else CHANNEL_BAR


static func _normalize_tone(v: Variant) -> String:
	return EnumTipTone.normalize_label(v)


static func _safe_dict(v: Variant) -> Dictionary:
	return v as Dictionary if v is Dictionary else {}
