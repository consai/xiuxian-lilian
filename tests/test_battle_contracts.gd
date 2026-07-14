extends SceneTree

const PlayerBattleSnapshotScript := preload(
	"res://scripts/features/battle/contracts/player_battle_snapshot.gd"
)
const ZhandouSummaryScript := preload(
	"res://scripts/features/battle/contracts/zhandou_summary.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_player_battle_snapshot()
	_test_zhandou_summary()
	print("PASS: battle contracts preserve current validation behavior")
	quit(0)


func _test_player_battle_snapshot() -> void:
	assert(not PlayerBattleSnapshotScript.validate({}))
	var attrs := {
		EnumPlayerAttr.HP_MAX: 100.0,
		EnumPlayerAttr.MP_MAX: 80.0,
		EnumPlayerAttr.PHYSICAL_ATK: 10.0,
		EnumPlayerAttr.MAGIC_ATK: 11.0,
		EnumPlayerAttr.PHYSICAL_DEF: 12.0,
		EnumPlayerAttr.MAGIC_DEF: 13.0,
		EnumPlayerAttr.SPD: 14.0,
	}
	var minimal := {"hp": 90.0, "mp": 70.0, "attrs": attrs}
	assert(PlayerBattleSnapshotScript.validate(minimal))
	var missing_hp := minimal.duplicate(true)
	missing_hp.erase("hp")
	assert(not PlayerBattleSnapshotScript.validate(missing_hp))
	var missing_mp := minimal.duplicate(true)
	missing_mp.erase("mp")
	assert(not PlayerBattleSnapshotScript.validate(missing_mp))
	for core_key in attrs.keys():
		var missing_attr := minimal.duplicate(true)
		(missing_attr["attrs"] as Dictionary).erase(core_key)
		assert(not PlayerBattleSnapshotScript.validate(missing_attr))
	for array_field in ["skills", "items", "equips"]:
		var wrong_array := minimal.duplicate(true)
		wrong_array[array_field] = {}
		assert(not PlayerBattleSnapshotScript.validate(wrong_array))


func _test_zhandou_summary() -> void:
	for outcome in [
		ZhandouSummaryScript.OUTCOME_WIN,
		ZhandouSummaryScript.OUTCOME_LOSS,
		ZhandouSummaryScript.OUTCOME_DRAW,
		ZhandouSummaryScript.OUTCOME_ESCAPED,
	]:
		assert(ZhandouSummaryScript.validate({"outcome": outcome}))
	assert(not ZhandouSummaryScript.validate({"outcome": "unknown"}))
	assert(ZhandouSummaryScript.validate({"outcome": ZhandouSummaryScript.OUTCOME_WIN, "player_runtime": {}}))
	assert(ZhandouSummaryScript.validate({"outcome": ZhandouSummaryScript.OUTCOME_WIN, "player_runtime": "legacy"}))
	assert(ZhandouSummaryScript.validate({
		"outcome": ZhandouSummaryScript.OUTCOME_WIN,
		"player_runtime": {"hp": 10.0, "mp": 5.0, "items": []},
	}))
	assert(not ZhandouSummaryScript.validate({
		"outcome": ZhandouSummaryScript.OUTCOME_WIN,
		"player_runtime": {"hp": 10.0, "items": []},
	}))
