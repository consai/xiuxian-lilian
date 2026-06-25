class_name BattleVfxEvent
extends RefCounted

## 战斗逻辑层 → 表现层 的事件载荷（与 [FightObj] 解耦）。

var source_id: String = ""
var target_id: String = ""
var damage_value: float = 0.0
var skill_type: EnumBattleVfxSkillType.Type = EnumBattleVfxSkillType.Type.MELEE
var extra: Dictionary = {}


static func from_dict(data: Dictionary) -> BattleVfxEvent:
	var ev := BattleVfxEvent.new()
	ev.source_id = str(data.get("source_id", data.get("SourceID", ""))).strip_edges()
	ev.target_id = str(data.get("target_id", data.get("TargetID", ""))).strip_edges()
	ev.damage_value = float(data.get("damage_value", data.get("DamageValue", 0.0)))
	ev.skill_type = _parse_skill_type(data.get("skill_type", data.get("SkillType", "melee")))
	var ex: Variant = data.get("extra", {})
	if ex is Dictionary:
		ev.extra = (ex as Dictionary).duplicate(true)
	return ev


static func _parse_skill_type(raw: Variant) -> EnumBattleVfxSkillType.Type:
	return EnumBattleVfxSkillType.from_label(raw)
