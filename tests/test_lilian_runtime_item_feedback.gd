extends SceneTree

const InventoryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_application.gd"
)
const LilianSessionScript := preload("res://scripts/lilian/lilian_state.gd")
const LilianSessionHostScript := preload("res://scripts/app/lilian_session_host.gd")
const GameSessionHostScript := preload("res://scripts/app/game_session_host.gd")
const GameSessionScript := preload("res://scripts/sim/game_state.gd")

var _failures: PackedStringArray = []
var _feedback_count := 0
var _vitals_count := 0
var _last_feedback := ""
var _lilian_state
var _scene_manager


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_lilian_state = LilianSessionScript.new()
	root.add_child(_lilian_state)
	_scene_manager = root.get_node("SceneManager")
	_lilian_state.bind_scene_manager(_scene_manager)
	_lilian_state.runtime_item_feedback.connect(_on_runtime_item_feedback)
	_lilian_state.runtime_vitals_changed.connect(_on_runtime_vitals_changed)
	_test_success()
	_test_failures_do_not_mutate_session()
	_test_slot_signal_forwarding()
	await _test_page_pending_feedback()
	_lilian_state.runtime_item_feedback.disconnect(_on_runtime_item_feedback)
	_lilian_state.runtime_vitals_changed.disconnect(_on_runtime_vitals_changed)
	_lilian_state.reset()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: lilian runtime item feedback")
	quit(0)


func _test_success() -> void:
	_seed_active_session("items_LingGuo", 2, 40.0, 30.0)
	_reset_signal_counts()
	var result: Dictionary = _lilian_state.use_runtime_inventory_item("items_LingGuo")
	_check(bool(result.get("ok", false)), "active recovery item succeeds")
	_check(int((_lilian_state.runtime.inventory as Dictionary).get("items_LingGuo", 0)) == 1, "success consumes exactly one item")
	_check(is_equal_approx(float(_lilian_state.runtime.hp), 50.0), "success restores configured hp")
	_check(str(result.get("feedback", "")).contains("气血回升 10 点"), "success keeps recovery feedback text")
	_check(_feedback_count == 1 and _last_feedback == str(result.feedback), "success emits exactly one final feedback")
	_check(_vitals_count == 1, "success emits exactly one vitals change")


func _test_failures_do_not_mutate_session() -> void:
	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_lilian_state.active = false
	_expect_failure("items_LingGuo", "历练未进行", "inactive")

	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	var battle_overlay := Node.new()
	_scene_manager.set("_zhandou_overlay", battle_overlay)
	_expect_failure("items_LingGuo", "战斗中无法使用丹药", "battle blocked")
	_scene_manager.set("_zhandou_overlay", null)
	battle_overlay.free()

	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_expect_failure("", "无效物品", "empty id")

	_seed_active_session("items_LingGuo", 0, 40.0, 30.0)
	_expect_failure("items_LingGuo", "背包中没有该物品", "missing inventory")

	_seed_active_session("items_LingGuo", 1, 40.0, 3.0)
	var costly := (_lilian_state.runtime.item_definitions as Dictionary)["items_LingGuo"] as Dictionary
	costly["fight_mp_cost"] = 5.0
	_expect_failure("items_LingGuo", "法力不足，无法催动丹药", "insufficient mana")

	_seed_active_session("items_LingCao", 1, 40.0, 30.0)
	_expect_failure("items_LingCao", "该物品无法在此使用", "unusable item")

	_seed_active_session("items_LingCao", 2, 40.0, 30.0)
	_reset_signal_counts()
	_lilian_state.use_runtime_inventory_item("items_LingCao")
	_lilian_state.use_runtime_inventory_item("items_LingCao")
	_check(_feedback_count == 2 and _vitals_count == 0, "repeated attempts emit once per attempt without duplicate vitals")


func _expect_failure(item_id: String, expected_error: String, label: String) -> void:
	var before: Dictionary = _lilian_state.session_snapshot()
	_reset_signal_counts()
	var result: Dictionary = _lilian_state.use_runtime_inventory_item(item_id)
	_check(result == {"ok": false, "error": expected_error}, "%s keeps failure result" % label)
	_check(_lilian_state.session_snapshot() == before, "%s keeps the full session unchanged" % label)
	_check(_feedback_count == 1 and _last_feedback == expected_error, "%s emits exactly one failure feedback" % label)
	_check(_vitals_count == 0, "%s does not emit vitals" % label)


func _test_slot_signal_forwarding() -> void:
	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_lilian_state.active = false
	_reset_signal_counts()
	_check(not bool(_lilian_state.use_runtime_item_slot(0).get("ok", false)), "inactive slot precheck fails")
	_check(_feedback_count == 0 and _vitals_count == 0, "inactive slot precheck emits no item feedback")

	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_reset_signal_counts()
	_check(not bool(_lilian_state.use_runtime_item_slot(3).get("ok", false)), "invalid slot precheck fails")
	_check(_feedback_count == 0 and _vitals_count == 0, "invalid slot precheck emits no item feedback")

	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_lilian_state.runtime.item_slots = ["", "", ""]
	_reset_signal_counts()
	_check(not bool(_lilian_state.use_runtime_item_slot(0).get("ok", false)), "empty slot precheck fails")
	_check(_feedback_count == 0 and _vitals_count == 0, "empty slot precheck emits no item feedback")

	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_reset_signal_counts()
	_check(bool(_lilian_state.use_runtime_item_slot(0).get("ok", false)), "equipped slot forwards to item use")
	_check(_feedback_count == 1 and _vitals_count == 1, "forwarded slot inherits exactly one item and vitals signal")


func _test_page_pending_feedback() -> void:
	_seed_active_session("items_LingGuo", 1, 40.0, 30.0)
	_lilian_state.location_id = "qinglan_mountain"
	var page := (load("res://scenes/lilian/lilian_xunhuan.tscn") as PackedScene).instantiate()
	var session_host := LilianSessionHostScript.new()
	session_host.bind_session(_lilian_state)
	var game_session_host := GameSessionHostScript.new()
	var game_session := GameSessionScript.new()
	game_session.bind_store(root.get_node("DataStore"))
	game_session.bind_scene_manager(root.get_node("SceneManager"))
	game_session_host.bind_session(game_session)
	page.bind_lilian_session_host(session_host)
	page.bind_game_session_host(game_session_host)
	root.add_child(page)
	await process_frame
	page.set("_pending_bag_feedback", "最新背包反馈")
	page.call("_on_overlay_dismissed", "zhandou_peizhi_mianban")
	_check(str(page.get("_pending_bag_feedback")) == "最新背包反馈", "other overlay route does not consume bag feedback")
	page.call("_on_overlay_dismissed", "beibao_panel")
	_check(str(page.get("_pending_bag_feedback")) == "", "bag dismissal consumes pending feedback")
	_check(str((page.get_node("%Feedback") as Label).text) == "最新背包反馈", "bag dismissal presents latest feedback")
	page.queue_free()
	session_host.queue_free()
	game_session_host.queue_free()
	game_session.queue_free()
	await process_frame


func _seed_active_session(item_id: String, count: int, hp: float, mp: float) -> void:
	_lilian_state.reset()
	_lilian_state.active = true
	_lilian_state.phase = "resolving"
	_lilian_state.runtime = {
		"hp": hp,
		"mp": mp,
		"item_slots": [item_id, "", ""],
		"inventory": {item_id: count} if count > 0 else {},
		"item_definitions": InventoryApplicationScript.definition_snapshots_for_item_ids([item_id]),
		"owned_equips": [],
	}
	_lilian_state.player_snapshot = {
		"attrs": {EnumPlayerAttr.HP_MAX: 100.0, EnumPlayerAttr.MP_MAX: 100.0},
	}


func _reset_signal_counts() -> void:
	_feedback_count = 0
	_vitals_count = 0
	_last_feedback = ""


func _on_runtime_item_feedback(feedback: String) -> void:
	_feedback_count += 1
	_last_feedback = feedback


func _on_runtime_vitals_changed(_feedback: String) -> void:
	_vitals_count += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
