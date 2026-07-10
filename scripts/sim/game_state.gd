extends Node

const SIM_PATH := "res://data/exportjson/yunxing_params/moni.json"
const HUB_SCENE := "res://scenes/sim/dongfu.tscn"

const INSTABILITY_REDUCTION_PER_WIN := 10
const PASSIVE_METHOD_PRACTICE_RATIO := 0.25


var day: int:
	get: return int(DataStore.savedata.get("day", 1))
	set(value): DataStore.savedata["day"] = value
var realm_index: int:
	get: return int(DataStore.savedata.get("realm_index", 0))
	set(value): DataStore.savedata["realm_index"] = value
var realm_name: String:
	get: return str(DataStore.savedata.get("realm_name", ""))
	set(value): DataStore.savedata["realm_name"] = value
var cultivation: int:
	get: return int(DataStore.savedata.get("cultivation", 0))
	set(value): DataStore.savedata["cultivation"] = value
var cultivation_instability: int:
	get: return int(DataStore.savedata.get("cultivation_instability", 0))
	set(value): DataStore.savedata["cultivation_instability"] = maxi(0, value)
var breakthrough_at: int:
	get: return int(DataStore.savedata.get("breakthrough_at", 100))
	set(value): DataStore.savedata["breakthrough_at"] = value
var injury_days: int:
	get: return int(DataStore.savedata.get("injury_days", 0))
	set(value): DataStore.savedata["injury_days"] = value
var ling_stones: int:
	get: return int(DataStore.savedata.get("ling_stones", 0))
	set(value): DataStore.savedata["ling_stones"] = value
var player_name: String:
	get: return str(DataStore.savedata.get("player_name", ""))
	set(value): DataStore.savedata["player_name"] = value
var player_icon: String:
	get: return str(DataStore.savedata.get("player_icon", ""))
	set(value): DataStore.savedata["player_icon"] = value
var foundations: Dictionary:
	get: return DataStore.savedata.get("foundations", CharacterStats.default_foundations()) as Dictionary
	set(value): DataStore.savedata["foundations"] = CharacterStats.normalize_foundations(value)
var aptitudes: Dictionary:
	get: return DataStore.savedata.get("aptitudes", CharacterStats.default_aptitudes()) as Dictionary
	set(value): DataStore.savedata["aptitudes"] = CharacterStats.normalize_aptitudes(value)
var attrs: Dictionary:
	get: return DataStore.savedata.get("attrs", {}) as Dictionary
	set(value): DataStore.savedata["attrs"] = value
var hp: float:
	get: return float(DataStore.savedata.get("hp", 100.0))
	set(value): DataStore.savedata["hp"] = value
var mp: float:
	get: return float(DataStore.savedata.get("mp", 100.0))
	set(value): DataStore.savedata["mp"] = value
var knowledge: Dictionary:
	get: return DataStore.savedata.get("knowledge", {}) as Dictionary
	set(value): DataStore.savedata["knowledge"] = value
var unlocked_abilities: Array:
	get: return DataStore.savedata.get("unlocked_abilities", []) as Array
	set(value): DataStore.savedata["unlocked_abilities"] = value
var equipped_abilities: Array:
	get: return DataStore.savedata.get("equipped_abilities", []) as Array
	set(value): DataStore.savedata["equipped_abilities"] = value
var unlocked_methods: Array:
	get: return DataStore.savedata.get("unlocked_methods", ["method.hunyuan.1"]) as Array
	set(value): DataStore.savedata["unlocked_methods"] = value
var cultivation_method_slots: Dictionary:
	get: return DataStore.savedata.get("cultivation_method_slots", {}) as Dictionary
	set(value): DataStore.savedata["cultivation_method_slots"] = value
var current_cultivation_method_id: String:
	get: return str(DataStore.savedata.get("current_cultivation_method_id", ""))
	set(value): DataStore.savedata["current_cultivation_method_id"] = value
var auto_battle_enabled: bool:
	get: return bool(DataStore.savedata.get("auto_battle_enabled", false))
	set(value): DataStore.savedata["auto_battle_enabled"] = value
var auto_battle_preset: String:
	get: return str(DataStore.savedata.get("auto_battle_preset", "balanced"))
	set(value): DataStore.savedata["auto_battle_preset"] = value
var auto_battle_rules: Dictionary:
	get: return DataStore.savedata.get("auto_battle_rules", {}) as Dictionary
	set(value): DataStore.savedata["auto_battle_rules"] = value
var owned_equips: Array:
	get: return DataStore.savedata.get("owned_equips", []) as Array
	set(value): DataStore.savedata["owned_equips"] = value
var equip_slots: Array:
	get: return DataStore.savedata.get("equip_slots", [-1, -1, -1]) as Array
	set(value): DataStore.savedata["equip_slots"] = value
var treasure_item_slots: Array:
	get: return DataStore.savedata.get("treasure_item_slots", ["", "", ""]) as Array
	set(value): DataStore.savedata["treasure_item_slots"] = value
var item_slots: Array:
	get: return DataStore.savedata.get("item_slots", ["", "", ""]) as Array
	set(value): DataStore.savedata["item_slots"] = value
var inventory: Dictionary:
	get: return DataStore.savedata.get("inventory", {}) as Dictionary
	set(value): DataStore.savedata["inventory"] = value
var liandan: Dictionary:
	get: return DataStore.savedata.get("liandan", DataStore.savedata.get("alchemy", LiandanService.default_state())) as Dictionary
	set(value): DataStore.savedata["liandan"] = LiandanService.normalize_state(value)
var storage: Dictionary:
	get: return DataStore.savedata.get("storage", {}) as Dictionary
	set(value): DataStore.savedata["storage"] = value
var storage_equips: Array:
	get: return DataStore.savedata.get("storage_equips", []) as Array
	set(value): DataStore.savedata["storage_equips"] = value
var activity_log: Array:
	get: return DataStore.savedata.get("activity_log", []) as Array
	set(value): DataStore.savedata["activity_log"] = value
var totals: Dictionary:
	get: return DataStore.savedata.get("totals", {}) as Dictionary
	set(value): DataStore.savedata["totals"] = value
var last_rewards: Array:
	get: return DataStore.game_runtime().get("last_rewards", []) as Array
	set(value): DataStore.game_runtime()["last_rewards"] = value
var last_lilian_summary: Dictionary:
	get: return DataStore.game_runtime().get("last_lilian_summary", {}) as Dictionary
	set(value): DataStore.game_runtime()["last_lilian_summary"] = value
var last_settled_lilian_id: String:
	get: return str(DataStore.game_runtime().get("last_settled_lilian_id", ""))
	set(value): DataStore.game_runtime()["last_settled_lilian_id"] = value
var active_save_slot: int:
	get: return int(DataStore.game_runtime().get("active_save_slot", 0))
	set(value): DataStore.game_runtime()["active_save_slot"] = value
var current_city_id: String:
	get: return str(DataStore.map_savedata().get("current_city_id", ""))
	set(value): _map_savedata()["current_city_id"] = value
var map_discovered_cities: Array:
	get: return DataStore.map_savedata().get("discovered_cities", []) as Array
	set(value): _map_savedata()["discovered_cities"] = value
var map_discovered_regions: Array:
	get: return DataStore.map_savedata().get("discovered_regions", []) as Array
	set(value): _map_savedata()["discovered_regions"] = value
var map_discovered_locations: Array:
	get: return DataStore.map_savedata().get("discovered_locations", []) as Array
	set(value): _map_savedata()["discovered_locations"] = value


func _ready() -> void:
	_bootstrap_savedata()


func _bootstrap_savedata() -> void:
	# 主界面负责新局与读档，启动时不自动加载存档。
	pass


func new_game(profile: Dictionary = {}) -> void:
	DataStore.reset_all()
	DataStore.start_tutorial()
	var root := JsonLoader.load_moni_bundle()
	var initial := root.get("initial_player", {}) as Dictionary
	day = 1
	realm_index = 0
	cultivation = 0
	cultivation_instability = 0
	injury_days = 0
	ling_stones = 0
	player_name = str(initial.get("name", "修士"))
	player_icon = str(initial.get("icon", ""))
	# 新表使用 attrs/linggen；保留旧键以兼容尚未重新导出的配置。
	foundations = initial.get("attrs", initial.get("foundations", CharacterStats.default_foundations())) as Dictionary
	aptitudes = initial.get("linggen", initial.get("aptitudes", CharacterStats.default_aptitudes())) as Dictionary
	refresh_derived_attrs(false)
	hp = float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0))
	mp = float(attrs.get(EnumPlayerAttr.MP_MAX, 100.0))
	unlocked_abilities = _initial_ability_ids(initial)
	equipped_abilities = _initial_equipped_abilities(initial, unlocked_abilities)
	unlocked_methods = _initial_method_ids(initial)
	var default_method := str(unlocked_methods[0]) if not unlocked_methods.is_empty() else "method.hunyuan.1"
	cultivation_method_slots = (initial.get("method_slots", {
		"main": default_method, "support_1": "", "support_2": "", "support_3": "",
	}) as Dictionary).duplicate(true)
	current_cultivation_method_id = str(cultivation_method_slots.get("main", default_method))
	_seed_starter_knowledge()
	auto_battle_enabled = false
	auto_battle_preset = "balanced"
	auto_battle_rules = {}
	owned_equips = (initial.get("equips", []) as Array).duplicate(true)
	equip_slots = (initial.get("equip_slots", [-1, -1, -1]) as Array).duplicate(true)
	treasure_item_slots = (initial.get("treasure_item_slots", ["", "", ""]) as Array).duplicate(true)
	item_slots = (initial.get("item_slots", ["", "", ""]) as Array).duplicate(true)
	inventory = (initial.get("items", initial.get("inventory", {})) as Dictionary).duplicate(true)
	liandan = LiandanService.default_state()
	storage = (initial.get("storage", {}) as Dictionary).duplicate(true)
	storage_equips = (initial.get("storage_equips", []) as Array).duplicate(true)
	activity_log = []
	totals = {
		"battles": 0, "wins": 0, "losses": 0, "items_gained": 0,
		"lilian_count": 0, "lilian_steps": 0, "max_difficulty": 0,
	}
	last_rewards = []
	last_lilian_summary = {}
	last_settled_lilian_id = ""
	active_save_slot = 0
	DataStore.savedata = DataStore.coalesce_savedata(DataStore.savedata)
	_apply_character_profile(profile)
	if LilianState != null and LilianState.has_method("reset"):
		LilianState.reset()
	_initialize_map_state()
	_sync_realm()


func _apply_character_profile(profile: Dictionary) -> void:
	if profile.is_empty():
		return
	var name := str(profile.get("player_name", "")).strip_edges()
	if name != "":
		player_name = name
	DataStore.savedata["character_origin_id"] = str(profile.get("origin_id", ""))
	DataStore.savedata["character_root_id"] = str(profile.get("root_id", ""))
	DataStore.savedata["character_talent_id"] = str(profile.get("talent_id", ""))
	var root_id := str(profile.get("root_id", "")).strip_edges()
	if root_id != "":
		var next_aptitudes := aptitudes.duplicate(true)
		next_aptitudes[EnumPlayerAttr.ROOTS] = {root_id: 80.0}
		aptitudes = next_aptitudes
		refresh_derived_attrs(false)
		hp = float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0))
		mp = float(attrs.get(EnumPlayerAttr.MP_MAX, 100.0))


func _initial_ability_ids(initial: Dictionary) -> Array:
	var out: Array = []
	for aid_v in initial.get("jineng", initial.get("abilities", ["factive_lq_001"])) as Array:
		var aid := str(aid_v).strip_edges()
		if aid != "" and not out.has(aid):
			out.append(aid)
	return out


func _initial_method_ids(initial: Dictionary) -> Array:
	var out: Array = []
	for method_id_v in initial.get("gongfa", initial.get("methods", ["method.hunyuan.1"])) as Array:
		var method_id := str(method_id_v).strip_edges()
		if method_id != "":
			out.append(method_id)
	return out


func _initial_equipped_abilities(initial: Dictionary, unlocked: Array) -> Array:
	var raw_v: Variant = initial.get("jineng_use", initial.get("equipped_abilities", []))
	if raw_v is Array and not (raw_v as Array).is_empty():
		return DataStore._normalize_ability_slots(raw_v)
	var slots: Array = ["", "", "", "", ""]
	for i in unlocked.size():
		if i >= 5:
			break
		slots[i] = str(unlocked[i])
	return DataStore._normalize_ability_slots(slots)


func _seed_starter_knowledge() -> void:
	KnowledgeService.grant_level(DataStore.savedata, "zhuji.breathing", 1)


func can_persist() -> bool:
	return LilianState == null or not LilianState.active


func save_game(slot: int) -> Dictionary:
	if slot == SaveService.AUTO_SAVE_SLOT:
		return {"ok": false, "error": "槽位 1 为自动存档，无法手动存入"}
	return _persist_slot(slot)


func auto_save() -> Dictionary:
	var result := _persist_slot(SaveService.AUTO_SAVE_SLOT)
	if bool(result.get("ok", false)):
		DataEvents.emit_tip_intent({
			"type": EnumTipIntentType.LABEL_TOAST,
			"text": "自动存档成功",
			"tone": EnumTipTone.LABEL_GAIN,
			"channel": EnumTipChannel.LABEL_BAR,
			"source": "auto_save",
			"ttl_ms": 2200,
			"dedupe_key": "auto_save_success",
			"dedupe_window_ms": 800,
		})
	return result


func _persist_slot(slot: int) -> Dictionary:
	if not can_persist():
		return {"ok": false, "error": "历练中无法存档，请先完成或结算"}
	var result: Dictionary = SaveService.save_slot(slot, to_dict())
	if bool(result.get("ok", false)):
		active_save_slot = slot
	return result


func load_game(slot: int) -> Dictionary:
	if not can_persist():
		return {"ok": false, "error": "历练中无法读档，请先完成或结算"}
	var loaded: Dictionary = SaveService.load_slot(slot)
	if not bool(loaded.get("ok", false)):
		return loaded
	if not apply_dict(loaded.get("game", {}) as Dictionary):
		return {"ok": false, "error": "存档数据无效"}
	active_save_slot = slot
	return {"ok": true, "slot": slot}


func cultivate() -> int:
	var result := cultivate_session(
		EnumXiulianMode.LABEL_CYCLE,
		min_cultivation_days()
	)
	return int(result.get("cultivation_gained", 0))


func time_date_label(target_day: int) -> String:
	return GameTimeService.date_label(target_day)


func time_duration_label(days_value: int) -> String:
	return GameTimeService.duration_label(days_value)


func liandan_recipes() -> Array:
	return LiandanService.all_recipes()


func liandan_strategies() -> Array:
	return LiandanService.all_strategies()


func preview_liandan(recipe_id: String, strategy_id: String = "steady", selection_mode: String = "lowest") -> Dictionary:
	return LiandanService.preview(
		recipe_id,
		strategy_id,
		selection_mode,
		liandan,
		inventory,
		foundations,
		aptitudes,
		major_realm_id()
	)


func max_liandan_batch_count(preview: Dictionary) -> int:
	return LiandanService.max_batch_count(preview, inventory, liandan)


func brew_liandan(
	recipe_id: String,
	strategy_id: String = "steady",
	selection_mode: String = "lowest",
	seed_override: int = -1
) -> Dictionary:
	return brew_liandan_batches(recipe_id, strategy_id, selection_mode, 1, seed_override)


func brew_liandan_batches(
	recipe_id: String,
	strategy_id: String = "steady",
	selection_mode: String = "lowest",
	batch_count: int = 1,
	seed_override: int = -1
) -> Dictionary:
	if not can_persist():
		return {"ok": false, "error": "历练中无法炼丹"}
	batch_count = maxi(1, batch_count)
	var initial_preview := preview_liandan(recipe_id, strategy_id, selection_mode)
	if not bool(initial_preview.get("ok", false)):
		return initial_preview
	var max_allowed := max_liandan_batch_count(initial_preview)
	if batch_count > max_allowed:
		return {"ok": false, "error": "药材或丹炉不足以连炼 %d 炉" % batch_count}
	var rng := RandomNumberGenerator.new()
	if seed_override >= 0:
		rng.seed = seed_override
	else:
		rng.randomize()
	var results: Array = []
	for _index in batch_count:
		var preview := preview_liandan(recipe_id, strategy_id, selection_mode)
		if not bool(preview.get("ok", false)):
			break
		var rolled := LiandanService.roll(preview, rng)
		if not bool(rolled.get("ok", false)):
			return rolled
		var applied := _apply_liandan_brew_result(recipe_id, strategy_id, rolled, batch_count > 1)
		results.append(applied)
	if results.is_empty():
		return {"ok": false, "error": "炼制失败"}
	var result: Dictionary
	if results.size() == 1:
		result = results[0] as Dictionary
	else:
		result = LiandanService.aggregate_batch_results(results)
		result["recipe_mastery"] = LiandanService.mastery_for(liandan, recipe_id)
		result["liandan_level"] = int(liandan.get("level", 1))
		result["liandan_xp"] = int(liandan.get("xp", 0))
		var furnace_id := str(liandan.get("equipped_furnace", ""))
		var owned := liandan.get("owned_furnaces", {}) as Dictionary
		var furnace_state := owned.get(furnace_id, {}) as Dictionary
		result["furnace_durability"] = int(furnace_state.get("durability", 0))
		_append_activity("连炼%d炉%s：%s" % [
			results.size(),
			str(result.get("pill_name", "丹药")),
			str(result.get("quality_summary", "")),
		])
	_emit_tip_intents(RewardTipBuilder.liandan_result(result, "liandan"))
	auto_save()
	return result


func _apply_liandan_brew_result(
	recipe_id: String,
	strategy_id: String,
	result: Dictionary,
	defer_activity_log: bool = false
) -> Dictionary:
	for ingredient_v in result.get("ingredients", []) as Array:
		var ingredient := ingredient_v as Dictionary
		InventoryService.remove_item(
			inventory,
			str(ingredient.get("id", "")),
			int(ingredient.get("count", 0))
		)
	var product_id := str(result.get("product_id", ""))
	if product_id != "":
		result["added"] = InventoryService.add_item(inventory, product_id, int(result.get("count", 0)))
	else:
		result["added"] = 0
	var next_liandan := LiandanService.apply_xp(liandan, int(result.get("xp", 0)))
	next_liandan = LiandanService.apply_recipe_mastery(
		next_liandan,
		recipe_id,
		int(result.get("mastery_gain", 0))
	)
	var furnace_id := str(next_liandan.get("equipped_furnace", ""))
	var owned := next_liandan.get("owned_furnaces", {}) as Dictionary
	var furnace_state_v: Variant = owned.get(furnace_id, {})
	var furnace_state := furnace_state_v as Dictionary if furnace_state_v is Dictionary else {}
	furnace_state["durability"] = maxi(0, int(furnace_state.get("durability", 0)) - 1)
	owned[furnace_id] = furnace_state
	next_liandan["owned_furnaces"] = owned
	next_liandan["last_recipe"] = recipe_id
	next_liandan["last_strategy"] = strategy_id
	next_liandan["total_batches"] = int(next_liandan.get("total_batches", 0)) + 1
	liandan = next_liandan
	var elapsed := int(result.get("days", 1))
	_advance_time(elapsed, true, true)
	if not defer_activity_log:
		var outcome := str(result.get("quality_name", "无产物"))
		var log_text := "炼制%s：%s" % [str(result.get("pill_name", "丹药")), outcome]
		if int(result.get("added", 0)) > 0:
			log_text += " x%d" % int(result.get("added", 0))
		_append_activity(log_text)
	result["liandan_level"] = int(liandan.get("level", 1))
	result["liandan_xp"] = int(liandan.get("xp", 0))
	result["recipe_mastery"] = LiandanService.mastery_for(liandan, recipe_id)
	result["furnace_durability"] = int(furnace_state.get("durability", 0))
	return result


const CULTIVATION_MAX_YEARS := 1


## 单次闭关最短天数（1 个游戏月）。
func min_cultivation_days() -> int:
	return GameTimeService.days_per_month()


func max_cultivation_days_cap() -> int:
	return CULTIVATION_MAX_YEARS * GameTimeService.days_per_year()


func max_cultivation_days(
	mode_id: String = EnumXiulianMode.LABEL_CYCLE,
	pill_id: String = ""
) -> int:
	var cap := max_cultivation_days_cap()
	if EnumXiulianMode.is_pill_mode(mode_id):
		var resolved_pill_id := resolve_cultivation_pill_id(pill_id)
		if resolved_pill_id == "":
			return min_cultivation_days()
		return mini(cap, maxi(min_cultivation_days(), int(inventory.get(resolved_pill_id, 0)) * GameTimeService.days_per_month()))
	return cap


func max_knowledge_study_days(skill_id: String = "") -> int:
	var sid := skill_id.strip_edges()
	var rank := 1.0
	if sid != "":
		var skill := DaoTreeService.skill_by_id(sid)
		rank = maxf(1.0, float(skill.get("rank", 1)))
	var suggested := GameTimeService.suggested_activity_days(
		EnumActivityTime.LABEL_SELF_STUDY,
		major_realm_id(),
		rank
	)
	if sid == "":
		return suggested
	var gate := KnowledgeStudyService.can_study(DataStore.savedata, sid, major_realm_id())
	if not bool(gate.get("ok", false)):
		return suggested
	var entry := KnowledgeService.get_entry(DataStore.savedata, sid)
	var current_level := int(entry.get("level", 0))
	var policy := gate.get("policy", {}) as Dictionary
	var skill := DaoTreeService.skill_by_id(sid)
	var target_level := mini(current_level + 1, int(skill.get("maxLevel", 5)))
	if target_level <= current_level:
		return suggested
	var speed := DaoTreeService.training_speed(sid, foundations, aptitudes)
	var required := DaoTreeService.required_xp_for_level(sid, target_level)
	var remaining := maxf(0.0, required - float(entry.get("xp", 0.0)))
	var days_to_next := int(ceil(remaining / maxf(0.01, speed * float(policy.get("efficiency", 1.0)))))
	return maxi(suggested, days_to_next)


func studyable_knowledge() -> Array:
	return KnowledgeStudyService.studyable_skills(DataStore.savedata, major_realm_id())


func preview_knowledge_study(skill_id: String, days: int = 1) -> Dictionary:
	var safe_days := clampi(days, 1, max_knowledge_study_days(skill_id))
	var preview := KnowledgeStudyService.preview(
		DataStore.savedata,
		skill_id,
		safe_days,
		major_realm_id()
	)
	if bool(preview.get("ok", false)):
		preview["duration_label"] = GameTimeService.duration_label(safe_days)
		preview["start_day"] = day
		preview["end_day"] = day + safe_days
		preview["start_date_label"] = GameTimeService.date_label(day)
		preview["end_date_label"] = GameTimeService.date_label(day + safe_days)
	return preview


func study_knowledge(skill_id: String, days: int = 1) -> Dictionary:
	if not can_persist():
		return {"ok": false, "error": "历练中无法自主研读"}
	var preview := preview_knowledge_study(skill_id, days)
	if not bool(preview.get("ok", false)):
		return preview
	var safe_days := int(preview.get("days", 1))
	var result := KnowledgeStudyService.apply_study(
		DataStore.savedata,
		skill_id,
		safe_days,
		major_realm_id()
	)
	if not bool(result.get("ok", false)):
		return result
	_advance_time(safe_days, true, true)
	var skill_name := str(result.get("skill_name", skill_id))
	var log_text := "自主研读%s：%s训练点 +%.1f" % [
		GameTimeService.duration_label(safe_days),
		skill_name,
		float(result.get("xp", 0.0)),
	]
	if int(result.get("levels_gained", 0)) > 0:
		log_text += "，提升至%s级" % _roman_knowledge_level(int(result.get("level_after", 0)))
	_append_activity(log_text)
	result["days"] = safe_days
	result["duration_label"] = GameTimeService.duration_label(safe_days)
	result["start_day"] = int(preview.get("start_day", day - safe_days))
	result["end_day"] = day
	result["start_date_label"] = str(preview.get("start_date_label", GameTimeService.date_label(day - safe_days)))
	result["end_date_label"] = GameTimeService.date_label(day)
	return result


func preview_cultivation_session(mode_id: String = EnumXiulianMode.LABEL_CYCLE, days: int = 1, pill_id: String = "") -> Dictionary:
	var mode := _cultivation_mode(mode_id)
	var safe_days := clampi(
		maxi(1, days),
		min_cultivation_days(),
		max_cultivation_days(mode_id, pill_id)
	)
	var resolved_pill_id := ""
	var pill_ids: Array = []
	if EnumXiulianMode.is_pill_mode(mode_id):
		resolved_pill_id = resolve_cultivation_pill_id(pill_id)
		if resolved_pill_id == "":
			return {
				"ok": false,
				"error": "背包中没有可用于修炼的丹药。",
			}
		var owned_pills := int(inventory.get(resolved_pill_id, 0))
		var required_pills := _cultivation_pill_count(safe_days)
		if owned_pills < required_pills:
			return {
				"ok": false,
				"error": "丹药炼化每月需要一枚%s，当前仅有 %d 枚。" % [
					ConfigManager.get_item_display_name(resolved_pill_id),
					owned_pills,
				],
			}
		for _pill_index in required_pills:
			pill_ids.append(resolved_pill_id)
	var method_id := XiulianMethodService.active_cultivation_method_id(DataStore.savedata)
	var method := XiulianMethodService.by_id(method_id)
	var base_gain := RealmBalanceService.base_daily_cultivation_gain(_realm_row(realm_index))
	var speed := XiulianMethodService.cultivation_session_speed(method_id, DataStore.savedata)
	if speed <= 0.0:
		return {"ok": false, "error": "需要先选择当前修炼功法"}
	var method_breakdown := XiulianMethodService.base_cultivation_gain_breakdown(method_id)
	var method_base_gain := int(method_breakdown.get("gain", 0))
	var estimated_gain := 0
	var remaining_injury := injury_days
	var daily_gains: Array = []
	var first_day_formula: Dictionary = {}
	for _day_index in safe_days:
		var speed_part := 0
		var pill_gain := 0
		if EnumXiulianMode.is_pill_mode(mode_id):
			# 丹药炼化：每月消耗一颗丹药，药力在当月闭关期间持续生效。
			pill_gain = cultivation_pill_daily_gain(str(pill_ids[int(_day_index / GameTimeService.days_per_month())]))
			speed_part = pill_gain
		else:
			var multiplier := float(mode["cultivation_multiplier"])
			speed_part = int(round(float(base_gain) * speed * multiplier))
		var raw_gain := speed_part + method_base_gain
		var injury_multiplier := 0.5 if remaining_injury > 0 else 1.0
		var day_gain := maxi(1, int(round(float(raw_gain) * injury_multiplier)))
		estimated_gain += day_gain
		daily_gains.append(day_gain)
		if first_day_formula.is_empty():
			first_day_formula = {
				"player_base": base_gain,
				"speed": speed,
				"mode_name": str(mode.get("name", "运转周天")),
				"is_pill_mode": EnumXiulianMode.is_pill_mode(mode_id),
				"pill_gain": pill_gain,
				"speed_part": speed_part,
				"method_realm_base": int(method_breakdown.get("realm_base", 0)),
				"method_quality": int(method_breakdown.get("quality", 1)),
				"method_coefficient": float(method_breakdown.get("coefficient", 1.0)),
				"method_base_gain": method_base_gain,
				"raw_gain": raw_gain,
				"injury_multiplier": injury_multiplier,
				"daily_total": day_gain,
			}
		remaining_injury = maxi(0, remaining_injury - 1)
	first_day_formula["days"] = safe_days
	first_day_formula["daily_gains"] = daily_gains
	first_day_formula["pill_count"] = pill_ids.size()
	var recommended_days := max_cultivation_days(mode_id, resolved_pill_id)
	return {
		"ok": true,
		"mode_id": mode_id,
		"mode": mode.duplicate(true),
		"days": safe_days,
		"duration_label": GameTimeService.duration_label(safe_days),
		"recommended_days": recommended_days,
		"recommended_duration_label": GameTimeService.duration_label(recommended_days),
		"estimated_cultivation": estimated_gain,
		"start_day": day,
		"end_day": day + safe_days,
		"start_date_label": GameTimeService.date_label(day),
		"end_date_label": GameTimeService.date_label(day + safe_days),
		"method_id": method_id,
		"method_name": str(method.get("name", "未选择修炼功法")),
		"method_mastery": XiulianMethodService.method_mastery(DataStore.savedata, method_id),
		"base_daily_gain": base_gain,
		"cultivation_speed": speed,
		"method_base_gain": method_base_gain,
		"cultivation_formula": first_day_formula,
		"pill_ids": pill_ids,
		"pill_count": pill_ids.size(),
		"pill_id": resolved_pill_id,
		"instability_gain": 0,
		"cultivation_instability": cultivation_instability,
	}


func cultivate_session(mode_id: String = EnumXiulianMode.LABEL_CYCLE, days: int = 1, pill_id: String = "") -> Dictionary:
	var preview := preview_cultivation_session(mode_id, days, pill_id)
	if not bool(preview.get("ok", false)):
		return preview
	var mode: Dictionary = preview.get("mode", {}) as Dictionary
	var safe_days := int(preview.get("days", 1))
	var method_id := str(preview.get("method_id", ""))
	var mastery_before := XiulianMethodService.method_mastery(DataStore.savedata, method_id)
	var cultivation_before := cultivation
	var realm_before := realm_name
	var instability_before := cultivation_instability
	var pill_ids := preview.get("pill_ids", []) as Array
	var layer_advances := 0
	for day_index in safe_days:
		var base_gain := RealmBalanceService.base_daily_cultivation_gain(_realm_row(realm_index))
		var speed := XiulianMethodService.cultivation_session_speed(method_id, DataStore.savedata)
		var method_base_gain := XiulianMethodService.base_cultivation_gain(method_id)
		var raw_gain := 0
		if EnumXiulianMode.is_pill_mode(mode_id):
			var active_pill_id := str(pill_ids[int(day_index / GameTimeService.days_per_month())])
			if day_index % GameTimeService.days_per_month() == 0:
				InventoryService.remove_item(inventory, active_pill_id, 1)
			raw_gain = cultivation_pill_daily_gain(active_pill_id) + method_base_gain
		else:
			var multiplier := float(mode["cultivation_multiplier"])
			raw_gain = int(round(float(base_gain) * speed * multiplier)) + method_base_gain
		var injury_multiplier := 0.5 if injury_days > 0 else 1.0
		var gain := maxi(1, int(round(float(raw_gain) * injury_multiplier)))
		cultivation += gain
		XiulianMethodService.apply_cultivation_cycle(
			DataStore.savedata,
			float(base_gain) * speed,
			float(mode["mastery_multiplier"])
		)
		injury_days = maxi(0, injury_days - 1)
		layer_advances += _auto_advance_layers()
	_advance_time(safe_days, false, false)
	var gained := cultivation - cultivation_before
	var activity_text := "闭关 %s：%s，修为 +%d" % [
		GameTimeService.duration_label(safe_days),
		str(mode["name"]),
		gained,
	]
	if layer_advances > 0:
		activity_text += "，提升至%s" % realm_name
	if cultivation_instability > instability_before:
		activity_text += "，灵力驳杂 +%d" % (cultivation_instability - instability_before)
	_append_activity(activity_text)
	var result := {
		"ok": true,
		"mode_id": mode_id,
		"mode_name": str(mode["name"]),
		"days": safe_days,
		"duration_label": GameTimeService.duration_label(safe_days),
		"start_day": int(preview.get("start_day", day - safe_days)),
		"end_day": day,
		"start_date_label": GameTimeService.date_label(int(preview.get("start_day", day - safe_days))),
		"end_date_label": GameTimeService.date_label(day),
		"cultivation_gained": gained,
		"cultivation": cultivation,
		"breakthrough_at": breakthrough_at,
		"method_id": method_id,
		"method_name": str(preview.get("method_name", "")),
		"mastery_gained": XiulianMethodService.method_mastery(DataStore.savedata, method_id) - mastery_before,
		"method_mastery": XiulianMethodService.method_mastery(DataStore.savedata, method_id),
		"knowledge_gains": [],
		"layer_advances": layer_advances,
		"realm_before": realm_before,
		"realm_name": realm_name,
		"instability_gained": cultivation_instability - instability_before,
		"cultivation_instability": cultivation_instability,
	}
	_emit_tip_intents(RewardTipBuilder.cultivation_result(result, "cultivation"))
	return result


func _cultivation_mode(mode_id: String) -> Dictionary:
	return EnumXiulianMode.config(mode_id)


func resolve_cultivation_pill_id(preferred_id: String = "") -> String:
	var preferred := preferred_id.strip_edges()
	if preferred != "" and int(inventory.get(preferred, 0)) > 0 and is_cultivation_pill(preferred):
		return preferred
	return best_owned_cultivation_pill_id()


func best_owned_cultivation_pill_id() -> String:
	var best_id := ""
	var best_rank := -1
	for item_id_v in inventory.keys():
		var item_id := str(item_id_v)
		if int(inventory.get(item_id_v, 0)) <= 0 or not is_cultivation_pill(item_id):
			continue
		var rank := cultivation_pill_rank(item_id)
		if rank > best_rank:
			best_rank = rank
			best_id = item_id
	return best_id


func is_cultivation_pill(item_id: String) -> bool:
	var def := ConfigManager.item_def_by_id(item_id)
	return def != null and def.is_cultivation_pill()


## 修炼丹药配置的月修为（来自物品 use_effect.pill_cultivation）。
func cultivation_pill_gain(item_id: String) -> int:
	var def := ConfigManager.item_def_by_id(item_id)
	if def == null:
		return 0
	return maxi(0, int(round(def.get_use_effect_amount("pill_cultivation"))))


## 丹药炼化闭关逐日结算用的日修为（配置月修为 × DAILY_CULTIVATION_GAIN_SCALE）。
func cultivation_pill_daily_gain(item_id: String) -> int:
	return RealmBalanceService.cultivation_pill_daily_gain(cultivation_pill_gain(item_id))


func cultivation_pill_rank(item_id: String) -> int:
	var def := ConfigManager.item_def_by_id(item_id)
	if def == null:
		return 0
	return def.quality * 1000 + cultivation_pill_gain(item_id)


func _cultivation_pill_count(days: int) -> int:
	var month_days := maxi(1, GameTimeService.days_per_month())
	return maxi(1, (maxi(1, days) + month_days - 1) / month_days)


func rest() -> void:
	hp = float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0))
	mp = float(attrs.get(EnumPlayerAttr.MP_MAX, 100.0))
	injury_days = maxi(0, injury_days - maxi(0, int(_activity_cfg("rest").get("injury_recovery", 2))))
	_finish_activity("休息：恢复气血与法力", false)


## 重复调用 [method rest] 直至伤势清零；每次均推进 1 日并恢复气血法力。
func rest_until_injury_cleared() -> int:
	var rests := 0
	while injury_days > 0:
		rest()
		rests += 1
		if rests > 64:
			break
	return rests


## 增加修为并触发小境界自动提升与属性重算（不推进日数）。
func grant_cultivation(amount: int) -> Dictionary:
	var added := maxi(0, amount)
	if added <= 0:
		return {"ok": false, "error": "增加量必须大于 0", "added": 0, "layer_advances": 0}
	var realm_before := realm_name
	cultivation += added
	var layer_advances := _auto_advance_layers()
	var log_text := "修为 +%d" % added
	if layer_advances > 0:
		log_text += "，提升至%s" % realm_name
	_append_activity(log_text)
	var result := {
		"ok": true,
		"added": added,
		"cultivation_gained": added,
		"layer_advances": layer_advances,
		"realm_before": realm_before,
		"realm_name": realm_name,
	}
	_emit_tip_intents(RewardTipBuilder.cultivation_result(result, "grant_cultivation"))
	return result


## 将修为补至当前突破门槛并尝试小境界自动提升（不推进日数）。
func fill_cultivation_to_breakthrough() -> Dictionary:
	cultivation = breakthrough_at
	var layer_advances := _auto_advance_layers()
	var log_text := "修为已至突破门槛 %d" % breakthrough_at
	if layer_advances > 0:
		log_text += "，提升至%s" % realm_name
	_append_activity(log_text)
	return {"ok": true, "layer_advances": layer_advances}


## 按正常规则提升一个境界：大境界走 [method breakthrough]，小层走自动升层。
func advance_realm_one_step() -> Dictionary:
	if can_breakthrough():
		return breakthrough()
	if cultivation < breakthrough_at:
		cultivation = breakthrough_at
	var layer_advances := _auto_advance_layers()
	if layer_advances > 0:
		_append_activity("境界提升至%s" % realm_name)
		return {"ok": true, "mode": "layer", "new_realm": realm_name, "layer_advances": layer_advances}
	if realm_index + 1 >= _realms().size():
		return {"ok": false, "error": "已达最高境界"}
	return {"ok": false, "error": "当前无法继续提升境界"}


## 逐步调用 [method advance_realm_one_step] 直至达到目标境界索引。
func advance_realm_to_index(target_index: int) -> Dictionary:
	var realms := _realms()
	if realms.is_empty():
		return {"ok": false, "error": "境界表为空"}
	var safe_target := clampi(target_index, 0, realms.size() - 1)
	var steps := 0
	while realm_index < safe_target:
		var result := advance_realm_one_step()
		if not bool(result.get("ok", false)):
			return result
		steps += 1
		if steps > realms.size() + 4:
			return {"ok": false, "error": "境界提升步数异常"}
	var row := _realm_row(realm_index)
	cultivation = maxi(cultivation, int(row.get("breakthrough_at", breakthrough_at)))
	_sync_realm()
	return {"ok": true, "steps": steps, "new_realm": realm_name, "realm_index": realm_index}


## 经 [method RewardService.apply_rewards] 发放奖励（物品、灵石等）。
func grant_rewards(rewards: Array) -> Array:
	return RewardService.apply_rewards(self, rewards, "grant_rewards")


func can_breakthrough() -> bool:
	if cultivation < breakthrough_at:
		return false
	var next_index := realm_index + 1
	if next_index >= _realms().size():
		return false
	return not _same_major_realm(realm_index, next_index)


func next_realm_name() -> String:
	var next_index := realm_index + 1
	var realms := _realms()
	if next_index >= realms.size():
		return ""
	return str(_realm_row(next_index).get("name", ""))


func preview_breakthrough() -> Dictionary:
	var realms := _realms()
	if realms.is_empty():
		return {"ok": false, "error": "境界表为空"}
	return TupoService.compute_breakdown(DataStore.savedata, realms, realm_index)


func attempt_breakthrough() -> Dictionary:
	if cultivation < breakthrough_at:
		return {"ok": false, "error": "修为尚未达到突破门槛"}
	var realms := _realms()
	if realms.is_empty():
		return {"ok": false, "error": "境界表为空"}
	if not TupoService.is_major_breakthrough(realms, realm_index):
		return {"ok": false, "error": "同境界小层已自动提升，无需突破"}
	var breakdown := TupoService.compute_breakdown(DataStore.savedata, realms, realm_index)
	if not bool(breakdown.get("ok", false)):
		return breakdown
	if not bool(breakdown.get("can_attempt", false)):
		return {"ok": false, "error": str(breakdown.get("hint", "突破值过低，无法突破"))}
	var old_name := realm_name
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := TupoService.resolve(DataStore.savedata, realms, realm_index, rng)
	if not bool(result.get("ok", false)):
		return result
	if bool(result.get("success", false)):
		_apply_breakthrough_vitals()
		_sync_realm()
		_append_activity("突破成功：%s → %s（%s）" % [
			old_name, realm_name, str(result.get("tier_label", "")),
		])
		return _breakthrough_result_dict(old_name, result)
	_append_activity("突破失败，境界不稳")
	return {
		"ok": true,
		"success": false,
		"error": str(result.get("error", "突破失败，境界不稳")),
		"tier_label": str(result.get("tier_label", "")),
		"breakdown": breakdown,
	}


func breakthrough() -> Dictionary:
	if cultivation < breakthrough_at:
		return {"ok": false, "error": "修为尚未达到突破门槛"}
	var realms := _realms()
	if realms.is_empty():
		return {"ok": false, "error": "境界表为空"}
	if not TupoService.is_major_breakthrough(realms, realm_index):
		return {"ok": false, "error": "同境界小层已自动提升，无需突破"}
	var breakdown := preview_breakthrough()
	if not bool(breakdown.get("ok", false)):
		return breakdown
	if bool(breakdown.get("can_attempt", false)):
		return attempt_breakthrough()
	# 突破值未达新系统门槛时，沿用简易突破，确保修为达标后可跨入大境界。
	var old_name := realm_name
	realm_index += 1
	_apply_breakthrough_vitals()
	_sync_realm()
	_append_activity("突破成功：%s → %s" % [old_name, realm_name])
	return _breakthrough_result_dict(old_name, {})


func _apply_breakthrough_vitals() -> void:
	refresh_derived_attrs(false)
	hp = float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0))
	mp = float(attrs.get(EnumPlayerAttr.MP_MAX, 100.0))


func _breakthrough_result_dict(old_name: String, service_result: Dictionary) -> Dictionary:
	var payload := {
		"ok": true,
		"success": true,
		"old_realm": str(service_result.get("old_realm", old_name)),
		"new_realm": str(service_result.get("new_realm", realm_name)),
		"day": day,
		"totals": totals.duplicate(true),
	}
	if not service_result.is_empty():
		payload["tier_label"] = str(service_result.get("tier_label", ""))
		payload["quality"] = int(service_result.get("quality", 0))
		payload["perks"] = (service_result.get("perks", []) as Array).duplicate()
	return payload


func begin_lilian(location_id: String) -> Dictionary:
	var location := DidianService.by_id(location_id)
	if location.is_empty():
		return {"ok": false, "error": "未知地点"}
	return {"ok": true, "location": location}


func map_data() -> Dictionary:
	return DataStore.map_savedata()


func set_map_data(data: Dictionary) -> void:
	DataStore.savedata["map"] = data.duplicate(true)


func discover_map_node(node_id: String, category: String) -> void:
	set_map_data(WorldMapService.discover_map_node(map_data(), node_id, category))


func travel_to_city(target_city_id: String, path: Array, total_days: int) -> Dictionary:
	if target_city_id == "":
		return {"ok": false, "error": "缺少目标城市"}
	var preview := WorldMapService.build_travel_preview(current_city_id, target_city_id, map_data())
	if not bool(preview.get("ok", false)):
		return preview
	var expected_path: Array = preview.get("path", []) as Array
	if expected_path.size() != path.size():
		return {"ok": false, "error": "旅行路径已变化，请重新确认"}
	for i in range(path.size()):
		if str(path[i]) != str(expected_path[i]):
			return {"ok": false, "error": "旅行路径已变化，请重新确认"}
	var elapsed := maxi(0, total_days)
	if elapsed != int(preview.get("total_days", -1)):
		return {"ok": false, "error": "旅行耗时已变化，请重新确认"}
	var next_map := WorldMapService.discover_along_path(map_data(), path)
	next_map["current_city_id"] = target_city_id
	set_map_data(next_map)
	if elapsed > 0:
		_advance_time(elapsed, true, true)
	activity_log.append({
		"day": day,
		"text": "旅行至%s，耗时 %s" % [
			str(WorldMapService.city_by_id(target_city_id).get("name", target_city_id)),
			GameTimeService.duration_label(elapsed),
		],
	})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	return {
		"ok": true,
		"city_id": target_city_id,
		"elapsed_days": elapsed,
		"duration_label": GameTimeService.duration_label(elapsed),
		"date_label": GameTimeService.date_label(day),
	}


func apply_battle_player_runtime(summary: Dictionary) -> void:
	var runtime_summary := summary.get("player_runtime", {}) as Dictionary
	if runtime_summary.is_empty():
		return
	if runtime_summary.has("hp"):
		hp = float(runtime_summary.get("hp", hp))
	if runtime_summary.has("mp"):
		mp = float(runtime_summary.get("mp", mp))
	var battle_items_v: Variant = runtime_summary.get("items", [])
	if battle_items_v is Array:
		InventoryService.sync_battle_item_counts(
			inventory, item_slots, battle_items_v as Array
		)


func _skills_include_id(skills: Array, skill_id: int) -> bool:
	for row_v in skills:
		if not row_v is Dictionary:
			continue
		if int((row_v as Dictionary).get("id", -1)) == skill_id:
			return true
	return false


func build_player_battle_snapshot(runtime: Dictionary) -> Dictionary:
	var snapshot := PlayerBuildService.build_battle_snapshot(DataStore.savedata, runtime)
	snapshot["ai"] = resolved_auto_battle_rules()
	return snapshot


func build_battle_init(event: Dictionary) -> Dictionary:
	var player := build_player_battle_snapshot({
		"hp": hp,
		"mp": mp,
		"inventory": inventory,
		"item_slots": item_slots,
	})
	var enemy := LilianEventService.build_battle_enemy(event)
	var enemies := LilianEventService.build_battle_enemies(event)
	return {
		"player": player,
		"enemy": enemy,
		"enemies": enemies,
		"battle_time_limit": 200.0,
		"auto_battle": {"player": auto_battle_enabled, "enemy": true},
		"spd_jitter_ratio": 0.0,
	}


func settle_lilian(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {"ok": false, "error": "缺少历练结算数据"}
	var result_errors := LilianResult.collect_errors(result)
	if not result_errors.is_empty():
		return {"ok": false, "error": result_errors[0]}
	var settlement_id := str(result.get("settlement_id", "")).strip_edges()
	if settlement_id == "":
		return {"ok": false, "error": "缺少 settlement_id"}
	if settlement_id == last_settled_lilian_id:
		return {"ok": false, "error": "duplicate", "duplicate": true}
	last_settled_lilian_id = settlement_id
	var elapsed_days := maxi(1, int(result.get("elapsed_days", 1)))
	var start_day := int(result.get("start_day", 0))
	injury_days = maxi(0, injury_days - elapsed_days)
	var exit_reason := str(result.get("exit_reason", "manual"))
	hp = float(result.get("hp", hp))
	mp = float(result.get("mp", mp))
	if exit_reason == "defeated":
		var rules := LilianRulesService.rules()
		hp = maxf(hp, float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0)) * float(rules.get("defeat_hp_floor_ratio", 0.25)))
		injury_days = maxi(injury_days, int(rules.get("defeat_injury_days", 3)))
	elif exit_reason == "fled":
		var fled_rules := LilianRulesService.rules()
		injury_days = maxi(injury_days, int(fled_rules.get("fled_injury_days", 1)))
	for item_row_v in result.get("items", []) as Array:
		if not item_row_v is Dictionary:
			continue
		var item_row := item_row_v as Dictionary
		var iid := str(item_row.get("inventory_id", ""))
		if iid == "":
			continue
		var remaining := maxi(0, int(item_row.get("count", 0)))
		if remaining > 0:
			inventory[iid] = remaining
		else:
			inventory.erase(iid)
	var applied_loot := RewardService.apply_rewards(self, result.get("loot", []) as Array, "lilian_jiesuan")
	last_rewards = applied_loot if not applied_loot.is_empty() else (result.get("loot", []) as Array).duplicate(true)
	for lost_v in result.get("loot_lost", []) as Array:
		if not lost_v is Dictionary:
			continue
		var lost := lost_v as Dictionary
		if str(lost.get("source", "inventory")) == "session_loot":
			continue
		InventoryService.remove_item(
			inventory,
			str(lost.get("id", "")),
			int(lost.get("count", 0))
		)
	for reward in last_rewards:
		totals["items_gained"] = int(totals.get("items_gained", 0)) + int((reward as Dictionary).get("count", 0))
	var stats := result.get("stats", {}) as Dictionary
	totals["lilian_count"] = int(totals.get("lilian_count", 0)) + 1
	totals["lilian_steps"] = int(totals.get("lilian_steps", 0)) + int(stats.get("steps", 0))
	var max_diff := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	totals["max_difficulty"] = maxi(int(totals.get("max_difficulty", totals.get("max_depth", 0))), max_diff)
	totals["battles"] = int(totals.get("battles", 0)) + int(stats.get("battles", 0))
	totals["wins"] = int(totals.get("wins", 0)) + int(stats.get("wins", 0))
	totals["losses"] = int(totals.get("losses", 0)) + int(stats.get("losses", 0))
	var instability_reduced := mini(
		cultivation_instability,
		int(stats.get("wins", 0)) * INSTABILITY_REDUCTION_PER_WIN
	)
	cultivation_instability -= instability_reduced
	if start_day > 0:
		day = start_day
		_advance_time(elapsed_days, false, true)
	else:
		_advance_time(elapsed_days, false, true)
	var location_name := str(result.get("location_name", "未知地点"))
	var reward_labels: PackedStringArray = []
	for reward in last_rewards:
		reward_labels.append(reward_label(reward))
	var peak_diff := maxi(int(stats.get("max_difficulty", 0)), int(stats.get("max_depth", 0)))
	var log_text := "%s：%s历练，最高难度 %d，胜 %d 场" % [
		GameTimeService.date_label(day - elapsed_days),
		location_name,
		peak_diff,
		int(stats.get("wins", 0)),
	]
	if not reward_labels.is_empty():
		log_text += "，带回 %s" % "、".join(reward_labels)
	if exit_reason == "defeated":
		log_text += "（战败撤退）"
	elif exit_reason == "fled":
		log_text += "（战中遁走）"
	if instability_reduced > 0:
		log_text += "，灵力驳杂 -%d" % instability_reduced
	activity_log.append({"day": day, "text": log_text})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)
	last_settled_lilian_id = settlement_id
	result["instability_reduced"] = instability_reduced
	result["cultivation_instability"] = cultivation_instability
	last_lilian_summary = result.duplicate(true)
	TutorialService.game_event("tutorial.lilian_returned")
	WeituoService.record_lilian_result(result, DataStore.savedata)
	auto_save()
	return {
		"ok": true,
		"rewards": last_rewards.duplicate(true),
		"elapsed_days": elapsed_days,
		"instability_reduced": instability_reduced,
		"cultivation_instability": cultivation_instability,
	}


func to_dict() -> Dictionary:
	return DataStore.export_savedata()


func apply_dict(data: Dictionary) -> bool:
	if not DataStore.import_savedata(data):
		return false
	refresh_derived_attrs(true)
	var attrs_dict := attrs
	hp = clampf(hp, 0.0, float(attrs_dict.get(EnumPlayerAttr.HP_MAX, 100.0)))
	mp = clampf(mp, 0.0, float(attrs_dict.get(EnumPlayerAttr.MP_MAX, 100.0)))
	if Engine.get_main_loop() is SceneTree:
		var lilian := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("LilianState")
		if lilian != null and lilian.has_method("reset"):
			lilian.reset()
	_initialize_map_state()
	_sync_realm()
	return true


func refresh_derived_attrs(preserve_vital_ratio: bool = true) -> void:
	var old_hp_max := maxf(1.0, float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0)))
	var old_mp_max := maxf(1.0, float(attrs.get(EnumPlayerAttr.MP_MAX, 100.0)))
	var hp_ratio := clampf(hp / old_hp_max, 0.0, 1.0)
	var mp_ratio := clampf(mp / old_mp_max, 0.0, 1.0)
	var method_mods := XiulianMethodService.build_modifiers(
		cultivation_method_slots, DataStore.savedata
	)
	var flat_mods: Dictionary = (method_mods.get('flat', {}) as Dictionary).duplicate(true)
	var percent_mods: Dictionary = (method_mods.get("percent", {}) as Dictionary).duplicate(true)
	var next_attrs := _realm_combat_attrs()
	if next_attrs.is_empty():
		next_attrs = CharacterStats.build_combat_attrs(foundations)
	for key in flat_mods.keys():
		var stat := str(key)
		next_attrs[stat] = ZhandouAttr.get_attr(next_attrs, stat) + float(flat_mods[key])
	for key in percent_mods.keys():
		var stat := str(key)
		next_attrs[stat] = ZhandouAttr.get_attr(next_attrs, stat) * (1.0 + float(percent_mods[key]))
	attrs = CharacterStats.finalize_combat_attrs(next_attrs)
	if preserve_vital_ratio:
		hp = float(attrs.get(EnumPlayerAttr.HP_MAX, 100.0)) * hp_ratio
		mp = float(attrs.get(EnumPlayerAttr.MP_MAX, 100.0)) * mp_ratio


func major_realm_id() -> String:
	return _major_realm_id(_realm_row(realm_index))


func grant_knowledge(skill_id: String, level: int) -> void:
	KnowledgeService.grant_level(DataStore.savedata, skill_id, level)


func learn_ability(ability_id: String) -> Dictionary:
	var aid := ability_id.strip_edges()
	if AbilityService.by_id(aid).is_empty():
		return {"ok": false, "error": "未知技能"}
	if not AbilityService.can_learn(aid, DataStore.savedata, major_realm_id()):
		return {"ok": false, "error": "尚未满足学习条件"}
	if unlocked_abilities.has(aid):
		return {"ok": false, "error": "已经掌握该技能"}
	unlocked_abilities.append(aid)
	# 战斗被动/通用被动学会即生效，仅主动与持续技尝试填入战斗栏空槽
	var ability_type := str(AbilityService.by_id(aid).get("type", ""))
	if AbilityService.uses_combat_skill_slot(ability_type):
		var slots := equipped_abilities.duplicate(true)
		for i in slots.size():
			if str(slots[i]).strip_edges() == "":
				slots[i] = aid
				equipped_abilities = DataStore._normalize_ability_slots(slots)
				break
	return {"ok": true, "ability_id": aid}


func learn_method(method_id: String) -> Dictionary:
	var row := XiulianMethodService.by_id(method_id)
	if row.is_empty():
		return {"ok": false, "error": "未知功法"}
	if not XiulianMethodService.can_learn(row, DataStore.savedata, major_realm_id()):
		return {"ok": false, "error": "尚未满足学习条件"}
	if unlocked_methods.has(method_id):
		return {"ok": false, "error": "已经掌握该功法"}
	unlocked_methods.append(method_id)
	if current_cultivation_method_id.strip_edges() == "":
		current_cultivation_method_id = method_id
	return {"ok": true, "method_id": method_id}


func set_current_cultivation_method(method_id: String) -> Dictionary:
	var id := method_id.strip_edges()
	if not unlocked_methods.has(id) or XiulianMethodService.by_id(id).is_empty():
		return {"ok": false, "error": "尚未掌握该功法"}
	current_cultivation_method_id = id
	return {"ok": true, "method_id": id}


func use_inventory_item(item_id: String) -> Dictionary:
	var iid := item_id.strip_edges()
	if iid == "":
		return {"ok": false, "error": "无效物品"}
	var def := ConfigManager.item_def_by_id(iid)
	if def == null or int(inventory.get(iid, 0)) <= 0:
		return {"ok": false, "error": "背包中没有该物品"}
	var result: Dictionary
	if def.is_learning_book():
		result = use_learning_book(iid)
	elif _has_alchemy_mastery_effect(def):
		result = _use_alchemy_mastery_notes(iid, def)
	elif _has_attrs_effect(def):
		result = _use_attrs_effect(iid, def)
	else:
		return {"ok": false, "error": "该物品无法直接使用"}
	if bool(result.get("ok", false)):
		DataEvents.emit_inventory_changed()
	return result


func _has_attrs_effect(def: ItemDef) -> bool:
	for row_v in def.use_effect:
		if not row_v is Dictionary:
			continue
		if str((row_v as Dictionary).get("op", "")).strip_edges().to_lower() == "attrs":
			return true
	return false


func _use_attrs_effect(item_id: String, def: ItemDef) -> Dictionary:
	var applied: Array = []
	for row_v in def.use_effect:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if str(row.get("op", "")).strip_edges().to_lower() != "attrs":
			continue
		var args_v: Variant = row.get("args", [])
		if not (args_v is Array) or (args_v as Array).size() < 2:
			continue
		var args := args_v as Array
		var attr_key := str(args[0]).strip_edges()
		var delta := float(args[1])
		if attr_key == "" or delta == 0.0:
			continue
		attrs[attr_key] = ZhandouAttr.get_attr(attrs, attr_key, 0.0) + delta
		applied.append({"attr": attr_key, "delta": delta})
	if applied.is_empty():
		return {"ok": false, "error": "无有效的属性修改"}
	InventoryService.remove_item(inventory, item_id, 1)
	return {"ok": true, "attrs": applied, "feedback": "属性已变化"}


func use_learning_book(item_id: String) -> Dictionary:
	var def := ConfigManager.item_def_by_id(item_id)
	if def == null or int(inventory.get(item_id, 0)) <= 0:
		return {"ok": false, "error": "背包中没有该典籍"}
	var result: Dictionary
	if def.learn_ability_id != "":
		result = learn_ability(def.learn_ability_id)
	elif def.learn_method_id != "":
		result = learn_method(def.learn_method_id)
	else:
		return {"ok": false, "error": "该物品不是可学习典籍"}
	if bool(result.get("ok", false)):
		InventoryService.remove_item(inventory, item_id, 1)
	return result


func _has_alchemy_mastery_effect(def: ItemDef) -> bool:
	for row_v in def.use_effect:
		if not row_v is Dictionary:
			continue
		if str((row_v as Dictionary).get("op", "")).strip_edges().to_lower() == "alchemy_mastery":
			return true
	return false


func _use_alchemy_mastery_notes(item_id: String, def: ItemDef) -> Dictionary:
	var recipe_id := "recipe.juqi"
	var amount := 180
	for row_v in def.use_effect:
		if not row_v is Dictionary:
			continue
		var row := row_v as Dictionary
		if str(row.get("op", "")).strip_edges().to_lower() != "alchemy_mastery":
			continue
		var args_v: Variant = row.get("args", [])
		if args_v is Array:
			var args := args_v as Array
			if not args.is_empty():
				recipe_id = str(args[0])
			if args.size() > 1:
				amount = int(args[1])
		break
	var before := LiandanService.mastery_for(liandan, recipe_id)
	var next_liandan := LiandanService.apply_recipe_mastery(liandan, recipe_id, amount)
	liandan = next_liandan
	var gained := LiandanService.mastery_for(liandan, recipe_id) - before
	var recipe := LiandanService.recipe_by_id(recipe_id)
	var recipe_name := str(recipe.get("pill_name", recipe.get("name", "丹方")))
	InventoryService.remove_item(inventory, item_id, 1)
	return {
		"ok": true,
		"message": "研读心得，%s熟练度 +%d" % [recipe_name, gained],
		"mastery_gain": gained,
		"recipe_id": recipe_id,
	}


func equip_method(slot_key: String, method_id: String) -> Dictionary:
	var row := XiulianMethodService.by_id(method_id)
	if not unlocked_methods.has(method_id) or not XiulianMethodService.can_equip(row, slot_key):
		return {"ok": false, "error": "该功法无法装备到此位置"}
	var slots := cultivation_method_slots.duplicate(true)
	for key in slots.keys():
		if str(slots[key]) == method_id:
			slots[key] = ""
	slots[slot_key] = method_id
	cultivation_method_slots = slots
	refresh_derived_attrs(true)
	return {"ok": true}


func equip_ability(slot_index: int, ability_id: String) -> Dictionary:
	var aid := ability_id.strip_edges()
	if slot_index < 0 or slot_index >= 5:
		return {"ok": false, "error": "无法配置该技能"}
	if aid != "" and not unlocked_abilities.has(aid):
		return {"ok": false, "error": "无法配置该技能"}
	if aid != "":
		var ability_type := str(AbilityService.by_id(aid).get("type", ""))
		if not AbilityService.uses_combat_skill_slot(ability_type):
			return {"ok": false, "error": "该技能学会后自动生效，无需编入战斗栏"}
	var slots := DataStore._normalize_ability_slots(equipped_abilities)
	var previous := slots.find(aid)
	if previous >= 0:
		slots[previous] = ""
	slots[slot_index] = aid
	equipped_abilities = slots
	return {"ok": true}


func assign_equip_slot(slot_index: int, equip_id: int) -> Dictionary:
	if slot_index < 0 or slot_index >= equip_slots.size():
		return {"ok": false, "error": "无效法宝槽位"}
	var slots := (equip_slots as Array).duplicate(true)
	var treasure_slots := (treasure_item_slots as Array).duplicate(true)
	if equip_id <= 0:
		slots[slot_index] = -1
		equip_slots = slots
		return {"ok": true}
	if not _owns_equip_id(equip_id):
		return {"ok": false, "error": "未拥有该法宝"}
	for i in slots.size():
		if i != slot_index and int(slots[i]) == equip_id:
			slots[i] = -1
	slots[slot_index] = equip_id
	equip_slots = slots
	if slot_index < treasure_slots.size():
		treasure_slots[slot_index] = ""
		treasure_item_slots = treasure_slots
	var cfg := ConfigManager.equip_by_id(equip_id)
	return {"ok": true, "message": "已装备 %s。" % str(cfg.get("name", "法宝"))}


func assign_treasure_item_slot(slot_index: int, item_id: String) -> Dictionary:
	if slot_index < 0 or slot_index >= treasure_item_slots.size():
		return {"ok": false, "error": "无效法宝槽位"}
	var iid := item_id.strip_edges()
	var treasure_slots := (treasure_item_slots as Array).duplicate(true)
	var equip_slot_values := (equip_slots as Array).duplicate(true)
	if iid == "":
		treasure_slots[slot_index] = ""
		treasure_item_slots = treasure_slots
		return {"ok": true}
	if int(inventory.get(iid, 0)) <= 0:
		return {"ok": false, "error": "背包中没有该法宝"}
	var def := ConfigManager.item_def_by_id(iid)
	if def == null or not def.is_treasure():
		return {"ok": false, "error": "该物品不是法宝"}
	for i in treasure_slots.size():
		if i != slot_index and str(treasure_slots[i]) == iid:
			treasure_slots[i] = ""
	treasure_slots[slot_index] = iid
	treasure_item_slots = treasure_slots
	if slot_index < equip_slot_values.size():
		equip_slot_values[slot_index] = -1
		equip_slots = equip_slot_values
	return {"ok": true, "message": "已装备 %s。" % def.name}


func _owns_equip_id(equip_id: int) -> bool:
	for eid_v in owned_equips:
		if int(eid_v) == equip_id:
			return true
	return false


func assign_item_slot(slot_index: int, item_id: String) -> Dictionary:
	if slot_index < 0 or slot_index >= item_slots.size():
		return {"ok": false, "error": "无效道具槽位"}
	var iid := item_id.strip_edges()
	var slots := (item_slots as Array).duplicate(true)
	if iid == "":
		slots[slot_index] = ""
		item_slots = slots
		return {"ok": true}
	if int(inventory.get(iid, 0)) <= 0:
		return {"ok": false, "error": "背包中没有该道具"}
	var def := ConfigManager.item_def_by_id(iid)
	if def == null or not def.has_fight_config():
		return {"ok": false, "error": "该物品不可带入战斗"}
	for i in slots.size():
		if i != slot_index and str(slots[i]) == iid:
			slots[i] = ""
	slots[slot_index] = iid
	item_slots = slots
	return {"ok": true, "message": "已装备 %s。" % def.name}


func resolved_auto_battle_rules() -> Dictionary:
	return PlayerAutoBattleService.normalize_rules(auto_battle_rules)


func auto_battle_strategies() -> Array:
	var rules := resolved_auto_battle_rules()
	return (rules.get("strategies", []) as Array).duplicate(true)


func set_auto_battle_strategies(strategies: Array) -> void:
	auto_battle_rules = PlayerAutoBattleService.with_strategies(strategies)


func append_auto_battle_strategy(strategy: Dictionary) -> void:
	var strategies := auto_battle_strategies()
	strategies.append(strategy.duplicate(true))
	set_auto_battle_strategies(strategies)


func remove_auto_battle_strategy(index: int) -> void:
	var strategies := auto_battle_strategies()
	if index < 0 or index >= strategies.size():
		return
	strategies.remove_at(index)
	set_auto_battle_strategies(strategies)


func reward_label(reward: Dictionary) -> String:
	var kind := str(reward.get("kind", "item"))
	if kind == "equip":
		return "%s x1" % str(ConfigManager.equip_by_id(int(reward.get("id", -1))).get("name", "法宝"))
	if kind == "currency":
		return "灵石 x%d" % int(reward.get("count", 0))
	var cm := _config_manager()
	var name := str(reward.get("id", ""))
	if cm != null and cm.has_method("get_item_display_name"):
		name = str(cm.call("get_item_display_name", name))
	return "%s x%d" % [name, int(reward.get("count", 0))]


func _finish_activity(text: String, reduce_injury: bool, passive_method: bool = true) -> void:
	if reduce_injury and injury_days > 0:
		injury_days -= 1
	_append_activity(text)
	_advance_time(1, false, passive_method)


func _advance_time(days_value: int, reduce_injury: bool = true, passive_method: bool = true) -> Dictionary:
	var elapsed := maxi(0, days_value)
	var summary := {
		"days": elapsed,
		"method_id": XiulianMethodService.active_cultivation_method_id(DataStore.savedata),
		"mastery_gained": 0.0,
		"knowledge": [],
	}
	if elapsed <= 0:
		return summary
	if passive_method:
		summary = _apply_passive_method_practice(elapsed)
	day += elapsed
	if reduce_injury:
		injury_days = maxi(0, injury_days - elapsed)
	return summary


func _apply_passive_method_practice(days_value: int) -> Dictionary:
	var method_id := XiulianMethodService.active_cultivation_method_id(DataStore.savedata)
	var mastery_before := XiulianMethodService.method_mastery(DataStore.savedata, method_id)
	var summary := {
		"days": maxi(0, days_value),
		"method_id": method_id,
		"mastery_gained": 0.0,
		"knowledge": [],
	}
	var speed := XiulianMethodService.cultivation_session_speed(method_id, DataStore.savedata)
	if method_id == "" or speed <= 0.0:
		return summary
	var base_gain := RealmBalanceService.base_daily_cultivation_gain(_realm_row(realm_index))
	var method_base_gain := XiulianMethodService.base_cultivation_gain(method_id)
	var daily_xp := float(maxi(1, int(round(float(base_gain) * speed)) + method_base_gain))
	var practice_xp := daily_xp * PASSIVE_METHOD_PRACTICE_RATIO
	for _day_index in days_value:
		XiulianMethodService.apply_cultivation_cycle(
			DataStore.savedata,
			practice_xp,
			PASSIVE_METHOD_PRACTICE_RATIO
		)
	summary["mastery_gained"] = XiulianMethodService.method_mastery(
		DataStore.savedata,
		method_id
	) - mastery_before
	return summary


func _append_activity(text: String) -> void:
	activity_log.append({"day": day, "text": text})
	if activity_log.size() > 30:
		activity_log = activity_log.slice(activity_log.size() - 30)


func _roman_knowledge_level(level: int) -> String:
	match level:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
		5:
			return "V"
		_:
			return "—"


func _realms() -> Array:
	return RealmService.realms()


func _realm_row(index: int) -> Dictionary:
	var realms := _realms()
	if realms.is_empty():
		return {}
	var safe_index := clampi(index, 0, realms.size() - 1)
	var row_v: Variant = realms[safe_index]
	return row_v as Dictionary if row_v is Dictionary else {}


func _major_realm_id(row: Dictionary) -> String:
	var major := EnumMajorRealm.normalize_id(str(row.get("major_realm", "")))
	if major != "" and EnumMajorRealm.is_valid_id(major):
		return major
	var id := str(row.get("id", "")).strip_edges()
	if id == "":
		return EnumMajorRealm.default_id()
	return EnumMajorRealm.normalize_id(id.split("_", false, 1)[0])


func _same_major_realm(index_a: int, index_b: int) -> bool:
	var major_a := _major_realm_id(_realm_row(index_a))
	var major_b := _major_realm_id(_realm_row(index_b))
	return major_a != "" and major_a == major_b


func _can_auto_advance_layer() -> bool:
	if cultivation < breakthrough_at:
		return false
	var next_index := realm_index + 1
	if next_index >= _realms().size():
		return false
	return _same_major_realm(realm_index, next_index)


func _auto_advance_layers() -> int:
	var advances := 0
	while _can_auto_advance_layer():
		realm_index += 1
		advances += 1
		_apply_realm_row()
	if advances > 0:
		refresh_derived_attrs(true)
	return advances


func _apply_realm_row() -> void:
	var realms := _realms()
	var index := mini(realm_index, maxi(0, realms.size() - 1))
	var row := _realm_row(index)
	realm_name = str(row.get("name", "练气初期"))
	breakthrough_at = maxi(cultivation + 100, int(row.get("breakthrough_at", 100))) if realm_index >= realms.size() else int(row.get("breakthrough_at", 100))
	var row_foundations_v: Variant = row.get("foundations", {})
	if row_foundations_v is Dictionary and not (row_foundations_v as Dictionary).is_empty():
		foundations = row_foundations_v as Dictionary


func _realm_combat_attrs() -> Dictionary:
	var attrs_v: Variant = _realm_row(realm_index).get("combat_attrs", {})
	return (attrs_v as Dictionary).duplicate(true) if attrs_v is Dictionary else {}

func _sync_realm() -> void:
	_apply_realm_row()
	_auto_advance_layers()


func _activity_cfg(activity_id: String) -> Dictionary:
	var activities := _simulation_root().get("activities", {}) as Dictionary
	var cfg_v: Variant = activities.get(activity_id, {})
	return cfg_v as Dictionary if cfg_v is Dictionary else {}


func _simulation_root() -> Dictionary:
	return JsonLoader.load_moni_bundle()


func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")


func _emit_tip_intents(intents: Array) -> void:
	if intents.is_empty() or DataEvents == null:
		return
	DataEvents.emit_tip_intents(intents)


func _map_savedata() -> Dictionary:
	return DataStore.map_savedata()


func _initialize_map_state() -> void:
	var map_state := map_data()
	if str(map_state.get("current_city_id", "")) == "":
		map_state["current_city_id"] = WorldMapService.starter_city_id()
	set_map_data(WorldMapService.apply_starter_discovery(map_data()))
