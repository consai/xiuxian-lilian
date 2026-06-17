class_name StoryGuideMask
extends Control

const HOLE_PADDING := Vector2(10, 10)

@onready var _top: ColorRect = $Top
@onready var _bottom: ColorRect = $Bottom
@onready var _left: ColorRect = $Left
@onready var _right: ColorRect = $Right


func set_active(active: bool) -> void:
	visible = active


func set_hole(global_rect: Rect2) -> void:
	var viewport_size := size
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size
	if global_rect.size == Vector2.ZERO:
		_set_full_cover(viewport_size)
		return
	var hole := global_rect.grow_individual(
		HOLE_PADDING.x,
		HOLE_PADDING.y,
		HOLE_PADDING.x,
		HOLE_PADDING.y
	)
	hole = hole.intersection(Rect2(Vector2.ZERO, viewport_size))
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		_set_full_cover(viewport_size)
		return
	_top.position = Vector2.ZERO
	_top.size = Vector2(viewport_size.x, maxf(0.0, hole.position.y))
	_bottom.position = Vector2(0.0, hole.end.y)
	_bottom.size = Vector2(viewport_size.x, maxf(0.0, viewport_size.y - hole.end.y))
	_left.position = Vector2(0.0, hole.position.y)
	_left.size = Vector2(maxf(0.0, hole.position.x), hole.size.y)
	_right.position = Vector2(hole.end.x, hole.position.y)
	_right.size = Vector2(maxf(0.0, viewport_size.x - hole.end.x), hole.size.y)


func _set_full_cover(viewport_size: Vector2) -> void:
	_top.position = Vector2.ZERO
	_top.size = viewport_size
	_bottom.size = Vector2.ZERO
	_left.size = Vector2.ZERO
	_right.size = Vector2.ZERO
