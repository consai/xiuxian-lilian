class_name StoryPlayer
extends RefCounted

const StoryConditionScript := preload("res://scripts/story/story_condition.gd")
const StoryValidatorScript := preload("res://scripts/story/story_validator.gd")

var _story: Dictionary = {}
var _state: Dictionary = {}
var _current_node_id := ""
var _history: Array[String] = []
var _started := false


func load_story(story: Dictionary, initial_state: Dictionary = {}) -> Dictionary:
	var errors := StoryValidatorScript.collect_errors(story)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	_story = story.duplicate(true)
	_state = initial_state.duplicate(true)
	_current_node_id = str(_story.get("entry", ""))
	_history = []
	_started = false
	return {"ok": true}


func start() -> Dictionary:
	if _story.is_empty():
		return _error("story_not_loaded")
	_started = true
	return current_frame()


func current_frame() -> Dictionary:
	if not _started:
		return _error("story_not_started")
	var node := _node(_current_node_id)
	if node.is_empty():
		return _error("unknown_node:%s" % _current_node_id)
	var node_type := str(node.get("type", ""))
	var frame := {
		"ok": true,
		"story_id": str(_story.get("id", "")),
		"node_id": _current_node_id,
		"type": node_type,
		"meta": (node.get("meta", {}) as Dictionary).duplicate(true),
	}
	match node_type:
		"line":
			frame["speaker"] = str(node.get("speaker", ""))
			frame["text"] = str(node.get("text", ""))
			frame["portrait"] = str(node.get("portrait", ""))
			frame["can_advance"] = true
		"choice":
			frame["prompt"] = str(node.get("prompt", ""))
			frame["choices"] = _available_choices(node)
			frame["can_advance"] = false
		"command":
			frame["commands"] = (node.get("commands", []) as Array).duplicate(true)
			frame["can_advance"] = true
		"end":
			frame["result"] = str(node.get("result", "completed"))
			frame["can_advance"] = false
	return frame


func advance() -> Dictionary:
	if not _started:
		return _error("story_not_started")
	var node := _node(_current_node_id)
	var node_type := str(node.get("type", ""))
	if node_type not in ["line", "command"]:
		return _error("node_cannot_advance:%s" % node_type)
	return _move_to(str(node.get("next", "")))


func select_choice(choice_id: String) -> Dictionary:
	if not _started:
		return _error("story_not_started")
	var node := _node(_current_node_id)
	if str(node.get("type", "")) != "choice":
		return _error("current_node_is_not_choice")
	for choice_v in node.get("choices", []) as Array:
		if not choice_v is Dictionary:
			continue
		var choice := choice_v as Dictionary
		if str(choice.get("id", "")) != choice_id:
			continue
		if not StoryConditionScript.matches_all(choice.get("requires", []), _state):
			return _error("choice_not_available:%s" % choice_id)
		StoryConditionScript.apply_effects(choice.get("effects", []), _state)
		return _move_to(str(choice.get("next", "")))
	return _error("choice_not_available:%s" % choice_id)


func snapshot() -> Dictionary:
	return {
		"story_id": str(_story.get("id", "")),
		"current_node_id": _current_node_id,
		"state": _state.duplicate(true),
		"history": _history.duplicate(),
		"started": _started,
	}


func restore(story: Dictionary, saved_snapshot: Dictionary) -> Dictionary:
	var loaded := load_story(story, saved_snapshot.get("state", {}) as Dictionary)
	if not bool(loaded.get("ok", false)):
		return loaded
	var node_id := str(saved_snapshot.get("current_node_id", "")).strip_edges()
	if not _story.get("nodes", {}).has(node_id):
		return _error("snapshot_unknown_node:%s" % node_id)
	_current_node_id = node_id
	_history.assign(saved_snapshot.get("history", []) as Array)
	_started = bool(saved_snapshot.get("started", true))
	return {"ok": true}


func state() -> Dictionary:
	return _state.duplicate(true)


func _available_choices(node: Dictionary) -> Array:
	var out: Array = []
	for choice_v in node.get("choices", []) as Array:
		if not choice_v is Dictionary:
			continue
		var choice := choice_v as Dictionary
		if not StoryConditionScript.matches_all(choice.get("requires", []), _state):
			continue
		out.append({
			"id": str(choice.get("id", "")),
			"label": str(choice.get("label", "")),
			"hint": str(choice.get("hint", "")),
			"meta": (choice.get("meta", {}) as Dictionary).duplicate(true),
		})
	return out


func _move_to(next_id: String) -> Dictionary:
	if not _story.get("nodes", {}).has(next_id):
		return _error("unknown_next_node:%s" % next_id)
	_history.append(_current_node_id)
	_current_node_id = next_id
	return current_frame()


func _node(node_id: String) -> Dictionary:
	var node_v: Variant = (_story.get("nodes", {}) as Dictionary).get(node_id, {})
	return node_v as Dictionary if node_v is Dictionary else {}


func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
