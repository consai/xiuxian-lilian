class_name LilianLogService
extends RefCounted

static func build_departure_entry(location: Dictionary) -> Dictionary:
	var loc_name := str(location.get("name", "未知之地"))
	var subtitle := str(location.get("subtitle", "")).strip_edges()
	var scene := "踏入%s" % loc_name
	if subtitle != "":
		scene = "%s，%s" % [scene, subtitle]
	var narrative := join_scene_outcome(scene, "你整理行装，握紧法器，正式踏上历练之路。")
	return {
		"difficulty": 0,
		"journey_step": 0,
		"event_id": "",
		"name": "启程",
		"scene": scene,
		"outcome": "你整理行装，握紧法器，正式踏上历练之路。",
		"narrative": narrative,
		"feedback": narrative,
	}


static func event_scene(event: Dictionary) -> String:
	return str(event.get("desc", "")).strip_edges()


static func apply_outcome(entry: Dictionary, outcome: String) -> void:
	var tail := outcome.strip_edges()
	entry["outcome"] = tail
	var scene := str(entry.get("scene", "")).strip_edges()
	entry["narrative"] = join_scene_outcome(scene, tail)
	entry["feedback"] = entry["narrative"]


static func build_event_entry(
		event: Dictionary,
		step_day: int,
		difficulty: int,
		scene: String,
		outcome: String,
		log_name: String = ""
) -> Dictionary:
	var title := log_name.strip_edges()
	if title == "":
		title = str(event.get("name", ""))
	var entry := {
		"difficulty": difficulty,
		"journey_step": step_day,
		"event_id": str(event.get("id", "")),
		"name": title,
		"scene": scene.strip_edges(),
		"outcome": "",
		"narrative": "",
		"feedback": "",
	}
	apply_outcome(entry, outcome)
	return entry


static func build_battle_victory_entry(
		event: Dictionary,
		step_day: int,
		difficulty: int,
		rewards: Array
) -> Dictionary:
	var scene := str(event.get("desc", "")).strip_edges()
	var enemy_name := str((event.get("enemy", {}) as Dictionary).get("name", event.get("name", "强敌")))
	var event_type := str(event.get("type", "battle"))
	var clash := "一番厮杀之后，你击退%s。" % enemy_name
	if event_type == "boss":
		clash = "山巅威压骤散，你终于斩落%s！" % enemy_name
	elif event_type == "elite":
		clash = "恶战良久，你险胜%s。" % enemy_name
	var loot := format_rewards(rewards)
	var outcome := clash if loot == "" else "%s %s" % [clash, loot]
	return build_event_entry(event, step_day, difficulty, scene, outcome)


static func build_battle_victory_outcome(event: Dictionary, rewards: Array) -> String:
	var entry := build_battle_victory_entry(event, 0, 0, rewards)
	return str(entry.get("outcome", ""))


static func build_battle_defeat_outcome(event: Dictionary) -> String:
	var entry := build_battle_defeat_entry(event, 0, 0)
	return str(entry.get("outcome", ""))


static func build_battle_fled_outcome(event: Dictionary) -> String:
	var entry := build_battle_fled_entry(event, 0, 0)
	return str(entry.get("outcome", ""))


static func build_battle_fled_entry(
		event: Dictionary,
		step_day: int,
		difficulty: int
) -> Dictionary:
	var scene := str(event.get("desc", "")).strip_edges()
	var enemy_name := str((event.get("enemy", {}) as Dictionary).get("name", event.get("name", "强敌")))
	var outcome := "施展遁法，摆脱%s追袭，结束本次历练。" % enemy_name
	return build_event_entry(event, step_day, difficulty, scene, outcome)


static func build_battle_defeat_entry(
		event: Dictionary,
		step_day: int,
		difficulty: int
) -> Dictionary:
	var scene := str(event.get("desc", "")).strip_edges()
	var enemy_name := str((event.get("enemy", {}) as Dictionary).get("name", event.get("name", "强敌")))
	var outcome := "力竭不敌，你被%s击退，只得撤出战局。" % enemy_name
	return build_event_entry(event, step_day, difficulty, scene, outcome)


static func build_retreat_entry(event: Dictionary, difficulty: int) -> Dictionary:
	var scene := str(event.get("desc", "")).strip_edges()
	var enemy_name := str((event.get("enemy", {}) as Dictionary).get("name", event.get("name", "强敌")))
	var outcome := "见%s来势凶猛，你当机立断，抽身撤退，结束本次历练。" % enemy_name
	return build_event_entry(event, 0, difficulty, scene, outcome)


static func join_scene_outcome(scene: String, outcome: String) -> String:
	var lead := scene.strip_edges()
	var tail := outcome.strip_edges()
	if lead == "":
		return tail
	if tail == "":
		return lead
	if tail.begins_with(lead) or lead in tail:
		return tail
	if not lead.ends_with("。") and not lead.ends_with("！") and not lead.ends_with("？"):
		lead += "。"
	return "%s%s" % [lead, tail]


static func travel_outcome(event: Dictionary) -> String:
	var configured := str(event.get("outcome_text", "")).strip_edges()
	if configured != "":
		return configured
	var desc := str(event.get("desc", "")).strip_edges()
	if desc != "":
		return "前路尚远，你未停步履。"
	return "山道蜿蜒，风声掠过林梢，你稳步向前。"


static func gather_outcome(event: Dictionary, rewards: Array) -> String:
	var loot := reward_list(rewards)
	if loot == "":
		return str(event.get("empty_text", "你仔细搜寻半晌，却一无所获。"))
	var configured := str(event.get("success_text", "")).strip_edges()
	if configured != "":
		return configured.replace("{loot}", loot)
	return "你俯身采摘，收得%s。" % loot


static func format_rewards(rewards: Array) -> String:
	var loot := reward_list(rewards)
	if loot == "":
		return ""
	return "战利品落入袋中：%s。" % loot


static func reward_list(rewards: Array) -> String:
	if rewards.is_empty():
		return ""
	var parts: PackedStringArray = []
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var label := _reward_label(reward_v as Dictionary)
		if label != "":
			parts.append(label)
	return "、".join(parts)


static func format_effect_lines(lines: PackedStringArray) -> String:
	return " ".join(lines)


static func format_bbcode(entry: Dictionary) -> String:
	var header := _format_header(entry)
	var name := str(entry.get("name", "")).strip_edges()
	var scene := str(entry.get("scene", "")).strip_edges()
	var outcome := str(entry.get("outcome", "")).strip_edges()
	var lines: PackedStringArray = []
	lines.append("[color=#8a7568]%s[/color]" % header)
	if name != "":
		lines.append("[color=#4a3028]%s[/color]" % name)
	if scene != "":
		lines.append(scene)
	if outcome != "":
		lines.append("[color=#6a5048]%s[/color]" % outcome)
	return "\n".join(lines)


static func format_plain(entry: Dictionary) -> String:
	var header := _format_header(entry)
	var name := str(entry.get("name", "")).strip_edges()
	var scene := str(entry.get("scene", "")).strip_edges()
	var outcome := str(entry.get("outcome", "")).strip_edges()
	var body_parts: PackedStringArray = []
	if scene != "":
		body_parts.append(scene)
	if outcome != "":
		body_parts.append(outcome)
	var body := "\n".join(body_parts)
	if name != "":
		return "【%s】%s\n%s" % [header, name, body] if body != "" else "【%s】%s" % [header, name]
	return "【%s】\n%s" % [header, body] if body != "" else "【%s】" % header


static func _format_header(entry: Dictionary) -> String:
	var step := int(entry.get("journey_step", 0))
	if step <= 0:
		return "启程"
	return "第%d天" % step


static func _reward_label(reward: Dictionary) -> String:
	var kind := str(reward.get("kind", "item"))
	var count := maxi(1, int(reward.get("count", reward.get("amount", 1))))
	if kind == "equip":
		var equip_name := "法宝"
		equip_name = str(reward.get("name", equip_name))
		return equip_name if count <= 1 else "%s×%d" % [equip_name, count]
	if kind == "currency":
		var amount := int(reward.get("count", reward.get("amount", 0)))
		if str(reward.get("id", "")) == "ling_stones":
			return "灵石×%d" % amount
		return "货币×%d" % amount
	var item_id := str(reward.get("id", ""))
	var item_name := str(reward.get("name", reward.get("item_name", item_id)))
	return "%s×%d" % [item_name, count] if count > 1 else item_name
