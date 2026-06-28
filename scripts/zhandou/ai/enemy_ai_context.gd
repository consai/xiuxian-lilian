class_name EnemyAiContext
extends RefCounted
## 敌方 AI 决策只读上下文快照。

var self_unit: ZhandouObj
var target: ZhandouObj
var skill_cfg: Dictionary = {}
var item_cfg: Dictionary = {}
var equip_cfg: Dictionary = {}
var self_hp_ratio: float = 1.0
var target_hp_ratio: float = 1.0
var battle_elapsed: float = 0.0
var active_phase_id: String = ""


static func from_units(
		enemy: ZhandouObj,
		player: ZhandouObj,
		skill_cfg: Dictionary,
		item_cfg: Dictionary = {},
		equip_cfg: Dictionary = {},
		domain_ctx: Dictionary = {}
) -> EnemyAiContext:
	var ctx := EnemyAiContext.new()
	ctx.self_unit = enemy
	ctx.target = player
	ctx.skill_cfg = skill_cfg if skill_cfg is Dictionary else {}
	ctx.item_cfg = item_cfg if item_cfg is Dictionary else {}
	ctx.equip_cfg = equip_cfg if equip_cfg is Dictionary else {}
	ctx.self_hp_ratio = _hp_ratio(enemy)
	ctx.target_hp_ratio = _hp_ratio(player)
	ctx.battle_elapsed = float(domain_ctx.get("battle_elapsed", 0.0))
	ctx.active_phase_id = str(domain_ctx.get("active_phase_id", ""))
	return ctx


static func _hp_ratio(unit: ZhandouObj) -> float:
	if unit == null:
		return 0.0
	var cap := unit.get_hp_max()
	if cap <= 0.0:
		return 0.0
	return clampf(unit.hp / cap, 0.0, 1.0)
