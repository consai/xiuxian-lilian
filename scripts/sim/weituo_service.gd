class_name WeituoService
extends RefCounted
## 委托领域服务：配置读取、榜单刷新、接取/提交和历练进度回填。

const WeituoCatalogScript := preload(
	"res://scripts/features/commission/infrastructure/weituo_catalog.gd"
)
const WeituoStateScript := preload(
	"res://scripts/features/commission/domain/weituo_state.gd"
)
const InventoryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_application.gd"
)
const InventoryQueryApplicationScript := preload(
	"res://scripts/features/inventory/application/inventory_query_application.gd"
)


static func rules() -> Dictionary:
	return WeituoCatalogScript.rules()


static func weituo_dict() -> Dictionary:
	return WeituoCatalogScript.commissions()


static func active_limit() -> int:
	return int(rules()["active_limit"])


## 委托榜单次刷新展示的可接受委托数量（默认每月 3 个）。
static func board_offer_count() -> int:
	return int(rules()["board_offer_count"])


static func weituo_by_id(weituo_id: String) -> Dictionary:
	return WeituoCatalogScript.commission_by_id(weituo_id)


static func prepare_state_for_commit(raw: Variant, action: String) -> Dictionary:
	var prepared := WeituoStateScript.prepare(raw)
	if prepared.is_empty():
		push_error("[weituo_service:invalid_state] action=%s" % action)
		return {}
	if not _validate_catalog_references(prepared, action):
		return {}
	return prepared


static func visible_entries(savedata: Dictionary, game_state: Node = null) -> Array:
	var weituo_data := _prepare_weituo_data(savedata, "visible_entries")
	if weituo_data.is_empty():
		return []
	var entries: Array = []
	var active_map := weituo_data.get("active", {}) as Dictionary
	var active_weituo_ids: Dictionary = {}

	for instance_id_v in active_map.keys():
		var instance_id := str(instance_id_v)
		var rec := active_map[instance_id] as Dictionary
		var weituo_id := _record_weituo_id(rec)
		var weituo_def := weituo_by_id(weituo_id)
		active_weituo_ids[weituo_id] = instance_id
		# 已接取委托优先以 active 记录展示，避免同一委托在榜单重复出现。
		entries.append(
			_build_entry(
				savedata,
				game_state,
				weituo_data,
				weituo_id,
				instance_id,
				"active:%s" % instance_id,
				rec,
				weituo_def
			)
		)

	for offer_id_v in (weituo_data.get("board", {}) as Dictionary).get("offer_ids", []) as Array:
		var weituo_id := str(offer_id_v)
		if active_weituo_ids.has(weituo_id):
			continue
		var weituo_def := weituo_by_id(weituo_id)
		if not is_unlocked(weituo_def, savedata, game_state):
			continue
		var state := _offer_state(weituo_data, weituo_id, weituo_def)
		if state == EnumWeituoState.State.LOCKED:
			continue
		entries.append(
			_build_entry(
				savedata,
				game_state,
				weituo_data,
				weituo_id,
				"",
				"offer:%s" % weituo_id,
				{},
				weituo_def,
				state
			)
		)

	entries.sort_custom(_sort_entries)
	return entries


static func board_badge(savedata: Dictionary, game_state: Node = null) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "board_badge")
	if weituo_data.is_empty():
		return {"has_ready": false, "has_new": false, "active_count": 0, "active_limit": active_limit()}
	var active_map := weituo_data.get("active", {}) as Dictionary
	var has_ready := false
	for instance_id_v in active_map.keys():
		var check := can_submit(str(instance_id_v), savedata, game_state)
		if bool(check.get("ok", false)):
			has_ready = true
			break
	return {
		"has_ready": has_ready,
		"has_new": false,
		"active_count": active_map.size(),
		"active_limit": active_limit(),
	}


static func accept(weituo_id: String, savedata: Dictionary, game_state: Node = null) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "accept")
	if weituo_data.is_empty():
		return {"ok": false, "error": "委托状态无效"}
	var cid := weituo_id.strip_edges()
	var weituo_def := weituo_by_id(cid)
	if weituo_def.is_empty():
		return {"ok": false, "error": "委托不存在"}
	if not is_unlocked(weituo_def, savedata, game_state):
		return {"ok": false, "error": "委托尚未解锁"}
	var active := weituo_data.get("active", {}) as Dictionary
	if _active_instance_for_weituo(active, cid) != "":
		return {"ok": false, "error": "该委托已在进行中"}
	if active.size() >= active_limit():
		return {"ok": false, "error": "当前委托已满，先提交或放弃一项"}
	if not bool(weituo_def.get("repeatable", true)):
		var completed_once: Array = weituo_data.get("completed_once", []) as Array
		if cid in completed_once:
			return {"ok": false, "error": "该委托已完成"}
	var day := int(savedata.get("day", 1))
	var instance_id := "%s_d%d_%d" % [cid, day, Time.get_ticks_msec()]
	active[instance_id] = {
		"weituo_id": cid,
		"accepted_day": day,
		"progress": {},
	}
	weituo_data["active"] = active
	if not _commit_weituo_data(savedata, weituo_data, "accept"):
		return {"ok": false, "error": "委托状态提交失败"}
	return {"ok": true, "instance_id": instance_id}


static func can_submit(instance_id: String, savedata: Dictionary, game_state: Node = null) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "can_submit")
	if weituo_data.is_empty():
		return {"ok": false, "missing": [], "requirements": []}
	var active := weituo_data.get("active", {}) as Dictionary
	if not active.has(instance_id):
		return {"ok": false, "missing": [], "requirements": []}
	var rec := active[instance_id] as Dictionary
	var weituo_def := weituo_by_id(str(_record_weituo_id(rec)))
	var requirements := _evaluate_requirements(weituo_def, rec, savedata, game_state, true)
	var missing: Array = []
	for req_v in requirements:
		var req := req_v as Dictionary
		if not bool(req.get("satisfied", false)):
			missing.append(req)
	return {"ok": missing.is_empty(), "missing": missing, "requirements": requirements}


static func submit(instance_id: String, savedata: Dictionary, game_state: Node) -> Dictionary:
	var check := can_submit(instance_id, savedata, game_state)
	if not bool(check.get("ok", false)):
		return {"ok": false, "error": "条件未满足", "missing": check.get("missing", [])}
	if game_state == null:
		return {"ok": false, "error": "缺少 GameState"}
	var weituo_data := _prepare_weituo_data(savedata, "submit")
	if weituo_data.is_empty():
		return {"ok": false, "error": "委托状态无效", "missing": []}
	var active := weituo_data.get("active", {}) as Dictionary
	var rec := active[instance_id] as Dictionary
	var weituo_def := weituo_by_id(str(_record_weituo_id(rec)))
	var inventory := _resolve_inventory(savedata, game_state)
	var consume_result := _consume_item_requirements(inventory, weituo_def)
	if not bool(consume_result.get("ok", false)):
		return {
			"ok": false,
			"error": str(consume_result.get("error", "扣除物品失败")),
			"missing": consume_result.get("missing", []),
		}
	_persist_inventory(savedata, game_state, inventory)
	var rewards := weituo_def.get("rewards", []) as Array
	var applied := RewardService.apply_rewards(game_state, rewards, "weituo")
	_emit_inventory_changed()
	var title := str(weituo_def.get("title", "委托"))
	_append_activity(game_state, "提交委托「%s」，获得预定奖励" % title)
	var weituo_id := _record_weituo_id(rec)
	if not bool(weituo_def.get("repeatable", true)):
		var completed_once: Array = weituo_data.get("completed_once", []) as Array
		if weituo_id not in completed_once:
			completed_once.append(weituo_id)
		weituo_data["completed_once"] = completed_once
	var completed_count := weituo_data.get("completed_count", {}) as Dictionary
	completed_count[weituo_id] = int(completed_count.get(weituo_id, 0)) + 1
	weituo_data["completed_count"] = completed_count
	active.erase(instance_id)
	weituo_data["active"] = active
	if not _commit_weituo_data(savedata, weituo_data, "submit"):
		return {"ok": false, "error": "委托状态提交失败", "missing": []}
	if game_state.has_method("auto_save"):
		game_state.call("auto_save")
	return {"ok": true, "rewards": applied}


static func abandon(instance_id: String, savedata: Dictionary) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "abandon")
	if weituo_data.is_empty():
		return {"ok": false, "error": "委托状态无效"}
	var active := weituo_data.get("active", {}) as Dictionary
	if not active.has(instance_id):
		return {"ok": false, "error": "委托不存在"}
	active.erase(instance_id)
	weituo_data["active"] = active
	if not _commit_weituo_data(savedata, weituo_data, "abandon"):
		return {"ok": false, "error": "委托状态提交失败"}
	return {"ok": true}


static func record_lilian_result(result: Dictionary, savedata: Dictionary) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "record_lilian_result")
	if weituo_data.is_empty():
		return {"ok": false, "error": "委托状态无效", "updated": []}
	var active := weituo_data.get("active", {}) as Dictionary
	if active.is_empty():
		return {"ok": true, "updated": []}
	var settlement_id := str(result.get("settlement_id", "")).strip_edges()
	var location_id := str(result.get("location_id", "")).strip_edges()
	if location_id == "":
		return {"ok": true, "updated": []}
	var stats := result.get("stats", {}) as Dictionary
	var steps := maxi(0, int(stats.get("steps", 0)))
	var exit_reason := str(result.get("exit_reason", "manual"))
	var updated: Array = []

	for instance_id_v in active.keys():
		var instance_id := str(instance_id_v)
		var rec := (active[instance_id] as Dictionary).duplicate(true)
		var weituo_def := weituo_by_id(str(_record_weituo_id(rec)))
		var progress := rec.get("progress", {}) as Dictionary
		var applied_ids: Array = progress.get("settlement_ids", []) as Array
		if settlement_id != "" and settlement_id in applied_ids:
			continue
		# 一次历练结算只回填匹配地点的委托，并用 settlement_id 防重复累计。
		var matched := false
		for req_v in weituo_def.get("requirements", []) as Array:
			if not req_v is Dictionary:
				continue
			var req := req_v as Dictionary
			if str(req.get("kind", "")) == "lilian" and str(req.get("location_id", "")) == location_id:
				matched = true
				break
		if not matched:
			continue
		progress["lilian_steps"] = maxi(int(progress.get("lilian_steps", 0)), steps)
		if not progress.has("not_defeated"):
			progress["not_defeated"] = true
		if exit_reason == "defeated":
			progress["not_defeated"] = false
		elif exit_reason != "defeated":
			progress["not_defeated"] = true
		if settlement_id != "":
			var next_ids := applied_ids.duplicate()
			next_ids.append(settlement_id)
			progress["settlement_ids"] = next_ids
		rec["progress"] = progress
		active[instance_id] = rec
		updated.append(instance_id)

	weituo_data["active"] = active
	if not _commit_weituo_data(savedata, weituo_data, "record_lilian_result"):
		return {"ok": false, "error": "委托状态提交失败", "updated": []}
	return {"ok": true, "updated": updated}


static func refresh_board_if_needed(savedata: Dictionary, _game_state: Node = null) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "refresh_board_if_needed")
	if weituo_data.is_empty():
		return {"ok": false, "error": "委托状态无效", "refreshed": false}
	var board := weituo_data.get("board", {}) as Dictionary
	var refresh_days := int(rules()["refresh_days"])
	var day := int(savedata.get("day", 1))
	var refresh_day := int(board.get("refresh_day", 1))
	var offer_ids: Array = board.get("offer_ids", []) as Array
	var refreshed := false
	if offer_ids.is_empty():
		# 空榜立即补齐；正常刷新按配置天数滚动。
		board["offer_ids"] = _pick_board_offer_ids(savedata, _game_state)
		refreshed = true
	elif day >= refresh_day + refresh_days:
		board["refresh_day"] = day
		board["offer_ids"] = _pick_board_offer_ids(savedata, _game_state)
		refreshed = true
	weituo_data["board"] = board
	if not _commit_weituo_data(savedata, weituo_data, "refresh_board_if_needed"):
		return {"ok": false, "error": "委托状态提交失败", "refreshed": false}
	return {"ok": true, "refreshed": refreshed}


static func weituo_block(savedata: Dictionary) -> Dictionary:
	return _prepare_weituo_data(savedata, "weituo_block")


static func is_unlocked(weituo_def: Dictionary, savedata: Dictionary, _game_state: Node = null) -> bool:
	var unlock_v: Variant = weituo_def.get("unlock", {})
	if not unlock_v is Dictionary:
		return true
	var unlock := unlock_v as Dictionary
	if int(savedata.get("realm_index", 0)) < int(unlock.get("min_realm_index", 0)):
		return false
	var city_id := str(unlock.get("city_id", "")).strip_edges()
	if city_id != "":
		var map_v: Variant = savedata.get("map", {})
		if map_v is Dictionary:
			var discovered: Array = (map_v as Dictionary).get("discovered_cities", []) as Array
			if city_id not in discovered:
				return false
	return true


static func build_reward_row(reward: Dictionary) -> Dictionary:
	var kind := str(reward.get("kind", EnumRewardKind.LABEL_ITEM))
	var count := maxi(1, int(reward.get("count", 1)))
	if kind == EnumRewardKind.LABEL_CURRENCY:
		var currency_id := str(reward.get("id", "ling_stones"))
		return {
			"kind": kind,
			"id": currency_id,
			"count": count,
			"display_name": "灵石" if currency_id == "ling_stones" else currency_id,
			"icon_path": "res://assets/art/ui_new/lingshi.png",
		}
	if kind == EnumRewardKind.LABEL_EQUIP:
		var equip_id := int(reward.get("id", -1))
		var equip: Dictionary = _config_manager().equip_by_id(equip_id) if _config_manager() != null else {}
		return {
			"kind": kind,
			"id": str(equip_id),
			"count": 1,
			"display_name": str(equip.get("name", "法宝")),
			"icon_path": str(equip.get("icon", "")),
		}
	var item_id := str(reward.get("id", ""))
	var def := _item_def(item_id)
	var display_name := item_id
	var icon_path := ""
	if def != null:
		display_name = def.name
		icon_path = def.icon_path
	else:
		display_name = InventoryQueryApplicationScript.display_name(item_id)
	return {
		"kind": kind,
		"id": item_id,
		"count": count,
		"display_name": display_name,
		"icon_path": icon_path,
	}


static func refresh_header(savedata: Dictionary) -> Dictionary:
	var weituo_data := _prepare_weituo_data(savedata, "refresh_header")
	if weituo_data.is_empty():
		return {}
	var board := weituo_data.get("board", {}) as Dictionary
	var refresh_days := int(rules()["refresh_days"])
	var refresh_day := int(board.get("refresh_day", 1))
	var next_day := refresh_day + refresh_days
	var active_count := int((weituo_data.get("active", {}) as Dictionary).size())
	return {
		"active_text": "当前委托  %d/%d" % [active_count, active_limit()],
		"refresh_text": "下次刷新：%s" % GameTimeService.date_label(next_day),
	}


static func _build_entry(
		savedata: Dictionary,
		game_state: Node,
		weituo_data: Dictionary,
		weituo_id: String,
		instance_id: String,
		entry_key: String,
		active_rec: Dictionary,
		weituo_def: Dictionary,
		forced_state: int = -1
) -> Dictionary:
	var state := forced_state
	if state < 0:
		if instance_id != "" and bool(can_submit(instance_id, savedata, game_state).get("ok", false)):
			state = EnumWeituoState.State.READY
		else:
			state = EnumWeituoState.State.ACTIVE
	var requirements := _evaluate_requirements(
		weituo_def,
		active_rec,
		savedata,
		game_state,
		instance_id != ""
	)
	var rewards: Array = []
	for reward_v in weituo_def.get("rewards", []) as Array:
		if reward_v is Dictionary:
			rewards.append(build_reward_row(reward_v as Dictionary))
	var summary := _build_summary(requirements)
	var progress_ratio := _progress_ratio(requirements)
	var active_count := int((weituo_data.get("active", {}) as Dictionary).size())
	var at_limit := active_count >= active_limit()
	var ui_v: Variant = weituo_def.get("ui", {})
	var portrait := ""
	if ui_v is Dictionary:
		portrait = str((ui_v as Dictionary).get("portrait", ""))
	return {
		"key": entry_key,
		"weituo_id": weituo_id,
		"instance_id": instance_id,
		"state": state,
		"title": str(weituo_def.get("title", "")),
		"issuer": str(weituo_def.get("issuer", "")),
		"desc": str(weituo_def.get("desc", "")),
		"rarity": str(weituo_def.get("rarity", "common")),
		"type_label": _type_label(weituo_def),
		"summary": summary,
		"progress_ratio": progress_ratio,
		"requirements": requirements,
		"rewards": rewards,
		"portrait": portrait,
		"can_accept": state == EnumWeituoState.State.AVAILABLE and not at_limit,
		"can_submit": state == EnumWeituoState.State.READY,
		"can_abandon": state == EnumWeituoState.State.ACTIVE or state == EnumWeituoState.State.READY,
		"active_full": at_limit,
	}


static func _evaluate_requirements(
		weituo_def: Dictionary,
		active_rec: Dictionary,
		_savedata: Dictionary,
		game_state: Node,
		require_active_progress: bool
) -> Array:
	var progress := active_rec.get("progress", {}) as Dictionary
	var inventory: Dictionary = {}
	if game_state != null and "inventory" in game_state:
		inventory = game_state.inventory
	var out: Array = []
	for req_v in weituo_def.get("requirements", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		var kind := str(req.get("kind", ""))
		if kind == "item":
			var item_id := _requirement_item_id(req)
			var need := maxi(1, int(req.get("count", 1)))
			var have := int(inventory.get(item_id, 0))
			out.append({
				"kind": "item",
				"id": item_id,
				"label": _item_label(req, item_id),
				"current_count": have,
				"required_count": need,
				"satisfied": have >= need,
				"consume": bool(req.get("consume", true)),
				"icon_path": _item_icon_path(item_id),
			})
		elif kind == "lilian":
			var location_id := str(req.get("location_id", ""))
			var min_steps := maxi(1, int(req.get("min_steps", 1)))
			var current_steps := int(progress.get("lilian_steps", 0)) if require_active_progress else 0
			var location_name := str(DidianService.by_id(location_id).get("name", location_id))
			var require_not_defeated := bool(req.get("require_not_defeated", false))
			var not_defeated := bool(progress.get("not_defeated", true)) if require_active_progress else true
			var steps_ok := current_steps >= min_steps
			var defeated_ok := (not require_not_defeated) or not_defeated
			out.append({
				"kind": "lilian",
				"label": location_name,
				"current_count": current_steps,
				"required_count": min_steps,
				"satisfied": steps_ok and defeated_ok,
				"unit": "步",
				"require_not_defeated": require_not_defeated,
				"not_defeated": not_defeated,
				"icon_path": "res://assets/art/ui_new/flag.png",
			})
	return out


static func _build_summary(requirements: Array) -> String:
	var parts: PackedStringArray = []
	for req_v in requirements:
		var req := req_v as Dictionary
		var kind := str(req.get("kind", ""))
		if kind == "item":
			parts.append(
				"%s %d/%d" % [
					str(req.get("label", "")),
					int(req.get("current_count", 0)),
					int(req.get("required_count", 0)),
				]
			)
		elif kind == "lilian":
			parts.append(
				"%s %d/%d 步" % [
					str(req.get("label", "")),
					int(req.get("current_count", 0)),
					int(req.get("required_count", 0)),
				]
			)
			if bool(req.get("require_not_defeated", false)):
				parts.append("未战败" if bool(req.get("not_defeated", true)) else "已战败")
	return " · ".join(parts)


static func _progress_ratio(requirements: Array) -> float:
	if requirements.is_empty():
		return 0.0
	var total := 0.0
	var sum := 0.0
	for req_v in requirements:
		var req := req_v as Dictionary
		var need := maxf(1.0, float(req.get("required_count", 1)))
		total += 1.0
		sum += clampf(float(req.get("current_count", 0)) / need, 0.0, 1.0)
	return sum / total


static func _type_label(weituo_def: Dictionary) -> String:
	for req_v in weituo_def.get("requirements", []) as Array:
		if req_v is Dictionary and str((req_v as Dictionary).get("kind", "")) == "lilian":
			return "历练"
	return "交付"


static func _offer_state(weituo_data: Dictionary, weituo_id: String, weituo_def: Dictionary) -> int:
	if not bool(weituo_def.get("repeatable", true)):
		var completed_once: Array = weituo_data.get("completed_once", []) as Array
		if weituo_id in completed_once:
			return EnumWeituoState.State.COMPLETED
	return EnumWeituoState.State.AVAILABLE


static func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	var state_a := int(a.get("state", EnumWeituoState.State.LOCKED))
	var state_b := int(b.get("state", EnumWeituoState.State.LOCKED))
	var order_a := EnumWeituoState.sort_order(state_a)
	var order_b := EnumWeituoState.sort_order(state_b)
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("weituo_id", "")) < str(b.get("weituo_id", ""))


static func _prepare_weituo_data(savedata: Dictionary, action: String) -> Dictionary:
	if not savedata.has("weituo"):
		push_error("[weituo_service:missing_state] action=%s field=weituo" % action)
		return {}
	return prepare_state_for_commit(savedata["weituo"], action)


static func _commit_weituo_data(savedata: Dictionary, candidate: Dictionary, action: String) -> bool:
	var prepared := prepare_state_for_commit(candidate, action)
	if prepared.is_empty():
		push_error("[weituo_service:invalid_commit] action=%s" % action)
		return false
	savedata["weituo"] = prepared
	return true


static func _validate_catalog_references(state: Dictionary, action: String) -> bool:
	var referenced_ids: Dictionary = {}
	for record_v in (state["active"] as Dictionary).values():
		var record := record_v as Dictionary
		referenced_ids[str(record["weituo_id"])] = "active"
	for weituo_id_v in state["completed_once"] as Array:
		referenced_ids[str(weituo_id_v)] = "completed_once"
	for weituo_id_v in (state["completed_count"] as Dictionary).keys():
		referenced_ids[str(weituo_id_v)] = "completed_count"
	for weituo_id_v in (state["board"] as Dictionary)["offer_ids"] as Array:
		referenced_ids[str(weituo_id_v)] = "board.offer_ids"
	for weituo_id_v in referenced_ids.keys():
		var weituo_id := str(weituo_id_v)
		if weituo_by_id(weituo_id).is_empty():
			push_error(
				"[weituo_service:unknown_reference] action=%s field=%s weituo_id=%s"
				% [action, str(referenced_ids[weituo_id_v]), weituo_id]
			)
			return false
	return true


static func _record_weituo_id(rec: Dictionary) -> String:
	return str(rec["weituo_id"])


static func _active_instance_for_weituo(active: Dictionary, weituo_id: String) -> String:
	for instance_id_v in active.keys():
		var rec := active[instance_id_v] as Dictionary
		if _record_weituo_id(rec) == weituo_id:
			return str(instance_id_v)
	return ""


## 从已解锁委托池中按 weight 抽取本周期榜单位（ponytail: 无种子随机，读档后空榜重抽可能变化）。
static func _pick_board_offer_ids(savedata: Dictionary, game_state: Node = null) -> Array:
	var weituo_data := _prepare_weituo_data(savedata, "pick_board_offer_ids")
	if weituo_data.is_empty():
		return []
	var completed_once: Array = weituo_data.get("completed_once", []) as Array
	var candidates: Array = []
	for weituo_id_v in weituo_dict().keys():
		var weituo_id := str(weituo_id_v)
		var weituo_def := weituo_by_id(weituo_id)
		if not is_unlocked(weituo_def, savedata, game_state):
			continue
		if not bool(weituo_def.get("repeatable", true)) and weituo_id in completed_once:
			continue
		var weight := maxi(0, int(weituo_def.get("weight", 1)))
		if weight > 0:
			candidates.append({"id": weituo_id, "weight": weight})
	var pick_count := mini(board_offer_count(), candidates.size())
	var picked: Array = []
	while picked.size() < pick_count:
		var total := 0
		for entry_v in candidates:
			total += int((entry_v as Dictionary).get("weight", 0))
		if total <= 0:
			break
		var roll := randi_range(1, total)
		for i in candidates.size():
			var entry := candidates[i] as Dictionary
			roll -= int(entry.get("weight", 0))
			if roll <= 0:
				picked.append(str(entry.get("id", "")))
				candidates.remove_at(i)
				break
	return picked


static func _item_label(req: Dictionary, item_id: String) -> String:
	var label := str(req.get("label", "")).strip_edges()
	if label != "":
		return label
	return InventoryQueryApplicationScript.display_name(item_id)


static func _item_icon_path(item_id: String) -> String:
	var def := _item_def(item_id)
	if def != null and def.icon_path != "":
		return def.icon_path
	return "res://assets/art/ui_new/item_cao.png"


static func _item_def(item_id: String) -> ItemDef:
	return InventoryQueryApplicationScript.definition_by_id(item_id)


static func _config_manager() -> Node:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("ConfigManager")


static func _requirement_item_id(req: Dictionary) -> String:
	var item_id := str(req.get("id", "")).strip_edges()
	if item_id != "":
		return item_id
	return str(req.get("item_id", "")).strip_edges()


static func _resolve_inventory(savedata: Dictionary, game_state: Node) -> Dictionary:
	if game_state != null and "inventory" in game_state:
		return game_state.inventory
	return savedata.get("inventory", {}) as Dictionary


static func _persist_inventory(savedata: Dictionary, game_state: Node, inventory: Dictionary) -> void:
	savedata["inventory"] = inventory
	if game_state != null and "inventory" in game_state:
		game_state.inventory = inventory


## 按委托配置扣除需交付的物品；提交前已由 can_submit 校验数量。
static func _consume_item_requirements(inventory: Dictionary, weituo_def: Dictionary) -> Dictionary:
	var missing: Array = []
	for req_v in weituo_def.get("requirements", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		if str(req.get("kind", "")) != "item" or not bool(req.get("consume", true)):
			continue
		var item_id := _requirement_item_id(req)
		var need := maxi(1, int(req.get("count", 1)))
		if item_id == "":
			continue
		var have := int(inventory.get(item_id, 0))
		if have < need:
			missing.append({
				"kind": "item",
				"id": item_id,
				"label": _item_label(req, item_id),
				"current_count": have,
				"required_count": need,
				"satisfied": false,
			})
	if not missing.is_empty():
		return {"ok": false, "error": "物品不足", "missing": missing}
	for req_v in weituo_def.get("requirements", []) as Array:
		if not req_v is Dictionary:
			continue
		var req := req_v as Dictionary
		if str(req.get("kind", "")) != "item" or not bool(req.get("consume", true)):
			continue
		var item_id := _requirement_item_id(req)
		var need := maxi(1, int(req.get("count", 1)))
		if item_id == "":
			continue
		var removed := InventoryApplicationScript.remove_item(inventory, item_id, need)
		if removed < need:
			push_error("WeituoService: item consume mismatch for %s (%d/%d)" % [item_id, removed, need])
			return {"ok": false, "error": "扣除物品失败", "missing": []}
	return {"ok": true}


static func _emit_inventory_changed() -> void:
	var bus := Engine.get_main_loop()
	if not bus is SceneTree:
		return
	var data_events := (bus as SceneTree).root.get_node_or_null("DataEvents")
	if data_events != null and data_events.has_method("emit_inventory_changed"):
		data_events.call("emit_inventory_changed")


static func _append_activity(game_state: Node, text: String) -> void:
	if game_state == null:
		return
	var day := int(game_state.day) if "day" in game_state else 1
	var activity_log_rows: Array = game_state.activity_log if "activity_log" in game_state else []
	activity_log_rows.append({"day": day, "text": text})
	if activity_log_rows.size() > 30:
		activity_log_rows = activity_log_rows.slice(activity_log_rows.size() - 30)
	game_state.activity_log = activity_log_rows
