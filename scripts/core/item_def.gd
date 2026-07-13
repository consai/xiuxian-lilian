class_name ItemDef
extends RefCounted

const EnumItemTypeScript := preload("res://scripts/enum/enum_itemtype.gd")

## 与导出的物品配置 id 一致（字符串）
var id: String = ""
var name: String = ""
var item_type: String = ""
var primary_type: String = ""
var secondary_type: String = ""
var quality: int = 1
var tier: int = 1
var desc: String = ""
var stackable: int = 1
var max_stack: int = 999
## 灵石基准价（收购参考）；未配置则为 0，部分商店不出价收购。
var base_ling_shi: int = 0
## 背包/详情图标，[code]res://[/code] 纹理路径；空则 UI 按类型用默认图。
var icon_path: String = ""
## 直接使用时的效果行：[[code]{ "op", "args" }[/code]]；空数组表示不可直接使用。
var use_effect: Array = []
## 战斗内使用时的效果行，与技能 [code]effects[/code] 相同：[[code]{ "type", "value", "target" }[/code]]。
var fight_effect: Array = []
## 战斗槽位引用 id（[code]player.items[].id[/code]）；未配置或为 0 时不进入 [code]item_cfg[/code]。
var fight_id: int = 0
var fight_cd: float = 0.0
var fight_mp_cost: float = 0.0
var learn_ability_id: String = ""
var learn_method_id: String = ""


static func resolve_icon_texture(icon_path: String, fallback: Texture2D) -> Texture2D:
	var p := icon_path.strip_edges()
	if p != "" and ResourceLoader.exists(p):
		var res := load(p)
		if res is Texture2D:
			return res as Texture2D
	return fallback


func has_use_effect() -> bool:
	return not use_effect.is_empty()


func get_use_effect_amount(op: String, default_value: float = 0.0) -> float:
	for effect_v in use_effect:
		if not effect_v is Dictionary:
			continue
		var effect := effect_v as Dictionary
		if str(effect.get("op", "")) != op:
			continue
		var args_v: Variant = effect.get("args", [])
		if args_v is Array and not (args_v as Array).is_empty():
			return float((args_v as Array)[0])
	return default_value


func is_cultivation_pill() -> bool:
	return get_use_effect_amount("pill_cultivation") > 0.0


func is_pill() -> bool:
	return EnumItemTypeScript.is_pill_secondary(secondary_type)


func has_fight_config() -> bool:
	return fight_id > 0 and not fight_effect.is_empty()


func is_learning_book() -> bool:
	return learn_ability_id != "" or learn_method_id != ""


func is_treasure() -> bool:
	return EnumItemTypeScript.is_treasure_primary(primary_type)


func to_fight_runtime_dict() -> Dictionary:
	var out := {
		"id": fight_id,
		"name": name,
		"quality": quality,
		"tier": tier,
		"effects": fight_effect.duplicate(true),
		"cd": fight_cd,
		"cd_total": fight_cd,
		"mp_cost": fight_mp_cost,
		"vfx_type": "heal",
		"vfx": "status_cast",
	}
	if icon_path != "":
		out["icon"] = icon_path
	return out


static func from_dict(data: Dictionary) -> ItemDef:
	## 参数说明：
	## - data: 单条道具配置字典
	if not data.has("id") or not data.has("name"):
		push_error("ItemDef.from_dict: missing id or name in %s" % str(data))
		return null
	var item := ItemDef.new()
	item.id = str(data["id"]).strip_edges()
	item.name = str(data["name"]).strip_edges()
	if item.id == "" or item.name == "":
		push_error("ItemDef.from_dict: id/name cannot be empty in %s" % str(data))
		return null
	var legacy_type := str(data.get("type", "")).strip_edges()
	item.primary_type = EnumItemTypeScript.resolve_primary_label(
		str(data.get("primary_type", "")),
		str(data.get("secondary_type", "")),
		legacy_type
	)
	item.secondary_type = EnumItemTypeScript.resolve_secondary_label(
		item.primary_type,
		str(data.get("secondary_type", "")),
		legacy_type
	)
	item.item_type = EnumItemTypeScript.full_label(item.primary_type, item.secondary_type)
	if not data.has("quality"):
		push_error("ItemDef.from_dict: missing quality in %s" % item.id)
		return null
	item.quality = int(data.get("quality", 0))
	if not EnumQuality.is_valid_quality(item.quality):
		push_error("ItemDef.from_dict: invalid quality %s in %s" % [str(data.get("quality")), item.id])
		return null
	if not data.has("tier"):
		push_error("ItemDef.from_dict: missing tier in %s" % item.id)
		return null
	item.tier = int(data.get("tier", 0))
	if not EnumItemTier.is_valid_tier(item.tier):
		push_error("ItemDef.from_dict: invalid tier %s in %s" % [str(data.get("tier")), item.id])
		return null
	item.desc = str(data.get("desc", ""))
	item.stackable = int(data.get("stackable", 1))
	item.max_stack = maxi(1, int(data.get("max_stack", 999)))
	item.base_ling_shi = maxi(0, int(data.get("ling_shi", data.get("base_ling_shi", 0))))
	item.icon_path = str(data.get("icon", data.get("icon_path", data.get("tuBiao", "")))).strip_edges()
	var ue: Variant = data.get("use_effect", data.get("shiYongXiaoGuo", null))
	if ue is Array:
		item.use_effect = _normalize_use_effects(ue as Array)
	else:
		item.use_effect = []
	var fe: Variant = data.get("fight_effect", null)
	if fe is Array:
		item.fight_effect = (fe as Array).duplicate(true)
	else:
		item.fight_effect = []
	item.fight_id = maxi(0, int(data.get("fight_id", 0)))
	item.fight_cd = maxf(0.0, float(data.get("fight_cd", data.get("cd", 0.0))))
	item.fight_mp_cost = maxf(0.0, float(data.get("fight_mp_cost", data.get("mp_cost", 0.0))))
	item.learn_ability_id = str(data.get("learn_ability_id", "")).strip_edges()
	item.learn_method_id = str(data.get("learn_method_id", "")).strip_edges()
	if item.stackable == 0:
		item.max_stack = 1
	return item


static func _normalize_use_effects(rows: Array) -> Array:
	var out: Array = []
	for row_v in rows:
		if row_v is Dictionary:
			out.append((row_v as Dictionary).duplicate(true))
			continue
		if not row_v is Array or (row_v as Array).is_empty():
			push_error("ItemDef: use_effect row must be a non-empty Array or Dictionary")
			continue
		var cells := row_v as Array
		var op := str(cells[0]).strip_edges().to_lower()
		if op == "":
			push_error("ItemDef: use_effect op cannot be empty")
			continue
		var args := cells.slice(1).duplicate(true)
		while not args.is_empty() and (args.back() == null or str(args.back()).strip_edges() == ""):
			args.pop_back()
		out.append({"op": op, "args": args})
	return out
