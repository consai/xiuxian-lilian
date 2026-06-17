class_name BattleSetup
extends RefCounted
## [BattleInitData.resolve] 产出的单场战斗快照：逻辑单位、配置表与 UI 展示数据同源。

var player: FightObj
var enemy: FightObj
var enemies: Array = []
var player_row: Dictionary = {}
var enemy_row: Dictionary = {}
var enemy_rows: Array = []
var skill_cfg: Dictionary = {}
var item_cfg: Dictionary = {}
var equip_cfg: Dictionary = {}
var battle_time_limit: float = 200.0
var battle_session_id: String = ""
var auto_battle: Dictionary = {}
var enemy_formation: Dictionary = {}
var ui_payload: Dictionary = {}
var record_names: Dictionary = {}


func get_enemy_ai_cfg() -> Dictionary:
	var ai_v: Variant = enemy_row.get("ai")
	return (ai_v as Dictionary).duplicate(true) if ai_v is Dictionary else {}


func get_enemy_ai_cfg_at(index: int) -> Dictionary:
	if index < 0 or index >= enemy_rows.size():
		return get_enemy_ai_cfg()
	var row_v: Variant = enemy_rows[index]
	if not row_v is Dictionary:
		return {}
	var ai_v: Variant = (row_v as Dictionary).get("ai")
	return (ai_v as Dictionary).duplicate(true) if ai_v is Dictionary else {}


func get_player_ai_cfg() -> Dictionary:
	var ai_v: Variant = player_row.get("ai")
	return (ai_v as Dictionary).duplicate(true) if ai_v is Dictionary else {}
