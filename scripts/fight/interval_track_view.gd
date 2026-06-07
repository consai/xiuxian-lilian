class_name IntervalTrackView
extends Control

## 走条轨道：底栏 + 沿轨道移动的小头像（[code]%avatar[/code]）。

@onready var _track: Panel = %track
@onready var _avatar: TextureRect = %avatar

var _cap: float = 1.0
var _elapsed: float = 0.0


func _ready() -> void:
	resized.connect(_update_avatar_position)
	call_deferred("_update_avatar_position")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_avatar_position()


func set_avatar_texture(tex: Texture2D) -> void:
	if _avatar != null and tex != null:
		_avatar.texture = tex


func set_progress(elapsed: float, cap: float) -> void:
	_cap = maxf(cap, 0.001)
	_elapsed = clampf(elapsed, 0.0, _cap)
	_update_avatar_position()


func apply_row(row: Variant) -> void:
	if not row is Dictionary:
		return
	var d := row as Dictionary
	set_progress(float(d.get("elapsed", 0.0)), float(d.get("cap", 100.0)))


func _update_avatar_position() -> void:
	if _avatar == null or _track == null:
		return
	var track_w := _track.size.x
	if track_w <= 0.0:
		return
	var avatar_w := _avatar.size.x
	var avatar_h := _avatar.size.y
	var ratio := _elapsed / _cap
	var x := _track.position.x + ratio * maxf(track_w - avatar_w, 0.0)
	_avatar.position.x = x
	var track_h := _track.size.y
	_avatar.position.y = _track.position.y + (track_h - avatar_h) * 0.5
