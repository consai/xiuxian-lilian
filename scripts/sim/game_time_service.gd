class_name GameTimeService
extends RefCounted

## 时间规则：扁平键 `分组:字段`，见 [code]res://data/exportjson/yunxing_params/shijian_rules.json[/code]。

const DATA_PATH := "res://data/exportjson/yunxing_params/shijian_rules.json"


static func calendar() -> Dictionary:
	return {
		"days_per_month": days_per_month(),
		"months_per_year": months_per_year(),
		"days_per_year": days_per_year(),
	}


static func days_per_month() -> int:
	return maxi(1, int(_setting("calendar:days_per_month", 30)))


static func months_per_year() -> int:
	return maxi(1, int(_setting("calendar:months_per_year", 12)))


static func days_per_year() -> int:
	return maxi(1, int(_setting("calendar:days_per_year", days_per_month() * months_per_year())))


static func realm_multiplier(major_realm_id: String) -> float:
	var key := "major_realm_multipliers:%s" % major_realm_id.strip_edges()
	return maxf(0.01, float(_setting(key, 1.0)))


static func activity_base_days(activity_id: String) -> int:
	var key := activity_id.strip_edges()
	# ponytail: 旧存档/配置仍可能用 alchemy、breakthrough 键
	if key == "alchemy":
		key = "liandan"
	elif key == "breakthrough":
		key = "tupo"
	return maxi(1, int(_setting("activity_base_days:%s" % key, 1)))


static func suggested_activity_days(
	activity_id: String,
	major_realm_id: String,
	rank_multiplier: float = 1.0,
	aptitude_multiplier: float = 1.0
) -> int:
	return days_for_activity(
		activity_id,
		major_realm_id,
		rank_multiplier,
		aptitude_multiplier
	)


static func days_for_activity(
	activity_id: String,
	major_realm_id: String = "",
	rank_multiplier: float = 1.0,
	aptitude_multiplier: float = 1.0,
	apply_realm_multiplier: bool = true
) -> int:
	var configured_days := activity_base_days(activity_id)
	var realm_scale := realm_multiplier(major_realm_id) if apply_realm_multiplier else 1.0
	var days := float(configured_days) * realm_scale * maxf(0.01, rank_multiplier) * maxf(0.01, aptitude_multiplier)
	return maxi(1, int(ceil(days)))


static func day_parts(day: int) -> Dictionary:
	var safe_day := maxi(1, day)
	var zero_based := safe_day - 1
	var year := zero_based / days_per_year() + 1
	var day_in_year := zero_based % days_per_year()
	var month := day_in_year / days_per_month() + 1
	var month_day := day_in_year % days_per_month() + 1
	return {
		"year": year,
		"month": month,
		"day": month_day,
	}


static func date_label(day: int) -> String:
	var parts := day_parts(day)
	return "第%d年%d月%d日" % [
		int(parts.get("year", 1)),
		int(parts.get("month", 1)),
		int(parts.get("day", 1)),
	]


static func duration_label(days: int) -> String:
	var remaining := maxi(0, days)
	var years := remaining / days_per_year()
	remaining %= days_per_year()
	var months := remaining / days_per_month()
	remaining %= days_per_month()
	var parts: PackedStringArray = []
	if years > 0:
		parts.append("%d年" % years)
	if months > 0:
		parts.append("%d月" % months)
	if remaining > 0 or parts.is_empty():
		parts.append("%d日" % remaining)
	return "".join(parts)


## 读取扁平配置项；缺省时返回 [param default_value]。
static func _setting(key: String, default_value: Variant) -> Variant:
	return _root().get(key, default_value)


static func _root() -> Dictionary:
	return JsonLoader.load_shijian_rules_bundle()
