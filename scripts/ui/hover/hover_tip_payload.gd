extends RefCounted
class_name HoverTipPayload

## 通用 Hover Tip 内容载荷。任意场景通过 [HoverTipSource] 传入此结构即可展示。


static func make(fields: Dictionary) -> Dictionary:
	var lines_v: Variant = fields.get("lines", [])
	var lines: Array[String] = []
	if lines_v is Array:
		for line_v in lines_v as Array:
			var line := str(line_v).strip_edges()
			if line != "":
				lines.append(line)
	var out := {
		"title": str(fields.get("title", "")).strip_edges(),
		"lines": lines,
	}
	var title_color_v: Variant = fields.get("title_color", null)
	if title_color_v is Color:
		out["title_color"] = title_color_v
	var icon_v: Variant = fields.get("icon", null)
	if icon_v is Texture2D:
		out["icon"] = icon_v
	var footer := str(fields.get("footer", "")).strip_edges()
	if footer != "":
		out["footer"] = footer
	return out


static func is_empty(payload: Dictionary) -> bool:
	if payload.is_empty():
		return true
	if str(payload.get("title", "")).strip_edges() != "":
		return false
	var lines_v: Variant = payload.get("lines", [])
	if lines_v is Array and not (lines_v as Array).is_empty():
		return false
	if str(payload.get("footer", "")).strip_edges() != "":
		return false
	return true
