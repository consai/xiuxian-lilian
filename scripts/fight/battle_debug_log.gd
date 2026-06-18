class_name BattleDebugLog
extends RefCounted
## 战斗全流程调试输出。控制台过滤关键字：[Battle]

const PREFIX := "[Battle]"

## 总开关；可在 fight_scene 导出项覆盖。
static var enabled: bool = false
## 为 true 时，推进态约每秒打印一次走条进度（否则仅在到点/状态变化时打印）。
static var verbose_tick: bool = false

static var _tick_log_accum: float = 0.0
static var _domain: BattleDomainService = null


static func set_domain(domain: BattleDomainService) -> void:
	_domain = domain


static func clear_domain() -> void:
	_domain = null


static func format_advancing_time(domain: BattleDomainService = null) -> String:
	var d := domain if domain != null else _domain
	if d == null:
		return ""
	return "%.2f/%.2f" % [d.battle_elapsed_advancing, d.battle_time_limit]


static func reset_tick_throttle() -> void:
	_tick_log_accum = 0.0


static func state_label(state: int) -> String:
	match state:
		0:
			return "推进中"
		1:
			return "暂停"
		2:
			return "表现中"
		3:
			return "结束"
	return "未知(%d)" % state


static func side_label(side: String) -> String:
	match side.strip_edges():
		"player":
			return "玩家"
		"enemy":
			return "敌方"
		_:
			return side if side != "" else "无"


static func end_reason_label(reason: String) -> String:
	match reason.strip_edges():
		"player_dead":
			return "玩家阵亡"
		"enemy_dead":
			return "敌方阵亡"
		"time_limit":
			return "战斗超时"
		_:
			return reason if reason != "" else "无"


static func skill_type_label(skill_type: int) -> String:
	match skill_type:
		BattleVfxEvent.SkillType.MELEE:
			return "近战"
		BattleVfxEvent.SkillType.RANGED:
			return "远程"
		BattleVfxEvent.SkillType.HEAL:
			return "治疗"
		BattleVfxEvent.SkillType.BUFF:
			return "增益"
		_:
			return "其他"


static func fail_reason_label(reason: String) -> String:
	match reason.strip_edges():
		"not_paused":
			return "非暂停状态"
		"wrong_actor":
			return "出手方不匹配"
		"cannot_act":
			return "当前不可操作"
		"failed":
			return "失败"
		_:
			return reason if reason != "" else "未知"


## 勿命名为 log：会与内置 log()（自然对数）冲突。
static func write(category: String, message: String, extra: Dictionary = {}) -> void:
	if not enabled:
		return
	var head := _line_prefix()
	if extra.is_empty():
		print("%s [%s] %s" % [head, category, message])
	else:
		print("%s [%s] %s | %s" % [head, category, message, extra])


static func _line_prefix() -> String:
	var adv := format_advancing_time()
	if adv == "":
		return PREFIX
	return "[%s]%s" % [adv, PREFIX]


static func log_state(
		from_state: int,
		to_state: int,
		reason: String,
		extra: Dictionary = {}
) -> void:
	var data := {
		"从": state_label(from_state),
		"到": state_label(to_state),
		"原因": reason,
	}
	data.merge(extra, true)
	write("状态", "状态切换", data)


static func log_unit(unit: FightObj, role: String) -> Dictionary:
	if unit == null:
		return {"角色": role, "错误": "空引用"}
	return {
		"角色": side_label(role) if role in ["player", "enemy"] else role,
		"生命": "%.1f/%.1f" % [unit.hp, unit.get_hp_max()],
		"法力": "%.1f/%.1f" % [unit.mp, unit.get_mp_max()],
		"物理攻击": unit.get_attr(FightObj.ATTR_PHYSICAL_ATK),
		"法术攻击": unit.get_attr(FightObj.ATTR_MAGIC_ATK),
		"物理防御": unit.get_attr(FightObj.ATTR_PHYSICAL_DEF),
		"法术防御": unit.get_attr(FightObj.ATTR_MAGIC_DEF),
		"速度": unit.get_attr(FightObj.ATTR_SPD),
		"行动进度速率": CombatBalance.action_progress_rate_for(unit),
		"预计出手间隔": CombatBalance.interval_cap_for(unit),
	}


static func log_domain(domain: BattleDomainService, tag: String = "快照") -> void:
	if not enabled or domain == null:
		return
	write("数据", tag, domain.get_debug_snapshot())


static func tick_progress(domain: BattleDomainService, delta: float) -> void:
	if not enabled or domain == null or not verbose_tick:
		return
	_tick_log_accum += delta
	if _tick_log_accum < 1.0:
		return
	_tick_log_accum = 0.0
	write("走条", "推进中", {
		"玩家走条": domain.format_interval(EnumBattleSide.PLAYER),
		"敌方走条": domain.format_interval(EnumBattleSide.ENEMY),
	})
