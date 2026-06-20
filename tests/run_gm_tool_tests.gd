extends SceneTree

const GmItemGrantPanelScene := preload("res://scenes/ui/gm_item_grant_panel.tscn")
const GmItemSearchScript := preload("res://scripts/ui/gm_item_search.gd")

var _failures: Array[String] = []
var _tests_run := 0


func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_run("gm item search handles chinese and english", _test_search_handles_chinese_and_english)
	_run("gm grant panel includes equips first", _test_grant_panel_includes_equips_first)
	_run("gm grant equip writes owned equips", _test_grant_equip_writes_owned_equips)
	if _failures.is_empty():
		print("PASS: %d gm tool tests" % _tests_run)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)


func _run(name: String, test: Callable) -> void:
	_tests_run += 1
	var before := _failures.size()
	test.call()
	if before == _failures.size():
		print("PASS: %s" % name)


func _test_search_handles_chinese_and_english() -> void:
	var catalog := [
		{"kind": "equip", "id": 5001, "name": "天雷印", "type": "法宝", "primary_type": "法宝", "secondary_type": "战斗法宝", "rarity": "品质4"},
		{"kind": "item", "id": "items_LingCao", "name": "灵草", "type": "材料", "primary_type": "材料", "secondary_type": "草药", "rarity": "1"},
	]
	var by_kind := GmItemSearchScript.filter_entries(catalog, "法宝")
	_expect_true(not by_kind.is_empty(), "search 法宝 returns results")
	_expect_eq(str((by_kind[0] as Dictionary).get("kind", "")), "equip", "search 法宝 returns equip")
	var by_name := GmItemSearchScript.filter_entries(catalog, "tly")
	_expect_true(by_name.is_empty(), "pinyin is not treated as a hidden alias")
	var by_id := GmItemSearchScript.filter_entries(catalog, "5001")
	_expect_eq(int((by_id[0] as Dictionary).get("id", -1)), 5001, "search equip id")


func _test_grant_panel_includes_equips_first() -> void:
	var panel := _new_panel()
	_expect_true(panel._catalog.size() > 0, "gm catalog built")
	_expect_eq(str((panel._catalog[0] as Dictionary).get("kind", "")), EnumRewardKind.LABEL_EQUIP, "equips are visible at top")
	var found := false
	for row_v in panel._catalog:
		var row := row_v as Dictionary
		if str(row.get("kind", "")) == EnumRewardKind.LABEL_EQUIP and int(row.get("id", -1)) == 5001:
			found = true
			break
	_expect_true(found, "catalog includes equip 5001")
	panel.queue_free()


func _test_grant_equip_writes_owned_equips() -> void:
	var state := root.get_node("GameState")
	state.new_game()
	state.owned_equips = []
	var panel := _new_panel()
	var ok: bool = panel._grant_entry({"kind": EnumRewardKind.LABEL_EQUIP, "id": 5001}, 10, false)
	_expect_true(ok, "grant equip succeeds")
	_expect_true((state.owned_equips as Array).has(5001), "owned_equips receives equip id")
	panel.queue_free()


func _new_panel() -> Control:
	var panel := GmItemGrantPanelScene.instantiate() as Control
	root.add_child(panel)
	return panel


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s got %s" % [message, str(expected), str(actual)])
