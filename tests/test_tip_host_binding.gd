extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load("res://scripts/tips/tip_policy_catalog.gd")
	var snapshot: Dictionary = catalog.call("snapshot")
	assert(snapshot["default_dedupe_window_ms"] == 450)
	assert(snapshot["default_throttle_ms"] == 160)
	assert((snapshot["channels"] as Dictionary)["bar"]["max_inflight"] == 2)
	snapshot["default_dedupe_window_ms"] = -1
	assert((catalog.call("snapshot") as Dictionary)["default_dedupe_window_ms"] == 450)

	var data_events := root.get_node("DataEvents")
	var tip_host_script := load("res://scripts/ui/tips_host.gd")
	var standalone: Node = tip_host_script.new()
	root.add_child(standalone)
	assert(not data_events.tip_intent.is_connected(standalone._on_tip_intent))
	standalone.free()

	var app_root: Node = load("res://scenes/app/app_root.tscn").instantiate()
	root.add_child(app_root)
	var tips_host: Node = app_root.get_node("TipsHost")
	assert(data_events.tip_intent.is_connected(tips_host._on_tip_intent))
	assert(data_events.tip_intents.is_connected(tips_host._on_tip_intents))
	tips_host.bind_dependencies(data_events, catalog.call("snapshot"))
	assert(data_events.tip_intent.get_connections().filter(
		func(row: Dictionary) -> bool: return row["callable"] == tips_host._on_tip_intent
	).size() == 1)
	data_events.emit_tip_intent({"text": "binding smoke"})
	print("PASS: TipsHost explicit binding")
	quit(0)
