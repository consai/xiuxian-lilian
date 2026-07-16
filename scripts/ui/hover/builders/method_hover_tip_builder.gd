extends RefCounted
class_name MethodHoverTipBuilder

## 根据功法配置构建 Hover Tip 载荷。

const XiulianMethodServiceScript := preload("res://scripts/sim/xiulian_method_service.gd")
const DaoTreeQueryApplicationScript := preload(
	"res://scripts/features/dao/application/dao_tree_query_application.gd"
)
const ZhandouInitDataScript := preload("res://scripts/zhandou/zhandou_init_data.gd")


static func build(method_id: String, savedata: Dictionary, icon: Texture2D = null) -> Dictionary:
	var method := XiulianMethodServiceScript.by_id(method_id)
	if method.is_empty():
		return {}
	var family := XiulianMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	var quality := clampi(int(method.get("quality", family.get("quality", 1))), EnumQuality.Type.LOW, EnumQuality.Type.SUPREME)
	var tier := EnumItemTier.clamp_tier(int(method.get("tier", 1)))
	var mastery := XiulianMethodServiceScript.method_mastery(savedata, method_id)
	var lines: Array[String] = []
	var desc := str(method.get("description", "")).strip_edges()
	if desc != "":
		lines.append(_localize_config_text(desc))
	lines.append("类型：%s" % method_type_label(method))
	var realm := DaoTreeQueryApplicationScript.realm_display_name(str(method.get("realm", "")))
	if realm != "":
		lines.append("境界：%s" % realm)
	lines.append("阶位：%s" % EnumItemTier.label(tier))
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
		var risk := float(practice.get("deviationRisk", 0.0))
		if risk > 0.0:
			lines.append("走火风险：%s%%" % _fmt_num(risk * 100.0))
	lines.append("熟练：%s%%" % _fmt_num(mastery * 100.0))
	var mastery_ratio := XiulianMethodServiceScript.method_mastery_value_ratio(savedata, method_id)
	for effect_line in HoverTipEffectFormatter.format_raw_ability_lines(method.get("effects", []), mastery_ratio):
		lines.append(effect_line)
	var payload_fields := {
		"title": str(method.get("name", method_id)),
		"title_color": EnumQuality.get_color(quality),
		"lines": lines,
	}
	if icon != null:
		payload_fields["icon"] = icon
	elif method.has("icon"):
		var tex := ZhandouInitDataScript._resolve_icon_texture(method)
		if tex != null:
			payload_fields["icon"] = tex
	return HoverTipPayload.make(payload_fields)


static func method_type_label(method: Dictionary) -> String:
	var family := XiulianMethodServiceScript.family_by_id(str(method.get("familyId", "")))
	var role := str(family.get("role", "")).strip_edges()
	if bool(method.get("is_movement", false)) or str(method.get("slot_type", "")) == "movement" \
			or role.find("身法") >= 0 or role.find("遁法") >= 0:
		return "身法"
	if str(family.get("progressionType", method.get("progressionType", ""))) == "side_path":
		return "旁门"
	return "功法"


static func _localize_config_text(text: String) -> String:
	var out := text
	for row_v in DaoTreeQueryApplicationScript.all_skills():
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
