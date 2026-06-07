class_name CombatVfxContext
extends RefCounted

## 单次战斗表现事件的运行时上下文：角色、锚点、可调参数。

var host: Node
var source_id: String = ""
var target_id: String = ""
var is_crit: bool = false
var settings: CombatVfxSettings
var overrides: Dictionary = {}
var actors: Dictionary = {} # unit_id -> CombatActorVfx
var preset_library: CombatVfxPresetLibrary
var projectile_parent: Node
var shake_target: CanvasItem

var _hit_direction: Vector2 = Vector2.RIGHT


func get_vfx_for_role(role: String) -> CombatActorVfx:
	return get_vfx(_role_to_unit_id(role))


func get_vfx(unit_id: String) -> CombatActorVfx:
	return actors.get(unit_id.strip_edges(), null) as CombatActorVfx


func get_actor_for_role(role: String) -> Node2D:
	var vfx := get_vfx_for_role(role)
	return vfx.get_actor() if vfx != null else null


func _role_to_unit_id(role: String) -> String:
	match str(role).strip_edges().to_lower():
		CombatVfxStepDefs.ACTOR_TARGET, "target_id":
			return target_id
		_:
			return source_id


func resolve_step_actor(step: Dictionary) -> CombatActorVfx:
	var role := str(step.get("actor", CombatVfxStepDefs.ACTOR_CASTER)).strip_edges().to_lower()
	return get_vfx_for_role(role)


func prepare_caster_action() -> void:
	var vfx := get_vfx(source_id)
	if vfx != null:
		vfx.stop_idle()
		vfx.kill_action_tween()
		# 仅停止待机和动作 tween；rest pose 由注册时采样，避免动作中 scale 漂移被写回基准。


func compute_hit_direction() -> Vector2:
	var source := get_actor_for_role(CombatVfxStepDefs.ACTOR_CASTER)
	var target := get_actor_for_role(CombatVfxStepDefs.ACTOR_TARGET)
	_hit_direction = FightVfxManager.melee_hit_direction_local(source, target)
	return _hit_direction


func resolve_anchor(actor_vfx: CombatActorVfx, anchor_name: String) -> Variant:
	if actor_vfx == null or settings == null:
		return null
	var key := anchor_name.strip_edges().to_lower()
	var target_actor := get_actor_for_role(
		CombatVfxStepDefs.ACTOR_CASTER if actor_vfx == get_vfx(target_id) else CombatVfxStepDefs.ACTOR_TARGET
	)
	var other_vfx := get_vfx(target_id) if actor_vfx == get_vfx(source_id) else get_vfx(source_id)
	match key:
		"rest":
			return actor_vfx.get_rest_position()
		"rest_scale":
			return actor_vfx.get_rest_scale()
		"rest_modulate":
			return actor_vfx.get_rest_modulate()
		"windup":
			var dir := actor_vfx.attack_direction(target_actor)
			return actor_vfx.get_rest_position() - dir * _f("melee.windup_offset", settings.melee_windup_offset)
		"strike":
			return actor_vfx.strike_point_in_front(target_actor, _f("melee.strike_inset", settings.melee_strike_inset))
		"melee_squash":
			var rs := actor_vfx.get_rest_scale()
			return Vector2(
				_f("melee.squash_scale_x", settings.melee_squash_scale_x) * rs.x,
				_f("melee.squash_scale_y", settings.melee_squash_scale_y) * rs.y
			)
		"recoil":
			var dir_r := actor_vfx.attack_direction(target_actor)
			return actor_vfx.get_rest_position() - dir_r * _f("ranged.recoil_offset", settings.ranged_recoil_offset)
		"release":
			var dir_rel := actor_vfx.attack_direction(target_actor)
			return actor_vfx.get_rest_position() + dir_rel * _f("ranged.recoil_offset", settings.ranged_recoil_offset) * 0.35
		"knockback":
			var dir_h := actor_vfx.world_direction_to_parent_local(compute_hit_direction())
			if dir_h.length_squared() < 0.001:
				dir_h = Vector2.LEFT if actor_vfx.get_rest_position().x > 0.0 else Vector2.RIGHT
			return actor_vfx.get_rest_position() + dir_h * _f("hit.knockback_distance", settings.hit_knockback_distance)
		"hit_squash":
			var dir_s := actor_vfx.world_direction_to_parent_local(compute_hit_direction())
			if dir_s.length_squared() < 0.001:
				dir_s = Vector2.LEFT if actor_vfx.get_rest_position().x > 0.0 else Vector2.RIGHT
			var squash := Vector2(
				_f("hit.stretch_along_dir", settings.hit_stretch_along_dir),
				_f("hit.squash_perpendicular", settings.hit_squash_perpendicular)
			)
			if absf(dir_s.y) > absf(dir_s.x):
				squash = Vector2(squash.y, squash.x)
			return actor_vfx.get_rest_scale() * squash
		"hit_flash":
			if is_crit:
				return settings.hit_crit_flash_color
			return settings.hit_flash_color
		_:
			push_warning("CombatVfxContext: 未知 anchor '%s'" % anchor_name)
			return actor_vfx.get_rest_position()


func resolve_tween_target(step: Dictionary) -> Variant:
	var to_v: Variant = step.get("to", null)
	if to_v is Dictionary:
		var d := to_v as Dictionary
		if d.has("anchor"):
			var vfx := resolve_step_actor(step)
			return resolve_anchor(vfx, str(d["anchor"]))
		if d.has("value"):
			return d["value"]
	if to_v is Vector2 or to_v is Color:
		return to_v
	return null


func resolve_duration(step: Dictionary, fallback: float = 0.1) -> float:
	if step.has("duration"):
		return maxf(0.001, float(step["duration"]))
	var key := str(step.get("duration_key", "")).strip_edges()
	if key != "":
		return maxf(0.001, _f(key, fallback))
	return fallback


func resolve_trans(step: Dictionary, group_fallback: int = Tween.TRANS_LINEAR) -> Tween.TransitionType:
	var key := str(step.get("trans_key", "")).strip_edges()
	if key != "":
		return _enum_from_settings(key, group_fallback) as Tween.TransitionType
	var name := str(step.get("trans", "")).strip_edges().to_lower()
	return _parse_trans_name(name, group_fallback)


func resolve_ease(step: Dictionary, group_fallback: int = Tween.EASE_IN_OUT) -> Tween.EaseType:
	var key := str(step.get("ease_key", "")).strip_edges()
	if key != "":
		return _enum_from_settings(key, group_fallback) as Tween.EaseType
	var name := str(step.get("ease", "")).strip_edges().to_lower()
	return _parse_ease_name(name, group_fallback)


func _f(dot_key: String, fallback: float) -> float:
	if overrides.has(dot_key):
		return float(overrides[dot_key])
	var prop := _dot_key_to_property(dot_key)
	if prop != "" and settings != null and prop in settings:
		return float(settings.get(prop))
	return fallback


func _enum_from_settings(dot_key: String, fallback: int) -> int:
	if overrides.has(dot_key):
		return int(overrides[dot_key])
	var prop := _dot_key_to_property(dot_key)
	if prop != "" and settings != null and prop in settings:
		return int(settings.get(prop))
	return fallback


static func _dot_key_to_property(dot_key: String) -> String:
	var parts := dot_key.split(".")
	if parts.size() == 2:
		return "%s_%s" % [parts[0], parts[1]]
	return ""


static func _parse_trans_name(name: String, fallback: int) -> Tween.TransitionType:
	match name:
		"linear": return Tween.TRANS_LINEAR
		"sine": return Tween.TRANS_SINE
		"quad": return Tween.TRANS_QUAD
		"cubic": return Tween.TRANS_CUBIC
		"expo": return Tween.TRANS_EXPO
		"back": return Tween.TRANS_BACK
		"elastic": return Tween.TRANS_ELASTIC
		"bounce": return Tween.TRANS_BOUNCE
		_: return fallback as Tween.TransitionType


static func _parse_ease_name(name: String, fallback: int) -> Tween.EaseType:
	match name:
		"in": return Tween.EASE_IN
		"out": return Tween.EASE_OUT
		"in_out", "inout": return Tween.EASE_IN_OUT
		"out_in", "outin": return Tween.EASE_OUT_IN
		_: return fallback as Tween.EaseType
