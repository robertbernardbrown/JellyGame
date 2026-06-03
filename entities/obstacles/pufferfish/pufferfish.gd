extends Area2D

const PUFF_RADIUS = 375.0
const SMALL_RADIUS = 20.0
const LARGE_RADIUS = 55.0
const PUFF_DURATION = 0.5  # 5 frames at 10fps

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

enum State { IDLE, PUFFING, PUFFED, DEFLATING }
var _state: State = State.IDLE
var _player: Node = null
var _tween: Tween = null

var _origin: Vector2
var _origin_set: bool = false
var _time: float = 0.0
var _phase: float
var _freq_x: float
var _freq_y: float
var _radius_x: float
var _radius_y: float
var _spin_speed: float

func _ready():
	_player = get_tree().get_first_node_in_group("Player")
	anim.animation_finished.connect(_on_animation_finished)
	anim.play("Idle")
	_phase = randf() * TAU
	_freq_x = randf_range(0.3, 0.5)
	_freq_y = randf_range(0.35, 0.55)
	_radius_x = randf_range(8.0, 16.0)
	_radius_y = randf_range(6.0, 12.0)
	var direction = 1.0 if randf() > 0.5 else -1.0
	_spin_speed = randf_range(0.6, 1.8) * direction

func _process(delta):
	if not _origin_set:
		_origin = global_position
		_origin_set = true

	_time += delta
	global_position = _origin + Vector2(
		sin(_time * _freq_x + _phase) * _radius_x,
		cos(_time * _freq_y + _phase * 0.7) * _radius_y
	)
	if _state == State.PUFFED:
		anim.rotate(_spin_speed * delta)

	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()
		return

	if not _player:
		return

	var near = global_position.distance_to(_player.global_position) < PUFF_RADIUS

	match _state:
		State.IDLE:
			if near:
				_set_state(State.PUFFING)
		State.PUFFED:
			if not near:
				_set_state(State.DEFLATING)

func _set_state(new_state: State):
	_state = new_state
	match new_state:
		State.PUFFING:
			anim.play("Puff")
			_tween_radius(SMALL_RADIUS, LARGE_RADIUS)
		State.PUFFED:
			anim.play("PuffedIdle")
		State.DEFLATING:
			anim.play_backwards("Puff")
			_tween_radius(LARGE_RADIUS, SMALL_RADIUS)
		State.IDLE:
			anim.play("Idle")

func _tween_radius(from: float, to: float):
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_collision_radius, from, to, PUFF_DURATION)

func _set_collision_radius(r: float):
	(collision.shape as CircleShape2D).radius = r

func _on_animation_finished():
	match _state:
		State.PUFFING:
			_set_state(State.PUFFED)
		State.DEFLATING:
			_set_state(State.IDLE)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body._trigger_death()
