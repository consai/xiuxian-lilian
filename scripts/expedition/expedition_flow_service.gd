class_name ExpeditionFlowService
extends RefCounted

## 历练结算编排：finish → settle，避免场景与 autoload 散落重复调用。


static func settle_active_expedition(reason: String) -> Dictionary:
	if ExpeditionState == null or not ExpeditionState.active:
		return {"ok": false, "error": "没有可结算的历练"}
	var result: Dictionary = ExpeditionState.finish(reason)
	if not bool(result.get("ok", false)):
		return result
	if GameState == null:
		return {"ok": false, "error": "缺少 GameState"}
	var settled: Dictionary = GameState.settle_expedition(result)
	if not bool(settled.get("ok", false)):
		return settled
	return result
