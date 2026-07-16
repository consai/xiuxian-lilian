extends SceneTree

const LilianSettlementPayloadContract := preload(
	"res://scripts/features/lilian/contracts/lilian_settlement_payload.gd"
)
const BreakthroughPagePayloadContract := preload(
	"res://scripts/features/cultivation/contracts/breakthrough_page_payload.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_lilian_settlement_payload()
	_test_breakthrough_page_payload()
	print("PASS: feature-owned scene payload contracts")
	quit(0)


func _test_lilian_settlement_payload() -> void:
	var manual := LilianSettlementPayloadContract.create("manual")
	assert(manual == {"reason": "manual"})
	assert(LilianSettlementPayloadContract.validate(manual))
	assert(LilianSettlementPayloadContract.create("invalid_reason").is_empty())
	var first_errors := LilianSettlementPayloadContract.collect_errors({
		"reason": "invalid_reason",
	})
	var repeated_errors := LilianSettlementPayloadContract.collect_errors({
		"reason": "invalid_reason",
	})
	assert(first_errors == repeated_errors)
	assert(first_errors == PackedStringArray([
		"lilian_jiesuan.reason 无效: invalid_reason",
	]))
	assert(not LilianSettlementPayloadContract.validate({}))


func _test_breakthrough_page_payload() -> void:
	var panel := BreakthroughPagePayloadContract.panel()
	assert(panel == {"mode": "panel"})
	assert(BreakthroughPagePayloadContract.validate(panel))

	var nested := {"values": [1, {"key": "original"}]}
	var summary := {"new_realm": "筑基", "nested": nested}
	var result := BreakthroughPagePayloadContract.result(summary)
	assert(result["mode"] == "result")
	assert(result["new_realm"] == "筑基")
	assert(BreakthroughPagePayloadContract.validate(result))
	summary["new_realm"] = "changed"
	(nested["values"] as Array)[0] = 9
	((nested["values"] as Array)[1] as Dictionary)["key"] = "changed"
	assert(result["new_realm"] == "筑基")
	assert((result["nested"]["values"] as Array)[0] == 1)
	assert((result["nested"]["values"] as Array)[1]["key"] == "original")

	var returned := BreakthroughPagePayloadContract.to_dict(result)
	(returned["nested"]["values"] as Array)[0] = 5
	assert((result["nested"]["values"] as Array)[0] == 1)
	assert(BreakthroughPagePayloadContract.result({}).is_empty())
	var first_errors := BreakthroughPagePayloadContract.collect_errors({"mode": "result"})
	var repeated_errors := BreakthroughPagePayloadContract.collect_errors({"mode": "result"})
	assert(first_errors == repeated_errors)
	assert(first_errors == PackedStringArray(["tupo_zongjie 缺少 new_realm"]))
	assert(
		BreakthroughPagePayloadContract.collect_errors({"mode": "unknown"})
		== PackedStringArray(["tupo_zongjie.mode 无效: unknown"])
	)
