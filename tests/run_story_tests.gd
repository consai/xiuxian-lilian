extends SceneTree

const StoryPlayerScript := preload("res://scripts/story/story_player.gd")
const StoryValidatorScript := preload("res://scripts/story/story_validator.gd")
const STORY_PATH := "res://data/stories/prologue_fragment.yaml"
const TUTORIAL_STORY_PATH := "res://data/stories/prologue_tutorial.yaml"

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	var story := _load_story()
	_run("sample story validates", func() -> void:
		_expect_true(StoryValidatorScript.collect_errors(story).is_empty(), "sample validation")
	)
	_run("tutorial story validates", func() -> void:
		var tutorial_story := _load_story_at(TUTORIAL_STORY_PATH)
		_expect_true(StoryValidatorScript.collect_errors(tutorial_story).is_empty(), "tutorial validation")
		_expect_eq(str(tutorial_story.get("entry", "")), "empty_cave", "tutorial entry")
		var narration_count := 0
		var line_count := 0
		var text_chars := 0
		for node_v in (tutorial_story.get("nodes", {}) as Dictionary).values():
			if not node_v is Dictionary:
				continue
			var node := node_v as Dictionary
			if str(node.get("type", "")) == "line":
				line_count += 1
				text_chars += str(node.get("text", "")).length()
			if bool((node.get("meta", {}) as Dictionary).get("narration", false)):
				narration_count += 1
		_expect_true(narration_count >= 6, "tutorial preserves key narration")
		_expect_true(line_count <= 10, "tutorial keeps required reading concise")
		_expect_true(text_chars <= 700, "tutorial text stays under reading budget")
		var nodes := tutorial_story.get("nodes", {}) as Dictionary
		_expect_false(nodes.has("start_plain"), "tutorial does not require plain cultivation")
		_expect_eq(
			str((((nodes.get("select_recipe", {}) as Dictionary).get("commands", []) as Array)[0] as Dictionary).get("target", "")),
			"RecipeOption",
			"tutorial highlights recipe selection"
		)
	)
	_run("new and legacy saves keep tutorial completed by default", func() -> void:
		var store := root.get_node("DataStore")
		store.reset_savedata()
		_expect_true(bool((store.savedata.get("tutorial", {}) as Dictionary).get("completed", false)), "new save tutorial completed")
		var legacy: Dictionary = store.export_savedata()
		legacy.erase("tutorial")
		var merged: Dictionary = store.coalesce_savedata(legacy)
		_expect_true(bool((merged.get("tutorial", {}) as Dictionary).get("completed", false)), "legacy tutorial completed")
	)
	_run("line advances to choice", func() -> void:
		var player = StoryPlayerScript.new()
		_expect_true(bool(player.load_story(story).get("ok", false)), "load story")
		var first: Dictionary = player.start()
		_expect_eq(str(first.get("type", "")), "line", "entry type")
		var choice: Dictionary = player.advance()
		_expect_eq(str(choice.get("type", "")), "choice", "choice type")
		_expect_eq((choice.get("choices", []) as Array).size(), 2, "choice count")
	)
	_run("choice writes local story state", func() -> void:
		var player = StoryPlayerScript.new()
		player.load_story(story)
		player.start()
		player.advance()
		var frame: Dictionary = player.select_choice("search")
		_expect_eq(str(frame.get("node_id", "")), "master_answer", "choice next")
		_expect_true(bool(player.state().get("prologue.asked_master", false)), "choice effect")
	)
	_run("command frame can be acknowledged", func() -> void:
		var player = StoryPlayerScript.new()
		player.load_story(story)
		player.start()
		player.advance()
		player.select_choice("steady")
		var command_frame: Dictionary = player.current_frame()
		_expect_eq(str(command_frame.get("type", "")), "command", "command type")
		_expect_eq((command_frame.get("commands", []) as Array).size(), 2, "command count")
		var end_frame: Dictionary = player.advance()
		_expect_eq(str(end_frame.get("type", "")), "end", "end type")
	)
	_run("snapshot restores current node and flags", func() -> void:
		var player = StoryPlayerScript.new()
		player.load_story(story)
		player.start()
		player.advance()
		player.select_choice("search")
		var restored = StoryPlayerScript.new()
		_expect_true(bool(restored.restore(story, player.snapshot()).get("ok", false)), "restore")
		_expect_eq(str(restored.current_frame().get("node_id", "")), "master_answer", "restored node")
		_expect_true(bool(restored.state().get("prologue.asked_master", false)), "restored state")
	)
	_run("validator catches broken references", func() -> void:
		var broken := story.duplicate(true)
		(broken["nodes"]["wake"] as Dictionary)["next"] = "missing"
		_expect_false(StoryValidatorScript.collect_errors(broken).is_empty(), "broken next")
	)
	if _failures.is_empty():
		print("PASS: %d story tests" % _tests_run)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _load_story() -> Dictionary:
	return _load_story_at(STORY_PATH)


func _load_story_at(path: String) -> Dictionary:
	var parsed: Variant = JsonLoader._read_json_variant(path)
	return parsed as Dictionary if parsed is Dictionary else {}


func _run(name: String, test: Callable) -> void:
	_tests_run += 1
	var before := _failures.size()
	test.call()
	if before == _failures.size():
		print("PASS: %s" % name)


func _expect_true(value: bool, label: String) -> void:
	if not value:
		_failures.append("%s (expected true)" % label)


func _expect_false(value: bool, label: String) -> void:
	if value:
		_failures.append("%s (expected false)" % label)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s got %s)" % [label, str(expected), str(actual)])
