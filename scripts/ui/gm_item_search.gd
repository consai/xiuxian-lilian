class_name GmItemSearch
extends RefCounted

## GM 道具模糊搜索：支持名称 / ID / 类型 / 品质 / 阶位的子序列匹配与关键词组合。


static func filter_entries(catalog: Array, query: String, limit: int = 200) -> Array:
	var trimmed := query.strip_edges()
	if trimmed == "":
		return catalog.slice(0, mini(limit, catalog.size()))
	var scored: Array = []
	for row_v in catalog:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var score := _entry_score(trimmed, row)
		if score >= 0:
			scored.append({"score": score, "entry": row})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	var out: Array = []
	for i in range(mini(limit, scored.size())):
		out.append((scored[i] as Dictionary).get("entry"))
	return out


static func _entry_score(query: String, entry: Dictionary) -> int:
	var haystack := "%s %s %s %s %s %s" % [
		str(entry.get("kind", "")),
		str(entry.get("name", "")),
		str(entry.get("id", "")),
		str(entry.get("type", "")),
		"%s %s" % [str(entry.get("primary_type", "")), str(entry.get("secondary_type", ""))],
		str(entry.get("quality", "")),
		str(entry.get("tier", "")),
	]
	return _score_text(query, haystack)


static func _score_text(query: String, text: String) -> int:
	var normalized_query := query.to_lower()
	var normalized_text := text.to_lower()
	var tokens := normalized_query.split(" ", false)
	var total := 0
	var matched_tokens := 0
	for token_v in tokens:
		var token := str(token_v).strip_edges()
		if token == "":
			continue
		var token_score := _fuzzy_score_single(token, normalized_text)
		if token_score < 0:
			return -1
		total += token_score
		matched_tokens += 1
	return total if matched_tokens > 0 else -1


static func _fuzzy_score_single(query: String, text: String) -> int:
	if query == "":
		return 0
	if text == query:
		return 2000
	if text.begins_with(query):
		return 1500 - text.length()
	var pos := text.find(query)
	if pos >= 0:
		return 1000 - pos
	var sub := _subsequence_score(query, text)
	if sub < 0:
		return -1
	return 400 + sub


static func _subsequence_score(query: String, text: String) -> int:
	var qi := 0
	var score := 0
	var run := 0
	var last_pos := -2
	for i in range(text.length()):
		if qi >= query.length():
			break
		if text.substr(i, 1) == query.substr(qi, 1):
			if last_pos == i - 1:
				run += 1
			else:
				run = 1
			score += run * 8
			if i == 0 or (i > 0 and text.substr(i - 1, 1) in [" ", "_", "·"]):
				score += 12
			last_pos = i
			qi += 1
	return score if qi >= query.length() else -1
