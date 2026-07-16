class_name ZhandouActionExecutor
extends RefCounted

const _CTX := preload("res://scripts/zhandou/vfx/zhandou_vfx_context.gd")
const _LIB := preload("res://scripts/zhandou/vfx/zhandou_vfx_preset_library.gd")
const _DEFS := preload("res://scripts/features/battle/domain/zhandou_vfx_step_defs.gd")


func play_sequence(ctx: ZhandouVfxContext, steps: Array) -> void:
	if ctx == null or ctx.host == null or steps.is_empty():
		return
	await _run_steps(ctx, steps)


func _run_steps(ctx: ZhandouVfxContext, steps: Array) -> void:
	for step_v in steps:
		if step_v is Dictionary:
			await _run_step(ctx, step_v as Dictionary)


func _run_step(ctx: ZhandouVfxContext, step: Dictionary) -> void:
	var op := str(step.get("op", "")).strip_edges().to_lower()
	match op:
		_DEFS.OP_STOP_IDLE:
			var v := ctx.resolve_step_actor(step)
			if v != null:
				v.stop_idle()
				v.kill_action_tween()
		_DEFS.OP_RESUME_IDLE:
			var vr := ctx.resolve_step_actor(step)
			if vr != null:
				vr.start_idle()
		_DEFS.OP_TWEEN:
			await _op_tween(ctx, step)
		_DEFS.OP_TWEEN_METHOD:
			await _op_tween_method(ctx, step)
		_DEFS.OP_PARALLEL:
			await _op_parallel(ctx, step)
		_DEFS.OP_SEQUENCE:
			var sub: Variant = step.get("steps", [])
			if sub is Array:
				await _run_steps(ctx, sub as Array)
		_DEFS.OP_IMPACT:
			await _op_impact(ctx)
		_DEFS.OP_PROJECTILE:
			await _op_projectile(ctx, step)
		_DEFS.OP_SCREEN_SHAKE:
			await _op_screen_shake(ctx)
		_DEFS.OP_CAPTURE_REST:
			var vc := ctx.resolve_step_actor(step)
			if vc != null:
				vc.capture_rest_pose(false)
		_DEFS.OP_WAIT:
			var dur := float(step.get("duration", 0.05))
			if ctx.host.get_tree() != null:
				await ctx.host.get_tree().create_timer(maxf(0.001, dur)).timeout
		_DEFS.OP_SUBSEQUENCE:
			var preset_id := str(step.get("preset", "")).strip_edges()
			if ctx.preset_library != null and preset_id != "":
				await _run_steps(ctx, ctx.preset_library.get_sequence(preset_id))
		_:
			push_warning("ZhandouActionExecutor: 未知 op '%s'" % op)


func _op_tween(ctx: ZhandouVfxContext, step: Dictionary) -> void:
	var role := str(step.get("actor", _DEFS.ACTOR_CASTER)).strip_edges()
	var vfx := ctx.resolve_step_actor(step)
	if vfx == null:
		_log_tween_skip(role, "角色 VFX 未注册", step)
		return
	var actor := vfx.get_actor()
	if not is_instance_valid(actor):
		_log_tween_skip(role, "Sprite 节点无效", step)
		return
	var prop := str(step.get("prop", "position")).strip_edges()
	if prop == "scale" or prop == "modulate":
		return
	var from_pos := actor.position
	var from_scale := actor.scale
	var target_value: Variant = ctx.resolve_tween_target(step)
	if target_value == null:
		_log_tween_skip(role, "无法解析 tween 目标", step)
		return
	var duration := ctx.resolve_duration(step, 0.1)
	var anchor_name := _step_anchor_name(step)
	if ZhandouDebugLog.enabled:
		ZhandouDebugLog.write("特效", "tween 开始", {
			"角色": role,
			"属性": prop,
			"锚点": anchor_name,
			"时长": duration,
			"起点": _vec2_text(from_pos if prop == "position" else from_scale),
			"终点": _value_text(target_value),
		})
	var trans := ctx.resolve_trans(step)
	var ease := ctx.resolve_ease(step)
	var tw := actor.create_tween()
	tw.set_trans(trans).set_ease(ease)
	tw.tween_property(actor, prop, target_value, duration)
	await _await_tween(ctx, tw)
	if ZhandouDebugLog.enabled and is_instance_valid(actor):
		ZhandouDebugLog.write("特效", "tween 完成", {
			"角色": role,
			"属性": prop,
			"锚点": anchor_name,
			"当前": _value_text(actor.get(prop)),
		})


func _op_tween_method(ctx: ZhandouVfxContext, step: Dictionary) -> void:
	var vfx := ctx.resolve_step_actor(step)
	if vfx == null:
		return
	var actor := vfx.get_actor()
	if not is_instance_valid(actor) or ctx.settings == null:
		return
	var method := str(step.get("method", "")).strip_edges().to_lower()
	var duration := ctx.resolve_duration(step, 0.1)
	if method == "hit_shake":
		var dir := vfx.world_direction_to_parent_local(ctx.compute_hit_direction())
		if dir.length_squared() < 0.001:
			dir = Vector2.LEFT if vfx.get_rest_position().x > 0.0 else Vector2.RIGHT
		var knock := ctx.resolve_anchor(vfx, "knockback") as Vector2
		var tw := actor.create_tween()
		tw.tween_method(
			func(t: float) -> void:
				if not is_instance_valid(actor):
					return
				var perp := dir.orthogonal()
				var decay := 1.0 - t
				var wobble := sin(t * ctx.settings.hit_shake_frequency * TAU) * ctx.settings.hit_shake_amplitude * decay
				actor.position = knock + perp * wobble,
			0.0,
			1.0,
			duration
		)
		await _await_tween(ctx, tw)


func _op_parallel(ctx: ZhandouVfxContext, step: Dictionary) -> void:
	var branches: Variant = step.get("steps", [])
	if not branches is Array or (branches as Array).is_empty():
		return
	var default_actor := str(step.get("actor", _DEFS.ACTOR_CASTER)).strip_edges()
	var arr := branches as Array
	var remaining := {"n": arr.size()}
	for branch_v in arr:
		_branch_async(ctx, _inject_actor(branch_v, default_actor), func() -> void:
			remaining.n -= 1
		)
	while remaining.n > 0 and is_instance_valid(ctx.host):
		await ctx.host.get_tree().process_frame


func _inject_actor(branch_v: Variant, default_actor: String) -> Variant:
	if not branch_v is Dictionary:
		return branch_v
	var d := (branch_v as Dictionary).duplicate(true)
	if d.has("op") and not d.has("actor"):
		d["actor"] = default_actor
	if d.has("steps") and d["steps"] is Array:
		var new_steps: Array = []
		for child_v in d["steps"] as Array:
			new_steps.append(_inject_actor(child_v, default_actor))
		d["steps"] = new_steps
	return d


func _branch_async(ctx: ZhandouVfxContext, branch_v: Variant, on_done: Callable) -> void:
	if branch_v is Dictionary:
		var branch := branch_v as Dictionary
		if branch.has("op"):
			await _run_step(ctx, branch)
		else:
			var sub: Variant = branch.get("steps", [])
			if sub is Array:
				await _run_steps(ctx, sub as Array)
	if on_done.is_valid():
		on_done.call()


func _op_impact(ctx: ZhandouVfxContext) -> void:
	if ctx.preset_library == null:
		return
	var hit_id := ctx.preset_library.get_impact_preset_id() if ctx.preset_library != null else "hit_default"
	var hit_steps := ctx.preset_library.get_sequence(hit_id) if ctx.preset_library != null else []
	var target_vfx := ctx.get_vfx(ctx.target_id)
	if target_vfx != null and not hit_steps.is_empty():
		target_vfx.play_hit_animation()
		target_vfx.stop_idle()
		target_vfx.kill_hit_tween()
		await _run_steps(ctx, hit_steps)


func _op_projectile(ctx: ZhandouVfxContext, step: Dictionary) -> void:
	var src := ctx.get_actor_for_role(_DEFS.ACTOR_CASTER)
	var dst := ctx.get_actor_for_role(_DEFS.ACTOR_TARGET)
	if not is_instance_valid(src) or not is_instance_valid(dst) or ctx.settings == null:
		return
	var parent := ctx.projectile_parent if ctx.projectile_parent != null else ctx.host
	var projectile := ZhandouProjectileVfx.new()
	var tex_path := str(step.get("texture", "")).strip_edges()
	projectile.visual_texture = Tools.load_image(tex_path) if tex_path != "" else null
	projectile.visual_size = _vector2_from_value(step.get("visual_size", projectile.visual_size), projectile.visual_size)
	projectile.rotation_offset_deg = float(step.get("rotation_offset_deg", 0.0))
	parent.add_child(projectile)
	var done := {"ok": false}
	projectile.arrived.connect(func() -> void:
		done.ok = true
	, CONNECT_ONE_SHOT)
	projectile.launch(
		src.global_position,
		dst.global_position,
		ctx.settings,
		bool(step.get("use_bezier", true))
	)
	var wait_sec := 0.0
	const MAX_WAIT := 12.0
	while not done.ok and is_instance_valid(ctx.host):
		await ctx.host.get_tree().process_frame
		wait_sec += ctx.host.get_process_delta_time()
		if wait_sec >= MAX_WAIT:
			push_warning("ZhandouActionExecutor: projectile timeout")
			break


static func _vector2_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		var arr := value as Array
		return Vector2(float(arr[0]), float(arr[1]))
	return fallback


func _op_screen_shake(ctx: ZhandouVfxContext) -> void:
	if not is_instance_valid(ctx.shake_target) or ctx.settings == null:
		return
	var target := ctx.shake_target
	var rest: Vector2 = target.position
	var tw := target.create_tween()
	tw.set_trans(ctx.settings.screen_shake_trans).set_ease(ctx.settings.screen_shake_ease)
	var amp := ctx._f("screen_shake.amplitude", ctx.settings.screen_shake_amplitude)
	var freq := ctx._f("screen_shake.frequency", ctx.settings.screen_shake_frequency)
	var dur := ctx._f("screen_shake.duration", ctx.settings.screen_shake_duration)
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(target):
				return
			var decay := 1.0 - t
			var a := amp * decay
			target.position = rest + Vector2(
				sin(t * freq * TAU) * a,
				cos(t * freq * 1.37 * TAU) * a * 0.65
			),
		0.0,
		1.0,
		dur
	)
	tw.tween_callback(func() -> void:
		if is_instance_valid(target):
			target.position = rest
	)
	await _await_tween(ctx, tw)


func _await_tween(ctx: ZhandouVfxContext, tw: Tween) -> void:
	if tw == null or not tw.is_valid():
		return
	while tw.is_valid() and tw.is_running():
		if not is_instance_valid(ctx.host):
			tw.kill()
			return
		await ctx.host.get_tree().process_frame


static func _log_tween_skip(role: String, reason: String, step: Dictionary) -> void:
	var msg := "ZhandouActionExecutor: tween 跳过 (%s) actor=%s" % [reason, role]
	push_warning(msg)
	if ZhandouDebugLog.enabled:
		ZhandouDebugLog.write("特效", "tween 跳过", {
			"原因": reason,
			"角色": role,
			"属性": str(step.get("prop", "")),
			"锚点": _step_anchor_name(step),
		})


static func _step_anchor_name(step: Dictionary) -> String:
	var to_v: Variant = step.get("to", null)
	if to_v is Dictionary and (to_v as Dictionary).has("anchor"):
		return str((to_v as Dictionary)["anchor"])
	return ""


static func _vec2_text(v: Vector2) -> String:
	return "(%.1f, %.1f)" % [v.x, v.y]


static func _value_text(v: Variant) -> String:
	if v is Vector2:
		return _vec2_text(v as Vector2)
	if v is Color:
		var c := v as Color
		return "(%.2f, %.2f, %.2f)" % [c.r, c.g, c.b]
	return str(v)
