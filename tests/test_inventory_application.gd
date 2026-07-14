extends SceneTree

const InventoryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_application.gd"
)
const InventoryDomainServiceScript := preload(
	"res://scripts/features/inventory/domain/inventory_service.gd"
)
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: PackedStringArray = []
	_test_domain_requires_explicit_definition(errors)
	_test_application_add_and_reject(errors)
	_test_battle_slots(errors)
	_test_runtime_definition_snapshots(errors)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	print("PASS: inventory domain and application")
	quit(0)


func _test_domain_requires_explicit_definition(errors: PackedStringArray) -> void:
	var definition := InventoryQueryApplicationScript.definition_by_id("items_LingCao")
	var inventory: Dictionary = {}
	_expect(errors, definition != null, "known item definition loads")
	_expect(
		errors,
		InventoryDomainServiceScript.add_item(inventory, definition, 2) == 2,
		"domain adds with explicit definition"
	)
	_expect(errors, inventory == {"items_LingCao": 2}, "domain writes canonical item id")


func _test_application_add_and_reject(errors: PackedStringArray) -> void:
	var inventory: Dictionary = {}
	_expect(
		errors,
		InventoryApplicationScript.add_item(inventory, "items_LingCao", 2) == 2,
		"application adds catalog item"
	)
	var before := inventory.duplicate(true)
	_expect(
		errors,
		InventoryApplicationScript.add_item(inventory, "missing.item", 1) == 0,
		"application rejects unknown item"
	)
	_expect(errors, inventory == before, "unknown item leaves inventory unchanged")


func _test_battle_slots(errors: PackedStringArray) -> void:
	var slots := ["items_HuiQiDan", "", ""]
	var built := InventoryApplicationScript.build_battle_item_slots(
		{"items_HuiQiDan": 2}, slots
	)
	_expect(errors, built.size() == 3, "battle slots retain configured slot count")
	_expect(
		errors,
		int((built[0] as Dictionary).get("count", -1)) == 2,
		"battle slot uses inventory count"
	)


func _test_runtime_definition_snapshots(errors: PackedStringArray) -> void:
	var snapshots := InventoryApplicationScript.definition_snapshots_for_item_ids(["items_HuiQiDan"])
	_expect(errors, snapshots.get("items_HuiQiDan") is Dictionary, "runtime item snapshot is a plain dictionary")
	var snapshot := snapshots.get("items_HuiQiDan", {}) as Dictionary
	var definition := InventoryApplicationScript.definition_from_snapshot(snapshot)
	_expect(errors, definition != null and definition.id == "items_HuiQiDan", "runtime snapshot restores item definition")
	if definition != null:
		definition.name = "mutated"
		_expect(errors, str((snapshots["items_HuiQiDan"] as Dictionary).get("name", "")) != "mutated", "runtime snapshot is isolated from restored definition")
	var slots := InventoryApplicationScript.build_battle_item_slots_from_snapshots(
		{"items_HuiQiDan": 2}, ["items_HuiQiDan", "", ""], snapshots
	)
	_expect(errors, int((slots[0] as Dictionary).get("count", -1)) == 2, "battle slots consume runtime definition snapshots")


func _expect(errors: PackedStringArray, condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
