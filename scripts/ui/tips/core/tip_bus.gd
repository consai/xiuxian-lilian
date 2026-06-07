extends RefCounted
class_name TipBus

var policy: TipPolicyEngine
var router: TipRouter
var metrics: TipMetrics


func setup(in_policy: TipPolicyEngine, in_router: TipRouter, in_metrics: TipMetrics) -> void:
	policy = in_policy
	router = in_router
	metrics = in_metrics


func publish(intent_like: Dictionary) -> Dictionary:
	if policy == null or router == null or metrics == null:
		return {"ok": false, "reason_code": "not_initialized"}
	var intent := TipIntent.safe(intent_like)
	metrics.inc("received")
	var decision := policy.decide(intent)
	if not bool(decision.get("accepted", false)):
		var reason_code := str(decision.get("reason_code", "rejected"))
		metrics.inc("rejected")
		metrics.inc_reason("rejected_reason", reason_code)
		return {"ok": false, "reason_code": reason_code}

	policy.on_tip_started(intent)
	metrics.inc("accepted")
	metrics.inc_reason("routed_channel", str(intent.get("channel", TipIntent.CHANNEL_BAR)))
	var routed := router.route(intent)
	if not bool(routed.get("ok", false)):
		var route_reason := str(routed.get("reason_code", "route_failed"))
		metrics.inc("presenter_failed")
		metrics.inc_reason("presenter_failed_reason", route_reason)
		policy.on_tip_finished(intent)
		return {"ok": false, "reason_code": route_reason}

	if bool(routed.get("async_finish", false)):
		return {"ok": true}
	policy.on_tip_finished(intent)
	return {"ok": true}


func notify_present_finished(intent: Dictionary) -> void:
	if policy == null:
		return
	policy.on_tip_finished(intent)


func publish_many(intents: Array) -> Dictionary:
	var accepted := 0
	var rejected := 0
	for v in intents:
		if not v is Dictionary:
			rejected += 1
			continue
		var res := publish(v as Dictionary)
		if bool(res.get("ok", false)):
			accepted += 1
		else:
			rejected += 1
	return {"ok": true, "accepted": accepted, "rejected": rejected}
