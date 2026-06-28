class_name ZhandouVfxManager
extends Node

const _EXECUTOR := preload("res://scripts/zhandou/vfx/zhandou_action_executor.gd")
const _RESOLVER := preload("res://scripts/zhandou/vfx/zhandou_vfx_sequence_resolver.gd")
const _CTX := preload("res://scripts/zhandou/vfx/zhandou_vfx_context.gd")
const _LIB := preload("res://scripts/zhandou/vfx/zhandou_vfx_preset_library.gd")

## 战斗表现调度器：接收 [ZhandouVfxEvent]，按 JSON 动作序列串行播放，与 [ZhandouObj] 逻辑解耦。
##
## 用法示例：
## [codeblock]
## var vfx := ZhandouVfxManager.new()
## add_child(vfx)
## vfx.register_actor("player", sprite_left)
## vfx.register_actor("enemy", sprite_right)
## vfx.set_screen_shake_target(center_control)
## vfx.enqueue(ZhandouVfxEvent.from_dict({...}))
## await vfx.play_queue()
## [/codeblock]

signal event_started(event: ZhandouVfxEvent)
signal event_finished(event: ZhandouVfxEvent)
signal queue_finished

## 全局表现参数；各角色未单独指定时使用此资源。
@export var settings: ZhandouVfxSettings

var _actors: Dictionary = {} # id -> ZhandouActorVfx
var _queue: Array[ZhandouVfxEvent] = []
var _busy: bool = false
const PRESENTATION_EVENT_TIMEOUT_SEC := 12.0
var _shake_target: CanvasItem
var _shake_rest: Vector2 = Vector2.ZERO
var _projectile_parent: Node
var _preset_library: ZhandouVfxPresetLibrary
var _executor: ZhandouActionExecutor


func _ready() -> void:
	if settings == null:
		settings = ZhandouVfxSettings.new()
	_projectile_parent = self
	_preset_library = _LIB.load_default()
	_executor = _EXECUTOR.new()
	call_deferred("refresh_all_actors")


func set_projectile_parent(node: Node) -> void:
	_projectile_parent = node if node != null else self


func set_screen_shake_target(target: CanvasItem) -> void:
	_shake_target = target
	if is_instance_valid(_shake_target):
		_shake_rest = _shake_target.position


func register_actor(unit_id: String, sprite: Node2D, vfx_settings: ZhandouVfxSettings = null) -> ZhandouActorVfx:
	var id := unit_id.strip_edges()
	if id == "" or sprite == null:
		return null
	var resolved := _resolve_settings(vfx_settings)
	var vfx := sprite.get_node_or_null("ZhandouActorVfx") as ZhandouActorVfx
	if vfx == null:
		vfx = ZhandouActorVfx.new()
		vfx.name = "ZhandouActorVfx"
		if resolved != null:
			vfx.settings = resolved
		sprite.add_child(vfx)
	else:
		vfx.bind_actor(sprite)
	if resolved != null:
		vfx.apply_settings(resolved)
	_actors[id] = vfx
	if ZhandouDebugLog.enabled:
		ZhandouDebugLog.write("特效", "注册战斗角色", _actor_debug_row(id, sprite, vfx, "新建"))
	return vfx


## 已注册则仅重新绑定 Sprite；避免每次出手都 apply_settings 打断位移。
func ensure_actor_registered(unit_id: String, sprite: Node2D, vfx_settings: ZhandouVfxSettings = null) -> ZhandouActorVfx:
	var id := unit_id.strip_edges()
	if id == "" or sprite == null:
		return null
	var existing := get_actor_vfx(id)
	if existing != null and is_instance_valid(existing):
		existing.bind_actor(sprite)
		_actors[id] = existing
		return existing
	return register_actor(id, sprite, vfx_settings)


func _resolve_settings(override_settings: ZhandouVfxSettings) -> ZhandouVfxSettings:
	if override_settings != null:
		return override_settings
	return settings


## 将当前 [member settings] 同步到已注册的全部单位（改 Inspector 参数后可调用）。
func refresh_all_actors() -> void:
	var resolved := settings
	if resolved == null:
		return
	for unit_id in _actors.keys():
		var vfx: ZhandouActorVfx = _actors[unit_id] as ZhandouActorVfx
		if vfx != null and is_instance_valid(vfx):
			vfx.apply_settings(resolved)


func unregister_actor(unit_id: String) -> void:
	_actors.erase(unit_id.strip_edges())


func get_actor_vfx(unit_id: String) -> ZhandouActorVfx:
	return _actors.get(unit_id.strip_edges(), null) as ZhandouActorVfx


func enqueue(event: ZhandouVfxEvent) -> void:
	if event == null:
		return
	_queue.append(event)


func enqueue_dict(data: Dictionary) -> void:
	enqueue(ZhandouVfxEvent.from_dict(data))


func clear_queue() -> void:
	_queue.clear()


func is_playing() -> bool:
	return _busy


## 串行播放队列；返回后整队播完。若已有队列在播，则等待其结束。
func play_queue() -> void:
	while _busy:
		ZhandouDebugLog.write("特效", "等待上一段特效队列")
		await queue_finished
	_busy = true
	ZhandouDebugLog.write("特效", "开始播放队列", {"待播数量": _queue.size()})
	while not _queue.is_empty():
		var ev: ZhandouVfxEvent = _queue.pop_front()
		await play_event(ev)
	_busy = false
	ZhandouDebugLog.write("特效", "队列播放完毕")
	queue_finished.emit()


func play_event(event: ZhandouVfxEvent) -> void:
	if event == null:
		return
	ZhandouDebugLog.write("特效", "播放事件", {
		"来源": ZhandouDebugLog.side_label(event.source_id),
		"目标": ZhandouDebugLog.side_label(event.target_id),
		"类型": ZhandouDebugLog.skill_type_label(event.skill_type),
		"伤害": event.damage_value,
	})
	event_started.emit(event)
	await _play_sequence_event(event)
	ZhandouDebugLog.write("特效", "事件播放完毕", {
		"来源": ZhandouDebugLog.side_label(event.source_id),
		"目标": ZhandouDebugLog.side_label(event.target_id),
	})
	event_finished.emit(event)


func _play_sequence_event(event: ZhandouVfxEvent) -> void:
	if _preset_library == null:
		_preset_library = _LIB.load_default()
	var steps := _RESOLVER.resolve(event, _preset_library)
	if steps.is_empty():
		ZhandouDebugLog.write("特效", "中止（无动作序列）")
		return
	var ctx := _build_context(event)
	var caster_vfx := ctx.get_vfx(event.source_id)
	var target_vfx := ctx.get_vfx(event.target_id)
	var needs_caster_motion := event.skill_type in [
		EnumBattleVfxSkillType.Type.MELEE,
		EnumBattleVfxSkillType.Type.RANGED,
	]
	if needs_caster_motion and caster_vfx == null:
		ZhandouDebugLog.write("特效", "中止（施法者未注册）", {
			"来源ID": event.source_id,
			"目标ID": event.target_id,
		})
		push_warning(
			"ZhandouVfxManager: 施法者 '%s' 未注册，近战/远程位移不会播放" % event.source_id
		)
		return
	if caster_vfx == null and target_vfx == null:
		ZhandouDebugLog.write("特效", "中止（角色未注册）", {
			"来源ID": event.source_id,
			"目标ID": event.target_id,
		})
		return
	var preset_label := _event_preset_label(event)
	ZhandouDebugLog.write("特效", "动作序列开始", {
		"preset": preset_label,
		"步骤数": steps.size(),
		"施法者": _vfx_actor_snapshot(caster_vfx),
		"目标": _vfx_actor_snapshot(target_vfx),
		"windup偏移": settings.melee_windup_offset if settings != null else -1.0,
		"冲锋时长": settings.melee_dash_duration if settings != null else -1.0,
	})
	ctx.prepare_caster_action()
	var caster_after := ctx.get_vfx(event.source_id)
	ZhandouDebugLog.write("特效", "施法者动作前快照", {
		"施法者": _vfx_actor_snapshot(caster_after),
	})
	var wait_sec := 0.0
	var seq_done := {"ok": false}
	_run_sequence_async(ctx, steps, func() -> void:
		seq_done.ok = true
	)
	while not seq_done.ok and is_instance_valid(self):
		await get_tree().process_frame
		wait_sec += get_process_delta_time()
		if wait_sec >= PRESENTATION_EVENT_TIMEOUT_SEC:
			push_warning("ZhandouVfxManager: presentation sequence timeout")
			ZhandouDebugLog.write("特效", "动作序列等待超时", {"已等待秒": wait_sec})
			break
	_restore_event_actors(ctx, event)
	ZhandouDebugLog.write("特效", "动作序列结束", {
		"preset": preset_label,
		"耗时秒": "%.3f" % wait_sec,
		"施法者": _vfx_actor_snapshot(ctx.get_vfx(event.source_id)),
		"目标": _vfx_actor_snapshot(ctx.get_vfx(event.target_id)),
	})


func _run_sequence_async(ctx: ZhandouVfxContext, steps: Array, on_done: Callable) -> void:
	await _executor.play_sequence(ctx, steps)
	if on_done.is_valid():
		on_done.call()


func _restore_event_actors(ctx: ZhandouVfxContext, event: ZhandouVfxEvent) -> void:
	if ctx == null or event == null:
		return
	_restore_single_actor(ctx.get_vfx(event.source_id))
	_restore_single_actor(ctx.get_vfx(event.target_id))


func _restore_single_actor(vfx: ZhandouActorVfx) -> void:
	if vfx == null or not is_instance_valid(vfx):
		return
	var actor := vfx.get_actor()
	if not is_instance_valid(actor):
		return
	vfx.kill_action_tween()
	vfx.kill_hit_tween()
	vfx.stop_idle()
	vfx.reset_pose()
	vfx.start_idle()


func _build_context(event: ZhandouVfxEvent) -> ZhandouVfxContext:
	var ctx := _CTX.new()
	ctx.host = self
	ctx.source_id = event.source_id
	ctx.target_id = event.target_id
	if settings == null:
		settings = ZhandouVfxSettings.new()
	ctx.settings = settings
	ctx.overrides = _RESOLVER.overrides_from_event(event)
	ctx.preset_library = _preset_library
	ctx.projectile_parent = _projectile_parent
	ctx.shake_target = _shake_target
	ctx.actors = _actors.duplicate()
	return ctx


func get_preset_library() -> ZhandouVfxPresetLibrary:
	if _preset_library == null:
		_preset_library = _LIB.load_default()
	return _preset_library


func _resolve_vfx(unit_id: String) -> ZhandouActorVfx:
	return get_actor_vfx(unit_id)


func _resolve_actor(unit_id: String) -> Node2D:
	var vfx := _resolve_vfx(unit_id)
	return vfx.get_actor() if vfx != null else null


## 受击击退方向：优先用同父节点下的本地位移。
static func _event_preset_label(event: ZhandouVfxEvent) -> String:
	if event == null or not event.extra is Dictionary:
		return ""
	var vfx := _RESOLVER.normalize_vfx_binding(event.extra.get("vfx", {}))
	if vfx.has("preset"):
		return str(vfx["preset"]).strip_edges()
	if vfx.has("sequence"):
		return "inline_sequence"
	return ZhandouVfxPresetLibrary.legacy_preset_for_vfx_type(
		_RESOLVER._skill_type_to_vfx_type(event.skill_type)
	)


static func _vfx_actor_snapshot(vfx: ZhandouActorVfx) -> Dictionary:
	if vfx == null or not is_instance_valid(vfx):
		return {"ok": false}
	var actor := vfx.get_actor()
	if not is_instance_valid(actor):
		return {"ok": false, "vfx": vfx.name}
	return {
		"ok": true,
		"pos": _vec2_text(actor.position),
		"scale": _vec2_text(actor.scale),
		"rest_scale": _vec2_text(vfx.get_rest_scale()),
	}


static func _actor_debug_row(
		unit_id: String,
		sprite: Node2D,
		vfx: ZhandouActorVfx,
		mode: String
) -> Dictionary:
	var row := {
		"单位": ZhandouDebugLog.side_label(unit_id),
		"模式": mode,
	}
	if is_instance_valid(sprite):
		row["sprite_pos"] = _vec2_text(sprite.position)
	if vfx != null and is_instance_valid(vfx):
		row["rest_pos"] = _vec2_text(vfx.get_rest_position())
	return row


static func _vec2_text(v: Vector2) -> String:
	return "(%.1f, %.1f)" % [v.x, v.y]


static func melee_hit_direction_local(source: Node2D, target: Node2D) -> Vector2:
	if source == null or target == null:
		return Vector2.RIGHT
	if source.get_parent() == target.get_parent():
		var delta := target.position - source.position
		if delta.length_squared() > 1.0:
			return delta.normalized()
	return source.global_position.direction_to(target.global_position)


# --- 演示：模拟战斗事件队列 ---

func demo_play_sample_queue() -> void:
	clear_queue()
	enqueue_dict({
		"source_id": "player",
		"target_id": "enemy",
		"damage_value": 42,
		"extra": {"vfx": {"preset": "melee_default"}},
	})
	enqueue_dict({
		"source_id": "player",
		"target_id": "enemy",
		"damage_value": 88,
		"extra": {"vfx": {"preset": "ranged_default"}},
	})
	play_queue()
