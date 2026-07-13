extends SceneTree

const SceneManagerScript := preload("res://scripts/core/scene_manager.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for route_id_v in SceneManagerScript.SCENE_PATHS:
		var route_id := str(route_id_v)
		var path := str(SceneManagerScript.SCENE_PATHS[route_id_v])
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("route %s cannot load %s" % [route_id, path])
			quit(1)
			return
		var scene := packed.instantiate()
		root.add_child(scene)
		await process_frame
		scene.queue_free()
		await process_frame
	print("PASS: %d route scenes" % SceneManagerScript.SCENE_PATHS.size())
	quit(0)
