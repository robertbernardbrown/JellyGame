extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var _light: PointLight2D = $Light/LightTexture
@onready var _swim_sfx: AudioStreamPlayer = $SwimSFX
var _warning_sfx: AudioStreamPlayer
var _warning_loop_id: int = 0
var _plankton_sfx: AudioStreamPlayer
var _plankton_sfx_id: int = 0
var _splat_sfx: AudioStreamPlayer

const MIN_PROPEL_SPEED = 280.0
const MAX_PROPEL_SPEED = 670.0
const MAX_CHARGE_TIME = 1.0     # Seconds to reach full charge
const GRAVITY = 320.0
const WATER_DRAG_X = 2.0
const WATER_DRAG_Y = 1.6
const ROTATION_SPEED = 8.0
const MIN_RING_RADIUS = 20.0
const MAX_RING_RADIUS = 85.0
const RING_WIDTH = 3.0
const VIEWPORT_WIDTH = 720.0
const VIEWPORT_HEIGHT = 1280.0
const SIDE_MARGIN = 60.0  # Buffer past screen edge before death
const FALL_MARGIN = 80.0  # How far below screen bottom before death
const ENERGY_SWIM_COST_MIN = 0.02
const ENERGY_SWIM_COST_MAX = 0.08
const LIGHT_SCALE_MIN = 3.2
const LIGHT_SCALE_MAX = 11.5
const MIN_PULL_DISTANCE = 50.0   # pixels of drag before aim activates
const PULL_FULL_DISTANCE = 320.0 # pixels of drag for pull_factor to reach 1.0

var _start_y: float = 0.0
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
var _light_bonus: float = 0.0
var _light_bonus_target: float = 0.0
var _time: float = 0.0
var _dying: bool = false
var _death_velocity: float = 0.0
var _free_swim: bool = false
var current_touch_pos: Vector2 = Vector2.ZERO
var _plankton_count: int = 0
var _brine_pool_count: int = 0
var _blink_time: float = 0.0
var _in_tutorial: bool = false
var _swim_sfx_id: int = 0

const _BUBBLE_PUFF = preload("res://entities/player/bubble_puff.gd")

func set_in_tutorial(value: bool):
	_in_tutorial = value
	if _in_tutorial:
		velocity = Vector2.ZERO
		anim.play('Float')

func _ready():
	camera_start_x = global_position.x
	highest_y = global_position.y
	_start_y = global_position.y
	var mat = ShaderMaterial.new()
	mat.shader = load("res://entities/player/flash.gdshader")
	anim.material = mat
	_free_swim = get_tree().get_meta("free_swim", false)
	if not _free_swim:
		_setup_energy_bar.call_deferred()
	_setup_plankton_counter.call_deferred()
	_setup_swim_sfx_bus()
	_setup_warning_sfx()
	_setup_plankton_sfx()
	_setup_splat_sfx()

func _setup_swim_sfx_bus() -> void:
	var bus_name = "SwimSFX"
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "SFX")
		var lpf = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 1100.0
		lpf.resonance = 0.5
		AudioServer.add_bus_effect(idx, lpf)
		var reverb = AudioEffectReverb.new()
		reverb.room_size = 0.75
		reverb.damping = 0.6
		reverb.wet = 0.1
		AudioServer.add_bus_effect(idx, reverb)
	var final_bus = bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"
	_swim_sfx.bus = final_bus
	_swim_sfx.pitch_scale = 1.6
	_swim_sfx.volume_db = -10.0

func _setup_warning_sfx() -> void:
	var bus_name = "WarningSFX"
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
		var lpf = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 600.0
		lpf.resonance = 0.3
		AudioServer.add_bus_effect(idx, lpf)
		var reverb = AudioEffectReverb.new()
		reverb.room_size = 0.85
		reverb.damping = 0.7
		reverb.wet = 0.35
		AudioServer.add_bus_effect(idx, reverb)
	_warning_sfx = AudioStreamPlayer.new()
	_warning_sfx.stream = load("res://audio/new_sonar.wav")
	_warning_sfx.pitch_scale = 0.45
	_warning_sfx.volume_db = -4.0
	_warning_sfx.bus = bus_name
	add_child(_warning_sfx)

func _setup_plankton_sfx() -> void:
	var bus_name = "PlanktonSFX"
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
		var lpf = AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 700.0
		lpf.resonance = 0.5
		AudioServer.add_bus_effect(idx, lpf)
		var reverb = AudioEffectReverb.new()
		reverb.room_size = 0.85
		reverb.damping = 0.5
		reverb.wet = 0.45
		AudioServer.add_bus_effect(idx, reverb)
	_plankton_sfx = AudioStreamPlayer.new()
	_plankton_sfx.stream = load("res://audio/plankton.mp3")
	_plankton_sfx.bus = bus_name
	add_child(_plankton_sfx)

func _setup_splat_sfx() -> void:
	var bus_name = "SplatSFX"
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
	_splat_sfx = AudioStreamPlayer.new()
	_splat_sfx.stream = load("res://audio/splat.wav")
	_splat_sfx.bus = bus_name
	add_child(_splat_sfx)

func _start_warning_loop() -> void:
	_warning_loop_id += 1
	var id = _warning_loop_id
	_warning_sfx.play(0.0)
	get_tree().create_timer(2.0).timeout.connect(func(): _on_warning_timer(id))

func _on_warning_timer(id: int) -> void:
	if id != _warning_loop_id:
		return
	_warning_loop_id += 1
	var new_id = _warning_loop_id
	_warning_sfx.play(0.0)
	get_tree().create_timer(2.0).timeout.connect(func(): _on_warning_timer(new_id))

func _stop_warning_loop() -> void:
	_warning_loop_id += 1
	_warning_sfx.stop()

func _process(delta):
	if _dying:
		_process_death(delta)
		return

	if _in_tutorial:
		velocity = Vector2.ZERO
		_time += delta
		_update_light_scale()
		return

	# Water drag — X always, Y only when moving upward (so gravity pull isn't canceled)
	velocity.x = move_toward(velocity.x, 0.0, WATER_DRAG_X * abs(velocity.x) * delta + 20.0 * delta)
	if velocity.y < 0:
		velocity.y = move_toward(velocity.y, 0.0, WATER_DRAG_Y * abs(velocity.y) * delta + 10.0 * delta)
	if _brine_pool_count > 0:
		velocity = velocity.move_toward(Vector2.ZERO, 320.0 * delta)

	# Gravity layered on top of drag
	velocity.y += GRAVITY * delta

	_time += delta
	_light_bonus_target = maxf(0.0, _light_bonus_target - delta * 0.07)
	_light_bonus = lerpf(_light_bonus, _light_bonus_target, delta * 2.5)
	_update_energy_bar(delta)
	_update_light_scale()
	if not _free_swim:
		if energy < 0.35:
			if not _warning_sfx.playing:
				_start_warning_loop()
		elif _warning_sfx.playing:
			_stop_warning_loop()

	if _flash_amount > 0.0:
		_flash_amount = maxf(0.0, _flash_amount - delta * 4.0)
		(anim.material as ShaderMaterial).set_shader_parameter("flash", _flash_amount)

	# Death if player drifts off-screen horizontally
	if global_position.x < -SIDE_MARGIN or global_position.x > VIEWPORT_WIDTH + SIDE_MARGIN:
		_trigger_death()
		return

	move_and_slide()

	# Lock camera: only scrolls up, never back down
	if global_position.y < highest_y:
		highest_y = global_position.y

	# Death if player falls below the locked camera view
	var screen_bottom = highest_y + VIEWPORT_HEIGHT / 2.0
	if global_position.y > screen_bottom + FALL_MARGIN:
		_trigger_death()
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
	if pull_factor > 0.05:
		_draw_bell_dome(aim_dir, radius, pull_factor, color)
		_draw_tentacles(aim_dir, radius, pull_factor, color)

func _draw_bell_dome(aim_dir: Vector2, radius: float, pull_factor: float, color: Color):
	var perp := Vector2(-aim_dir.y, aim_dir.x)
	var dome_width: float = lerp(radius * 0.75, radius * 1.15, pull_factor)
	var dome_height: float = dome_width * 0.6
	var pulse_scale := 1.0 + sin(_time * 2.5) * 0.04
	dome_width *= pulse_scale
	dome_height *= pulse_scale
	var poly := PackedVector2Array()
	for i in range(33):
		var t: float = float(i) / 32.0
		var angle: float = lerp(-PI / 2.0, PI / 2.0, t)
		poly.append(aim_dir * cos(angle) * dome_height + perp * sin(angle) * dome_width)
	draw_polyline(poly, Color(color.r, color.g, color.b, color.a * 0.7), RING_WIDTH * 0.85, true)

func _draw_tentacles(aim_dir: Vector2, radius: float, pull_factor: float, color: Color):
	var trail_dir := -aim_dir
	var perp := Vector2(-trail_dir.y, trail_dir.x)
	var n_points := 22
	var length: float = 130.0 * pull_factor
	var wave_amp := 12.0
	var wave_freq := 2.2
	for i in range(3):
		var phase: float = float(i) / 3.0 * TAU
		var spread: float = lerp(-16.0, 16.0, float(i) / 2.0)
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for j in range(n_points + 1):
			var t: float = float(j) / float(n_points)
			var lateral: float = spread * (1.0 - t * 0.7) + sin(t * wave_freq * TAU + _time * 3.5 + phase) * wave_amp * t
			points.append(trail_dir * (radius * 0.6 + t * length) + perp * lateral)
			colors.append(Color(color.r, color.g, color.b, color.a * (1.0 - t)))
		draw_polyline_colors(points, colors, 2.5, true)

func _spawn_launch_bubbles(aim_dir: Vector2, charge: float) -> void:
	var parent = get_parent()
	if not parent:
		return
	var trail_dir := -aim_dir
	var perp := Vector2(-aim_dir.y, aim_dir.x)
	var count := int(lerp(3.0, 8.0, charge))
	for i in range(count):
		var bubble = _BUBBLE_PUFF.new()
		parent.add_child(bubble)
		bubble.global_position = global_position
		var trail_speed: float = randf_range(50.0, 130.0) * lerp(0.4, 1.0, charge)
		var vel := trail_dir * trail_speed + perp * randf_range(-55.0, 55.0)
		var radius: float = randf_range(3.0, 7.0)
		var lifetime: float = randf_range(0.4, 0.9)
		var col := Color(0.2, 0.85, 1.0, randf_range(0.55, 0.85))
		bubble.setup(vel, radius, col, lifetime)


func _get_charge_percent() -> float:
	return _get_pull_factor()

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
	var factor: float = clamp((drag_len - MIN_PULL_DISTANCE) / (PULL_FULL_DISTANCE - MIN_PULL_DISTANCE), 0.0, 1.0)
	if _brine_pool_count > 0:
		factor *= 0.45
	return factor

func _unhandled_input(event):
	if event is InputEventMouseMotion and is_pressing:
		current_touch_pos = get_global_mouse_position()
		queue_redraw()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _dying:
			return
		if _in_tutorial:
			_in_tutorial = false
			var path = "user://tutorial_seen_free_swim.save" if _free_swim else "user://tutorial_seen.save"
			var f = FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_var(true)
				f.close()
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
			_spawn_launch_bubbles(_get_aim_direction(), charge)
			_swim_sfx_id += 1
			var _sfx_id = _swim_sfx_id
			_swim_sfx.pitch_scale = randf_range(4.0, 5.0)
			_swim_sfx.volume_db = randf_range(-12.0, -8.0)
			_swim_sfx.play(0.06)
			var _pitch_tween = create_tween()
			_pitch_tween.tween_property(_swim_sfx, "pitch_scale", randf_range(7.0, 8.5), 0.24)
			get_tree().create_timer(0.24).timeout.connect(func(): if _swim_sfx_id == _sfx_id: _swim_sfx.stop())
			if not _free_swim:
				energy = maxf(0.0, energy - lerp(ENERGY_SWIM_COST_MIN, ENERGY_SWIM_COST_MAX, charge))
				if energy <= 0.0:
					_trigger_death()
			anim.play('Float')
			is_pressing = false

func restore_energy(amount: float):
	energy = min(1.0, energy + amount)
	_flash_amount = 1.0

func collect_plankton(amount: float):
	restore_energy(amount)
	_light_bonus_target = minf(1.0, _light_bonus_target + 0.18)
	_plankton_count += 1
	_plankton_sfx_id += 1
	var _pid = _plankton_sfx_id
	_plankton_sfx.play(0.02)
	get_tree().create_timer(0.1).timeout.connect(func(): if _plankton_sfx_id == _pid: _plankton_sfx.stop())

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
	var depth_px: float = _start_y - highest_y
	var depth_t: float = clampf(1.0 - depth_px / 1400.0, 0.0, 1.0)
	var t: float = clampf(depth_t + _light_bonus, 0.0, 1.0)
	var s: float = lerp(LIGHT_SCALE_MIN, LIGHT_SCALE_MAX, t)
	var f: float = 1.0 + sin(_time * 0.9) * 0.08
	_light.scale = Vector2(s * f, s * f)

func _update_energy_bar(delta: float):
	# Drain tracks fast (feels responsive), fill tracks slower (feels rewarding)
	var speed = 10.0 if energy < _displayed_energy else 5.0
	_displayed_energy = lerp(_displayed_energy, energy, speed * delta)
	if not _energy_bar_mat:
		return
	_energy_bar_mat.set_shader_parameter("fill_amount", _displayed_energy)
	if energy < 0.35:
		_blink_time += delta
		var t = (sin(_blink_time * TAU * 1.5) + 1.0) * 0.5
		_energy_bar_mat.set_shader_parameter("tint_color", Color(1.0 - t, 1.0, 1.0))
	else:
		_blink_time = 0.0
		_energy_bar_mat.set_shader_parameter("tint_color", Color.WHITE)

func _trigger_death():
	if _dying:
		return
	_dying = true
	_stop_warning_loop()
	_splat_sfx.play()
	is_pressing = false
	velocity = Vector2.ZERO
	_displayed_energy = 0.0
	_blink_time = 0.0
	if _energy_bar_mat:
		_energy_bar_mat.set_shader_parameter("fill_amount", 0.0)
	if _energy_bar_mat:
		_energy_bar_mat.set_shader_parameter("tint_color", Color.WHITE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	anim.scale = Vector2(4, -4)
	anim.play('Float')
	_show_game_over()

func _show_game_over():
	var hud = get_node_or_null("/root/World/HUD")
	if not hud:
		return
	var bungee = load("res://assets/fonts/bungee/Bungee-Regular.ttf")

	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_override("font", bungee)
	title.add_theme_font_size_override("font_size", 90)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.5, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 5)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(VIEWPORT_WIDTH, 0)
	title.position = Vector2(0, VIEWPORT_HEIGHT / 2.0 - 120.0)
	hud.add_child(title)

	var dist_m: int = int((_start_y - highest_y) / 50.0)
	var effective_plankton: int = max(1, _plankton_count)
	var final_score: int = dist_m * effective_plankton

	var plankton_atlas = AtlasTexture.new()
	plankton_atlas.atlas = load("res://assets/sprites/plankton/plankton.png")
	plankton_atlas.region = Rect2(0, 16, 16, 16)

	var tracker = get_node_or_null("/root/World/ScoreTracker")
	var prev_best := {"score": 0, "distance": 0, "plankton": 1}
	if tracker:
		prev_best = tracker.get_best_score_data()
	var is_new_best: bool = final_score > prev_best.score

	if is_new_best:
		var nb_label = Label.new()
		nb_label.text = "NEW BEST!"
		nb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nb_label.custom_minimum_size = Vector2(VIEWPORT_WIDTH, 0)
		nb_label.position = Vector2(0, VIEWPORT_HEIGHT / 2.0 + 0.0)
		nb_label.add_theme_font_override("font", bungee)
		nb_label.add_theme_font_size_override("font_size", 52)
		nb_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.1, 1.0))
		nb_label.add_theme_color_override("font_shadow_color", Color(0.4, 0.3, 0.0, 0.5))
		nb_label.add_theme_constant_override("shadow_offset_x", 3)
		nb_label.add_theme_constant_override("shadow_offset_y", 3)
		hud.add_child(nb_label)

	var run_rtl = RichTextLabel.new()
	run_rtl.bbcode_enabled = true
	run_rtl.fit_content = true
	run_rtl.scroll_active = false
	run_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_rtl.custom_minimum_size = Vector2(VIEWPORT_WIDTH, 50)
	run_rtl.position = Vector2(0, VIEWPORT_HEIGHT / 2.0 + (70.0 if is_new_best else 30.0))
	run_rtl.add_theme_font_override("normal_font", bungee)
	run_rtl.add_theme_font_size_override("normal_font_size", 36)
	run_rtl.add_theme_color_override("default_color", Color(1.0, 0.85, 0.2, 0.95))
	run_rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	run_rtl.add_text("%dm  ×  %d  " % [dist_m, effective_plankton])
	run_rtl.add_image(plankton_atlas, 36, 36)
	run_rtl.add_text("  =  %d" % [final_score])
	run_rtl.pop()
	hud.add_child(run_rtl)

	if not is_new_best and prev_best.score > 0:
		var best_rtl = RichTextLabel.new()
		best_rtl.bbcode_enabled = true
		best_rtl.fit_content = true
		best_rtl.scroll_active = false
		best_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		best_rtl.custom_minimum_size = Vector2(VIEWPORT_WIDTH, 40)
		best_rtl.position = Vector2(0, VIEWPORT_HEIGHT / 2.0 + 100.0)
		best_rtl.add_theme_font_override("normal_font", bungee)
		best_rtl.add_theme_font_size_override("normal_font_size", 28)
		best_rtl.add_theme_color_override("default_color", Color(0.0, 0.85, 1.0, 0.8))
		best_rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
		best_rtl.add_text("BEST:  %dm  ×  %d  " % [prev_best.distance, prev_best.plankton])
		best_rtl.add_image(plankton_atlas, 28, 28)
		best_rtl.add_text("  =  %d" % [prev_best.score])
		best_rtl.pop()
		hud.add_child(best_rtl)

func _process_death(delta: float):
	_death_velocity += GRAVITY * delta
	global_position.y += _death_velocity * delta
	var screen_bottom = highest_y + VIEWPORT_HEIGHT / 2.0
	if global_position.y > screen_bottom + 300.0:
		get_tree().paused = false
		restart_game()

func enter_brine_pool():
	_brine_pool_count += 1
	if _brine_pool_count == 1:
		SettingsManager.set_brine_lpf(true)

func exit_brine_pool():
	_brine_pool_count = maxi(0, _brine_pool_count - 1)
	if _brine_pool_count == 0:
		SettingsManager.set_brine_lpf(false)

func restart_game():
	var tracker = get_node_or_null("/root/World/ScoreTracker")
	if tracker:
		tracker.finalize_score(_plankton_count)
		tracker.save_if_high_score()
	get_tree().change_scene_to_file("res://main.tscn")
