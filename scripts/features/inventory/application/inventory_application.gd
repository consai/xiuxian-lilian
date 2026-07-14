class_name InventoryApplication
extends RefCounted

const InventoryDomainServiceScript := preload("res://scripts/features/inventory/domain/inventory_service.gd")
const InventoryQueryApplicationScript := preload("res://scripts/features/inventory/application/inventory_query_application.gd")


static func add_item(inventory: Dictionary, item_id: String, count: int) -> int:
	return InventoryDomainServiceScript.add_item(inventory, InventoryQueryApplicationScript.definition_by_id(item_id), count)


static func remove_item(inventory: Dictionary, item_id: String, count: int) -> int:
	return InventoryDomainServiceScript.remove_item(inventory, item_id, count)


static func recovery_result(current_hp: float, current_mp: float, max_hp: float, max_mp: float, hp_amount: float, mp_amount: float) -> Dictionary:
	return InventoryDomainServiceScript.recovery_result(current_hp, current_mp, max_hp, max_mp, hp_amount, mp_amount)


static func transfer_capacity(inventory: Dictionary, item_id: String) -> int:
	return InventoryDomainServiceScript.transfer_capacity(inventory, InventoryQueryApplicationScript.definition_by_id(item_id))


static func transfer_item(from_inventory: Dictionary, to_inventory: Dictionary, item_id: String, count: int) -> int:
	return InventoryDomainServiceScript.transfer_item(from_inventory, to_inventory, InventoryQueryApplicationScript.definition_by_id(item_id), count)


static func transfer_all_items(from_inventory: Dictionary, to_inventory: Dictionary) -> void:
	InventoryDomainServiceScript.transfer_all_items(from_inventory, to_inventory, _definitions_for_item_ids(from_inventory.keys()))


static func add_equip(owned_equips: Array, equip_id: int) -> bool:
	return InventoryDomainServiceScript.add_equip(owned_equips, equip_id)


static func transfer_equip(from_equips: Array, to_equips: Array, equip_id: int) -> bool:
	return InventoryDomainServiceScript.transfer_equip(from_equips, to_equips, equip_id)


static func transfer_all_equips(from_equips: Array, to_equips: Array) -> void:
	InventoryDomainServiceScript.transfer_all_equips(from_equips, to_equips)


static func cycle_equip_slot(owned_equips: Array, slots: Array, index: int) -> void:
	InventoryDomainServiceScript.cycle_equip_slot(owned_equips, slots, index)


static func cycle_item_slot(inventory: Dictionary, slots: Array, index: int) -> void:
	InventoryDomainServiceScript.cycle_item_slot(inventory, slots, index, _definitions_for_item_ids(inventory.keys()))


static func build_battle_item_slots(inventory: Dictionary, slots: Array) -> Array:
	return InventoryDomainServiceScript.build_battle_item_slots(inventory, slots, _definitions_for_item_ids(slots))


static func sync_battle_item_counts(inventory: Dictionary, slots: Array, battle_slots: Array) -> void:
	InventoryDomainServiceScript.sync_battle_item_counts(inventory, slots, battle_slots)


## 为可恢复 session 生成纯值定义快照，避免 session 在运行中重新读取静态配置。
static func definition_snapshots_for_item_ids(item_ids: Array) -> Dictionary:
	var snapshots: Dictionary = {}
	for item_id_v in item_ids:
		var definition := InventoryQueryApplicationScript.definition_by_id(str(item_id_v))
		if definition == null:
			push_error("InventoryApplication: unknown item definition %s" % str(item_id_v))
			continue
		snapshots[definition.id] = definition.to_dict()
	return snapshots


static func definition_from_snapshot(snapshot: Dictionary) -> ItemDef:
	return ItemDef.from_dict(snapshot.duplicate(true))


static func build_battle_item_slots_from_snapshots(inventory: Dictionary, slots: Array, snapshots: Dictionary) -> Array:
	var definitions: Dictionary = {}
	for item_id_v in slots:
		var item_id := str(item_id_v).strip_edges()
		if item_id == "":
			continue
		var snapshot_v: Variant = snapshots.get(item_id)
		if not snapshot_v is Dictionary:
			push_error("InventoryApplication: missing runtime item definition %s" % item_id)
			continue
		var definition := definition_from_snapshot(snapshot_v as Dictionary)
		if definition == null:
			push_error("InventoryApplication: invalid runtime item definition %s" % item_id)
			continue
		definitions[item_id] = definition
	return InventoryDomainServiceScript.build_battle_item_slots(inventory, slots, definitions)


static func _definitions_for_item_ids(item_ids: Array) -> Dictionary:
	var definitions: Dictionary = {}
	for item_id_v in item_ids:
		var definition := InventoryQueryApplicationScript.definition_by_id(str(item_id_v))
		if definition != null:
			definitions[definition.id] = definition
	return definitions
