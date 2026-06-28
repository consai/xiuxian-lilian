extends SceneTree

const WeituoServiceScript := preload("res://scripts/sim/weituo_service.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var store: Node = root.get_node("DataStore")
	state.new_game()
	var savedata: Dictionary = store.savedata
	savedata["inventory"]["items_LingCao"] = 10
	savedata["inventory"]["items_LingGuo"] = 5
	var accept: Dictionary = WeituoServiceScript.accept(
		"qingxin_herb_delivery_001",
		savedata,
		state
	)
	if not bool(accept.get("ok", false)):
		printerr("accept failed: %s" % str(accept))
		quit(1)
		return
	var instance_id: String = str(accept.get("instance_id", ""))
	var before_cao: int = int(state.inventory.get("items_LingCao", 0))
	var before_guo: int = int(state.inventory.get("items_LingGuo", 0))
	var submit: Dictionary = WeituoServiceScript.submit(instance_id, savedata, state)
	if not bool(submit.get("ok", false)):
		printerr("submit failed: %s" % str(submit))
		quit(1)
		return
	if int(state.inventory.get("items_LingCao", 0)) != before_cao - 3 + 10:
		printerr("LingCao net mismatch")
		quit(1)
		return
	if int(state.inventory.get("items_LingGuo", 0)) != before_guo - 2:
		printerr("LingGuo not consumed")
		quit(1)
		return
	print("PASS: weituo submit consumes items")
	quit(0)
