extends Control

const LilianBattleFlow := preload("res://scripts/lilian/lilian_battle_flow.gd")
const LilianRulesServiceScript := preload("res://scripts/lilian/lilian_rules_service.gd")

## 战斗场景编排层：布局在 [code]zhandou_changjing.tscn[/code]，逻辑按职责拆至 [code]scripts/zhandou/scene/[/code]。
## 域层 [ZhandouDomainService]、表现 [ZhandouChangjingPresentation]、HUD [ZhandouChangjingHud] 各司其职。

signal skill_slot_pressed(index: int)
signal equip_slot_pressed(index: int)
signal item_slot_pressed(index: int)
signal battle_finished(summary: Dictionary)

@export_group("Auto Battle")
@export var default_auto_battle_player: bool = false
@export var default_auto_battle_enemy: bool = true

@export_group("Editor")
@export var editor_battle_init: Dictionary = {}
@export var editor_auto_sample: bool = true

@export_group("Debug")
@export var battle_debug_enabled: bool = false
@export var battle_debug_verbose_tick: bool = false

@onready var _head_left: TextureRect = %head_left
@onready var _rolename_left: Label = %rolename_left
@onready var _hp_bar_left: ProgressBar = %shengming_left
@onready var _hp_val_left: Label = %hp_val_left
@onready var _shield_bar_left: ProgressBar = %shield_left
@onready var _shield_badge_left: HBoxContainer = %shield_badge_left
@onready var _shield_val_left: Label = %shield_val_left
@onready var _mp_bar_left: ProgressBar = %fali_left
@onready var _mp_val_left: Label = %mp_val_left
@onready var _buff_status_left: BuffStatusBar = %buff_status_left
@onready var _head_right: TextureRect = %head_right
@onready var _rolename_right: Label = %rolename_right
@onready var _hp_bar_right: ProgressBar = %shengming_right
@onready var _hp_val_right: Label = %hp_val_right
@onready var _shield_bar_right: ProgressBar = %shield_right
@onready var _shield_badge_right: HBoxContainer = %shield_badge_right
@onready var _shield_val_right: Label = %shield_val_right
@onready var _mp_bar_right: ProgressBar = %fali_right
@onready var _mp_val_right: Label = %mp_val_right
@onready var _buff_status_right: BuffStatusBar = %buff_status_right
@onready var _interval_left: IntervalTrackView = %interval_left
@onready var _interval_right: IntervalTrackView = %interval_right
@onready var _fighttime: Label = %fighttime
@onready var _sprite_left: EnemyFormationSlotView = %sprite_left
@onready var _sprite_right: Sprite2D = %sprite_right
@onready var _center: Control = %center
@onready var _chk_auto_player: CheckButton = %auto
@onready var _vfx: ZhandouVfxManager = %ZhandouVfxManager
@onready var _float_layer: ZhandouFloatLayer = %ZhandouFloatLayer
@onready var _battle_log_panel = %BattleLogPanel
@onready var _battle_result_overlay = %BattleResultOverlay
@onready var _escape_button: TextureButton = %EscapeButton

var _ctx := ZhandouChangjingContext.new()
var _hud := ZhandouChangjingHud.new()
var _input := ZhandouChangjingInput.new()
var _presentation := ZhandouChangjingPresentation.new()
var _combat := ZhandouChangjingFlow.new()

var skill_cfg: Dictionary:
	get:
		return _ctx.skill_cfg


func _ready() -> void:
	ZhandouDebugLog.enabled = battle_debug_enabled
	ZhandouDebugLog.verbose_tick = battle_debug_verbose_tick
	_ctx.scene = self
	_bind_modules()
	_collect_slot_arrays()
	_input.bind_signals(self)
	_input.setup_auto_battle(default_auto_battle_player, default_auto_battle_enemy)
	_hud.setup_battle_vfx(_ctx)
	if not item_slot_pressed.is_connected(_on_item_slot_pressed):
		item_slot_pressed.connect(_on_item_slot_pressed)
	if not equip_slot_pressed.is_connected(_on_equip_slot_pressed):
		equip_slot_pressed.connect(_on_equip_slot_pressed)
	if not battle_finished.is_connected(_on_battle_finished):
		battle_finished.connect(_on_battle_finished)
	var vfx := _hud.get_vfx()
	if vfx != null:
		if not vfx.event_finished.is_connected(_on_vfx_event_finished):
			vfx.event_finished.connect(_on_vfx_event_finished)
		if not vfx.queue_finished.is_connected(_on_vfx_queue_finished):
			vfx.queue_finished.connect(_on_vfx_queue_finished)
	var battle_envelope := SceneManager.take_payload(SceneManager.ZHANDOU_CHANGJING)
	_ctx.init_ok = ZhandouChangjingBootstrap.try_initialize(
		_ctx, _hud, editor_battle_init, editor_auto_sample, battle_envelope
	)
	if not _ctx.init_ok:
		set_process(false)
		return
	if _battle_result_overlay != null and _battle_result_overlay.has_signal("close_requested"):
		if not _battle_result_overlay.is_connected("close_requested", _on_battle_result_close_requested):
			_battle_result_overlay.connect("close_requested", _on_battle_result_close_requested)
	call_deferred("_sync_after_init")
	set_process(true)


func _bind_modules() -> void:
	var refs := ZhandouChangjingHudRefs.new()
	refs.head_left = _head_left
	refs.rolename_left = _rolename_left
	refs.hp_bar_left = _hp_bar_left
	refs.hp_val_left = _hp_val_left
	refs.shield_bar_left = _shield_bar_left
	refs.shield_badge_left = _shield_badge_left
	refs.shield_val_left = _shield_val_left
	refs.mp_bar_left = _mp_bar_left
	refs.mp_val_left = _mp_val_left
	refs.buff_status_left = _buff_status_left
	refs.head_right = _head_right
	refs.rolename_right = _rolename_right
	refs.hp_bar_right = _hp_bar_right
	refs.hp_val_right = _hp_val_right
	refs.shield_bar_right = _shield_bar_right
	refs.shield_badge_right = _shield_badge_right
	refs.shield_val_right = _shield_val_right
	refs.mp_bar_right = _mp_bar_right
	refs.mp_val_right = _mp_val_right
	refs.buff_status_right = _buff_status_right
	refs.interval_left = _interval_left
	refs.interval_right = _interval_right
	refs.fighttime = _fighttime
	refs.sprite_left = _sprite_left
	refs.sprite_right = _sprite_right
	refs.center = _center
	refs.chk_auto_player = _chk_auto_player
	refs.vfx = _vfx
	refs.float_layer = _float_layer
	refs.battle_log_panel = _battle_log_panel
	refs.battle_result_overlay = _battle_result_overlay
	refs.escape_button = _escape_button
	_hud.bind(refs)
	_input.setup(
		_ctx,
		_hud,
		Callable(self, "_on_skill_slot_pressed"),
		Callable(self, "_schedule_player_side_act"),
		Callable(self, "_on_escape_pressed")
	)


func _collect_slot_arrays() -> void:
	_ctx.skill_slots.assign([
		%skill_1 as OneSkillView,
		%skill_2 as OneSkillView,
		%skill_3 as OneSkillView,
		%skill_4 as OneSkillView,
		%skill_5 as OneSkillView,
	])
	_ctx.equip_slots.assign([
		%equip_1 as OneSkillView,
	])
	_ctx.item_slots.assign([
		%item_1 as OneSkillView,
		%item_2 as OneSkillView,
		%item_3 as OneSkillView,
	])


func _sync_after_init() -> void:
	_hud.sync_from_domain(_ctx)
	_hud.sync_runtime_slot_interactive(_ctx)
	_hud.update_skill_input_enabled(_ctx)


func _process(delta: float) -> void:
	_combat.process_frame(_ctx, _hud, _presentation, delta)


func _unhandled_input(event: InputEvent) -> void:
	_input.handle_unhandled_input(event, self)


func _exit_tree() -> void:
	ZhandouDebugLog.clear_domain()


## 由 [ZhandouInitData.resolve] 消费进战数据；外部通过 BattleStartApplication 导航并提交 payload。
func initialize_battle(data: Dictionary) -> bool:
	return ZhandouChangjingBootstrap.initialize_battle(_ctx, _hud, data)


func apply_battle(data: Dictionary) -> void:
	_hud.apply_battle(_ctx, data)


func set_interval(side: String, elapsed: float, cap: float) -> void:
	_hud.set_interval(side, elapsed, cap)


func set_combatant_vitals(side: String, hp: float, hp_max: float, mp: float, mp_max: float) -> void:
	_hud.set_combatant_vitals(side, hp, hp_max, mp, mp_max)


func set_combatant_shield(side: String, shield: float, hp_max: float) -> void:
	_hud.set_combatant_shield(side, shield, hp_max)


func enqueue_battle_vfx(data: Dictionary) -> void:
	_presentation.enqueue_battle_vfx(_ctx, _hud, data)


func play_battle_vfx_queue() -> void:
	await _presentation.play_battle_vfx_queue(_hud)


func _deferred_register_vfx_actors() -> void:
	_hud.register_battle_actors(_ctx)


func _schedule_player_side_act() -> void:
	_combat.schedule_side_act(_ctx, EnumBattleSide.PLAYER)


func _deferred_side_act(side: String) -> void:
	await _combat.side_act_and_present(
		_ctx,
		_hud,
		_presentation,
		side,
		Callable(self, "_on_presentation_battle_end")
	)


func _on_presentation_battle_end(reason: String) -> void:
	_combat.return_battle_end(_ctx, _hud, reason)


func _on_skill_slot_pressed(index: int) -> void:
	await _combat.on_skill_pressed(
		_ctx,
		_hud,
		_presentation,
		index,
		Callable(self, "_on_presentation_battle_end")
	)


func _on_item_slot_pressed(index: int) -> void:
	await _combat.on_item_pressed(
		_ctx,
		_hud,
		_presentation,
		index,
		Callable(self, "_on_presentation_battle_end")
	)


func _on_equip_slot_pressed(index: int) -> void:
	await _combat.on_equip_pressed(
		_ctx,
		_hud,
		_presentation,
		index,
		Callable(self, "_on_presentation_battle_end")
	)


func _on_escape_pressed() -> void:
	_combat.on_escape_pressed(_ctx, _hud)


func _on_vfx_event_finished(_event: ZhandouVfxEvent) -> void:
	_presentation.on_vfx_event_finished(_ctx, _hud)


func _on_vfx_queue_finished() -> void:
	_presentation.on_vfx_queue_finished(_ctx)


func _on_battle_result_close_requested() -> void:
	if LilianBattleFlow.is_lilian_source(_ctx.battle_source):
		LilianBattleFlow.handle_result_close()
		return
	_hud.hide_battle_result()


func _on_battle_finished(summary: Dictionary) -> void:
	if LilianBattleFlow.is_lilian_source(_ctx.battle_source):
		LilianBattleFlow.handle_battle_finished(summary)
		_schedule_lilian_auto_result_close()
		return
	GameState.apply_battle_player_runtime(summary)


func _schedule_lilian_auto_result_close() -> void:
	if not _ctx.auto_battle_player:
		return
	var wait := float(LilianRulesServiceScript.rules()["auto_event_advance_seconds"])
	get_tree().create_timer(wait).timeout.connect(
		_on_battle_result_close_requested,
		CONNECT_ONE_SHOT
	)


## GM 战斗调试：暴露域层上下文（仅调试面板使用）。
func gm_get_context() -> ZhandouChangjingContext:
	return _ctx


## GM 战斗调试：将域层状态同步到战斗 HUD。
func gm_sync_hud() -> void:
	if _ctx.domain == null:
		return
	_hud.sync_from_domain(_ctx)
	_hud.sync_runtime_slot_interactive(_ctx)
	_hud.update_skill_input_enabled(_ctx)
