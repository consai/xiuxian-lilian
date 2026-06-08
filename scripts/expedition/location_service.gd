class_name LocationService
extends RefCounted


static func all_locations() -> Array:
	var cm := _config_manager()
	if cm != null and cm.has_method("all_locations"):
		return cm.call("all_locations") as Array
	return []


static func by_id(location_id: String) -> Dictionary:
	var cm := _config_manager()
	if cm != null and cm.has_method("location_by_id"):
		return cm.call("location_by_id", location_id) as Dictionary
	return {}


static func has_location(location_id: String) -> bool:
	return not by_id(location_id).is_empty()


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
