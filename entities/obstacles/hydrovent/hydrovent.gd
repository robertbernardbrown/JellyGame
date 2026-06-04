extends Area2D

const TRICKLE_INTERVAL_MIN = 0.3
const TRICKLE_INTERVAL_MAX = 0.9
const SURGE_TRICKLE_INTERVAL_MIN = 0.15
const SURGE_TRICKLE_INTERVAL_MAX = 0.4
const SURGE_INTERVAL_MIN = 4.0
const SURGE_INTERVAL_MAX = 10.0
const SURGE_DURATION_MIN = 2.0
const SURGE_DURATION_MAX = 4.0
const LIGHT_SURGE_ENERGY = 1.2
const LIGHT_IDLE_ENERGY = 0.35

const BUBBLE_SCENE = preload("res://entities/obstacles/hydrovent/bubble.tscn")

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _light: PointLight2D = $VentLight
@onready var _spawn_point: Marker2D = $BubbleSpawnPoint

enum State { IDLE, BELCHING, SURGING }
var _state: State = State.IDLE
var _on_left: bool = true
var _player: Node = null
var _trickle_timer: Timer
var _surge_timer: Timer
var _surge_end_timer: Timer

func setup(on_left: bool):
	_on_left = on_left

func _ready():
	_anim.flip_h = not _on_left
	_anim.animation_finished.connect(_on_animation_finished)
	_player = get_tree().get_first_node_in_group("Player")

	_trickle_timer = Timer.new()
	_trickle_timer.one_shot = true
	_trickle_timer.timeout.connect(_on_trickle)
	add_child(_trickle_timer)

	_surge_timer = Timer.new()
	_surge_timer.one_shot = true
	_surge_timer.timeout.connect(_on_surge_start)
	add_child(_surge_timer)

	_surge_end_timer = Timer.new()
	_surge_end_timer.one_shot = true
	_surge_end_timer.timeout.connect(_on_surge_end)
	add_child(_surge_end_timer)

	_set_state(State.IDLE)
	_surge_timer.start(randf_range(SURGE_INTERVAL_MIN, SURGE_INTERVAL_MAX))

func _process(_delta):
	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()

func _set_state(new_state: State):
	_state = new_state
	match new_state:
		State.IDLE:
			_anim.play("Idle")
			_tween_light(LIGHT_IDLE_ENERGY, 0.5)
			_trickle_timer.start(randf_range(TRICKLE_INTERVAL_MIN, TRICKLE_INTERVAL_MAX))
		State.BELCHING:
			_anim.play("Belch")
			_tween_light(LIGHT_SURGE_ENERGY, 0.6)
		State.SURGING:
			_anim.play("BelchHold")
			_surge_end_timer.start(randf_range(SURGE_DURATION_MIN, SURGE_DURATION_MAX))
			_trickle_timer.start(randf_range(SURGE_TRICKLE_INTERVAL_MIN, SURGE_TRICKLE_INTERVAL_MAX))

func _on_animation_finished():
	if _state == State.BELCHING:
		_set_state(State.SURGING)

func _on_trickle():
	match _state:
		State.IDLE:
			var count = randi_range(1, 2)
			for i in count:
				_spawn_bubble(_trickle_velocity(), randi_range(0, 1))
			_trickle_timer.start(randf_range(TRICKLE_INTERVAL_MIN, TRICKLE_INTERVAL_MAX))
		State.SURGING:
			var count = randi_range(1, 2)
			for i in count:
				_spawn_bubble(_surge_velocity(), randi_range(1, 2))
			_trickle_timer.start(randf_range(SURGE_TRICKLE_INTERVAL_MIN, SURGE_TRICKLE_INTERVAL_MAX))

func _on_surge_start():
	_set_state(State.BELCHING)

func _on_surge_end():
	_set_state(State.IDLE)
	_surge_timer.start(randf_range(SURGE_INTERVAL_MIN, SURGE_INTERVAL_MAX))

func _trickle_velocity() -> Vector2:
	var center_sign = 1.0 if _on_left else -1.0
	var angle = randf_range(PI * 0.26, PI * 0.34) * center_sign
	return Vector2(sin(angle), -cos(angle)) * randf_range(70.0, 140.0)

func _surge_velocity() -> Vector2:
	var center_sign = 1.0 if _on_left else -1.0
	var angle = randf_range(PI * 0.28, PI * 0.38) * center_sign
	return Vector2(sin(angle), -cos(angle)) * randf_range(130.0, 210.0)

func _spawn_bubble(vel: Vector2, size: int):
	var bubble = BUBBLE_SCENE.instantiate()
	bubble.setup(vel, size)
	get_parent().add_child(bubble)
	bubble.global_position = _spawn_point.global_position

func _tween_light(target: float, duration: float):
	var tween = create_tween()
	tween.tween_property(_light, "energy", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

