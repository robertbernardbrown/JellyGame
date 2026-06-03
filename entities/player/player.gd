extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var _light: PointLight2D = $Light/LightTexture

const MIN_PROPEL_SPEED = 200.0   # Quick tap — small nudge
const MAX_PROPEL_SPEED = 900.0  # Full charge — big burst
const MAX_CHARGE_TIME = 1.0     # Seconds to reach full charge
const GRAVITY = 300.0
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
const ENERGY_SWIM_COST_MIN = 0.01  # Cost for a minimal tap
const ENERGY_SWIM_COST_MAX = 0.06  # Cost for a full-charge burst
const LIGHT_SCALE_MIN = 3.99
const LIGHT_SCALE_MAX = 14.98
const MIN_PULL_DISTANCE = 50.0   # pixels of drag before aim activates
const PULL_FULL_DISTANCE = 150.0 # pixels of drag for pull_factor to reach 1.0

var tap_position: Vector2 = Vector2.ZERO
var is_pressing: bool = false
var press_start_time: float = 0.0
var camera_start_x: float = 0.0
var highest_y: float = 0.0  # Tracks the peak position (lowest Y value)
var pulse_time: float = 0.0
var energy: float = 1.0
var _displayed_energy: float = 1.0
var _energy_bar_mat: ShaderMaterial
var _energy_bar: TextureRect
var _flash_amount: float = 0.0
var _time: float = 0.0
var _dying: bool = false
var _death_velocity: float = 0.0
var _free_swim: bool = false
var current_touch_pos: Vector2 = Vector2.ZERO

const DEBUG_JUMP_METERS = 100.0
var _debug_noclip: bool = false
var _debug_label: Label = null

func _ready():
	camera_start_x = global_position.x
	highest_y = global_position.y
	var mat = ShaderMaterial.new()
	mat.shader = load("res://entities/player/flash.gdshader")
	anim.material = mat
	_free_swim = get_tree().get_meta("free_swim", false)
	if not _free_swim:
		_setup_energy_bar.call_deferred()
	_setup_plankton_counter.call_deferred()

func _process(delta):
	if _dying:
		_process_death(delta)
		return

	if _debug_noclip:
		_process_noclip(delta)
		return

	# Water drag — X always, Y only when moving upward (so gravity pull isn't canceled)
	velocity.x = move_toward(velocity.x, 0.0, WATER_DRAG_X * abs(velocity.x) * delta + 20.0 * delta)
	if velocity.y < 0:
		velocity.y = move_toward(velocity.y, 0.0, WATER_DRAG_Y * abs(velocity.y) * delta + 10.0 * delta)

	# Gravity layered on top of drag
	velocity.y += GRAVITY * delta

	_time += delta
	_update_energy_bar(delta)
	_update_light_scale()

	if _flash_amount > 0.0:
		_flash_amount = maxf(0.0, _flash_amount - delta * 4.0)
		(anim.material as ShaderMaterial).set_shader_parameter("flash", _flash_amount)

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
	var base_alpha = lerp(0.15, 0.5, charge)
	var pulse = sin(pulse_time) * 0.08
	var alpha = clamp(base_alpha + pulse, 0.05, 0.6)
	var color = Color(
		lerp(0.0, 0.7, charge),
		lerp(0.5, 1.0, charge),
		lerp(0.6, 1.0, charge),
		alpha
	)
	_draw_charge_shape(_get_aim_direction(), radius, _get_pull_factor(), color)

func _draw_charge_shape(aim_dir: Vector2, radius: float, pull_factor: float, color: Color):
	var n_points := 64
	var launch_angle := atan2(aim_dir.y, aim_dir.x)
	# Arc spans full circle at no pull, back-semicircle at full pull
	var arc_span: float = lerp(TAU, PI, pull_factor)
	var arc_start: float = (launch_angle + PI) - arc_span / 2.0
	# Tip extends from the circle edge outward in the launch direction
	var tip_dist: float = radius * (1.0 + 1.5 * pull_factor)
	var tip := aim_dir * tip_dist

	var poly := PackedVector2Array()
	for i in range(n_points + 1):
		var t := float(i) / n_points
		var angle := arc_start + t * arc_span
		poly.append(Vector2(cos(angle), sin(angle)) * radius)
	if pull_factor > 0.01:
		poly.append(tip)

	draw_colored_polygon(poly, Color(color.r, color.g, color.b, color.a * 0.25))

	var outline := PackedVector2Array(poly)
	outline.append(outline[0])
	draw_polyline(outline, color, RING_WIDTH, true)

	# Inner glow — slightly smaller, softer
	var ir := radius * 0.85
	var inner_poly := PackedVector2Array()
	for i in range(n_points + 1):
		var t := float(i) / n_points
		var angle := arc_start + t * arc_span
		inner_poly.append(Vector2(cos(angle), sin(angle)) * ir)
	if pull_factor > 0.01:
		inner_poly.append(aim_dir * (ir * (1.0 + 1.5 * pull_factor)))
	draw_colored_polygon(inner_poly, Color(color.r, color.g, color.b, color.a * 0.12))

func _get_charge_percent() -> float:
	var held = Time.get_ticks_msec() / 1000.0 - press_start_time
	return clamp(held / MAX_CHARGE_TIME, 0.0, 1.0)

func _get_aim_direction() -> Vector2:
	var drag := current_touch_pos - tap_position
	if drag.length() < MIN_PULL_DISTANCE:
		return Vector2.UP
	# Slingshot: launch opposite the drag vector
	var dir := -drag.normalized()
	# No downward launches — clamp Y so we never go below horizontal
	dir.y = minf(dir.y, 0.0)
	if dir.is_zero_approx():
		return Vector2.UP
	return dir.normalized()

func _get_pull_factor() -> float:
	var drag_len := (current_touch_pos - tap_position).length()
	return clamp((drag_len - MIN_PULL_DISTANCE) / (PULL_FULL_DISTANCE - MIN_PULL_DISTANCE), 0.0, 1.0)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				_toggle_noclip()
			KEY_F2:
				if _debug_noclip:
					_debug_teleport(100.0)
			KEY_F3:
				if _debug_noclip:
					_debug_teleport(-100.0)

	if event is InputEventMouseMotion and is_pressing:
		current_touch_pos = get_global_mouse_position()
		queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _dying:
			return
		if event.pressed:
			tap_position = get_global_mouse_position()
			current_touch_pos = tap_position
			press_start_time = Time.get_ticks_msec() / 1000.0
			anim.play('Set')
			is_pressing = true
		elif is_pressing:
			var charge = _get_charge_percent()
			var speed = lerp(MIN_PROPEL_SPEED, MAX_PROPEL_SPEED, charge)
			velocity = _get_aim_direction() * speed
			if not _free_swim:
				energy = maxf(0.0, energy - lerp(ENERGY_SWIM_COST_MIN, ENERGY_SWIM_COST_MAX, charge))
				if energy <= 0.0:
					_trigger_death()
			anim.play('Float')
			is_pressing = false

func restore_energy(amount: float):
	energy = min(1.0, energy + amount)
	_flash_amount = 1.0

func _setup_energy_bar():
	var hud = get_node_or_null("/root/World/HUD")
	if not hud:
		return

	var bar = TextureRect.new()
	bar.texture = load("res://assets/sprites/resource_meter/resource_meter_pink.png")
	bar.stretch_mode = TextureRect.STRETCH_KEEP
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat = ShaderMaterial.new()
	mat.shader = load("res://entities/player/energy_bar.gdshader")
	mat.set_shader_parameter("fill_amount", 1.0)
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.size = Vector2(VIEWPORT_WIDTH, 80)
	bar.material = mat
	_energy_bar_mat = mat
	_energy_bar = bar

	hud.add_child(bar)
	var vh = get_viewport().get_visible_rect().size.y
	bar.position = Vector2(0, vh - 72)


func _setup_plankton_counter():
	var hud = get_node_or_null("/root/World/HUD")
	if not hud:
		return

	var y = 108

	var icon = TextureRect.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/plankton/plankton.png")
	atlas.region = Rect2(0, 16, 16, 16)
	icon.texture = atlas
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(icon)
	icon.size = Vector2(48, 48)
	icon.position = Vector2(16, y)

	var label = Label.new()
	label.name = "ScoreDisplay"
	label.text = "0"
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.0, 0.5))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(label)
	label.position = Vector2(72, y + 4)



func _update_light_scale():
	var s = lerp(LIGHT_SCALE_MIN, LIGHT_SCALE_MAX, _displayed_energy)
	var f = 1.0 + sin(_time * 0.9) * 0.08
	_light.scale = Vector2(s * f, s * f)

func _update_energy_bar(delta: float):
	# Drain tracks fast (feels responsive), fill tracks slower (feels rewarding)
	var speed = 10.0 if energy < _displayed_energy else 5.0
	_displayed_energy = lerp(_displayed_energy, energy, speed * delta)
	if not _energy_bar_mat:
		return
	_energy_bar_mat.set_shader_parameter("fill_amount", _displayed_energy)

func _trigger_death():
	if _dying:
		return
	_dying = true
	is_pressing = false
	velocity = Vector2.ZERO
	_displayed_energy = 0.0
	if _energy_bar_mat:
		_energy_bar_mat.set_shader_parameter("fill_amount", 0.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	anim.scale = Vector2(4, -4)
	anim.play('Float')
	_show_game_over()

func _show_game_over():
	var hud = get_node_or_null("/root/World/HUD")
	if not hud:
		return
	var label = Label.new()
	label.text = "GAME OVER"
	var bungee = load("res://assets/fonts/bungee/Bungee-Regular.ttf")
	label.add_theme_font_override("font", bungee)
	label.add_theme_font_size_override("font_size", 90)
	label.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.5, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 5)
	label.add_theme_constant_override("shadow_offset_y", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(VIEWPORT_WIDTH, 0)
	label.position = Vector2(0, VIEWPORT_HEIGHT / 2.0 - 80.0)
	hud.add_child(label)

func _process_death(delta: float):
	_death_velocity += GRAVITY * delta
	global_position.y += _death_velocity * delta
	var screen_bottom = highest_y + VIEWPORT_HEIGHT / 2.0
	if global_position.y > screen_bottom + 300.0:
		get_tree().paused = false
		restart_game()

func restart_game():
	var tracker = get_node_or_null("/root/World/ScoreTracker")
	if tracker:
		tracker.save_if_high_score()
	get_tree().change_scene_to_file("res://main.tscn")

func _process_noclip(delta: float):
	energy = 1.0
	_time += delta
	_update_energy_bar(delta)
	_update_light_scale()

	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * 600.0
	move_and_slide()

	if global_position.y < highest_y:
		highest_y = global_position.y

	camera.position.x = camera_start_x - global_position.x
	camera.position.y = min(0.0, highest_y - global_position.y)

func _debug_teleport(metres: float):
	var new_y = global_position.y - metres * 50.0
	global_position.y = new_y
	highest_y = minf(highest_y, new_y)
	velocity = Vector2.ZERO

func _toggle_noclip():
	_debug_noclip = not _debug_noclip
	velocity = Vector2.ZERO
	if not _debug_label:
		var hud = get_node_or_null("/root/World/HUD")
		if hud:
			_debug_label = Label.new()
			_debug_label.add_theme_color_override("font_color", Color(1, 1, 0, 0.85))
			_debug_label.add_theme_font_size_override("font_size", 20)
			_debug_label.position = Vector2(12, 12)
			hud.add_child(_debug_label)
	if _debug_label:
		_debug_label.text = "DEBUG: noclip ON  |  F2 = +100m  |  F3 = -100m" if _debug_noclip else ""
