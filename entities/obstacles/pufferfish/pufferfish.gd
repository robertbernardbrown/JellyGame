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
var _puff_sfx: AudioStreamPlayer

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
	add_to_group("Pufferfish")
	_player = get_tree().get_first_node_in_group("Player")
	anim.animation_finished.connect(_on_animation_finished)
	anim.play("Idle")
	_setup_puff_sfx()
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

func _setup_puff_sfx() -> void:
	var bus_name = "PuffSFX"
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
		var lpf = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 1000.0
		lpf.resonance = 0.5
		AudioServer.add_bus_effect(idx, lpf)
		var reverb = AudioEffectReverb.new()
		reverb.room_size = 0.75
		reverb.damping = 0.6
		reverb.wet = 0.2
		AudioServer.add_bus_effect(idx, reverb)
	_puff_sfx = AudioStreamPlayer.new()
	_puff_sfx.stream = load("res://audio/pufferfish.wav")
	_puff_sfx.volume_db = -5.0
	_puff_sfx.bus = bus_name
	add_child(_puff_sfx)

func _set_state(new_state: State):
	_state = new_state
	match new_state:
		State.PUFFING:
			anim.play("Puff")
			_tween_radius(SMALL_RADIUS, LARGE_RADIUS)
			_puff_sfx.play()
		State.PUFFED:
			anim.play("PuffedIdle")
		State.DEFLATING:
			anim.play_backwards("Puff")
			_tween_radius(LARGE_RADIUS, SMALL_RADIUS)
			_puff_sfx.stop()
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
