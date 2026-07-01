class_name SkillDef
extends RefCounted

## 与导出的战斗技能配置对应。

var id: int = 0
var name: String = ""
var icon: String = ""
var mp_cost: float = 0.0
var cd: float = 0.0
var power: float = 1000.0
var quality: int = 1
var vfx_type: String = ""
## 表现 preset id，或含 [code]preset[/code]/[code]overrides[/code] 的字典。
var vfx: Variant = ""
var tags: Array = []
var effects: Array = []


static func from_dict(data: Dictionary) -> SkillDef:
	if not data.has("id"):
		push_error("SkillDef.from_dict: missing id in %s" % str(data))
		return null
	var sid := int(data["id"])
	if sid < 0:
		push_error("SkillDef.from_dict: id must be non-negative, got %d" % sid)
		return null
	var skill := SkillDef.new()
	skill.id = sid
	skill.name = str(data.get("name", "")).strip_edges()
	skill.icon = str(data.get("icon", data.get("icon_path", ""))).strip_edges()
	skill.mp_cost = maxf(0.0, float(data.get("mp_cost", 0.0)))
	skill.cd = maxf(0.0, float(data.get("cd", data.get("cd_total", 0.0))))
	skill.power = float(data.get("power", 1000.0))
	skill.quality = maxi(1, int(data.get("quality", 1)))
	skill.vfx_type = str(data.get("vfx_type", "")).strip_edges().to_lower()
	if data.has("vfx"):
		skill.vfx = data["vfx"]
	elif data.has("vfx_file"):
		skill.vfx = str(data["vfx_file"]).strip_edges()
	elif data.has("vfx_preset"):
		skill.vfx = str(data["vfx_preset"]).strip_edges()
	var tags_v: Variant = data.get("tags", [])
	if tags_v is Array:
		skill.tags = (tags_v as Array).duplicate(true)
	var effects_v: Variant = data.get("effects", [])
	if effects_v is Array:
		skill.effects = (effects_v as Array).duplicate(true)
	return skill


func to_runtime_dict() -> Dictionary:
	var out := {
		"id": id,
		"name": name,
		"mp_cost": mp_cost,
		"cd": cd,
		"cd_total": cd,
		"power": power,
		"quality": quality,
		"effects": effects.duplicate(true),
	}
	if icon != "":
		out["icon"] = icon
	if vfx_type != "":
		out["vfx_type"] = vfx_type
	if vfx is String and str(vfx).strip_edges() != "":
		out["vfx"] = str(vfx).strip_edges()
	elif vfx is Dictionary:
		out["vfx"] = (vfx as Dictionary).duplicate(true)
	if not tags.is_empty():
		out["tags"] = tags.duplicate(true)
	return out
