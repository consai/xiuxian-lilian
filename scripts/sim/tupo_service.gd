class_name TupoService
extends RefCounted

const RULES_PATH := "res://data/exportjson/tupo_rules.json"
const CharacterStatsScript := preload("res://scripts/sim/character_stats.gd")
const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
const KnowledgeServiceScript := preload("res://scripts/dao/knowledge_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")

const COMPONENT_KEYS := [
	"cultivation", "pills", "mind", "aptitude", "fortune", "special_method", "other"
]

const COMPONENT_LABELS := {
	"cultivation": "修为",
	"pills": "丹药",
	"mind": "心境",
	"aptitude": "根骨",
	"fortune": "气运",
	"special_method": "特殊功法",
	"other": "其他",
}

const TRANSITION_BY_MAJOR := {
	"qi": "qi_to_foundation",
	"foundation": "foundation_to_core",
	"core": "core_to_nascent",
}


static func rules() -> Dictionary:
	return JsonLoader.load_tupo_rules_bundle()


static func compute_breakdown(savedata: Dictionary, realms: Array, realm_index: int) -> Dictionary:
	var preview := _transition_preview(savedata, realms, realm_index)
	if not bool(preview.get("ok", false)):
		return preview
	var transition_id := str(preview.get("transition_id", ""))
	var transition := _transition_cfg(transition_id)
	var detail := _compute_component_detail(savedata, transition)
	var components: Dictionary = detail.get("components", {}) as Dictionary
	var component_sources: Dictionary = detail.get("sources", {}) as Dictionary
	var total := _sum_components(components)
	var min_total := int(transition.get("min_total", 0))
	var tier := evaluate_tier(total, transition_id)
	var knowledge_error := str(preview.get("knowledge_error", ""))
	var may_attempt := total >= min_total and knowledge_error == ""
	var hint := str(tier.get("hint", "可以尝试突破"))
	if knowledge_error != "":
		hint = knowledge_error
	elif not may_attempt:
		hint = "突破值过低，无法突破"
	return {
		"ok": true,
		"components": components,
		"component_sources": component_sources,
		"total": total,
		"transition_id": transition_id,
		"min_total": min_total,
		"target_realm_name": str(preview.get("target_realm_name", "")),
		"current_realm_name": str(preview.get("current_realm_name", "")),
		"can_attempt": may_attempt,
		"knowledge_error": knowledge_error,
		"tier": tier,
		"hint": hint,
	}


static func can_attempt(savedata: Dictionary, realms: Array, realm_index: int) -> Dictionary:
	var breakdown := compute_breakdown(savedata, realms, realm_index)
	if not bool(breakdown.get("ok", false)):
		return breakdown
	if not bool(breakdown.get("can_attempt", false)):
		return {"ok": false, "error": str(breakdown.get("hint", "突破值过低，无法突破"))}
	return {"ok": true, "breakdown": breakdown}


static func evaluate_tier(total: int, transition_id: String) -> Dictionary:
	var transition := _transition_cfg(transition_id)
	var tiers := _sorted_tiers(transition)
	var min_total := int(transition.get("min_total", 0))
	if total < min_total:
		return {
			"quality": 0,
			"label": "不可突破",
			"success_rate": 0.0,
			"foundation_growth": 0.0,
			"perks": [],
			"hint": "突破值过低，无法突破",
		}
	for row in tiers:
		if total >= int(row.get("min_total", 0)):
			return {
				"quality": int(row.get("quality", 5)),
				"label": str(row.get("label", "")),
				"success_rate": float(row.get("success_rate", 0.0)),
				"foundation_growth": float(row.get("foundation_growth", 1.0)),
				"perks": (row.get("perks", []) as Array).duplicate(),
				"hint": _tier_hint(str(row.get("label", "")), float(row.get("success_rate", 0.0))),
			}
	var fallback := tiers[tiers.size() - 1] as Dictionary
	return {
		"quality": int(fallback.get("quality", 5)),
		"label": str(fallback.get("label", "")),
		"success_rate": float(fallback.get("success_rate", 0.0)),
		"foundation_growth": float(fallback.get("foundation_growth", 1.0)),
		"perks": (fallback.get("perks", []) as Array).duplicate(),
		"hint": _tier_hint(str(fallback.get("label", "")), float(fallback.get("success_rate", 0.0))),
	}


static func major_gap_hint(breakdown: Dictionary, max_items: int = 2) -> String:
	if not bool(breakdown.get("ok", false)):
		return str(breakdown.get("error", "当前条件不足"))
	var knowledge_error := str(breakdown.get("knowledge_error", "")).strip_edges()
	if knowledge_error != "":
		return "主要缺口：%s。" % knowledge_error
	var total := int(breakdown.get("total", 0))
	var min_total := int(breakdown.get("min_total", 0))
	if total < min_total:
		return "主要缺口：还差 %d 突破值，优先补 %s。" % [
			min_total - total,
			_component_gap_labels(breakdown, max_items),
		]
	var next_tier := _next_tier_for_total(total, str(breakdown.get("transition_id", "")))
	if next_tier.is_empty():
		return "主要缺口：已达最高品质档，可直接尝试突破。"
	return "主要缺口：距%s还差 %d 突破值，优先补 %s。" % [
		str(next_tier.get("label", "下一品质")),
		int(next_tier.get("min_total", total)) - total,
		_component_gap_labels(breakdown, max_items),
	]


static func resolve(savedata: Dictionary, realms: Array, realm_index: int, rng: RandomNumberGenerator) -> Dictionary:
	var gate := can_attempt(savedata, realms, realm_index)
	if not bool(gate.get("ok", false)):
		return gate
	var breakdown: Dictionary = gate.get("breakdown", {}) as Dictionary
	var tier: Dictionary = breakdown.get("tier", {}) as Dictionary
	var success_rate := clampf(float(tier.get("success_rate", 0.0)), 0.0, 1.0)
	var success := success_rate >= 1.0 or rng.randf() < success_rate
	if not success:
		return _fail_result(savedata, breakdown, tier)
	return _success_result(savedata, realms, realm_index, breakdown, tier)


static func is_major_breakthrough(realms: Array, realm_index: int) -> bool:
	var next_index := realm_index + 1
	if next_index >= realms.size():
		return false
	return not _same_major_realm(realms, realm_index, next_index)


static func _success_result(
		savedata: Dictionary,
		realms: Array,
		realm_index: int,
		breakdown: Dictionary,
		tier: Dictionary
) -> Dictionary:
	var next_index := realm_index + 1
	var old_row := realms[realm_index] as Dictionary
	var new_row := realms[next_index] as Dictionary
	var to_major := str(new_row.get("major_realm", ""))
	var growth := float(tier.get("foundation_growth", 1.0))
	var grown: Dictionary = CharacterStatsScript.normalize_foundations(savedata.get("foundations", {}))
	for key in grown.keys():
		grown[key] = float(grown[key]) + growth
	savedata["foundations"] = grown
	savedata["realm_index"] = next_index
	savedata["realm_name"] = str(new_row.get("name", ""))
	savedata["breakthrough_at"] = int(new_row.get("breakthrough_at", savedata.get("breakthrough_at", 100)))
	var qualities: Dictionary = savedata.get("realm_quality", {}) as Dictionary
	if to_major in ["foundation", "core", "nascent"]:
		qualities[to_major] = int(tier.get("quality", 0))
		savedata["realm_quality"] = qualities
	return {
		"ok": true,
		"success": true,
		"old_realm": str(old_row.get("name", "")),
		"new_realm": str(new_row.get("name", "")),
		"tier_label": str(tier.get("label", "")),
		"quality": int(tier.get("quality", 0)),
		"foundation_growth": growth,
		"perks": (tier.get("perks", []) as Array).duplicate(),
		"breakdown": breakdown,
	}


static func _fail_result(savedata: Dictionary, breakdown: Dictionary, tier: Dictionary) -> Dictionary:
	var cfg := rules()
	var unstable_days := maxi(0, int(cfg.get("realm_unstable_days", 0)))
	if unstable_days > 0:
		savedata["breakthrough_attempt_cooldown_days"] = unstable_days
	if bool(cfg.get("consume_pills_on_fail", false)):
		var bonuses: Dictionary = savedata.get("breakthrough_bonuses", {}) as Dictionary
		bonuses["pills"] = 0
		savedata["breakthrough_bonuses"] = bonuses
	return {
		"ok": true,
		"success": false,
		"error": "突破失败，境界不稳",
		"tier_label": str(tier.get("label", "")),
		"breakdown": breakdown,
	}


static func format_source_expression(sources: Array) -> String:
	var parts: PackedStringArray = []
	for row_v in sources:
		if not row_v is Dictionary:
			continue
		var value := int((row_v as Dictionary).get("value", 0))
		if parts.is_empty():
			parts.append(str(value))
		elif value > 0:
			parts.append("+ %d" % value)
		elif value < 0:
			parts.append("- %d" % absi(value))
		else:
			parts.append("+ 0")
	if parts.is_empty():
		return "0"
	return " ".join(parts)


static func make_component_tip_payload(title: String, sources: Array) -> Dictionary:
	var HoverTipPayloadScript := preload("res://scripts/ui/hover/hover_tip_payload.gd")
	var expression := format_source_expression(sources)
	var detail_lines: Array[String] = []
	for row_v in sources:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var value := int(row.get("value", 0))
		var label := str(row.get("label", "")).strip_edges()
		if label == "":
			continue
		detail_lines.append("%s  %s" % [label, _format_source_value(value)])
	var lines: Array[String] = [expression]
	if not detail_lines.is_empty():
		lines.append("")
		lines.append_array(detail_lines)
	return HoverTipPayloadScript.make({
		"title": "%s来源" % title.strip_edges(),
		"lines": lines,
	})


static func _compute_component_detail(savedata: Dictionary, transition: Dictionary) -> Dictionary:
	var cfg := rules()
	var caps: Dictionary = cfg.get("component_caps", {}) as Dictionary
	var breakthrough_at := maxi(1, int(savedata.get("breakthrough_at", 100)))
	var cultivation := maxi(0, int(savedata.get("cultivation", 0)))
	var cultivation_cap := int(transition.get("cultivation_cap", caps.get("cultivation", 400)))
	var cultivation_points := int(
		floor(float(mini(cultivation, breakthrough_at)) / float(breakthrough_at) * float(cultivation_cap))
	)
	var bonuses: Dictionary = savedata.get("breakthrough_bonuses", {}) as Dictionary
	var injury_days := maxi(0, int(savedata.get("injury_days", 0)))
	var mind_base := int(cfg.get("mind_base", 80))
	var mind_bonus := int(bonuses.get("mind", 0))
	var mind_penalty := injury_days * int(cfg.get("mind_injury_penalty_per_day", 8))
	var mind_points := maxi(0, mind_base + mind_bonus - mind_penalty)
	var foundations := CharacterStatsScript.normalize_foundations(savedata.get("foundations", {}))
	var aptitudes := CharacterStatsScript.normalize_aptitudes(savedata.get("aptitudes", {}))
	var foundation_avg := 0.0
	for key in foundations.keys():
		foundation_avg += float(foundations[key])
	foundation_avg /= maxf(1.0, float(foundations.size()))
	var roots_v: Variant = aptitudes.get(CharacterStatsScript.ROOTS, {})
	var root_peak := 0.0
	if roots_v is Dictionary:
		for value in (roots_v as Dictionary).values():
			root_peak = maxf(root_peak, float(value))
	var foundation_weight := float(cfg.get("aptitude_foundations_weight", 0.6))
	var roots_weight := float(cfg.get("aptitude_roots_weight", 0.4))
	var foundation_points := int(round(foundation_avg * foundation_weight))
	var roots_points := int(round(root_peak * roots_weight))
	var aptitude_points := foundation_points + roots_points
	var fortune_value := float(aptitudes.get(CharacterStatsScript.FORTUNE, 0.0))
	var fortune_unit := float(cfg.get("fortune_points_per_unit", 8))
	var fortune_points := int(round(fortune_value * fortune_unit))
	var method_slots: Dictionary = savedata.get("cultivation_method_slots", {}) as Dictionary
	var method_sources := _special_method_sources(method_slots)
	var special_method_points := _sum_source_values(method_sources)
	var pill_points := int(bonuses.get("pills", 0))
	var other_points := maxi(0, int(bonuses.get("other", 0)))
	var components := {
		"cultivation": _cap_component(cultivation_points, int(caps.get("cultivation", cultivation_cap))),
		"pills": _cap_component(pill_points, int(caps.get("pills", 300))),
		"mind": _cap_component(mind_points, int(caps.get("mind", 200))),
		"aptitude": _cap_component(aptitude_points, int(caps.get("aptitude", 200))),
		"fortune": _cap_component(fortune_points, int(caps.get("fortune", 150))),
		"special_method": _cap_component(special_method_points, int(caps.get("special_method", 150))),
		"other": _cap_component(other_points, int(caps.get("other", 100))),
	}
	var sources := {
		"cultivation": [
			{"label": "修为折算", "value": cultivation_points},
		],
		"pills": [{"label": "破境丹药", "value": pill_points}],
		"mind": [
			{"label": "心境基础", "value": mind_base},
			{"label": "心境加成", "value": mind_bonus},
			{"label": "伤势惩罚", "value": -mind_penalty},
		],
		"aptitude": [
			{"label": "根基均值", "value": foundation_points},
			{"label": "灵根峰值", "value": roots_points},
		],
		"fortune": [{"label": "福缘×系数", "value": fortune_points}],
		"special_method": method_sources,
		"other": [{"label": "其他加成", "value": other_points}],
	}
	return {"components": components, "sources": sources}


static func _special_method_sources(method_slots: Dictionary) -> Array:
	var sources: Array = []
	var slot_labels := {
		"main": "主功法",
		"support_1": "辅功法一",
		"support_2": "辅功法二",
		"movement": "身法",
	}
	var weights := {"main": 1.0, "support_1": 0.6, "support_2": 0.6, "movement": 0.4}
	for slot_key in weights.keys():
		var slot_label := str(slot_labels.get(slot_key, slot_key))
		var method_id := str(method_slots.get(slot_key, "")).strip_edges()
		var points := 0
		var label := slot_label
		if method_id != "":
			var bonus := XiulianMethodServiceScript.breakthrough_bonus(method_id)
			points = int(round(bonus * float(weights[slot_key])))
			var method_name := str(XiulianMethodServiceScript.by_id(method_id).get("name", method_id))
			label = "%s·%s" % [slot_label, method_name]
		sources.append({"label": label, "value": points})
	return sources


static func _sum_source_values(sources: Array) -> int:
	var total := 0
	for row_v in sources:
		if row_v is Dictionary:
			total += int((row_v as Dictionary).get("value", 0))
	return total


static func _format_source_value(value: int) -> String:
	if value > 0:
		return "+%d" % value
	if value < 0:
		return "%d" % value
	return "0"


static func _transition_preview(savedata: Dictionary, realms: Array, realm_index: int) -> Dictionary:
	if cultivation_not_ready(savedata):
		return {"ok": false, "error": "修为尚未达到突破门槛"}
	if not is_major_breakthrough(realms, realm_index):
		return {"ok": false, "error": "同境界小层已自动提升，无需突破"}
	var current_row := realms[realm_index] as Dictionary
	var next_row := realms[realm_index + 1] as Dictionary
	var from_major := str(current_row.get("major_realm", ""))
	var transition_id := str(TRANSITION_BY_MAJOR.get(from_major, ""))
	if transition_id == "" or not rules().get("major_breakthroughs", {}).has(transition_id):
		return {"ok": false, "error": "当前境界尚未配置突破规则"}
	return {
		"ok": true,
		"transition_id": transition_id,
		"current_realm_name": str(current_row.get("name", "")),
		"target_realm_name": str(next_row.get("name", "")),
		"knowledge_error": _knowledge_gate_error(savedata, next_row),
	}


static func cultivation_not_ready(savedata: Dictionary) -> bool:
	return int(savedata.get("cultivation", 0)) < int(savedata.get("breakthrough_at", 100))


static func _knowledge_gate_error(savedata: Dictionary, next_realm_row: Dictionary) -> String:
	var target_major := str(next_realm_row.get("major_realm", ""))
	for realm_v in DaoTreeServiceScript.realms():
		if not realm_v is Dictionary:
			continue
		var realm := realm_v as Dictionary
		if str(realm.get("id", "")) != target_major:
			continue
		var gate := int(realm.get("gate", 0))
		if KnowledgeServiceScript.total_learned_points(savedata) < gate:
			return "知识点不足，需要 %d 点（当前 %d）" % [
				gate, KnowledgeServiceScript.total_learned_points(savedata),
			]
		break
	return ""


static func _transition_cfg(transition_id: String) -> Dictionary:
	var transitions: Dictionary = rules().get("major_breakthroughs", {}) as Dictionary
	return transitions.get(transition_id, {}) as Dictionary


static func _sorted_tiers(transition: Dictionary) -> Array:
	var tiers := (transition.get("tiers", []) as Array).duplicate()
	tiers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("min_total", 0)) > int(b.get("min_total", 0))
	)
	return tiers


static func _same_major_realm(realms: Array, left_index: int, right_index: int) -> bool:
	if left_index < 0 or right_index < 0 or left_index >= realms.size() or right_index >= realms.size():
		return false
	return str((realms[left_index] as Dictionary).get("major_realm", "")) == str((realms[right_index] as Dictionary).get("major_realm", ""))


static func _sum_components(components: Dictionary) -> int:
	var total := 0
	for key in COMPONENT_KEYS:
		total += int(components.get(key, 0))
	return total


static func _component_gap_labels(breakdown: Dictionary, max_items: int) -> String:
	var cfg := rules()
	var caps: Dictionary = cfg.get("component_caps", {}) as Dictionary
	var components: Dictionary = breakdown.get("components", {}) as Dictionary
	var rows: Array = []
	for key in COMPONENT_KEYS:
		var cap := int(caps.get(key, 0))
		var value := int(components.get(key, 0))
		var room := cap - value
		if room <= 0:
			continue
		rows.append({"key": key, "room": room})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("room", 0)) > int(b.get("room", 0))
	)
	var labels: PackedStringArray = []
	for i in mini(maxi(max_items, 1), rows.size()):
		var row := rows[i] as Dictionary
		labels.append("%s(+%d)" % [
			str(COMPONENT_LABELS.get(str(row.get("key", "")), row.get("key", ""))),
			int(row.get("room", 0)),
		])
	return "、".join(labels) if not labels.is_empty() else "已满分项"


static func _next_tier_for_total(total: int, transition_id: String) -> Dictionary:
	var best: Dictionary = {}
	for row_v in _sorted_tiers(_transition_cfg(transition_id)):
		var row := row_v as Dictionary
		var row_min := int(row.get("min_total", 0))
		if total < row_min and (best.is_empty() or row_min < int(best.get("min_total", 0))):
			best = row
	return best


static func _cap_component(value: int, cap: int) -> int:
	return clampi(value, 0, maxi(0, cap))


static func _tier_hint(label: String, success_rate: float) -> String:
	if success_rate >= 1.0:
		return "%s，把握十足" % label
	if success_rate >= 0.9:
		return "%s，成功把握较高" % label
	if success_rate >= 0.75:
		return "%s，尚可尝试，失败可能境界不稳" % label
	return "%s，风险较高，建议继续积累突破值" % label
