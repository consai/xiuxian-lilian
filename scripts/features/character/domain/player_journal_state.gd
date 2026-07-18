class_name PlayerJournalState
extends RefCounted

const MAX_ENTRIES := 30
const ENTRY_KEYS := ["day", "text"]


static func default_state() -> Array:
	return []


static func prepare(candidate: Variant) -> Dictionary:
	if not candidate is Array:
		return _failure("invalid_root_type", "activity_log")
	var entries := candidate as Array
	if entries.size() > MAX_ENTRIES:
		return _failure("too_many_entries", "activity_log")
	for index in entries.size():
		var entry_v: Variant = entries[index]
		var field := "activity_log.%d" % index
		if not entry_v is Dictionary:
			return _failure("invalid_entry_type", field)
		var entry := entry_v as Dictionary
		if entry.size() != ENTRY_KEYS.size():
			return _failure("invalid_entry_fields", field)
		for key in ENTRY_KEYS:
			if not entry.has(key):
				return _failure("missing_field", "%s.%s" % [field, key])
		if not entry["day"] is int or int(entry["day"]) < 1:
			return _failure("invalid_day", "%s.day" % field)
		if not entry["text"] is String or str(entry["text"]).strip_edges() == "":
			return _failure("invalid_text", "%s.text" % field)
	return _result(true, entries.duplicate(true), "")


static func append(current: Variant, day: Variant, text: Variant) -> Dictionary:
	var prepared := prepare(current)
	if not bool(prepared.get("ok", false)):
		return prepared
	if not day is int or int(day) < 1:
		return _failure("invalid_day", "activity_log.append.day")
	if not text is String or str(text).strip_edges() == "":
		return _failure("invalid_text", "activity_log.append.text")
	var next := prepared["value"] as Array
	next.append({"day": int(day), "text": str(text)})
	if next.size() > MAX_ENTRIES:
		next = next.slice(next.size() - MAX_ENTRIES)
	return _result(true, next, "")


static func _failure(code: String, field: String) -> Dictionary:
	var message := "[player_journal_state:%s] field=%s" % [code, field]
	push_error(message)
	return _result(false, [], message)


static func _result(ok: bool, value: Array, error: String) -> Dictionary:
	return {"ok": ok, "value": value.duplicate(true), "error": error}
