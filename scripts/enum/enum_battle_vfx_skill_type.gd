class_name EnumBattleVfxSkillType
extends RefCounted

## 战斗 VFX 事件的技能表现分类。

enum Type {
	MELEE,
	RANGED,
	HEAL,
	BUFF,
	OTHER,
}


static func from_label(raw: Variant) -> Type:
	if raw is int:
		return clampi(raw, 0, Type.size() - 1) as Type
	var key := str(raw).strip_edges().to_lower()
	match key:
		"melee", "physical", "attack", "近战":
			return Type.MELEE
		"ranged", "remote", "magic", "spell", "远程":
			return Type.RANGED
		"heal", "治疗":
			return Type.HEAL
		"buff", "shield", "护盾":
			return Type.BUFF
		_:
			return Type.OTHER
