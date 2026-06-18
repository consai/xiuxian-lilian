class_name TagService
extends RefCounted


static func collect_tag_stats(rows: Array) -> Dictionary:
	var stats: Dictionary = {}
	for row_v in rows:
		if not row_v is Dictionary:
			continue
		for tag_v in (row_v as Dictionary).get("tags", []) as Array:
			var tag := str(tag_v).strip_edges()
			if tag == "":
				continue
			stats[tag] = int(stats.get(tag, 0)) + 1
	return stats


static func merge_tag_stats(base: Dictionary, extra: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in extra.keys():
		var tag := str(key)
		out[tag] = int(out.get(tag, 0)) + int(extra[key])
	return out


static func reward_tags(reward: Dictionary) -> Array:
	var tags: Array = []
	for tag_v in reward.get("tags", []) as Array:
		var tag := str(tag_v).strip_edges()
		if tag != "" and not tags.has(tag):
			tags.append(tag)
	var kind := str(reward.get("kind", "item")).strip_edges()
	if kind != "" and not tags.has(kind):
		tags.append(kind)
	return tags
