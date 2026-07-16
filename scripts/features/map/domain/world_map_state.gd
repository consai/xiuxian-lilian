class_name WorldMapState
extends RefCounted

const REQUIRED_FIELDS := [
	"current_city_id",
	"discovered_cities",
	"discovered_regions",
	"discovered_locations",
	"vanished_nodes",
	"route_states",
	"region_exploration",
]


static func default_state() -> Dictionary:
	return {
		"current_city_id": "qingshi_market",
		"discovered_cities": ["qingshi_market"],
		"discovered_regions": [],
		"discovered_locations": [],
		"vanished_nodes": [],
		"route_states": {},
		"region_exploration": {},
	}


static func validate(raw: Variant) -> bool:
	if not raw is Dictionary:
		return _fail(
			"invalid_type", "map", "expected=Dictionary actual=%s" % type_string(typeof(raw))
		)
	var state := raw as Dictionary
	for field in REQUIRED_FIELDS:
		if not state.has(field):
			return _fail("missing_field", field)
	if not state["current_city_id"] is String:
		return _fail("invalid_type", "current_city_id", "expected=String")
	for field in [
		"discovered_cities", "discovered_regions", "discovered_locations", "vanished_nodes"
	]:
		if not _validate_string_array(state[field], field):
			return false
	for field in ["route_states", "region_exploration"]:
		if not state[field] is Dictionary:
			return _fail("invalid_type", field, "expected=Dictionary")
	return true


static func prepare(raw: Variant) -> Dictionary:
	if not validate(raw):
		return {}
	return (raw as Dictionary).duplicate(true)


static func _validate_string_array(value: Variant, field: String) -> bool:
	if not value is Array:
		return _fail("invalid_type", field, "expected=Array")
	for index in (value as Array).size():
		if not (value as Array)[index] is String:
			return _fail("invalid_type", "%s[%d]" % [field, index], "expected=String")
	return true


static func _fail(code: String, field: String, detail: String = "") -> bool:
	var message := "[world_map_state:%s] field=%s" % [code, field]
	if detail != "":
		message += " " + detail
	push_error(message)
	return false
