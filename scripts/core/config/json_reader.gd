class_name JsonReader
extends RefCounted


static func read_variant(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[config:missing_file] %s" % path)
		return null
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(path))
	if error != OK:
		push_error("[config:invalid_json] %s:%d %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data


static func read_object(path: String) -> Dictionary:
	var value: Variant = read_variant(path)
	if value == null:
		return {}
	if not value is Dictionary:
		push_error("[config:invalid_root] %s expected object, got %s" % [path, type_string(typeof(value))])
		return {}
	return (value as Dictionary).duplicate(true)
