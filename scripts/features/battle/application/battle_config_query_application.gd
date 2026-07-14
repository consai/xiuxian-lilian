class_name BattleConfigQueryApplication
extends RefCounted

## 战斗静态配置的只读应用入口；表现层不直接访问 Catalog 或 ConfigManager。

const BuffCatalogScript := preload("res://scripts/zhandou/buff_catalog.gd")
const MonsterCatalogScript := preload(
	"res://scripts/features/battle/infrastructure/monster_catalog.gd"
)


static func buff_by_id(buff_id: String) -> Dictionary:
	return BuffCatalogScript.buff_by_id(buff_id).duplicate(true)


static func all_buff_ids() -> Array:
	return BuffCatalogScript.all_buff_ids().duplicate()


static func all_buffs_snapshot() -> Dictionary:
	return BuffCatalogScript.all_buffs_snapshot().duplicate(true)


static func monster_by_id(monster_id: String) -> Dictionary:
	var raw := MonsterCatalogScript.monster_by_id(monster_id)
	if raw.is_empty():
		return {}
	return _normalize_monster(raw)


static func all_monster_ids() -> Array:
	return MonsterCatalogScript.all_monster_ids().duplicate()


static func all_monsters_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for monster_id_v in all_monster_ids():
		var monster_id := str(monster_id_v)
		out[monster_id] = monster_by_id(monster_id)
	return out


static func monster_drop_entries(monster: Dictionary) -> Array:
	var dropitem_v: Variant = monster.get("dropitem")
	if not dropitem_v is Array:
		return []
	var out: Array = []
	for row_v in dropitem_v as Array:
		if not row_v is Array or (row_v as Array).size() != 5:
			push_error("[battle_config_query:invalid_monster_drop] expected five-cell row")
			return []
		var cells := row_v as Array
		var kind := str(cells[0]).strip_edges()
		var reward_id: Variant = cells[1]
		if kind == "equip":
			reward_id = int(reward_id)
		out.append({
			"kind": kind,
			"id": reward_id,
			"min": int(cells[2]),
			"max": int(cells[3]),
			"weight": int(cells[4]),
		})
	return out


static func _normalize_monster(raw: Dictionary) -> Dictionary:
	var out := raw.duplicate(true)
	out["species"] = str(raw["type"]).strip_edges()
	var icon := str(raw["headicon"]).strip_edges()
	if icon == "":
		icon = str(raw["obj"]).strip_edges()
	out["icon"] = icon
	var stat_block := {
		EnumPlayerAttr.HP_MAX: raw["hp_max"],
		EnumPlayerAttr.MP_MAX: raw["mp_max"],
		EnumPlayerAttr.SHIELD: raw["shield"],
		EnumPlayerAttr.PHYSICAL_ATK: raw["physical_atk"],
		EnumPlayerAttr.MAGIC_ATK: raw["magic_atk"],
		EnumPlayerAttr.PHYSICAL_DEF: raw["physical_def"],
		EnumPlayerAttr.MAGIC_DEF: raw["magic_def"],
		EnumPlayerAttr.SPD: raw["spd"],
	}
	out["attrs"] = ZhandouAttr.from_stat_block(stat_block)
	var skills: Array = []
	for skill_v in raw["skills"] as Array:
		skills.append(int(skill_v))
	if not skills.has(0):
		skills.append(0)
	out["skills"] = skills
	return out
