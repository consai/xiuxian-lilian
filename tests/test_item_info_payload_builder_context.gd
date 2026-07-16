extends SceneTree

const BUILDER_PATH := "res://scripts/ui/item_info_payload_builder.gd"
const ITEM_QUERY_PATH := (
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)
const ACTIVE_BOOK_ID := "book_skill_skill_lq_004"
const PASSIVE_BOOK_ID := "book_skill_passive_0002"
const METHOD_BOOK_ID := "book_method_hunyuan_4"
const NORMAL_ITEM_ID := "items_LingCao"

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var builder: Script = load(BUILDER_PATH)
	var item_query: Script = load(ITEM_QUERY_PATH)
	_check(builder != null, "builder script loads at runtime")
	_check(item_query != null, "item query script loads at runtime")
	if builder == null or item_query == null:
		_finish()
		return

	var low_context := _savedata_snapshot()
	var high_context := _savedata_snapshot()
	for book_id in [ACTIVE_BOOK_ID, PASSIVE_BOOK_ID, METHOD_BOOK_ID]:
		_test_learning_book(builder, item_query, book_id, low_context, high_context)
	_test_unlocked_method(builder, item_query, low_context)
	_test_entry_and_item_consistency(builder, item_query, high_context)
	_test_input_is_read_only(builder, item_query)
	_test_non_learning_context_independence(builder)
	_test_invalid_context_and_item(builder)
	_finish()


func _test_learning_book(
		builder: Script,
		item_query: Script,
		book_id: String,
		low_context: Dictionary,
		high_context: Dictionary
) -> void:
	var definition: Variant = item_query.definition_by_id(book_id)
	_check(definition != null, "learning book definition exists: %s" % book_id)
	if definition == null:
		return
	_check(
		builder.learning_book_condition_unmet(definition, low_context, "lianqi"),
		"low realm blocks learning book: %s" % book_id
	)
	_check(
		not builder.learning_book_condition_unmet(definition, high_context, "dujie"),
		"high realm satisfies learning book: %s" % book_id
	)
	var blocked_payload: Dictionary = builder.from_item_id(
		book_id, 1, low_context, "lianqi"
	)
	var allowed_payload: Dictionary = builder.from_item_id(
		book_id, 1, high_context, "dujie"
	)
	_check(
		not blocked_payload.is_empty() and bool(blocked_payload.get("learn_blocked", false)),
		"blocked payload reports learning gate: %s" % book_id
	)
	_check(
		not allowed_payload.is_empty() and not bool(allowed_payload.get("learn_blocked", true)),
		"allowed payload clears learning gate: %s" % book_id
	)


func _test_unlocked_method(builder: Script, item_query: Script, low_context: Dictionary) -> void:
	var definition: Variant = item_query.definition_by_id(METHOD_BOOK_ID)
	if definition == null:
		return
	var unlocked := low_context.duplicate(true)
	unlocked["unlocked_methods"] = [definition.learn_method_id]
	_check(
		not builder.learning_book_condition_unmet(definition, unlocked, "lianqi"),
		"already unlocked method is not blocked by its realm gate"
	)


func _test_entry_and_item_consistency(
		builder: Script,
		item_query: Script,
		savedata_snapshot: Dictionary
) -> void:
	var definition: Variant = item_query.definition_by_id(ACTIVE_BOOK_ID)
	if definition == null:
		return
	var from_item: Dictionary = builder.from_item_id(
		ACTIVE_BOOK_ID, 2, savedata_snapshot, "dujie"
	)
	var from_entry: Dictionary = builder.from_entry(
		{"kind": "item", "id": ACTIVE_BOOK_ID, "count": 2},
		savedata_snapshot,
		"dujie"
	)
	_check(
		_comparable_payload(from_entry) == _comparable_payload(from_item),
		"from_entry and from_item_id produce equivalent payloads"
	)
	_check(
		bool(from_item.get("learn_blocked", true)) \
				== builder.learning_book_condition_unmet(
					definition, savedata_snapshot, "dujie"
				),
		"payload and condition query use the same snapshot"
	)


func _test_input_is_read_only(builder: Script, item_query: Script) -> void:
	var savedata_snapshot := _savedata_snapshot()
	savedata_snapshot["nested_probe"] = {"values": [1, {"token": "stable"}]}
	var before := savedata_snapshot.duplicate(true)
	var definition: Variant = item_query.definition_by_id(PASSIVE_BOOK_ID)
	if definition == null:
		return
	builder.from_item_id(PASSIVE_BOOK_ID, 1, savedata_snapshot, "dujie")
	builder.learning_book_condition_unmet(definition, savedata_snapshot, "dujie")
	_check(savedata_snapshot == before, "builder does not modify the input snapshot")


func _test_non_learning_context_independence(builder: Script) -> void:
	var first: Dictionary = builder.from_item_id(
		NORMAL_ITEM_ID, 3, _savedata_snapshot(), "lianqi"
	)
	var second_context := _savedata_snapshot()
	second_context["unlocked_methods"] = ["method.hunyuan.4"]
	var second: Dictionary = builder.from_item_id(NORMAL_ITEM_ID, 3, second_context, "")
	_check(not first.is_empty(), "ordinary item payload exists")
	_check(
		_comparable_payload(first) == _comparable_payload(second),
		"ordinary item payload is independent of learning context"
	)


func _test_invalid_context_and_item(builder: Script) -> void:
	Engine.print_error_messages = false
	var missing_realm: Dictionary = builder.from_item_id(
		ACTIVE_BOOK_ID, 1, _savedata_snapshot(), ""
	)
	Engine.print_error_messages = true
	_check(missing_realm.is_empty(), "learning book rejects an empty major realm")
	_check(
		builder.from_item_id("missing_item", 1, _savedata_snapshot(), "dujie").is_empty(),
		"invalid item remains empty"
	)


func _savedata_snapshot() -> Dictionary:
	return {
		"realm_name": "练气期",
		"unlocked_abilities": [],
		"unlocked_methods": [],
	}


func _comparable_payload(payload: Dictionary) -> Dictionary:
	var out := payload.duplicate(true)
	out.erase("icon")
	return out


func _finish() -> void:
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: item info payload builder explicit learning context")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
