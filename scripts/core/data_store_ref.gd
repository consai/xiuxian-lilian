extends Node

const DataStoreScript := preload("res://scripts/core/data_store.gd")

var _fallback: Node


func resolve() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		if root != null:
			var existing := root.get_node_or_null("DataStore")
			if existing != null:
				return existing
	if _fallback == null or not is_instance_valid(_fallback):
		_fallback = DataStoreScript.new()
		_fallback.name = "DataStore"
	return _fallback
