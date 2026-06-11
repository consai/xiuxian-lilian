class_name FightSceneBootstrap
extends RefCounted

## 战斗场景进战初始化与开战启动。

const EnemyAiRuntimeStateScript = preload("res://scripts/fight/ai/enemy_ai_runtime_state.gd")


static func try_initialize(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		editor_battle_init: Dictionary,
		editor_auto_sample: bool,
		tree: SceneTree
) -> bool:
	var envelope := BattleInitData.take_pending_envelope(tree)
	var data: Dictionary = {}
	if envelope.has("payload"):
		var payload_v: Variant = envelope.get("payload", {})
		data = payload_v as Dictionary if payload_v is Dictionary else {}
	ctx.battle_source = str(envelope.get("source", ""))
	if data.is_empty() and not editor_battle_init.is_empty():
		data = editor_battle_init.duplicate(true)
	if data.is_empty() and editor_auto_sample and OS.has_feature("editor"):
		data = BattleInitData.sample_for_editor()
		push_warning(
			"FightScene: 编辑器直开，已使用 sample_for_editor()。"
			+ "正式进战请 BattleInitData.set_pending(tree, data)（写入 DataStore）。"
		)
	if data.is_empty():
		push_error(
			"FightScene: 缺少战斗初始化数据。请 BattleInitData.set_pending(tree, data) 写入 DataStore 后切场景，"
			+ "或在编辑器填写 editor_battle_init（或开启 editor_auto_sample）。"
		)
		return false
	return initialize_battle(ctx, hud, data)


static func initialize_battle(ctx: FightSceneContext, hud: FightSceneHud, data: Dictionary) -> bool:
	return apply_battle_setup(ctx, hud, BattleInitData.resolve(data))


static func apply_battle_setup(ctx: FightSceneContext, hud: FightSceneHud, setup: BattleSetup) -> bool:
	if setup == null:
		push_error("FightScene: BattleInitData.resolve 失败，无法开战")
		return false
	ctx.battle_player = setup.player
	ctx.battle_enemy = setup.enemy
	ctx.skill_cfg = setup.skill_cfg
	ctx.battle_time_limit = setup.battle_time_limit
	apply_auto_battle_from_init(ctx, hud, setup.auto_battle)
	ctx.battle_session_id = setup.battle_session_id
	ctx.record_names = setup.record_names.duplicate(true)
	ctx.item_cfg = setup.item_cfg.duplicate(true)
	ctx.equip_cfg = setup.equip_cfg.duplicate(true)
	ctx.enemy_ai_cfg = setup.get_enemy_ai_cfg()
	ctx.enemy_ai_runtime = EnemyAiRuntimeStateScript.new()
	ctx.player_ai_cfg = setup.get_player_ai_cfg()
	ctx.player_ai_runtime = EnemyAiRuntimeStateScript.new()
	hud.apply_battle(ctx, setup.ui_payload)
	hud.register_battle_actors(ctx)
	start_battle(ctx, hud)
	BattleDebugLog.write("场景", "战斗初始化完成", {
		"玩家气血": ctx.battle_player.hp,
		"敌方气血": ctx.battle_enemy.hp,
		"玩家速度": ctx.battle_player.get_attr(FightObj.ATTR_SPD),
		"玩家走条周期": CombatBalance.interval_cap_for(ctx.battle_player),
		"敌方速度": ctx.battle_enemy.get_attr(FightObj.ATTR_SPD),
		"敌方走条周期": CombatBalance.interval_cap_for(ctx.battle_enemy),
		"时限": ctx.battle_time_limit,
	})
	return true


static func start_battle(ctx: FightSceneContext, hud: FightSceneHud) -> void:
	ctx.domain = BattleDomainService.new()
	BattleDebugLog.set_domain(ctx.domain)
	ctx.domain.start_battle(
		ctx.battle_player,
		ctx.battle_enemy,
		ctx.skill_cfg,
		ctx.battle_time_limit,
		ctx.item_cfg,
		ctx.equip_cfg
	)
	if ctx.recorder != null:
		ctx.recorder.begin({
			"session_id": ctx.battle_session_id,
			"player_name": str(ctx.record_names.get(BattleRecordTypes.UNIT_PLAYER, "")),
			"enemy_name": str(ctx.record_names.get(BattleRecordTypes.UNIT_ENEMY, "")),
		})
	var float_layer := hud.get_float_layer()
	if float_layer != null:
		float_layer.clear_all()
	hud.clear_battle_log()
	hud.sync_from_domain(ctx)
	hud.sync_runtime_slot_interactive(ctx)
	hud.update_skill_input_enabled(ctx)


static func apply_auto_battle_from_init(
		ctx: FightSceneContext,
		hud: FightSceneHud,
		auto_battle: Dictionary
) -> void:
	if auto_battle.is_empty():
		return
	if auto_battle.has("player"):
		ctx.auto_battle_player = bool(auto_battle["player"])
	if auto_battle.has("enemy"):
		ctx.auto_battle_enemy = bool(auto_battle["enemy"])
	hud.sync_auto_battle_ui(ctx)
