class_name ZhandouChangjingContext
extends RefCounted

## 战斗场景共享状态：域层、单位、配置与运行时标志。

const SCENE_ID := "zhandou_changjing"
const UNIT_PLAYER := "player"
const UNIT_ENEMY := "enemy"

var scene: Control

var domain: ZhandouDomainService
var battle_player: ZhandouObj
var battle_enemy: ZhandouObj
var battle_enemies: Array = []
var battle_enemy_rows: Array = []
var battle_player_row: Dictionary = {}
var enemy_formation: Dictionary = {}

var skill_cfg: Dictionary = {}
var item_cfg: Dictionary = {}
var equip_cfg: Dictionary = {}
var enemy_ai_cfg: Dictionary = {}
var enemy_ai_runtime: EnemyAiRuntimeState
var enemy_ai_runtimes: Array = []
var player_ai_cfg: Dictionary = {}
var player_ai_runtime: EnemyAiRuntimeState

var battle_time_limit: float = 0.0
var battle_session_id: String = ""
var battle_source: String = ""
var battle_flags: Dictionary = {}
var escape_bonus: float = 0.0
var escape_fail_count: int = 0
var record_names: Dictionary = {}

var recorder = ZhandouRecorder.new()
var record_formatter = ZhandouRecordFormatter.new()

var presentation_busy: bool = false
var player_act_scheduled: bool = false
var enemy_act_scheduled: bool = false

var auto_battle_player: bool = false
var auto_battle_enemy: bool = true
var init_ok: bool = false

var skill_slots: Array[OneSkillView] = []
var equip_slots: Array[OneSkillView] = []
var item_slots: Array[OneSkillView] = []
var skill_slot_interactive: Array[bool] = []
var equip_slot_interactive: Array[bool] = []
var item_slot_interactive: Array[bool] = []
