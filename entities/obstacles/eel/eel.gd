extends Area2D

const HALF_W        = 192.0   # half of 384px on-screen sprite width (96 * 4 / 2)
const PEEK_DIST     = 130.0   # px from wall edge the head reaches on peek
const LUNGE_DIST_MIN = 220.0   # shortest possible lunge
const LUNGE_DIST_MAX = 360.0   # longest possible lunge (tail stays off-screen below 384)

const SLIDE_IN_TIME   = 0.7
const PEEK_HOLD_TIME  = 1.2
const SLIDE_OUT_TIME  = 0.45
const PRE_LUNGE_PAUSE = 0.4
const LUNGE_TIME      = 0.18
const SNAP_DURATION   = 0.09  # frame 5 (0.25x) + frame 6 (1.0x) at 16fps ≈ 0.078s
const SNAP_HOLD_TIME  = 0.35  # hold the closed-mouth chomp frame
const LUNGE_LINGER    = 0.18  # idle animation while still extended, before retreating
const RETREAT_TIME    = 0.5
const CYCLE_GAP       = 1.5

const EYE_ENERGY_MAX  = 1.2
const EYE_GLOW_TIME   = 0.5
const EYE_DIM_TIME    = 0.3

# Offsets from sprite center in parent-space (96×32 sprite at 4× scale, head on LEFT unflipped)
const EYE_OFFSET_X  = 132.0   # x distance from center toward head
const EYE_OFFSET_Y  = -12.0
const HEAD_OFFSET_X = 160.0   # x distance from center to kill-zone circle centre

@onready var anim:     AnimatedSprite2D = $AnimatedSprite2D
@onready var eye_light: PointLight2D   = $EyeLight
@onready var kill_col: CollisionShape2D = $KillShape

enum State { HIDDEN, PEEKING, PEEK_HOLD, PEEK_RETREATING, PRE_LUNGE,
			 LUNGING, SNAPPING, SNAP_HOLD, LUNGE_LINGER, LUNGE_RETREATING }
var _state: State = State.HIDDEN

var _on_left:     bool  = true
var _hidden_x:    float
var _peek_x:      float
var _lunge_x:     float
var _left_edge:   float
var _right_edge:  float
var _tween:       Tween = null
var _eye_tween:   Tween = null
var _player:      Node  = null
var _lunge_sfx:   AudioStreamPlayer
var _lunge_sfx_id: int = 0
var _chomp_sfx:   AudioStreamPlayer

var _time:          float = 0.0
var _base_y:        float = 0.0
var _base_y_set:    bool  = false
var _phase:         float
var _freq_y:        float
var _radius_y:      float

func setup(on_left: bool):
	_on_left = on_left

func _ready():
	add_to_group("Eel")
	anim.flip_h = _on_left
	anim.play("Idle")
	kill_col.disabled = false
	eye_light.energy = 0.0
	_player = get_tree().get_first_node_in_group("Player")
	_setup_lunge_sfx()
	_setup_chomp_sfx()
	_phase    = randf() * TAU
	_freq_y   = randf_range(0.4, 0.75)
	_radius_y = randf_range(7.0, 13.0)

	var eye_x = EYE_OFFSET_X if _on_left else -EYE_OFFSET_X
	eye_light.position = Vector2(eye_x, EYE_OFFSET_Y)

	var ctf = get_canvas_transform()
	var vp  = get_viewport_rect().size
	var inv = ctf.affine_inverse()
	_left_edge  = (inv * Vector2.ZERO).x
	_right_edge = (inv * Vector2(vp.x, 0.0)).x

	if _on_left:
		_hidden_x = _left_edge  - HALF_W - 10.0
		_peek_x   = _left_edge  + PEEK_DIST - HALF_W
	else:
		_hidden_x = _right_edge + HALF_W + 10.0
		_peek_x   = _right_edge - PEEK_DIST + HALF_W

	position.x = _hidden_x
	_run_sequence()

func _process(delta):
	# Capture base Y on first frame — world.gd sets global_position.y after add_child()
	if not _base_y_set:
		_base_y = position.y
		_base_y_set = true

	_time += delta
	position.y = _base_y + sin(_time * _freq_y + _phase) * _radius_y

	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		_kill_tween()
		queue_free()

func _run_sequence():
	var dist = randf_range(LUNGE_DIST_MIN, LUNGE_DIST_MAX)
	_lunge_x = _left_edge + dist - HALF_W if _on_left else _right_edge - dist + HALF_W
	_kill_tween()
	_tween = create_tween()

	# Phase 1: peek
	_tween.tween_callback(func(): _set_state(State.PEEKING))
	_tween.tween_property(self, "position:x", _peek_x, SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(func(): _set_state(State.PEEK_HOLD))
	_tween.tween_interval(PEEK_HOLD_TIME)

	_tween.tween_callback(func(): _set_state(State.PEEK_RETREATING))
	_tween.tween_property(self, "position:x", _hidden_x, SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Phase 2: lunge
	_tween.tween_interval(PRE_LUNGE_PAUSE)

	_tween.tween_callback(func(): _set_state(State.LUNGING))
	_tween.tween_property(self, "position:x", _lunge_x, LUNGE_TIME) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	_tween.tween_callback(func(): _set_state(State.SNAPPING))
	_tween.tween_interval(SNAP_DURATION)

	_tween.tween_callback(func(): _set_state(State.SNAP_HOLD))
	_tween.tween_interval(SNAP_HOLD_TIME)

	_tween.tween_callback(func(): _set_state(State.LUNGE_LINGER))
	_tween.tween_interval(LUNGE_LINGER)

	_tween.tween_callback(func(): _set_state(State.LUNGE_RETREATING))
	_tween.tween_property(self, "position:x", _hidden_x, RETREAT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	_tween.tween_interval(CYCLE_GAP)
	_tween.tween_callback(_run_sequence)

func _set_state(new_state: State):
	_state = new_state
	match new_state:
		State.PEEKING:
			anim.play("Idle")
			_tween_eye(EYE_ENERGY_MAX, EYE_GLOW_TIME)
		State.PEEK_HOLD:
			pass
		State.PEEK_RETREATING:
			pass
		State.LUNGING:
			anim.play("LungeOpen")
			_lunge_sfx_id += 1
			var _lid = _lunge_sfx_id
			_lunge_sfx.play(0.0)
			get_tree().create_timer(1.5).timeout.connect(func(): if _lunge_sfx_id == _lid: _lunge_sfx.stop())
		State.SNAPPING:
			anim.play("Snap")
			_chomp_sfx.play(0.0)
		State.SNAP_HOLD:
			anim.stop()
			anim.frame = 1
			_tween_eye(0.0, EYE_DIM_TIME)
		State.LUNGE_LINGER:
			anim.play("Idle")
			_tween_eye(EYE_ENERGY_MAX, EYE_GLOW_TIME)
		State.LUNGE_RETREATING:
			pass

func _setup_lunge_sfx() -> void:
	var bus_name = "EelSFX"
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
	_lunge_sfx.stream = load("res://audio/eel_lunge.wav")
	_lunge_sfx.volume_db = 3.0
	_lunge_sfx.bus = bus_name
	add_child(_lunge_sfx)

func _setup_chomp_sfx() -> void:
	_chomp_sfx = AudioStreamPlayer.new()
	_chomp_sfx.stream = load("res://audio/chomp.wav")
	_chomp_sfx.pitch_scale = 0.6
	_chomp_sfx.volume_db = 0.0
	_chomp_sfx.bus = "EelSFX"
	add_child(_chomp_sfx)

func _tween_eye(target: float, duration: float):
	if _eye_tween:
		_eye_tween.kill()
	_eye_tween = create_tween()
	_eye_tween.tween_property(eye_light, "energy", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _kill_tween():
	if _tween:
		_tween.kill()
		_tween = null

func _on_body_entered(body, _s = null):
	if body.is_in_group("Player"):
		body._trigger_death()
