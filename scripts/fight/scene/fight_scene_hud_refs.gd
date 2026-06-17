class_name FightSceneHudRefs
extends RefCounted

## [FightSceneHud] 所需的场景节点引用集合。

var head_left: TextureRect
var rolename_left: Label
var hp_bar_left: ProgressBar
var hp_val_left: Label
var shield_bar_left: ProgressBar
var shield_badge_left: HBoxContainer
var shield_val_left: Label
var mp_bar_left: ProgressBar
var mp_val_left: Label
var buff_status_left: BuffStatusBar

var head_right: TextureRect
var rolename_right: Label
var hp_bar_right: ProgressBar
var hp_val_right: Label
var shield_bar_right: ProgressBar
var shield_badge_right: HBoxContainer
var shield_val_right: Label
var mp_bar_right: ProgressBar
var mp_val_right: Label
var buff_status_right: BuffStatusBar

var interval_left: IntervalTrackView
var interval_right: IntervalTrackView
var fighttime: Label
var sprite_left: EnemyFormationSlotView
var sprite_right: Sprite2D
var center: Control
var chk_auto_player: CheckButton
var vfx: FightVfxManager
var float_layer: CombatFloatLayer
var battle_log_panel: Node
var battle_result_overlay: Node
