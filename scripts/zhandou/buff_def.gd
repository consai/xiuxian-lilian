class_name BuffDef
extends RefCounted

## 与导出的 Buff 配置对应。

var id: String = ""
var name: String = ""
var icon: String = ""
var desc: String = ""
var duration: float = 0.0
var max_stacks: int = 1
var ticktime: float = 1.0
var modifiers: Dictionary = {}
var tick_effects: Array = []
var tags: Array = []


static func from_dict(data: Dictionary) -> BuffDef:
	var bid := str(data.get("id", "")).strip_edges()
	if bid == "":
		push_error("BuffDef.from_dict: missing or empty id in %s" % str(data))
		return null
	var buff := BuffDef.new()
	buff.id = bid
	buff.name = str(data.get("name", "")).strip_edges()
	buff.icon = str(data.get("icon", "")).strip_edges()
	buff.desc = str(data.get("desc", "")).strip_edges()
	buff.duration = float(data.get("duration", 0.0))
	buff.max_stacks = maxi(1, int(data.get("max_stacks", 1)))
	buff.ticktime = float(data.get("ticktime", 1.0))
	if buff.ticktime < 0.0:
		buff.ticktime = 0.0
	elif buff.ticktime > 0.0:
		buff.ticktime = maxf(0.01, buff.ticktime)
	buff.modifiers = normalize_modifiers(data.get("modifiers", {}))
	var tick_v: Variant = data.get("tick_effects", [])
	if tick_v is Array:
		buff.tick_effects = (tick_v as Array).duplicate(true)
	var tags_v: Variant = data.get("tags", [])
	if tags_v is Array:
		buff.tags = (tags_v as Array).duplicate(true)
	return buff


## 支持 [code]{"physical_atk": 10}[/code] 字典或 export positional attrschange 行（属性键与 ZhandouAttr 一致）。
static func normalize_modifiers(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var source := raw as Dictionary
		if source.has("_percent"):
			return source.duplicate(true)
		return source.duplicate(true)
	if raw is Array:
		if not raw.is_empty() and raw[0] is Array:
			return ZhandouEffectCodec.normalize_buff_modifiers(raw)
		var out: Dictionary = {}
		for entry_v in raw as Array:
			if not entry_v is Dictionary:
				continue
			for k in (entry_v as Dictionary).keys():
				var key := str(k).strip_edges()
				if key == "":
					continue
				var val_v: Variant = (entry_v as Dictionary)[k]
				if val_v is int or val_v is float:
					out[key] = float(out.get(key, 0.0)) + float(val_v)
		return out
	return {}


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"icon": icon,
		"desc": desc,
		"duration": duration,
		"max_stacks": max_stacks,
		"ticktime": ticktime,
		"modifiers": modifiers.duplicate(true),
		"tick_effects": tick_effects.duplicate(true),
		"tags": tags.duplicate(true),
	}
