extends RefCounted
class_name RewardTipBuilder

const TipIntentScript := preload("res://scripts/ui/tips/core/tip_intent.gd")

const LARGE_LING_STONE_THRESHOLD := 500
const RARE_QUALITY_THRESHOLD := 3


static func from_rewards(rewards: Array, source: String = "reward") -> Array:
	var out: Array = []
	for reward_v in rewards:
		if not reward_v is Dictionary:
			continue
		var reward := reward_v as Dictionary
		var kind := str(reward.get("kind", EnumRewardKind.LABEL_ITEM))
		match kind:
			EnumRewardKind.LABEL_CURRENCY:
				var currency_id := str(reward.get("id", "ling_stones"))
				var count := maxi(1, int(reward.get("count", 1)))
				out.append(resource(currency_label(currency_id), count, source, currency_id))
			EnumRewardKind.LABEL_EQUIP:
				var equip_id := int(reward.get("id", -1))
				var equip := _equip_by_id(equip_id)
				var name := str(equip.get("name", "法宝"))
				out.append(item(name, 1, source, 4, ""))
			_:
				var item_id := str(reward.get("id", ""))
				var def := _item_def_by_id(item_id)
				var count := maxi(1, int(reward.get("count", 1)))
				if def != null:
					out.append(item(def.name, count, source, def.quality, def.icon_path))
				else:
					out.append(item(item_id, count, source, 1, ""))
	return out


static func cultivation_result(result: Dictionary, source: String = "cultivation") -> Array:
	var out: Array = []
	var gained := int(result.get("cultivation_gained", result.get("added", 0)))
	if gained > 0:
		out.append(growth("修为", gained, source, "cultivation"))
	var mastery := int(result.get("mastery_gained", 0))
	if mastery > 0:
		var method_id := str(result.get("method_id", ""))
		var method_name := ""
		if method_id != "":
			var method_def := CultivationMethodService.by_id(method_id)
			method_name = str(method_def.get("name", method_id))
		if method_name.strip_edges() == "":
			method_name = "功法"
		var label := "%s熟练度" % method_name
		out.append(growth(label, mastery, source, "method_mastery"))
	for row_v in result.get("knowledge_gains", []) as Array:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		var xp := int(round(float(row.get("xp", 0.0))))
		if xp <= 0:
			continue
		var skill_id := str(row.get("skill_id", ""))
		var skill_name := ""
		if skill_id != "":
			var skill_def := DaoTreeService.skill_by_id(skill_id)
			skill_name = str(skill_def.get("name", skill_id))
		if skill_name.strip_edges() == "":
			skill_name = "知识"
		var label := "%s经验" % skill_name
		out.append(growth(label, xp, source, skill_id))
	var layer_advances := int(result.get("layer_advances", 0))
	if layer_advances > 0:
		var realm_name := str(result.get("realm_name", "新境界")).strip_edges()
		out.append(major_event("境界提升至%s" % realm_name, source, "realm_layer"))
	return out


static func alchemy_result(result: Dictionary, source: String = "alchemy") -> Array:
	var out: Array = []
	var xp := int(result.get("xp", 0))
	if xp > 0:
		out.append(growth("炼丹经验", xp, source, "alchemy_xp"))
	var mastery := int(result.get("mastery_gain", 0))
	if mastery > 0:
		out.append(growth("丹方经验", mastery, source, "alchemy_mastery"))
	var product_id := str(result.get("product_id", "")).strip_edges()
	var added := int(result.get("added", result.get("count", 0)))
	if product_id != "" and added > 0:
		out.append_array(from_rewards([{
			"kind": EnumRewardKind.LABEL_ITEM,
			"id": product_id,
			"count": added,
		}], source))
	return out


static func item(name: String, count: int, source: String, quality: int = 1, icon_path: String = "") -> Dictionary:
	var rare := quality >= RARE_QUALITY_THRESHOLD
	var text := "获得：%s x%d" % [name, maxi(1, count)]
	return TipIntentScript.make({
		"type": TipIntentScript.TYPE_TOAST,
		"text": text,
		"tone": TipIntentScript.TONE_GAIN,
		"channel": TipIntentScript.CHANNEL_REWARD_ITEM,
		"source": source,
		"priority": 80 if rare else 40,
		"ttl_ms": 2200 if rare else 1500,
		"dedupe_key": "reward.item.%s.%d.%s" % [name, count, source],
		"dedupe_window_ms": 350,
		"context": {
			"quality": quality,
			"icon_path": icon_path,
			"importance": "rare" if rare else "normal",
		},
	})


static func growth(label: String, amount: int, source: String, key: String = "") -> Dictionary:
	var safe_key := key if key.strip_edges() != "" else label
	return TipIntentScript.make({
		"type": TipIntentScript.TYPE_HINT,
		"text": "%s +%d" % [label, maxi(1, amount)],
		"tone": TipIntentScript.TONE_GAIN,
		"channel": TipIntentScript.CHANNEL_REWARD_GROWTH,
		"source": source,
		"priority": 20,
		"ttl_ms": 1400,
		"throttle_key": "reward.growth.%s" % safe_key,
		"throttle_ms": 120,
		"context": {
			"reward_group": "growth",
			"key": safe_key,
		},
	})


static func resource(label: String, amount: int, source: String, key: String = "") -> Dictionary:
	var large := amount >= LARGE_LING_STONE_THRESHOLD
	var channel := TipIntentScript.CHANNEL_REWARD_ITEM if large else TipIntentScript.CHANNEL_REWARD_RESOURCE
	return TipIntentScript.make({
		"type": TipIntentScript.TYPE_TOAST,
		"text": "%s +%d" % [label, maxi(1, amount)],
		"tone": TipIntentScript.TONE_GAIN,
		"channel": channel,
		"source": source,
		"priority": 60 if large else 30,
		"ttl_ms": 1900 if large else 1300,
		"throttle_key": "reward.resource.%s" % (key if key.strip_edges() != "" else label),
		"throttle_ms": 100,
		"context": {
			"reward_group": "resource",
			"resource_id": key,
			"importance": "large" if large else "normal",
			"icon_path": "res://assets/art/ui_new/lingshi.png" if key == "ling_stones" else "",
		},
	})


static func major_event(text: String, source: String, key: String = "") -> Dictionary:
	return TipIntentScript.make({
		"type": TipIntentScript.TYPE_TOAST,
		"text": text,
		"tone": TipIntentScript.TONE_GAIN,
		"channel": TipIntentScript.CHANNEL_REWARD_ITEM,
		"source": source,
		"priority": 100,
		"ttl_ms": 2400,
		"dedupe_key": "reward.major.%s.%s" % [source, key],
		"dedupe_window_ms": 600,
		"context": {
			"reward_group": "major_event",
			"importance": "major",
			"quality": 6,
		},
	})


static func currency_label(currency_id: String) -> String:
	match currency_id.strip_edges():
		"ling_stones":
			return "灵石"
		"contribution":
			return "贡献"
		"reputation":
			return "声望"
		"sect_merit":
			return "宗门功勋"
		_:
			return currency_id


static func _item_def_by_id(item_id: String) -> ItemDef:
	var cm := _config_manager()
	if cm == null or not cm.has_method("item_def_by_id"):
		return null
	return cm.call("item_def_by_id", item_id) as ItemDef


static func _equip_by_id(equip_id: int) -> Dictionary:
	var cm := _config_manager()
	if cm == null or not cm.has_method("equip_by_id"):
		return {}
	var found: Variant = cm.call("equip_by_id", equip_id)
	return found as Dictionary if found is Dictionary else {}


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")
