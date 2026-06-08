class_name PlayerBattleSnapshot
extends RefCounted


static func from_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func to_dict(data: Dictionary) -> Dictionary:
	return data.duplicate(true)


static func validate(data: Dictionary) -> bool:
	return collect_errors(data).is_empty()


static func collect_errors(data: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if data.is_empty():
		errors.append("player 快照不能为空")
		return errors
	if not data.has("hp") or not data.has("mp"):
		errors.append("player 缺少 hp/mp")
	var attrs_v: Variant = data.get("attrs", {})
	if not attrs_v is Dictionary:
		errors.append("player.attrs 必须是 Dictionary")
	else:
		errors.append_array(FightAttr.validate_core(attrs_v as Dictionary))
	if not data.get("skills", []) is Array:
		errors.append("player.skills 必须是 Array")
	if not data.get("items", []) is Array:
		errors.append("player.items 必须是 Array")
	if not data.get("equips", []) is Array:
		errors.append("player.equips 必须是 Array")
	return errors
