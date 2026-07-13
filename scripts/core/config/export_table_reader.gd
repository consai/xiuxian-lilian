class_name ExportTableReader
extends RefCounted


static func read_keyed_rows(path: String) -> Dictionary:
	var root := JsonReader.read_object(path)
	var out := {}
	for key_v in root.keys():
		var row_v: Variant = root[key_v]
		if row_v is Dictionary:
			out[str(key_v)] = _decode_value(row_v)
	return out


static func read_row_array(path: String) -> Array:
	var rows := read_keyed_rows(path)
	var keys: Array = rows.keys()
	keys.sort_custom(compare_keys)
	var out: Array = []
	for key_v in keys:
		out.append((rows[key_v] as Dictionary).duplicate(true))
	return out


static func read_settings(path: String) -> Dictionary:
	var rows := read_keyed_rows(path)
	var out := {}
	for key_v in rows.keys():
		var row := rows[key_v] as Dictionary
		var key := str(row.get("key", key_v)).strip_edges()
		if key == "":
			continue
		out[key] = _setting_payload(row)
	return out


static func compare_keys(a: Variant, b: Variant) -> bool:
	var left := str(a)
	var right := str(b)
	if left.is_valid_int() and right.is_valid_int():
		return int(left) < int(right)
	return left.naturalnocasecmp_to(right) < 0


static func _decode_value(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key_v in (value as Dictionary).keys():
			var cell: Variant = value[key_v]
			if cell != null:
				out[key_v] = _decode_value(cell)
		return out
	if value is Array:
		var out: Array = []
		for cell in value:
			out.append(_decode_value(cell))
		return out
	if value is String:
		var text := str(value).strip_edges()
		if text.begins_with("{") or text.begins_with("["):
			var parser := JSON.new()
			if parser.parse(text) == OK and (parser.data is Dictionary or parser.data is Array):
				return _decode_value(parser.data)
	return value


static func _setting_payload(row: Dictionary) -> Variant:
	if row.has("value") and row["value"] != null:
		return _coerce_scalar(row["value"])
	var out := {}
	for key_v in row.keys():
		var key := str(key_v)
		if key == "key" or key == "value":
			continue
		var value: Variant = row[key_v]
		if value == null:
			continue
		out[key] = _coerce_scalar(value)
	return out


static func _coerce_scalar(value: Variant) -> Variant:
	if not value is String:
		return value
	var text := str(value).strip_edges()
	var comment_at := text.find(" #")
	if comment_at >= 0:
		var before_comment := text.substr(0, comment_at).strip_edges()
		if before_comment.is_valid_int() or before_comment.is_valid_float() \
				or before_comment.to_lower() in ["true", "false"]:
			text = before_comment
	var lower := text.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if text.is_valid_int():
		return int(text)
	if text.is_valid_float():
		return float(text)
	return text
