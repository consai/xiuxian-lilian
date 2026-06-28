class_name ZhandouProjectileVfx
extends Node2D

## 无序列帧飞行道具：直线或二次贝塞尔，全程 Tween 驱动。

signal arrived

## 占位飞行道具的显示尺寸（像素）。
@export var visual_size: Vector2 = Vector2(18.0, 18.0)
## 占位飞行道具的颜色。
@export var visual_color: Color = Color(1.0, 0.85, 0.35, 0.95)
## 可选静态贴图；为空时使用 ColorRect 占位。
@export var visual_texture: Texture2D
## 贴图朝向修正角度（度）。默认素材朝右。
@export var rotation_offset_deg: float = 0.0

var _visual: CanvasItem
var _tween: Tween


func _ready() -> void:
	_create_visual()


func _create_visual() -> void:
	if visual_texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = visual_texture
		sprite.centered = true
		var tex_size := visual_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			sprite.scale = Vector2(visual_size.x / tex_size.x, visual_size.y / tex_size.y)
		_visual = sprite
	else:
		var rect := ColorRect.new()
		rect.size = visual_size
		rect.position = -visual_size * 0.5
		rect.color = visual_color
		_visual = rect
	add_child(_visual)


func launch(
	from_global: Vector2,
	to_global: Vector2,
	settings: ZhandouVfxSettings,
	use_bezier: bool = true
) -> void:
	global_position = from_global
	var dir := from_global.direction_to(to_global)
	rotation = (dir.angle() if dir.length_squared() > 0.001 else 0.0) + deg_to_rad(rotation_offset_deg)
	_kill_tween()
	var duration := settings.projectile_travel_duration
	_tween = create_tween()
	_tween.set_trans(settings.projectile_trans).set_ease(settings.projectile_ease)
	if use_bezier and settings.projectile_use_bezier:
		var mid := (from_global + to_global) * 0.5
		var arc := settings.projectile_arc_height
		var perp := (to_global - from_global).orthogonal().normalized()
		if perp.length_squared() < 0.001:
			perp = Vector2.UP
		var control := mid + perp * arc
		_tween.tween_method(
			func(t: float) -> void: global_position = _quad_bezier(from_global, control, to_global, t),
			0.0,
			1.0,
			duration
		)
	else:
		_tween.tween_property(self, "global_position", to_global, duration)
	_tween.tween_callback(func() -> void:
		arrived.emit()
		queue_free()
	)


func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_kill_tween()
