class_name StoryValidator
extends RefCounted

const VALID_NODE_TYPES := ["line", "choice", "command", "end"]
const VALID_CONDITION_OPS := ["eq", "neq", "has", "gte", "lte"]
const VALID_EFFECT_OPS := ["set", "add", "erase"]


static func collect_errors(story: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var story_id := str(story.get("id", "")).strip_edges()
	if story_id == "":
		errors.append("剧情缺少 id")
	var nodes_v: Variant = story.get("nodes", {})
	if not nodes_v is Dictionary or (nodes_v as Dictionary).is_empty():
		errors.append("剧情 %s 缺少 nodes" % story_id)
		return errors
	var nodes := nodes_v as Dictionary
	var entry := str(story.get("entry", "")).strip_edges()
	if entry == "" or not nodes.has(entry):
		errors.append("剧情 %s entry 无效: %s" % [story_id, entry])
	for node_id_v in nodes.keys():
		var node_id := str(node_id_v)
		var node_v: Variant = nodes[node_id_v]
		if not node_v is Dictionary:
			errors.append("剧情 %s 节点 %s 必须是对象" % [story_id, node_id])
			continue
		errors.append_array(_validate_node(story_id, node_id, node_v as Dictionary, nodes))
	return errors


static func _validate_node(
		story_id: String,
		node_id: String,
		node: Dictionary,
		nodes: Dictionary
) -> PackedStringArray:
	var errors: PackedStringArray = []
	var node_type := str(node.get("type", "")).strip_edges()
	var label := "剧情 %s 节点 %s" % [story_id, node_id]
	if node_type not in VALID_NODE_TYPES:
		errors.append("%s type 无效: %s" % [label, node_type])
		return errors
	errors.append_array(_validate_conditions(node.get("requires", []), "%s.requires" % label))
	match node_type:
		"line":
			if str(node.get("text", "")).strip_edges() == "":
				errors.append("%s 缺少 text" % label)
			errors.append_array(_validate_next(node, nodes, label))
		"choice":
			var choices_v: Variant = node.get("choices", [])
			if not choices_v is Array or (choices_v as Array).is_empty():
				errors.append("%s 缺少 choices" % label)
			else:
				var choice_ids := {}
				for choice_v in choices_v as Array:
					if not choice_v is Dictionary:
						errors.append("%s choice 必须是对象" % label)
						continue
					var choice := choice_v as Dictionary
					var choice_id := str(choice.get("id", "")).strip_edges()
					if choice_id == "":
						errors.append("%s choice 缺少 id" % label)
					elif choice_ids.has(choice_id):
						errors.append("%s choice id 重复: %s" % [label, choice_id])
					else:
						choice_ids[choice_id] = true
					errors.append_array(_validate_next(choice, nodes, "%s choice %s" % [label, choice_id]))
					errors.append_array(_validate_conditions(
						choice.get("requires", []), "%s choice %s.requires" % [label, choice_id]
					))
					errors.append_array(_validate_effects(
						choice.get("effects", []), "%s choice %s.effects" % [label, choice_id]
					))
		"command":
			if not node.get("commands", []) is Array or (node.get("commands", []) as Array).is_empty():
				errors.append("%s 缺少 commands" % label)
			errors.append_array(_validate_next(node, nodes, label))
		"end":
			pass
	return errors


static func _validate_next(owner: Dictionary, nodes: Dictionary, label: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	var next_id := str(owner.get("next", "")).strip_edges()
	if next_id == "":
		errors.append("%s 缺少 next" % label)
	elif not nodes.has(next_id):
		errors.append("%s next 引用了未知节点: %s" % [label, next_id])
	return errors


static func _validate_conditions(raw: Variant, label: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not raw is Array:
		errors.append("%s 必须是数组" % label)
		return errors
	for condition_v in raw as Array:
		if not condition_v is Dictionary:
			errors.append("%s 条目必须是对象" % label)
			continue
		var condition := condition_v as Dictionary
		if str(condition.get("flag", "")).strip_edges() == "":
			errors.append("%s 条目缺少 flag" % label)
		if str(condition.get("op", "eq")) not in VALID_CONDITION_OPS:
			errors.append("%s 条目 op 无效" % label)
	return errors


static func _validate_effects(raw: Variant, label: String) -> PackedStringArray:
	var errors: PackedStringArray = []
	if not raw is Array:
		errors.append("%s 必须是数组" % label)
		return errors
	for effect_v in raw as Array:
		if not effect_v is Dictionary:
			errors.append("%s 条目必须是对象" % label)
			continue
		var effect := effect_v as Dictionary
		if str(effect.get("flag", "")).strip_edges() == "":
			errors.append("%s 条目缺少 flag" % label)
		if str(effect.get("op", "set")) not in VALID_EFFECT_OPS:
			errors.append("%s 条目 op 无效" % label)
	return errors
