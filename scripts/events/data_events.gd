extends Node

signal snapshot_updated(scene_id: String, snapshot: Dictionary)
signal toast(message: String)
## 历练内由事件等写入的逐条提示：[code]{ "text": String, "tone": "gain"|"loss"|"neutral" }[/code]
signal tip_hints(entries: Array)
## 统一提示协议（TipIntent V1）
signal tip_intent(intent: Dictionary)
signal tip_intents(intents: Array)
signal error(message: String)
## 背包/仓库物品数量变化（使用、获得、转移等）
signal inventory_changed
## 效果系统请求：地图解锁（支持全局概率、候选地图、逐地图概率）
signal effect_map_unlock_request(percent: int, candidate_map_ids: Array, unlock_rows: Array)
## 效果系统请求：执行一次突破判定（与 UI 点「突破」共用逻辑）
signal effect_breakthrough_request()


func emit_snapshot(scene_id: String, snapshot: Dictionary) -> void:
	## 参数说明：
	## - scene_id: 场景标识
	## - snapshot: 场景快照信封
	snapshot_updated.emit(scene_id, snapshot)


func emit_toast(message: String) -> void:
	## 参数说明：
	## - message: 提示文本
	toast.emit(message)


func emit_tip_hints(entries: Array) -> void:
	## 参数说明：
	## - entries: 字典数组，每项含 [code]text[/code]、[code]tone[/code]（可选，默认 neutral）
	tip_hints.emit(entries)


func emit_tip_intent(intent: Dictionary) -> void:
	## 参数说明：
	## - intent: 统一提示载荷（TipIntent V1）
	tip_intent.emit(intent)


func emit_tip_intents(intents: Array) -> void:
	## 参数说明：
	## - intents: TipIntent 字典数组
	tip_intents.emit(intents)


func emit_error(message: String) -> void:
	## 参数说明：
	## - message: 错误文本
	error.emit(message)


func emit_inventory_changed() -> void:
	inventory_changed.emit()


func emit_effect_map_unlock_request(percent: int, candidate_map_ids: Array = [], unlock_rows: Array = []) -> void:
	## 参数说明：
	## - percent: 解锁成功概率（0~100）
	## - candidate_map_ids: 指定可解锁地图 id 列表；为空则走全图随机
	## - unlock_rows: 逐地图概率配置 [{map_id, percent}]，非空时优先生效
	effect_map_unlock_request.emit(clampi(percent, 0, 100), candidate_map_ids, unlock_rows)


func emit_effect_breakthrough_request() -> void:
	effect_breakthrough_request.emit()
