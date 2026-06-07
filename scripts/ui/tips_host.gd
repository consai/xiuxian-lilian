extends CanvasLayer

## 全局提示入口：接收 DataEvents 的 tip_intent 并交给 TipBus 策略化处理（战斗 combat_block 通道）。

const TipIntentScript := preload("res://scripts/ui/tips/core/tip_intent.gd")
const TipMetricsScript := preload("res://scripts/ui/tips/core/tip_metrics.gd")
const TipPolicyEngineScript := preload("res://scripts/ui/tips/core/tip_policy_engine.gd")
const TipRouterScript := preload("res://scripts/ui/tips/core/tip_router.gd")
const TipBusScript := preload("res://scripts/ui/tips/core/tip_bus.gd")
const CombatBlockPresenterScript := preload("res://scripts/ui/tips/presenter/combat_block_presenter.gd")

const POLICY_CFG_PATH := "res://data/ui/tip_policy.json"

var _metrics: TipMetrics
var _policy: TipPolicyEngine
var _router: TipRouter
var _bus: TipBus

@export var debug_print_metrics: bool = false


func _ready() -> void:
	layer = 1000
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_tip_runtime()
	if Engine.is_editor_hint():
		return
	var de: Node = get_node_or_null("/root/DataEvents")
	if de == null:
		return
	if de.has_signal("tip_intent") and not de.tip_intent.is_connected(_on_tip_intent):
		de.tip_intent.connect(_on_tip_intent)
	if de.has_signal("tip_intents") and not de.tip_intents.is_connected(_on_tip_intents):
		de.tip_intents.connect(_on_tip_intents)


func _on_tip_intent(intent: Dictionary) -> void:
	_publish_intent(intent)


func _on_tip_intents(intents: Array) -> void:
	if _bus == null:
		return
	_bus.publish_many(intents)


func _setup_tip_runtime() -> void:
	_metrics = TipMetricsScript.new()
	_policy = TipPolicyEngineScript.new()
	_router = TipRouterScript.new()
	_bus = TipBusScript.new()
	_policy.setup(_load_policy_config())
	_router.register_presenter(TipIntentScript.CHANNEL_COMBAT_BLOCK, CombatBlockPresenterScript.new())
	_bus.setup(_policy, _router, _metrics)


func _publish_intent(intent: Dictionary) -> void:
	if _bus == null:
		return
	var result := _bus.publish(intent)
	if debug_print_metrics and not bool(result.get("ok", false)):
		push_warning("TipsHost publish rejected: %s" % str(result.get("reason_code", "")))


func _load_policy_config() -> Dictionary:
	if not FileAccess.file_exists(POLICY_CFG_PATH):
		return {}
	var fp := FileAccess.open(POLICY_CFG_PATH, FileAccess.READ)
	if fp == null:
		return {}
	var txt := fp.get_as_text()
	var json := JSON.new()
	if json.parse(txt) != OK:
		return {}
	return json.data as Dictionary if json.data is Dictionary else {}
