extends CharacterBody2D

@onready var anim = get_node("AnimatedSprite2D")
@onready var camera = $Camera2D

const MIN_PROPEL_SPEED = 100.0   # Quick tap — small nudge
const MAX_PROPEL_SPEED = 450.0  # Full charge — big burst
const MAX_CHARGE_TIME = 1.0     # Seconds to reach full charge
const GRAVITY = 150.0
const WATER_DRAG_X = 3.0
const WATER_DRAG_Y = 1.5
const ROTATION_SPEED = 8.0
const MIN_RING_RADIUS = 30.0
const MAX_RING_RADIUS = 120.0
const RING_WIDTH = 3.0
const VIEWPORT_WIDTH = 720.0
const VIEWPORT_HEIGHT = 1280.0
const SIDE_MARGIN = 60.0  # Buffer past screen edge before death
const FALL_MARGIN = 80.0  # How far below screen bottom before death
const ENERGY_DRAIN_RATE = 0.01     # Passive drain per second (empties in ~20s)
const ENERGY_SWIM_COST_MIN = 0.01  # Energy cost for a quick tap
const ENERGY_SWIM_COST_MAX = 0.05  # Energy cost for a full-charge burst

var tap_position: Vector2 = Vector2.ZERO
var is_pressing: bool = false
var press_start_time: float = 0.0
var camera_start_x: float = 0.0
var highest_y: float = 0.0  # Tracks the peak position (lowest Y value)
var pulse_time: float = 0.0
var energy: float = 1.0
var _energy_bar_fill: ColorRect
var _energy_bar_bg_height: float = 492.0

func _ready():
	camera_start_x = global_position.x
	highest_y = global_position.y
	_setup_energy_bar()

func _process(delta):
	# Water drag — X always, Y only when moving upward (so gravity pull isn't canceled)
	velocity.x = move_toward(velocity.x, 0.0, WATER_DRAG_X * abs(velocity.x) * delta + 20.0 * delta)
	if velocity.y < 0:
		velocity.y = move_toward(velocity.y, 0.0, WATER_DRAG_Y * abs(velocity.y) * delta + 10.0 * delta)

	# Gravity layered on top of drag
	velocity.y += GRAVITY * delta

	position += velocity * delta

	energy = max(0.0, energy - ENERGY_DRAIN_RATE * delta)
	_update_energy_bar()

	# Death if player drifts off-screen horizontally
	if global_position.x < -SIDE_MARGIN or global_position.x > VIEWPORT_WIDTH + SIDE_MARGIN:
		restart_game()
		return

	move_and_slide()

	# Lock camera: only scrolls up, never back down
	if global_position.y < highest_y:
		highest_y = global_position.y

	# Death if player falls below the locked camera view
	var screen_bottom = highest_y + VIEWPORT_HEIGHT / 2.0
	if global_position.y > screen_bottom + FALL_MARGIN:
		restart_game()
		return

	var tilt_target = clamp(velocity.x / MAX_PROPEL_SPEED, -1.0, 1.0) * deg_to_rad(35.0)
	anim.rotation = lerp_angle(anim.rotation, tilt_target, ROTATION_SPEED * delta)

	# Pulse the sprite scale while charging to give visual feedback
	if is_pressing:
		var charge = _get_charge_percent()
		var squish = 1.0 - charge * 0.2  # Compress up to 20% at full charge
		anim.scale = Vector2(4 * (1.0 + charge * 0.1), 4 * squish)
		pulse_time += delta * 4.0
		queue_redraw()
	else:
		anim.scale = anim.scale.lerp(Vector2(4, 4), ROTATION_SPEED * delta)
		if pulse_time > 0.0:
			pulse_time = 0.0
			queue_redraw()

	camera.position.x = camera_start_x - global_position.x
	# Clamp camera Y so it never scrolls back down — offset from player to stay at peak
	camera.position.y = min(0.0, highest_y - global_position.y)

func _draw():
	if not is_pressing:
		return
	var charge = _get_charge_percent()
	var radius = lerp(MIN_RING_RADIUS, MAX_RING_RADIUS, charge)

	# Glow brightens and shifts from dim teal to bright cyan-white as charge builds
	var base_alpha = lerp(0.15, 0.5, charge)
	# Subtle pulse on the opacity so it feels alive
	var pulse = sin(pulse_time) * 0.08
	var alpha = clamp(base_alpha + pulse, 0.05, 0.6)

	# Color shifts from deep teal at low charge to bright cyan-white at full
	var color = Color(
		lerp(0.0, 0.7, charge),   # R: stays low, rises slightly at full
		lerp(0.5, 1.0, charge),   # G: teal to bright
		lerp(0.6, 1.0, charge),   # B: always strong
		alpha
	)

	# Outer ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, RING_WIDTH, true)

	# Softer inner glow ring — wider, more transparent
	var inner_color = Color(color.r, color.g, color.b, alpha * 0.3)
	draw_arc(Vector2.ZERO, radius * 0.85, 0, TAU, 64, inner_color, RING_WIDTH * 3.0, true)

func _get_charge_percent() -> float:
	var held = Time.get_ticks_msec() / 1000.0 - press_start_time
	return clamp(held / MAX_CHARGE_TIME, 0.0, 1.0)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tap_position = get_global_mouse_position()
			press_start_time = Time.get_ticks_msec() / 1000.0
			anim.play('Set')
			is_pressing = true
		elif is_pressing:
			var charge = _get_charge_percent()
			if energy > 0.0:
				var speed = lerp(MIN_PROPEL_SPEED, MAX_PROPEL_SPEED, charge)
				var diff_x = tap_position.x - global_position.x
				var x_factor = clamp(diff_x / 200.0, -1.0, 1.0)
				var y_factor = -sqrt(1.0 - x_factor * x_factor)
				y_factor = min(y_factor, -0.15)
				velocity = Vector2(x_factor, y_factor).normalized() * speed
				var cost = lerp(ENERGY_SWIM_COST_MIN, ENERGY_SWIM_COST_MAX, charge)
				energy = max(0.0, energy - cost)
			anim.play('Float')
			is_pressing = false

func restore_energy(amount: float):
	energy = min(1.0, energy + amount)

func _setup_energy_bar():
	var canvas = CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0.05, 0.15, 0.65)
	bg.position = Vector2(672, 200)
	bg.size = Vector2(36, 500)
	canvas.add_child(bg)

	var fill = ColorRect.new()
	fill.color = Color(0, 0.85, 1, 0.85)
	fill.position = Vector2(4, 4)
	fill.size = Vector2(28, _energy_bar_bg_height)
	bg.add_child(fill)
	_energy_bar_fill = fill

func _update_energy_bar():
	if not _energy_bar_fill:
		return
	var fill_height = _energy_bar_bg_height * energy
	_energy_bar_fill.size.y = fill_height
	_energy_bar_fill.position.y = (_energy_bar_bg_height - fill_height) + 4
	_energy_bar_fill.color = Color(
		lerp(0.9, 0.0, energy),
		lerp(0.15, 0.85, energy),
		lerp(0.1, 1.0, energy),
		0.85
	)

func restart_game():
	var tracker = get_node_or_null("/root/World/ScoreTracker")
	if tracker:
		tracker.save_if_high_score()
	get_tree().change_scene_to_file("res://main.tscn")
