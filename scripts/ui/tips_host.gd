extends CanvasLayer

## 全局提示入口：接收 DataEvents 的 tip_intent 并交给 TipBus 策略化处理。

const TipIntentScript := preload("res://scripts/ui/tips/core/tip_intent.gd")
const TipMetricsScript := preload("res://scripts/ui/tips/core/tip_metrics.gd")
const TipPolicyEngineScript := preload("res://scripts/ui/tips/core/tip_policy_engine.gd")
const TipRouterScript := preload("res://scripts/ui/tips/core/tip_router.gd")
const TipBusScript := preload("res://scripts/ui/tips/core/tip_bus.gd")
const BarTipPresenterScript := preload("res://scripts/ui/tips/presenter/bar_tip_presenter.gd")
const ZhandouBlockPresenterScript := preload("res://scripts/ui/tips/presenter/zhandou_block_presenter.gd")
const RewardTipPresenterScript := preload("res://scripts/ui/tips/presenter/reward_tip_presenter.gd")
const TipBarScene := preload("res://scenes/ui/tip_bar.tscn")
const RewardTipLayerScene := preload("res://scenes/ui/reward_tip_layer.tscn")

var _metrics: TipMetrics
var _policy: TipPolicyEngine
var _router: TipRouter
var _bus: TipBus
var _data_events: Node
var _policy_snapshot: Dictionary = {}

@export var debug_print_metrics: bool = false


func _ready() -> void:
	follow_viewport_enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind_dependencies(data_events: Node, policy_snapshot: Dictionary) -> void:
	if data_events == null or policy_snapshot.is_empty():
		push_error("TipsHost: DataEvents 或提示策略未绑定")
		return
	if _data_events != null:
		if _data_events == data_events and _policy_snapshot == policy_snapshot:
			return
		push_error("TipsHost: 禁止更换已绑定的依赖")
		return
	_data_events = data_events
	_policy_snapshot = policy_snapshot.duplicate(true)
	_setup_tip_runtime(_policy_snapshot)
	if not data_events.tip_intent.is_connected(_on_tip_intent):
		data_events.tip_intent.connect(_on_tip_intent)
	if not data_events.tip_intents.is_connected(_on_tip_intents):
		data_events.tip_intents.connect(_on_tip_intents)


func _on_tip_intent(intent: Dictionary) -> void:
	_publish_intent(intent)


func _on_tip_intents(intents: Array) -> void:
	if _bus == null:
		return
	_bus.publish_many(intents)


func _setup_tip_runtime(policy_snapshot: Dictionary) -> void:
	_metrics = TipMetricsScript.new()
	_policy = TipPolicyEngineScript.new()
	_router = TipRouterScript.new()
	_bus = TipBusScript.new()
	_policy.setup(policy_snapshot)
	var bar_root := TipBarScene.instantiate() as Control
	add_child(bar_root)
	var bar_presenter := BarTipPresenterScript.new()
	bar_presenter.setup(bar_root)
	_router.register_presenter(TipIntentScript.CHANNEL_BAR, bar_presenter)
	_router.register_presenter(TipIntentScript.CHANNEL_COMBAT_BLOCK, ZhandouBlockPresenterScript.new())
	var reward_root := RewardTipLayerScene.instantiate() as Control
	add_child(reward_root)
	var reward_presenter := RewardTipPresenterScript.new()
	reward_presenter.setup(reward_root)
	_router.register_presenter(TipIntentScript.CHANNEL_REWARD_ITEM, reward_presenter)
	_router.register_presenter(TipIntentScript.CHANNEL_REWARD_GROWTH, reward_presenter)
	_router.register_presenter(TipIntentScript.CHANNEL_REWARD_RESOURCE, reward_presenter)
	_bus.setup(_policy, _router, _metrics)


func _publish_intent(intent: Dictionary) -> void:
	if _bus == null:
		return
	var result := _bus.publish(intent)
	if debug_print_metrics and not bool(result.get("ok", false)):
		push_warning("TipsHost publish rejected: %s" % str(result.get("reason_code", "")))
