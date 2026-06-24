class_name CombatActorVfx
extends Node

## 挂在战斗单位 [Sprite2D] / [Node2D] 下：待机呼吸与静止姿势；攻击/受击由 [CombatActionExecutor] 驱动。

signal action_finished
signal hit_feedback_finished

@export var settings: CombatVfxSettings
@export var auto_start_idle: bool = true

var _actor: Node2D
var _rest_position: Vector2 = Vector2.ZERO
var _rest_scale: Vector2 = Vector2.ONE
var _rest_modulate: Color = Color.WHITE
var _idle_tween: Tween
var _action_tween: Tween
var _hit_tween: Tween


func _ready() -> void:
	_actor = get_parent() as Node2D
	if _actor == null:
		push_error("CombatActorVfx: 父节点须为 Node2D（如 Sprite2D）")
		return
	rebaseline_rest_pose()


func apply_settings(new_settings: CombatVfxSettings) -> void:
	if new_settings == null:
		push_warning("CombatActorVfx.apply_settings: settings 为空")
		return
	settings = new_settings
	_kill_idle()
	_kill_action()
	_kill_hit()
	if is_instance_valid(_actor):
		rebaseline_rest_pose()
		if auto_start_idle:
			start_idle()


func _exit_tree() -> void:
	_kill_idle()
	_kill_action()
	_kill_hit()


func get_actor() -> Node2D:
	return _actor


func bind_actor(actor: Node2D) -> void:
	## 仅更新 Sprite 引用；勿在此采样 rest（出手前常处于待机呼吸峰值，会抬高 rest_scale）。
	_actor = actor


func get_rest_position() -> Vector2:
	return _rest_position


func get_rest_scale() -> Vector2:
	return _rest_scale


func get_rest_modulate() -> Color:
	return _rest_modulate


## 战斗初始化时从当前 Sprite 采样静止姿势（须先 stop_idle，且不在动作 tween 中）。
func rebaseline_rest_pose() -> void:
	stop_idle()
	_kill_action()
	_kill_hit()
	if not is_instance_valid(_actor):
		return
	_rest_position = _actor.position
	_rest_scale = _fixed_rest_scale()
	_actor.scale = _rest_scale
	_rest_modulate = _actor.modulate


## 固定基准模式：忽略动态 scale 快照，始终使用 settings.actor_base_scale 作为 rest_scale。
func capture_rest_pose(_rebase_scale: bool = false) -> void:
	stop_idle()
	if not is_instance_valid(_actor):
		return
	# 固定基准模式：无论是否请求 rebase，都使用配置中的固定 (x, x) 作为 rest_scale。
	_rest_scale = _fixed_rest_scale()
	_actor.scale = _rest_scale
	_rest_position = _actor.position
	_rest_modulate = _actor.modulate


func reset_pose() -> void:
	if not is_instance_valid(_actor):
		return
	_actor.position = _rest_position
	_actor.scale = _rest_scale
	_actor.modulate = _rest_modulate


func start_idle() -> void:
	if not is_instance_valid(_actor) or settings == null or not settings.idle_enabled:
		return
	_kill_idle()
	var period := 1.0 / maxf(settings.idle_frequency_hz, 0.01)
	_idle_tween = _actor.create_tween().set_loops()
	_idle_tween.set_trans(settings.idle_transition).set_ease(settings.idle_ease)
	_idle_tween.tween_method(_apply_idle_sample, 0.0, TAU, period)


func stop_idle() -> void:
	_kill_idle()
	# 出手前回到静止位，避免待机呼吸偏移导致 windup/strike 锚点与当前位置脱节。
	if is_instance_valid(_actor):
		_actor.position = _rest_position
		_actor.scale = _rest_scale


func kill_action_tween() -> void:
	_kill_action()


func kill_hit_tween() -> void:
	_kill_hit()


func _apply_idle_sample(phase: float) -> void:
	if not is_instance_valid(_actor):
		return
	var wave := (sin(phase) + 1.0) * 0.5
	var scale_mul := lerpf(settings.idle_scale_min, settings.idle_scale_max, wave)
	_actor.scale = _rest_scale * scale_mul
	_actor.position = _rest_position + Vector2(0.0, -sin(phase) * settings.idle_float_amplitude)


func attack_direction(target: Node2D) -> Vector2:
	var delta := _delta_to_target_in_parent_space(target)
	if delta.length_squared() < 1.0:
		return Vector2.RIGHT if _rest_position.x <= 0.0 else Vector2.LEFT
	return delta.normalized()


func strike_point_in_front(target: Node2D, inset: float) -> Vector2:
	if not is_instance_valid(_actor):
		return Vector2.ZERO
	var delta := _delta_to_target_in_parent_space(target)
	if delta.length_squared() < 1.0:
		return _actor.position
	var dist := delta.length()
	# 终点必须在施法者父节点坐标系内；不可混用 target.position（阵型槽位下父节点不同）。
	if dist <= inset:
		return _actor.position + delta * 0.5
	return _actor.position + delta.normalized() * (dist - inset)


func world_direction_to_parent_local(dir: Vector2) -> Vector2:
	if dir.length_squared() < 0.001:
		return dir
	var parent := _actor.get_parent()
	if parent is Node2D:
		var local := (parent as Node2D).global_transform.affine_inverse().basis_xform(dir)
		if local.length_squared() > 0.001:
			return local.normalized()
	elif parent is CanvasItem:
		var local_ci := (parent as CanvasItem).get_global_transform_with_canvas().affine_inverse().basis_xform(dir)
		if local_ci.length_squared() > 0.001:
			return local_ci.normalized()
	return dir.normalized()


func _delta_to_target_in_parent_space(target: Node2D) -> Vector2:
	if not is_instance_valid(target) or not is_instance_valid(_actor):
		return Vector2.ZERO
	if target.get_parent() == _actor.get_parent():
		return target.position - _actor.position
	return _global_to_actor_local(target.global_position) - _actor.position


func _global_to_actor_local(global_pos: Vector2) -> Vector2:
	var parent := _actor.get_parent()
	if parent is Node2D:
		return (parent as Node2D).to_local(global_pos)
	if parent is CanvasItem:
		return (parent as CanvasItem).get_global_transform_with_canvas().affine_inverse() * global_pos
	return global_pos


func _kill_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null


func _kill_action() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = null


func _kill_hit() -> void:
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	_hit_tween = null


func _fixed_rest_scale() -> Vector2:
	var base := 1.0
	if settings != null:
		base = maxf(0.01, settings.actor_base_scale)
	return Vector2(base, base)
