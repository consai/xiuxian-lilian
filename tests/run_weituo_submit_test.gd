extends SceneTree

const WeituoServiceScript := preload("res://scripts/sim/weituo_service.gd")
const InventoryServiceScript := preload("res://scripts/sim/inventory_service.gd")


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
	var after_cao: int = int(state.inventory.get("items_LingCao", 0))
	var after_guo: int = int(state.inventory.get("items_LingGuo", 0))
	# 需求 3 草 + 2 果；奖励 +10 草，净 +7 草、-2 果
	var expected_cao: int = before_cao - 3 + 10
	var expected_guo: int = before_guo - 2
	if after_cao != expected_cao:
		printerr("LingCao mismatch: before=%d after=%d expected=%d" % [before_cao, after_cao, expected_cao])
		quit(1)
		return
	if after_guo != expected_guo:
		printerr("LingGuo mismatch: before=%d after=%d expected=%d" % [before_guo, after_guo, expected_guo])
		quit(1)
		return
	print("PASS: weituo submit consumes items")
	_test_node_typed_inventory_mutation(state)
	quit(0)


func _test_node_typed_inventory_mutation(state: Node) -> void:
	state.inventory["items_LingCao"] = 20
	var node_ref: Node = state
	InventoryServiceScript.remove_item(node_ref.inventory, "items_LingCao", 5)
	var after: int = int(state.inventory.get("items_LingCao", 0))
	if after != 15:
		printerr("Node-typed inventory mutation failed: expected 15 got %d" % after)
		quit(1)
	print("PASS: Node-typed inventory mutation")
