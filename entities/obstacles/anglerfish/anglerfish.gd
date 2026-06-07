extends Area2D

const LURE_OFFSET = Vector2(0, -40)
const TRIGGER_DISTANCE = 120.0  # px from lure centre to player before reveal starts
const ESCAPE_WINDOW = 0.3       # seconds the mouth holds open
const BODY_FADE_DURATION = 0.25 # how fast the body materialises on reveal
const SNAP_RESET_PAUSE = 0.4    # how long the idle pose shows after the snap before fading
const LUNGE_DISTANCE = 130.0    # px the body surges toward the player on trigger
const LUNGE_DURATION = 0.3      # seconds the lunge takes
const LURE_MAX_DRIFT = 120.0    # max px the lure can drift horizontally toward player
const LURE_DRIFT_SPEED = 1.2    # lerp rate per second toward player's lane

@onready var body_spr: AnimatedSprite2D = $BodySprite
@onready var eyes_spr: AnimatedSprite2D = $EyesSprite
@onready var lure: AnimatedSprite2D = $Lure
@onready var _lure_light: Node2D = $LureLight
@onready var _collision: CollisionShape2D = $CollisionShape2D

enum State { LURING, EYES_REVEAL, MOUTH_OPENING, MOUTH_HOLD, MOUTH_SNAP, RETREATING }
var _state: State = State.LURING

var _player: Node = null
var _origin: Vector2
var _origin_set: bool = false
var _lunge_sfx: AudioStreamPlayer
var _lunge_sfx_id: int = 0
var _time: float = 0.0
var _phase: float
var _freq_x: float
var _freq_y: float
var _radius_x: float
var _radius_y: float
var _escape_timer: float = 0.0
var _tween: Tween = null
var _lure_phase: float
var _lure_freq_x: float
var _lure_freq_y: float
var _lure_radius_x: float
var _lure_radius_y: float
var _lure_drift: Vector2 = Vector2.ZERO

func _ready():
	add_to_group("Anglerfish")
	lure.position = LURE_OFFSET
	body_spr.modulate.a = 0.0
	eyes_spr.modulate.a = 0.0
	body_spr.play("Idle")
	eyes_spr.animation_finished.connect(_on_eyes_animation_finished)
	body_spr.animation_finished.connect(_on_body_animation_finished)
	lure.play("Idle")
	_player = get_tree().get_first_node_in_group("Player")
	_setup_lunge_sfx()
	_phase = randf() * TAU
	_freq_x = randf_range(0.3, 0.5)
	_freq_y = randf_range(0.35, 0.55)
	_radius_x = randf_range(8.0, 16.0)
	_radius_y = randf_range(6.0, 12.0)
	# Lure wiggles at the same frequencies as a real plankton
	_lure_phase = randf() * TAU
	_lure_freq_x = randf_range(0.4, 0.7)
	_lure_freq_y = randf_range(0.45, 0.75)
	_lure_radius_x = randf_range(10.0, 20.0)
	_lure_radius_y = randf_range(8.0, 16.0)

func _process(delta):
	if not _origin_set:
		_origin = global_position
		_origin_set = true

	_time += delta

	# Only drift while luring — fish locks in place once triggered
	if _state == State.LURING:
		global_position = _origin + Vector2(
			sin(_time * _freq_x + _phase) * _radius_x,
			cos(_time * _freq_y + _phase * 0.7) * _radius_y
		)
		# Drift lure horizontally toward the player's lane
		if _player:
			var target_x: float = clamp(_player.global_position.x - global_position.x, -LURE_MAX_DRIFT, LURE_MAX_DRIFT)
			_lure_drift = _lure_drift.lerp(Vector2(target_x, 0.0), LURE_DRIFT_SPEED * delta)
		# Wiggle applied on top of the drift
		var lure_offset = Vector2(
			sin(_time * _lure_freq_x + _lure_phase) * _lure_radius_x,
			cos(_time * _lure_freq_y + _lure_phase * 0.7) * _lure_radius_y
		)
		lure.position = LURE_OFFSET + _lure_drift + lure_offset
		_lure_light.position = LURE_OFFSET + _lure_drift + lure_offset

	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()
		return

	if not _player:
		return

	match _state:
		State.LURING:
			if lure.global_position.distance_to(_player.global_position) < TRIGGER_DISTANCE:
				_set_state(State.EYES_REVEAL)
		State.MOUTH_HOLD:
			_escape_timer -= delta
			if _escape_timer <= 0.0:
				_set_state(State.MOUTH_SNAP)

func _set_state(new_state: State):
	_state = new_state
	match new_state:

		State.EYES_REVEAL:
			_kill_tween()
			_tween = create_tween().set_parallel(true)
			# Lure dims — something feels wrong
			_tween.tween_property(lure, "modulate:a", 0.3, 0.5)
			_tween.tween_property(_lure_light, "modulate:a", 0.3, 0.5)
			# Eyes fade in alongside their opening animation
			_tween.tween_property(eyes_spr, "modulate:a", 1.0, 0.4)
			eyes_spr.play("EyesReveal")
			# Lunge toward player — overshoot by 50px so fast players don't slip past
			if _player:
				var to_player: Vector2 = _player.global_position - global_position
				var lunge_dist: float = minf(to_player.length() + 50.0, LUNGE_DISTANCE)
				_tween.tween_property(self, "global_position", global_position + to_player.normalized() * lunge_dist, LUNGE_DURATION)

		State.MOUTH_OPENING:
			_kill_tween()
			_tween = create_tween().set_parallel(true)
			# Body materialises quickly
			_tween.tween_property(body_spr, "modulate:a", 1.0, BODY_FADE_DURATION)
			# Lure and its light vanish completely — the deception is over
			_tween.tween_property(lure, "modulate:a", 0.0, 0.4)
			_tween.tween_property(_lure_light, "modulate:a", 0.0, 0.4)
			# Eyes overlay no longer needed — body has them baked in
			_tween.tween_property(eyes_spr, "modulate:a", 0.0, BODY_FADE_DURATION)
			body_spr.play("MouthOpening")

		State.MOUTH_HOLD:
			_escape_timer = ESCAPE_WINDOW
			body_spr.play("MouthHold")

		State.MOUTH_SNAP:
			body_spr.play("MouthSnap")
			_lunge_sfx_id += 1
			var _lid = _lunge_sfx_id
			_lunge_sfx.play(0.0)
			get_tree().create_timer(1.3).timeout.connect(func(): if _lunge_sfx_id == _lid: _lunge_sfx.stop())
			_kill_tween()
			_tween = create_tween()
			_tween.tween_interval(1.0 / 18.0)
			_tween.tween_callback(func(): _collision.disabled = false)

		State.RETREATING:
			_kill_tween()
			# Restore eyes so they're visible for the backwards close animation
			eyes_spr.modulate.a = 1.0
			_tween = create_tween().set_parallel(true)
			_tween.tween_property(body_spr, "modulate:a", 0.0, 0.6)
			_tween.tween_property(lure, "modulate:a", 0.0, 0.3)
			# Eyes close — play the reveal animation in reverse
			eyes_spr.play_backwards("EyesReveal")

func _on_eyes_animation_finished():
	match _state:
		State.EYES_REVEAL:
			_set_state(State.MOUTH_OPENING)
		State.RETREATING:
			queue_free()

func _on_body_animation_finished():
	match _state:
		State.MOUTH_OPENING:
			_set_state(State.MOUTH_HOLD)
		State.MOUTH_SNAP:
			_collision.disabled = true
			# Return to idle pose (eyes open, mouth closed) for a beat before fading
			body_spr.play("Idle")
			_kill_tween()
			_tween = create_tween()
			_tween.tween_interval(SNAP_RESET_PAUSE)
			_tween.tween_callback(func(): _set_state(State.RETREATING))

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body._trigger_death()

func _setup_lunge_sfx() -> void:
	var bus_name = "AnglerSFX"
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
	_lunge_sfx = AudioStreamPlayer.new()
	_lunge_sfx.stream = load("res://audio/angler_lunge.mp3")
	_lunge_sfx.bus = bus_name
	add_child(_lunge_sfx)

func _kill_tween():
	if _tween:
		_tween.kill()
		_tween = null
