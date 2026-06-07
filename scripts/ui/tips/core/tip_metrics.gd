extends RefCounted
class_name TipMetrics

var _counters: Dictionary = {}


func inc(metric: String, amount: int = 1) -> void:
	if metric == "":
		return
	_counters[metric] = int(_counters.get(metric, 0)) + maxi(1, amount)


func inc_reason(prefix: String, reason_code: String) -> void:
	var key := "%s.%s" % [prefix, reason_code if reason_code != "" else "unknown"]
	inc(key)


func snapshot() -> Dictionary:
	return _counters.duplicate(true)


func reset() -> void:
	_counters.clear()
