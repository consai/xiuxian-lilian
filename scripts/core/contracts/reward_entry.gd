class_name RewardEntry
extends RefCounted

const KIND_ITEM := "item"
const KIND_EQUIP := "equip"
const KIND_CURRENCY := "currency"
const VALID_KINDS := [KIND_ITEM, KIND_EQUIP, KIND_CURRENCY]


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func to_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func validate(data: Dictionary) -> bool:
	return collect_errors(data).is_empty()


static func collect_errors(data: Dictionary, label: String = "reward") -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		errors.append("%s 不能为空" % label)
		return errors
	var kind := str(data.get("kind", KIND_ITEM))
	if kind not in VALID_KINDS:
		errors.append("%s.kind 无效: %s" % [label, kind])
	if kind == KIND_EQUIP:
		if int(data.get("id", -1)) <= 0:
			errors.append("%s 法宝 id 无效" % label)
	elif kind == KIND_ITEM:
		if str(data.get("id", "")).strip_edges() == "":
			errors.append("%s 物品 id 不能为空" % label)
	if int(data.get("count", 0)) <= 0:
		errors.append("%s.count 必须大于 0" % label)
	return errors
