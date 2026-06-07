class_name BuffDef
extends RefCounted

## 与 [code]data/buff.json[/code] 中单条 Buff 配置对应。

var id: String = ""
var name: String = ""
var desc: String = ""
var duration: float = 0.0
var max_stacks: int = 1
var ticktime: float = 1.0
var modifiers: Dictionary = {}
var tick_effects: Array = []
var tags: Array = []


static func from_dict(data: Dictionary) -> BuffDef:
	var bid := JsonLoader.config_id_to_string(data.get("id", ""))
	if bid == "":
		push_error("BuffDef.from_dict: missing or empty id in %s" % str(data))
		return null
	var buff := BuffDef.new()
	buff.id = bid
	buff.name = str(data.get("name", "")).strip_edges()
	buff.desc = str(data.get("desc", "")).strip_edges()
	buff.duration = float(data.get("duration", 0.0))
	buff.max_stacks = maxi(1, int(data.get("max_stacks", 1)))
	buff.ticktime = maxf(0.01, float(data.get("ticktime", 1.0)))
	buff.modifiers = normalize_modifiers(data.get("modifiers", {}))
	var tick_v: Variant = data.get("tick_effects", [])
	if tick_v is Array:
		buff.tick_effects = (tick_v as Array).duplicate(true)
	var tags_v: Variant = data.get("tags", [])
	if tags_v is Array:
		buff.tags = (tags_v as Array).duplicate(true)
	return buff


## 支持 [code]{"atk": 10}[/code] 或 [code][{"atk": 10}, {"def": 5}][/code]。
static func normalize_modifiers(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	if raw is Array:
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
		"desc": desc,
		"duration": duration,
		"max_stacks": max_stacks,
		"ticktime": ticktime,
		"modifiers": modifiers.duplicate(true),
		"tick_effects": tick_effects.duplicate(true),
		"tags": tags.duplicate(true),
	}
