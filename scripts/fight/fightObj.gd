class_name FightObj
extends RefCounted

## 单场战斗中的单位快照：气血/法力、属性、技能与物品冷却、下次行动时间。

const ATTR_HP_MAX := FightAttr.HP_MAX
const ATTR_MP_MAX := FightAttr.MP_MAX
const ATTR_SHIELD := FightAttr.SHIELD
const ATTR_SPD := FightAttr.SPD
const ATTR_CRIT := FightAttr.CRIT
const ATTR_CRIT_DAMAGE := FightAttr.CRIT_DAMAGE
const ATTR_PHYSICAL_ATK := FightAttr.PHYSICAL_ATK
const ATTR_MAGIC_ATK := FightAttr.MAGIC_ATK
const ATTR_PHYSICAL_DEF := FightAttr.PHYSICAL_DEF
const ATTR_MAGIC_DEF := FightAttr.MAGIC_DEF
const CombatEventScript = preload("res://scripts/fight/combat_event.gd")
const CombatReportScript = preload("res://scripts/fight/combat_report.gd")

const RESOURCE_MANA := "mana"
const RESOURCE_SPIRIT := "spirit"
const RESOURCE_STAMINA := "stamina"

const test_attr: Dictionary = FightAttr.TEST_DEFAULTS

var hp: float = 0.0
var mp: float = 0.0
var attrs: Dictionary = {}
## 技能/物品槽位（按栏位顺序）；元素为 [code]{ "id": int, "cd": float, ... }[/code]，[code]id < 0[/code] 为空槽。
var skills: Array = []
var equips: Array = []
var items: Array = []
## 当前挂接的 Buff：key 为 buff_id，value 为运行时实例（stacks、duration_left、tick_accum 等）。
var buffs: Dictionary = {}
var next_action_time: float = 0.0
## 运行时事件队列，由 Domain 层拉取并转发到表现层。
var _runtime_events: Array = []

# 初始化
func _init(data: Dictionary = {}) -> void:
	apply_dict(data)

# 应用数据
func apply_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("hp"):
		hp = float(data["hp"])
	if data.has("mp"):
		mp = float(data["mp"])
	if data.has("next_action_time"):
		next_action_time = float(data["next_action_time"])
	var attrs_in: Variant = data.get("attrs", null)
	if attrs_in is Dictionary:
		_merge_attrs(attrs_in as Dictionary)
	var skills_in: Variant = data.get("skills", null)
	skills = _normalize_slot_array(skills_in)
	var equips_in: Variant = data.get("equips", null)
	equips = _normalize_slot_array(equips_in)
	var items_in: Variant = data.get("items", null)
	items = _normalize_slot_array(items_in)
	var buffs_in: Variant = data.get("buffs", null)
	if buffs_in is Dictionary:
		buffs = _duplicate_nested_dict(buffs_in as Dictionary)

# 创建stub
static func create_stub(side: String = "player") -> FightObj:
	var attrs := test_attr.duplicate(true)
	attrs[ATTR_SHIELD] = 0.0
	var hp_max := float(attrs[ATTR_HP_MAX])
	var mp_max := float(attrs[ATTR_MP_MAX])
	var skill_cd_total := 5.0
	var cm := _get_config_manager()
	if cm != null and cm.has_method("skill_by_id"):
		var cfg: Dictionary = cm.call("skill_by_id", 1) as Dictionary
		if not cfg.is_empty():
			skill_cd_total = float(cfg.get("cd", skill_cd_total))
	var row := {
		"hp": hp_max,
		"mp": mp_max,
		"attrs": attrs,
		"skills": [
			{"id": 1, "cd": 0.0, "cd_total": skill_cd_total},
		],
		"items": [
			{"id": 9001, "cd": 0.0, "count": 5},
		],
		"equips": [
			{"id": -1, "cd": 0.0},
		],
		"next_action_time": 0.0,
	}
	var unit := FightObj.new(row)
	unit.clamp_vitals()
	return unit


static func _get_config_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")

# 转换为字典
func to_dict() -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"attrs": attrs.duplicate(true),
		"skills": _duplicate_slot_array(skills),
		"equips": _duplicate_slot_array(equips),
		"items": _duplicate_slot_array(items),
		"buffs": _duplicate_nested_dict(buffs),
		"next_action_time": next_action_time,
	}

# 获取属性
func get_attr(key: String, default_value: float = 0.0) -> float:
	var k := key.strip_edges()
	if k == "":
		return default_value
	var raw: Variant = attrs.get(k, default_value)
	if raw is int:
		return float(raw)
	if raw is float:
		return raw
	return float(raw)

# 设置属性
func set_attr(key: String, value: float) -> void:
	var k := key.strip_edges()
	if k == "":
		return
	attrs[k] = value

# 获取气血上限
func get_hp_max() -> float:
	return maxf(1.0, get_attr(ATTR_HP_MAX, 1.0))

# 获取法力上限	  
func get_mp_max() -> float:
	return maxf(0.0, get_attr(ATTR_MP_MAX, 0.0))

# 限制气血和法力
func clamp_vitals() -> void:
	hp = clampf(hp, 0.0, get_hp_max())
	mp = clampf(mp, 0.0, get_mp_max())

# 合并属性
func _merge_attrs(overlay: Dictionary) -> void:
	for k in overlay.keys():
		attrs[str(k)] = overlay[k]

# 复制嵌套字典  
static func _duplicate_nested_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in src.keys():
		var v: Variant = src[k]
		if v is Dictionary:
			out[k] = (v as Dictionary).duplicate(true)
		else:
			out[k] = v
	return out

#设置下次行动时间
func set_next_action_time(time: float) -> void:
	next_action_time = time

# 获取下次行动时间
func get_next_action_time() -> float:
	return next_action_time

# 设置技能冷却
func set_skill_cd(skill_id: int, cd: float) -> void:
	var slot := _get_skill_slot(skill_id)
	if not slot.is_empty():
		slot["cd"] = cd

# 获取技能冷却
func get_skill_cd(skill_id: int) -> float:
	var slot := _get_skill_slot(skill_id)
	if slot.is_empty():
		return 0.0
	return float(slot.get("cd", 0.0))

# 设置物品冷却
func set_item_cd(item_id: int, cd: float) -> void:
	var slot := _get_item_slot(item_id)
	if not slot.is_empty():
		slot["cd"] = cd

# 获取物品冷却
func get_item_cd(item_id: int) -> float:
	var slot := _get_item_slot(item_id)
	if slot.is_empty():
		return 0.0
	return float(slot.get("cd", 0.0))

# 死亡
func on_death() -> void:
	pass

# 是否死亡
func is_dead() -> bool:
	return hp <= 0

# hp 变化
func change_hp(value: float) -> void:
	hp += value
	clamp_vitals()
	if hp <= 0:
		on_death()

# mp 变化
func change_mp(value: float) -> void:
	mp += value
	clamp_vitals()

# 护盾变化
func change_shield(value: float) -> void:
	set_attr(ATTR_SHIELD, maxf(0.0, get_attr(ATTR_SHIELD) + value))


func _lookup_buff_def(buff_id: String) -> Dictionary:
	var bid := buff_id.strip_edges()
	if bid == "":
		return {}
	var cm := _get_config_manager()
	if cm != null and cm.has_method("buff_by_id"):
		var cfg: Dictionary = cm.call("buff_by_id", bid) as Dictionary
		if not cfg.is_empty():
			return cfg
	return {}


func add_buff(buff_id: String, stacks_add: int = 1, duration_override: float = -1.0) -> int:
	var bid := buff_id.strip_edges()
	if bid == "" or stacks_add <= 0:
		return 0
	var def := _lookup_buff_def(bid)
	if def.is_empty():
		push_warning("FightObj.add_buff: unknown buff '%s'" % bid)
		return 0
	var max_stacks := maxi(1, int(def.get("max_stacks", 1)))
	var ticktime := maxf(0.01, float(def.get("ticktime", 1.0)))
	var duration := float(def.get("duration", 0.0))
	if duration_override >= 0.0:
		duration = duration_override
	var tick_effects: Array = []
	var tick_v: Variant = def.get("tick_effects", [])
	if tick_v is Array:
		tick_effects = (tick_v as Array).duplicate(true)
	var stat_mods := BuffDef.normalize_modifiers(def.get("modifiers", {}))
	var inst: Dictionary
	if buffs.has(bid):
		inst = buffs[bid] as Dictionary
	else:
		inst = {
			"id": bid,
			"stacks": 0,
			"duration_left": duration,
			"tick_accum": 0.0,
			"ticktime": ticktime,
			"tick_effects": tick_effects,
			"stat_modifiers": stat_mods.duplicate(true),
		}
		buffs[bid] = inst
	var old_stacks := int(inst.get("stacks", 0))
	var new_stacks := mini(max_stacks, old_stacks + stacks_add)
	var applied := new_stacks - old_stacks
	if applied <= 0:
		return 0
	inst["stacks"] = new_stacks
	inst["duration_left"] = duration
	inst["ticktime"] = ticktime
	inst["tick_effects"] = tick_effects
	inst["stat_modifiers"] = stat_mods.duplicate(true)
	if not stat_mods.is_empty():
		attrs = FightAttr.apply_modifiers(attrs, stat_mods, applied)
	return applied


func add_runtime_modifier_buff(
		buff_id: String,
		duration: float,
		flat_modifiers: Dictionary = {},
		percent_modifiers: Dictionary = {}
) -> bool:
	var bid := buff_id.strip_edges()
	if bid == "" or duration <= 0.0:
		return false
	if buffs.has(bid):
		_expire_buff(bid)
	var resolved: Dictionary = {}
	for key in flat_modifiers.keys():
		resolved[str(key)] = float(flat_modifiers[key])
	for key in percent_modifiers.keys():
		var stat := str(key)
		resolved[stat] = float(resolved.get(stat, 0.0)) + get_attr(stat, 0.0) * float(percent_modifiers[key])
	var inst := {
		"id": bid,
		"stacks": 1,
		"duration_left": duration,
		"tick_accum": 0.0,
		"ticktime": 1.0,
		"tick_effects": [],
		"stat_modifiers": resolved,
	}
	buffs[bid] = inst
	if not resolved.is_empty():
		attrs = FightAttr.apply_modifiers(attrs, resolved)
	return true


func remove_buff(buff_id: String, stacks_remove: int = 1) -> void:
	var bid := buff_id.strip_edges()
	if bid == "" or stacks_remove <= 0:
		return
	if not buffs.has(bid):
		return
	var inst := buffs[bid] as Dictionary
	var old_stacks := int(inst.get("stacks", 0))
	if old_stacks <= 0:
		buffs.erase(bid)
		return
	var stat_mods_v: Variant = inst.get("stat_modifiers", {})
	var stat_mods: Dictionary = stat_mods_v as Dictionary if stat_mods_v is Dictionary else {}
	var removed := mini(stacks_remove, old_stacks)
	var new_stacks := old_stacks - removed
	if not stat_mods.is_empty() and removed > 0:
		attrs = FightAttr.apply_modifiers(attrs, stat_mods, -removed)
	if new_stacks <= 0:
		buffs.erase(bid)
	else:
		inst["stacks"] = new_stacks


func tick_buffs(delta: float) -> void:
	if delta <= 0.0 or buffs.is_empty() or is_dead():
		return
	var expired: Array[String] = []
	for bid_v in buffs.keys():
		var bid := str(bid_v)
		var inst_v: Variant = buffs[bid]
		if not inst_v is Dictionary:
			expired.append(bid)
			continue
		var inst := inst_v as Dictionary
		var stacks := int(inst.get("stacks", 0))
		if stacks <= 0:
			expired.append(bid)
			continue
		var duration_left := float(inst.get("duration_left", 0.0))
		if duration_left <= 0.0:
			expired.append(bid)
			continue
		var ticktime := maxf(0.01, float(inst.get("ticktime", 1.0)))
		var tick_accum := float(inst.get("tick_accum", 0.0))
		var alive := minf(delta, duration_left)
		duration_left -= alive
		inst["duration_left"] = duration_left
		var tick_effects_v: Variant = inst.get("tick_effects", [])
		if tick_effects_v is Array and not (tick_effects_v as Array).is_empty() and ticktime > 0.0:
			tick_accum += alive
			while tick_accum >= ticktime and duration_left > 0.0:
				tick_accum -= ticktime
				_apply_buff_tick_effects(tick_effects_v as Array, stacks, bid)
				if is_dead():
					break
		inst["tick_accum"] = tick_accum
		if duration_left <= 0.0 or is_dead():
			expired.append(bid)
	for bid in expired:
		_expire_buff(bid)


func _expire_buff(buff_id: String) -> void:
	var bid := buff_id.strip_edges()
	if bid == "" or not buffs.has(bid):
		return
	var inst := buffs[bid] as Dictionary
	var stacks := int(inst.get("stacks", 0))
	var stat_mods_v: Variant = inst.get("stat_modifiers", {})
	var stat_mods: Dictionary = stat_mods_v as Dictionary if stat_mods_v is Dictionary else {}
	if stacks > 0 and not stat_mods.is_empty():
		attrs = FightAttr.apply_modifiers(attrs, stat_mods, -stacks)
	buffs.erase(bid)
	_runtime_events.append(CombatEventScript.buff_expired("", bid))


func _apply_buff_tick_effects(tick_effects: Array, stacks: int, buff_id: String = "") -> void:
	if stacks <= 0:
		return
	var buff_name := _buff_display_name(buff_id)
	for eff_v in tick_effects:
		if not eff_v is Dictionary:
			continue
		var eff := eff_v as Dictionary
		var scaled := float(eff.get("value", 0.0)) * float(stacks)
		match str(eff.get("type", "")):
			"damage":
				var absorbed := be_attacked(scaled)
				if scaled > 0.0:
					_runtime_events.append(CombatEventScript.buff_tick_damage("", {
						CombatReportScript.KEY_DAMAGE: scaled,
						CombatReportScript.KEY_RAW_DAMAGE: scaled,
						CombatReportScript.KEY_HP_DAMAGE: maxf(0.0, scaled - absorbed),
						CombatReportScript.KEY_SHIELD_ABSORBED: absorbed,
						CombatReportScript.KEY_BUFF_NAME: buff_name,
					}))
			"heal":
				change_hp(scaled)
			"shield":
				change_shield(scaled)
			"restore_mp":
				change_mp(scaled)


func is_crit(crit: float) -> bool:
	return FightAttr.roll_crit(crit)


## 普攻数据结算（无前后摇）。
static func resolve_basic_attack(attacker: FightObj, defender: FightObj) -> Dictionary:
	if not FightAttr.roll_hit(attacker.attrs, defender.attrs):
		var missed := CombatReportScript.empty_fx_report()
		missed[CombatReportScript.KEY_MISSED] = true
		return missed
	var report := FightAttr.calc_basic_damage(attacker.attrs, defender.attrs)
	var raw_damage := float(report.get(CombatReportScript.KEY_DAMAGE, 0.0))
	var shield_abs := defender.be_attacked(raw_damage)
	report[CombatReportScript.KEY_DAMAGE] = raw_damage
	report[CombatReportScript.KEY_RAW_DAMAGE] = raw_damage
	report[CombatReportScript.KEY_HP_DAMAGE] = maxf(0.0, raw_damage - shield_abs)
	report[CombatReportScript.KEY_SHIELD_ABSORBED] = shield_abs
	report[CombatReportScript.KEY_HEAL] = 0.0
	report[CombatReportScript.KEY_MP_GAIN] = 0.0
	report[CombatReportScript.KEY_BUFF_NAMES] = []
	return report


## 使用技能。 [param skill_cfg] 为 [code]id -> 配置[/code] 表；[param target] 为受击方（伤害类效果）。
## 返回 [code]{ ok, reason }[/code]。
func use_skill(skill_id: int, skill_cfg: Dictionary = {}, target: FightObj = null) -> Dictionary:
	var slot := _get_skill_slot(skill_id)
	if slot.is_empty():
		return _fail_use("no_skill")
	if get_skill_cd(skill_id) > 0.0:
		return _fail_use("on_cooldown")
	var cfg := _lookup_cfg(skill_cfg, skill_id)
	if cfg.is_empty():
		return _fail_use("no_cfg")
	cfg = merged_slot_runtime_cfg(slot, cfg)
	if not can_pay_costs(cfg):
		return _fail_use("no_mp")
	pay_costs(cfg)
	var cd_total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
	slot["cd"] = cd_total
	var fx_report := _apply_skill_effects(cfg, target)
	return _merge_use_success(fx_report)


## 使用物品。 [param item_cfg] 为 [code]id -> 配置[/code] 表。
func use_item(item_id: int, item_cfg: Dictionary = {}) -> Dictionary:
	var slot := _get_item_slot(item_id)
	if slot.is_empty():
		return _fail_use("no_item")
	if get_item_cd(item_id) > 0.0:
		return _fail_use("on_cooldown")
	var count := int(slot.get("count", 0))
	if count <= 0:
		return _fail_use("no_count")
	var cfg := _lookup_cfg(item_cfg, item_id)
	if not can_pay_costs(cfg):
		return _fail_use("no_mp")
	pay_costs(cfg)
	slot["count"] = count - 1
	var cd_total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
	slot["cd"] = cd_total
	var fx_report := _apply_effects_with_routing(cfg, null)
	var out := _merge_use_success(fx_report)
	out["item_id"] = item_id
	return out


func use_item_at(slot_index: int, item_cfg: Dictionary = {}, target: FightObj = null) -> Dictionary:
	var slot := get_item_slot_at(slot_index)
	if slot.is_empty():
		return _fail_use("no_item")
	var item_id := int(slot.get("id", -1))
	if item_id < 0:
		return _fail_use("no_item")
	var cd := float(slot.get("cd", 0.0))
	if cd > 0.0:
		return _fail_use("on_cooldown")
	var count := int(slot.get("count", 0))
	if count <= 0:
		return _fail_use("no_count")
	var cfg := _lookup_cfg(item_cfg, item_id)
	if cfg.is_empty():
		return _fail_use("no_cfg")
	if not can_pay_costs(cfg):
		return _fail_use("no_mp")
	pay_costs(cfg)
	slot["count"] = count - 1
	var cd_total := float(slot.get("cd_total", cfg.get("cd", 0.0)))
	slot["cd"] = cd_total
	var fx_report := _apply_effects_with_routing(cfg, target)
	var out := _merge_use_success(fx_report)
	out["item_id"] = item_id
	return out


func use_equip_at(slot_index: int, target: FightObj = null, equip_cfg: Dictionary = {}) -> Dictionary:
	var slot := get_equip_slot_at(slot_index)
	if slot.is_empty():
		return _fail_use("no_equip")
	var equip_id := int(slot.get("id", -1))
	if equip_id < 0:
		return _fail_use("no_equip")
	var cd := float(slot.get("cd", 0.0))
	if cd > 0.0:
		return _fail_use("on_cooldown")
	var base_cfg := _lookup_cfg(equip_cfg, equip_id)
	var cost_cfg := base_cfg.duplicate(true)
	if slot.has("costs"):
		cost_cfg["costs"] = slot.get("costs", [])
	elif slot.has("mp_cost"):
		cost_cfg["mp_cost"] = slot.get("mp_cost", 0.0)
	if not can_pay_costs(cost_cfg):
		return _fail_use("no_mp")
	pay_costs(cost_cfg)
	var cd_total := float(slot.get("cd_total", base_cfg.get("cd_total", base_cfg.get("cd", 0.0))))
	slot["cd"] = cd_total
	var effect_src := slot.duplicate(true)
	var fx_report := _apply_effects_with_routing(effect_src, target)
	var out := _merge_use_success(fx_report)
	out["equip_id"] = equip_id
	return out


## 受到伤害：先扣护盾，再扣气血。返回护盾吸收量。
func be_attacked(value: float) -> float:
	if value <= 0.0:
		return 0.0
	var remaining := value
	var absorbed := 0.0
	var shield := get_attr(ATTR_SHIELD)
	if shield > 0.0:
		absorbed = minf(shield, remaining)
		set_attr(ATTR_SHIELD, shield - absorbed)
		remaining -= absorbed
	if remaining > 0.0:
		change_hp(-remaining)
	return absorbed


func tick_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return
	tick_buffs(delta)
	for slot_v in skills:
		if slot_v is Dictionary:
			_tick_slot_cd(slot_v as Dictionary, delta)
	for slot_v in equips:
		if slot_v is Dictionary:
			_tick_slot_cd(slot_v as Dictionary, delta)
	for slot_v in items:
		if slot_v is Dictionary:
			_tick_slot_cd(slot_v as Dictionary, delta)


## 按走条推进时长折算冷却/回蓝，用于敌人意图预测（不含暂停与表现阶段）。
func apply_advancing_projection(advancing_seconds: float) -> void:
	if advancing_seconds <= 0.0:
		return
	tick_cooldowns(advancing_seconds)
	var mp_ticks := int(floor(advancing_seconds / 2.0))
	if mp_ticks > 0:
		var mp_gain := get_attr(FightAttr.COMBAT_MP_RESTORE_2S, 0.0) * float(mp_ticks)
		if mp_gain > 0.0:
			change_mp(mp_gain)
	clamp_vitals()


static func duplicate_with_advancing_projection(source: FightObj, advancing_seconds: float) -> FightObj:
	if source == null:
		return null
	if advancing_seconds <= 0.0:
		return source
	var projected := FightObj.new(source.to_dict())
	projected.apply_advancing_projection(advancing_seconds)
	return projected


func get_skill_slot_at(index: int) -> Dictionary:
	if index < 0 or index >= skills.size():
		return {}
	var slot_v: Variant = skills[index]
	return slot_v as Dictionary if slot_v is Dictionary else {}


func get_item_slot_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var slot_v: Variant = items[index]
	return slot_v as Dictionary if slot_v is Dictionary else {}


func get_equip_slot_at(index: int) -> Dictionary:
	if index < 0 or index >= equips.size():
		return {}
	var slot_v: Variant = equips[index]
	return slot_v as Dictionary if slot_v is Dictionary else {}


func get_skill_cd_at(index: int) -> float:
	return float(get_skill_slot_at(index).get("cd", 0.0))


func get_item_cd_at(index: int) -> float:
	return float(get_item_slot_at(index).get("cd", 0.0))


func get_equip_cd_at(index: int) -> float:
	return float(get_equip_slot_at(index).get("cd", 0.0))


func _get_skill_slot(skill_id: int) -> Dictionary:
	return _find_slot_by_id(skills, skill_id)


func _get_item_slot(item_id: int) -> Dictionary:
	return _find_slot_by_id(items, item_id)


static func _normalize_slot_array(raw: Variant) -> Array:
	if raw is Array:
		return _duplicate_slot_array(raw as Array)
	return []


static func _duplicate_slot_array(raw: Array) -> Array:
	var out: Array = []
	for slot_v in raw:
		if slot_v is Dictionary:
			out.append((slot_v as Dictionary).duplicate(true))
	return out


static func _find_slot_by_id(slots: Array, id: int) -> Dictionary:
	for slot_v in slots:
		if not slot_v is Dictionary:
			continue
		var slot := slot_v as Dictionary
		if int(slot.get("id", -999)) == id:
			return slot
	return {}


## 兼容旧代码：按技能/物品 id 查找槽位（同 id 多槽时返回第一个）。
static func _find_slot(map: Variant, id: int) -> Dictionary:
	if map is Array:
		return _find_slot_by_id(map as Array, id)
	if map is Dictionary:
		var dict := map as Dictionary
		if dict.has(id):
			var v: Variant = dict[id]
			return v as Dictionary if v is Dictionary else {}
		var ks := str(id)
		if dict.has(ks):
			var v2: Variant = dict[ks]
			return v2 as Dictionary if v2 is Dictionary else {}
	return {}


static func _lookup_cfg(cfg_map: Dictionary, id: int) -> Dictionary:
	if cfg_map.has(id):
		var v: Variant = cfg_map[id]
		return v as Dictionary if v is Dictionary else {}
	var ks := str(id)
	if cfg_map.has(ks):
		var v2: Variant = cfg_map[ks]
		return v2 as Dictionary if v2 is Dictionary else {}
	return {}


static func merged_slot_runtime_cfg(slot: Dictionary, base_cfg: Dictionary) -> Dictionary:
	var cfg := base_cfg.duplicate(true)
	if slot.is_empty():
		return cfg
	for key in ["costs", "cost_text", "mp_cost", "can_miss", "accuracy_bonus"]:
		if slot.has(key):
			cfg[key] = slot[key]
	if slot.has("power_scale"):
		cfg["power"] = float(cfg.get("power", 1000.0)) * float(slot.get("power_scale", 1.0))
	elif slot.has("power"):
		cfg["power"] = slot["power"]
	var effect_scale := float(slot.get("effect_value_scale", slot.get("damage_scale", 1.0)))
	if not is_equal_approx(effect_scale, 1.0):
		cfg["effects"] = _scaled_runtime_effects(
			cfg.get("effects", cfg.get("fight_effect", [])),
			effect_scale
		)
	return cfg


static func _scaled_runtime_effects(raw: Variant, scale: float) -> Array:
	var out: Array = []
	if not raw is Array:
		return out
	for eff_v in raw as Array:
		if not eff_v is Dictionary:
			continue
		var eff := (eff_v as Dictionary).duplicate(true)
		var effect_type := str(eff.get("type", "")).strip_edges().to_lower()
		if effect_type in ["damage", "heal", "shield", "restore_mp"] and eff.has("value"):
			eff["value"] = float(eff.get("value", 0.0)) * scale
		out.append(eff)
	return out


func can_pay_costs(cfg: Dictionary) -> bool:
	return mp >= combat_resource_cost(cfg)


func pay_costs(cfg: Dictionary) -> void:
	var cost := combat_resource_cost(cfg)
	if cost > 0.0:
		change_mp(-cost)


static func combat_resource_cost(cfg: Dictionary) -> float:
	var costs := normalize_costs(cfg)
	var total := 0.0
	for cost_v in costs:
		if cost_v is Dictionary:
			total += maxf(0.0, float((cost_v as Dictionary).get("value", 0.0)))
	return total


static func normalize_costs(cfg: Dictionary) -> Array:
	var out: Array = []
	var costs_v: Variant = cfg.get("costs", [])
	if costs_v is Array:
		for cost_v in costs_v as Array:
			if not cost_v is Dictionary:
				continue
			var cost := cost_v as Dictionary
			var resource := str(cost.get("resource", RESOURCE_MANA)).strip_edges().to_lower()
			var value := maxf(0.0, float(cost.get("value", 0.0)))
			if value <= 0.0:
				continue
			out.append({"resource": resource, "value": value})
	if out.is_empty():
		var mp_cost := maxf(0.0, float(cfg.get("mp_cost", 0.0)))
		if mp_cost > 0.0:
			out.append({"resource": RESOURCE_MANA, "value": mp_cost})
	return out


static func _fail_use(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _tick_slot_cd(slot: Dictionary, delta: float) -> void:
	var cd := float(slot.get("cd", 0.0))
	if cd <= 0.0:
		return
	slot["cd"] = maxf(0.0, cd - delta)


static func _empty_fx_report() -> Dictionary:
	return CombatReportScript.empty_fx_report()


static func _merge_use_success(fx_report: Dictionary) -> Dictionary:
	var normalized := CombatReportScript.normalize_report(fx_report)
	return {
		"ok": true,
		"reason": "",
		CombatReportScript.KEY_DAMAGE: float(normalized.get(CombatReportScript.KEY_DAMAGE, 0.0)),
		CombatReportScript.KEY_RAW_DAMAGE: float(normalized.get(CombatReportScript.KEY_RAW_DAMAGE, 0.0)),
		CombatReportScript.KEY_HP_DAMAGE: float(normalized.get(CombatReportScript.KEY_HP_DAMAGE, 0.0)),
		CombatReportScript.KEY_IS_CRIT: bool(fx_report.get(CombatReportScript.KEY_IS_CRIT, false)),
		CombatReportScript.KEY_HEAL: float(normalized.get(CombatReportScript.KEY_HEAL, 0.0)),
		CombatReportScript.KEY_MP_GAIN: float(normalized.get(CombatReportScript.KEY_MP_GAIN, 0.0)),
		CombatReportScript.KEY_SHIELD_ABSORBED: float(normalized.get(CombatReportScript.KEY_SHIELD_ABSORBED, 0.0)),
		CombatReportScript.KEY_BUFF_NAMES: _duplicate_buff_names(
			normalized.get(CombatReportScript.KEY_BUFF_NAMES, [])
		),
		CombatReportScript.KEY_MISSED: bool(normalized.get(CombatReportScript.KEY_MISSED, false)),
		CombatReportScript.KEY_CONTROL_RESISTED: bool(
			normalized.get(CombatReportScript.KEY_CONTROL_RESISTED, false)
		),
	}


static func _duplicate_buff_names(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw as Array:
			var s := str(v).strip_edges()
			if s != "":
				out.append(s)
	return out


func _apply_skill_effects(cfg: Dictionary, target: FightObj) -> Dictionary:
	return _apply_effects_with_routing(cfg, target)


func _apply_effects_with_routing(cfg: Dictionary, default_target: FightObj = null) -> Dictionary:
	var power_scale := float(cfg.get("power", 1000.0)) / 1000.0
	var damage_type := _damage_type_from_cfg(cfg)
	var report := _empty_fx_report()
	var buff_names: Array = report["buff_names"] as Array
	var effects: Variant = cfg.get("effects", cfg.get("fight_effect", []))
	if not effects is Array:
		return report
	for eff_v in effects as Array:
		if not eff_v is Dictionary:
			continue
		var eff := eff_v as Dictionary
		var eff_type := str(eff.get("type", "")).strip_edges().to_lower()
		var target := _resolve_effect_target(eff, eff_type, default_target)
		match eff_type:
			"damage":
				if target == null:
					continue
				var can_miss := bool(eff.get("can_miss", cfg.get("can_miss", true)))
				var accuracy_bonus := float(eff.get(
					"accuracy_bonus", cfg.get("accuracy_bonus", 0.0)
				))
				if can_miss and not FightAttr.roll_hit(attrs, target.attrs, accuracy_bonus):
					report[CombatReportScript.KEY_MISSED] = true
					continue
				var hit := FightAttr.calc_skill_damage(
					attrs, target.attrs, power_scale, _scaled_effect_value(eff),
					str(eff.get("damage_type", damage_type)),
					float(eff.get("armor_pierce", 0.0))
				)
				var dmg := float(hit.get("damage", 0.0))
				if bool(hit.get("is_crit", false)):
					report[CombatReportScript.KEY_IS_CRIT] = true
				var absorbed := target.be_attacked(dmg)
				report[CombatReportScript.KEY_SHIELD_ABSORBED] = float(
					report[CombatReportScript.KEY_SHIELD_ABSORBED]
				) + absorbed
				report[CombatReportScript.KEY_RAW_DAMAGE] = float(
					report[CombatReportScript.KEY_RAW_DAMAGE]
				) + dmg
				report[CombatReportScript.KEY_HP_DAMAGE] = float(
					report[CombatReportScript.KEY_HP_DAMAGE]
				) + maxf(0.0, dmg - absorbed)
				# 兼容旧字段语义：damage 继续表示意图伤害（raw）。
				report[CombatReportScript.KEY_DAMAGE] = float(
					report[CombatReportScript.KEY_RAW_DAMAGE]
				)
			"heal":
				var heal_val := _scaled_effect_value(eff)
				var heal_target := target if target != null else self
				heal_target.change_hp(heal_val)
				report[CombatReportScript.KEY_HEAL] = float(report[CombatReportScript.KEY_HEAL]) + heal_val
			"shield":
				var shield_target := target if target != null else self
				shield_target.change_shield(_scaled_effect_value(eff))
			"restore_mp":
				var mp_val := _scaled_effect_value(eff)
				var mp_target := target if target != null else self
				mp_target.change_mp(mp_val)
				report[CombatReportScript.KEY_MP_GAIN] = float(
					report[CombatReportScript.KEY_MP_GAIN]
				) + mp_val
			"buff", "apply_buff", "buff_add":
				var buff_result := _collect_buff_names_from_effect(eff, target, buff_names)
				if bool(buff_result.get("resisted", false)):
					report[CombatReportScript.KEY_CONTROL_RESISTED] = true
			"timed_modifier":
				var mod_target := target if target != null else self
				var mod_id := str(eff.get("id", "runtime_modifier"))
				if mod_target.add_runtime_modifier_buff(
						mod_id,
						float(eff.get("duration", 1.0)),
						eff.get("modifiers", {}) as Dictionary,
						eff.get("percent_modifiers", {}) as Dictionary
				):
					buff_names.append(_runtime_buff_display_name(eff, mod_id))
			"control":
				if target == null:
					continue
				var base_chance := float(eff.get("control_chance", 1.0))
				if not FightAttr.roll_control(attrs, target.attrs, base_chance):
					report[CombatReportScript.KEY_CONTROL_RESISTED] = true
					continue
				var control_id := str(eff.get("id", "runtime_control"))
				if target.add_runtime_modifier_buff(
						control_id,
						float(eff.get("duration", 0.5)),
						{},
						{FightAttr.SPD: -0.95}
				):
					buff_names.append(target._runtime_buff_display_name(eff, control_id))
	report["buff_names"] = buff_names
	return report


func _scaled_effect_value(effect: Dictionary) -> float:
	var value := float(effect.get("value", 0.0))
	var scaling_v: Variant = effect.get("scaling", {})
	if not scaling_v is Dictionary:
		return value
	for key in (scaling_v as Dictionary).keys():
		value += get_attr(str(key), 0.0) * float((scaling_v as Dictionary)[key])
	return value


static func _damage_type_from_cfg(cfg: Dictionary) -> String:
	var explicit := str(cfg.get("damage_type", "")).strip_edges().to_lower()
	if explicit in [FightAttr.DAMAGE_PHYSICAL, FightAttr.DAMAGE_MAGIC, FightAttr.DAMAGE_TRUE]:
		return explicit
	var tags_v: Variant = cfg.get("tags", [])
	if tags_v is Array:
		for tag_v in tags_v as Array:
			if str(tag_v).strip_edges().to_lower() == FightAttr.DAMAGE_PHYSICAL:
				return FightAttr.DAMAGE_PHYSICAL
			if str(tag_v).strip_edges().to_lower() == FightAttr.DAMAGE_TRUE:
				return FightAttr.DAMAGE_TRUE
	return FightAttr.DAMAGE_MAGIC


func pop_runtime_events(unit_id: String) -> Array:
	if _runtime_events.is_empty():
		return []
	var out: Array = []
	for ev_v in _runtime_events:
		if not ev_v is Dictionary:
			continue
		var ev := (ev_v as Dictionary).duplicate(true)
		ev[CombatEventScript.KEY_UNIT_ID] = unit_id
		out.append(ev)
	_runtime_events.clear()
	return out


func _collect_buff_names_from_effect(eff: Dictionary, target: FightObj, buff_names: Array) -> Dictionary:
	if target == null:
		return {}
	var base_chance := float(eff.get("control_chance", 1.0))
	var uses_control := bool(eff.get("control", target != self))
	if uses_control and target != self and not FightAttr.roll_control(attrs, target.attrs, base_chance):
		return {"resisted": true}
	var duration_override := float(eff.get("duration", -1.0))
	var mods_v: Variant = eff.get("modifiers", null)
	if mods_v is Dictionary and not (mods_v as Dictionary).is_empty():
		for k in (mods_v as Dictionary).keys():
			var bid := str(k).strip_edges()
			if bid == "":
				continue
			var delta := int((mods_v as Dictionary)[k])
			if delta > 0:
				if target.add_buff(bid, delta, duration_override) > 0:
					buff_names.append(target._buff_display_name(bid))
			elif delta < 0:
				target.remove_buff(bid, absi(delta))
		return {"applied": true}
	var legacy_id := str(eff.get("id", eff.get("buff_id", ""))).strip_edges()
	if legacy_id != "":
		var stacks := maxi(1, int(eff.get("stacks", 1)))
		if target.add_buff(legacy_id, stacks, duration_override) > 0:
			buff_names.append(target._buff_display_name(legacy_id))
			return {"applied": true}
	return {}


func _buff_display_name(buff_id: String) -> String:
	var def := _lookup_buff_def(buff_id)
	if def.is_empty():
		return buff_id
	return str(def.get("name", buff_id)).strip_edges()


func _runtime_buff_display_name(effect: Dictionary, buff_id: String) -> String:
	var name := _buff_display_name(buff_id)
	if name != buff_id:
		return name
	return str(effect.get("name", buff_id)).strip_edges()


func _resolve_effect_target(eff: Dictionary, eff_type: String, default_target: FightObj) -> FightObj:
	var target_key := str(eff.get("target", "")).strip_edges().to_lower()
	if target_key == EnumCombatTarget.LABEL_SELF:
		return self
	if EnumCombatTarget.is_hostile_label(target_key):
		return default_target
	if default_target != null:
		return default_target if eff_type == "damage" else self
	return self
