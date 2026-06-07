class_name BattleSetup
extends RefCounted
## [BattleInitData.resolve] 产出的单场战斗快照：逻辑单位、配置表与 UI 展示数据同源。

var player: FightObj
var enemy: FightObj
var player_row: Dictionary = {}
var enemy_row: Dictionary = {}
var skill_cfg: Dictionary = {}
var item_cfg: Dictionary = {}
var equip_cfg: Dictionary = {}
var battle_time_limit: float = 200.0
var battle_session_id: String = ""
var auto_battle: Dictionary = {}
var ui_payload: Dictionary = {}
var record_names: Dictionary = {}


func get_enemy_ai_cfg() -> Dictionary:
	var ai_v: Variant = enemy_row.get("ai")
	return (ai_v as Dictionary).duplicate(true) if ai_v is Dictionary else {}
