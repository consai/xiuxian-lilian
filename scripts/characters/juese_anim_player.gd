class_name JueseAnimPlayer
extends Node2D

const ANIM_IDLE := &"idle"
const ANIM_ATTACK := &"attack"
const ANIM_CAST := &"cast"
const ANIM_HIT := &"hit"

@onready var _animation_player: AnimationPlayer = %AnimationPlayer
@onready var _sprite: Sprite2D = %CharacterSprite

var _play_token := 0


func _ready() -> void:
	play_idle()


func play_idle() -> void:
	_play_token += 1
	_animation_player.play(ANIM_IDLE)


func play_attack() -> void:
	_play_once(ANIM_ATTACK)


func play_cast() -> void:
	_play_once(ANIM_CAST)


func play_hit() -> void:
	_play_once(ANIM_HIT)


func set_texture(texture: Texture2D) -> void:
	if _sprite != null:
		_sprite.texture = texture


func set_flip_h(flip_h: bool) -> void:
	if _sprite != null:
		_sprite.flip_h = flip_h


func _play_once(animation_name: StringName) -> void:
	if not _animation_player.has_animation(animation_name):
		return
	_play_token += 1
	var token := _play_token
	_animation_player.play(animation_name)
	var finished_name: StringName = await _animation_player.animation_finished
	if token == _play_token and finished_name == animation_name:
		play_idle()
