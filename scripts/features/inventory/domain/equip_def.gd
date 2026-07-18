class_name InventoryEquipDef
extends RefCounted

var id: int = 0
var name: String = ""
var icon: String = ""
var quality: int = 1
var cd_total: float = 0.0
var effects: Array = []
var tags: Array = []


static func from_dict(data: Dictionary) -> InventoryEquipDef:
	if not data.has("id"):
		push_error("InventoryEquipDef.from_dict: missing id in %s" % str(data))
		return null
	var equip_id := int(data["id"])
	if equip_id <= 0:
		push_error("InventoryEquipDef.from_dict: id must be positive, got %d" % equip_id)
		return null
	var equip := InventoryEquipDef.new()
	equip.id = equip_id
	equip.name = str(data.get("name", "")).strip_edges()
	equip.icon = str(data.get("icon", data.get("icon_path", ""))).strip_edges()
	equip.quality = maxi(1, int(data.get("quality", 1)))
	equip.cd_total = maxf(0.0, float(data.get("cd_total", data.get("cd", 0.0))))
	var effects_v: Variant = data.get("effects", [])
	# 当前原样导出表将 effects 保持为 JSON 字符串；本迁移必须保持旧查询行为。
	if effects_v is Array:
		equip.effects = (effects_v as Array).duplicate(true)
	var tags_v: Variant = data.get("tags", [])
	if tags_v is Array:
		equip.tags = (tags_v as Array).duplicate(true)
	return equip


func to_runtime_dict() -> Dictionary:
	var out := {
		"id": id,
		"name": name,
		"quality": quality,
		"cd": cd_total,
		"cd_total": cd_total,
		"vfx_type": "heal",
		"vfx": "status_cast",
		"effects": effects.duplicate(true),
	}
	if icon != "":
		out["icon"] = icon
	if not tags.is_empty():
		out["tags"] = tags.duplicate(true)
	return out
