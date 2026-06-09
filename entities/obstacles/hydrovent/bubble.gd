extends Area2D

const TEXTURES = [
	preload("res://assets/sprites/bubbles/small_bubbles/small_bubbles.png"),
	preload("res://assets/sprites/bubbles/medium_bubbles/medium_bubbles.png"),
	preload("res://assets/sprites/bubbles/large_bubbles/large_bubbles.png"),
]
const RADII = [8.0, 16.0, 28.0]
const BASE_LIFETIMES = [6.0, 8.0, 10.0]
const BUBBLE_PUSH_FORCE = 130.0
const SIZE_PUSH_MULTIPLIERS = [0.4, 0.7, 1.0]

var _velocity: Vector2
var _lifetime: float
var _time: float = 0.0
var _wobble_phase: float
var _size: int
var _push_force: float

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

func setup(vel: Vector2, size: int):
	_size = size
	_velocity = vel
	_lifetime = BASE_LIFETIMES[size] * randf_range(0.8, 1.2)
	_push_force = BUBBLE_PUSH_FORCE * SIZE_PUSH_MULTIPLIERS[size]
	_wobble_phase = randf() * TAU

func _ready():
	_sprite.texture = TEXTURES[_size]
	_sprite.rotation = randf() * TAU
	_sprite.scale = Vector2(4, 4) * randf_range(0.85, 1.15)
	(_collision.shape as CircleShape2D).radius = RADII[_size]

func _process(delta):
	_time += delta
	_velocity.x = lerpf(_velocity.x, 0.0, 0.5 * delta)
	var wobble = sin(_time * 1.5 + _wobble_phase) * 5.0
	position += (_velocity + Vector2(wobble, 0.0)) * delta
	modulate.a = clamp(1.0 - (_time / _lifetime), 0.0, 1.0)
	if _time >= _lifetime:
		queue_free()

func _on_body_entered(body, _s = null):
	if body.is_in_group("Player"):
		var push_dir = _velocity.normalized()
		var perp = Vector2(-push_dir.y, push_dir.x) * (1.0 if randf() > 0.5 else -1.0)
		var jostle = (perp * 0.8 + push_dir * 0.2).normalized()
		body.velocity += jostle * _push_force
