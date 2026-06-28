class_name LilianFlowService
extends RefCounted

## 历练结算编排：finish → settle，避免场景与 autoload 散落重复调用。


static func settle_active_lilian(reason: String) -> Dictionary:
	if LilianState == null or not LilianState.active:
		return {"ok": false, "error": "没有可结算的历练"}
	var result: Dictionary = LilianState.finish(reason)
	if not bool(result.get("ok", false)):
		return result
	if GameState == null:
		return {"ok": false, "error": "缺少 GameState"}
	var settled: Dictionary = GameState.settle_lilian(result)
	if not bool(settled.get("ok", false)):
		return settled
	return result
