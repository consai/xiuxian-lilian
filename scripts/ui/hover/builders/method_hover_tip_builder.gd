extends RefCounted
class_name MethodHoverTipBuilder

## 根据功法配置构建 Hover Tip 载荷。

const CultivationMethodServiceScript := preload("res://scripts/sim/cultivation_method_service.gd")
const DaoTreeServiceScript := preload("res://scripts/dao/dao_tree_service.gd")
const BattleInitDataScript := preload("res://scripts/fight/battle_init_data.gd")


static func build(method_id: String, savedata: Dictionary, icon: Texture2D = null) -> Dictionary:
	var method := CultivationMethodServiceScript.by_id(method_id)
	if method.is_empty():
		return {}
	var family := CultivationMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	var quality := EnumQuality.from_label(str(method.get("rarity", "common")))
	var mastery := CultivationMethodServiceScript.method_mastery(savedata, method_id)
	var knowledge_bonus := CultivationMethodServiceScript.knowledge_mastery_for_method(savedata, method_id)
	var lines: Array[String] = []
	var desc := str(method.get("description", "")).strip_edges()
	if desc != "":
		lines.append(_localize_config_text(desc))
	lines.append("类型：%s" % method_type_label(method))
	var realm := DaoTreeServiceScript.realm_display_name(str(method.get("realm", "")))
	if realm != "":
		lines.append("境界：%s" % realm)
	lines.append("品质：%s" % EnumQuality.display_label(quality))
	var family_name := str(family.get("name", "")).strip_edges()
	if family_name != "":
		lines.append("传承：%s" % family_name)
	var family_role := str(family.get("role", "")).strip_edges()
	if family_role != "":
		lines.append("定位：%s" % family_role)
	var practice: Dictionary = method.get("practice", {}) as Dictionary
	if not practice.is_empty():
		lines.append("修炼速度：x%s" % _fmt_num(float(practice.get("efficiency", 1.0))))
		lines.append("知识经验：%s%%" % _fmt_num(float(practice.get("knowledgeXpRatio", 0.0)) * 100.0))
		var risk := float(practice.get("deviationRisk", 0.0))
		if risk > 0.0:
			lines.append("走火风险：%s%%" % _fmt_num(risk * 100.0))
	lines.append("熟练：%s%%" % _fmt_num(mastery * 100.0))
	if knowledge_bonus > 0.0:
		lines.append("知识反哺：+%s%%" % _fmt_num(knowledge_bonus * 100.0))
	var mastery_ratio := CultivationMethodServiceScript.method_mastery_value_ratio(savedata, method_id)
	for effect_line in HoverTipEffectFormatter.format_raw_ability_lines(method.get("effects", []), mastery_ratio):
		lines.append(effect_line)
	var knowledge_line := _knowledge_line(method_id)
	if knowledge_line != "":
		lines.append(knowledge_line)
	var payload_fields := {
		"title": str(method.get("name", method_id)),
		"title_color": EnumQuality.get_color(quality),
		"lines": lines,
	}
	if icon != null:
		payload_fields["icon"] = icon
	elif method.has("icon"):
		var tex := BattleInitDataScript._resolve_icon_texture(method)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func method_type_label(method: Dictionary) -> String:
	var family := CultivationMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	var role := str(family.get("role", "")).strip_edges()
	if bool(method.get("is_movement", false)) or str(method.get("slot_type", "")) == "movement" \
			or role.find("身法") >= 0 or role.find("遁法") >= 0:
		return "身法"
	if str(family.get("progressionType", method.get("progressionType", ""))) == "side_path":
		return "旁门"
	return "功法"


static func _knowledge_line(method_id: String) -> String:
	var rows := CultivationMethodServiceScript.resolved_knowledge(method_id)
	var names: PackedStringArray = []
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var sid := str(row.get("skillId", "")).strip_edges()
		if sid == "":
			continue
		var skill := DaoTreeServiceScript.skill_by_id(sid)
		var skill_name := str(skill.get("name", sid))
		names.append("%s 上限%d" % [skill_name, int(row.get("capLevel", 1))])
		if names.size() >= 4:
			break
	if names.is_empty():
		return ""
	var suffix := " 等" if rows.size() > names.size() else ""
	return "研习知识：%s%s" % ["、".join(names), suffix]


static func _localize_config_text(text: String) -> String:
	var out := text
	for row_v in DaoTreeServiceScript.config().get("skills", []) as Array:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var sid := str(row.get("id", "")).strip_edges()
		if sid != "":
			out = out.replace(sid, str(row.get("name", sid)))
	return out


static func _fmt_num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%0.1f" % value
