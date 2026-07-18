class_name GmBattleAccess
extends RefCounted

## GM 战斗调试：定位当前战斗场景并读写 [ZhandouObj] / 战斗行数据。

static var _game_session: Node


static func bind_game_session(game_session: Node) -> void:
	if game_session == null:
		push_error("GmBattleAccess: GameSession 未注入")
		return
	_game_session = game_session


static func is_in_battle() -> bool:
	return battle_scene() != null


static func battle_scene() -> Control:
	var sm: Node = _scene_manager()
	if sm == null or not sm.has_method("get_active_scene"):
		return null
	var active: Node = sm.call("get_active_scene") as Node
	if active != null and _is_battle_scene(active):
		return active as Control
	return null


static func context() -> ZhandouChangjingContext:
	var scene: Control = battle_scene()
	if scene == null:
		return null
	return scene.call("gm_get_context") as ZhandouChangjingContext


static func sync_hud() -> void:
	var scene: Control = battle_scene()
	if scene != null and scene.has_method("gm_sync_hud"):
		scene.call("gm_sync_hud")


## 返回当前战场单位列表；每项含 key/index/label/unit/row/is_player。
static func list_units() -> Array:
	var ctx: ZhandouChangjingContext = context()
	if ctx == null or ctx.domain == null:
		return []
	var out: Array = []
	var player: ZhandouObj = ctx.domain.player
	if player != null:
		out.append({
			"key": "player",
			"index": 0,
			"label": str(ctx.battle_player_row.get("name", "玩家")),
			"unit": player,
			"row": ctx.battle_player_row,
			"is_player": true,
		})
	for i in ctx.domain.enemies.size():
		var unit_v: Variant = ctx.domain.enemies[i]
		if not unit_v is ZhandouObj:
			continue
		var unit: ZhandouObj = unit_v as ZhandouObj
		var row: Dictionary = {}
		if i < ctx.battle_enemy_rows.size() and ctx.battle_enemy_rows[i] is Dictionary:
			row = ctx.battle_enemy_rows[i] as Dictionary
		var label: String = str(row.get("name", "敌方 %d" % (i + 1)))
		out.append({
			"key": "enemy",
			"index": i,
			"label": label,
			"unit": unit,
			"row": row,
			"is_player": false,
		})
	return out


static func entry_at(list_index: int) -> Dictionary:
	var units: Array = list_units()
	if list_index < 0 or list_index >= units.size():
		return {}
	var entry_v: Variant = units[list_index]
	return entry_v as Dictionary if entry_v is Dictionary else {}


static func passive_ids_for_entry(entry: Dictionary) -> Array:
	if entry.is_empty():
		return []
	var row_v: Variant = entry.get("row", {})
	if not row_v is Dictionary:
		return []
	var row: Dictionary = row_v as Dictionary
	var stored_v: Variant = row.get("gm_passives", null)
	if stored_v is Array:
		return (stored_v as Array).duplicate()
	if bool(entry.get("is_player", false)):
		return _player_passive_ids_from_save()
	return []


static func set_passive_ids_for_entry(entry: Dictionary, passive_ids: Array) -> void:
	if entry.is_empty():
		return
	var row_v: Variant = entry.get("row", {})
	if not row_v is Dictionary:
		return
	var row: Dictionary = row_v as Dictionary
	row["gm_passives"] = passive_ids.duplicate()
	if bool(entry.get("is_player", false)):
		_sync_player_unlocked_passives(passive_ids)
	var unit_v: Variant = entry.get("unit")
	if unit_v is ZhandouObj:
		(unit_v as ZhandouObj).sync_passive_ids(passive_ids)


static func _player_passive_ids_from_save() -> Array:
	var gs: Node = _game_state()
	if gs == null:
		return []
	var out: Array = []
	for aid_v in gs.get("unlocked_abilities") as Array:
		var aid: String = str(aid_v).strip_edges()
		if aid == "":
			continue
		var row: Dictionary = AbilityService.by_id(aid)
		if row.is_empty():
			continue
		if AbilityService.is_always_active_passive(str(row.get("type", ""))):
			out.append(aid)
	return out


static func _sync_player_unlocked_passives(passive_ids: Array) -> void:
	var gs: Node = _game_state()
	if gs == null:
		return
	var unlocked: Array = (gs.get("unlocked_abilities") as Array).duplicate()
	for aid_v in passive_ids:
		var aid: String = str(aid_v).strip_edges()
		if aid == "" or unlocked.has(aid):
			continue
		unlocked.append(aid)
	gs.set("unlocked_abilities", unlocked)


static func _is_battle_scene(node: Node) -> bool:
	return node.has_method("gm_get_context") and node.has_method("gm_sync_hud")


static func _scene_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("SceneManager")


static func _game_state() -> Node:
	return _game_session
