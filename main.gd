extends Node2D

const JELLY_BEHIND_COUNT = 13
const JELLY_FRONT_COUNT = 5
const VIEWPORT_WIDTH = 720.0
const VIEWPORT_HEIGHT = 1280.0
const BLOOM_SINK_RATE = 0.90

var jelly_sheet: Texture2D
var idle_frames: SpriteFrames

# Each jelly stores: {node, speed, sway_offset, sway_speed}
var jellies: Array = []

var bungee_font: Font

func _ready():
	jelly_sheet = preload("res://assets/sprites/player/jelly_animations-Sheet.png")
	bungee_font = preload("res://assets/fonts/bungee/Bungee-Regular.ttf")
	idle_frames = _build_idle_frames()
	_spawn_bloom()
	_apply_theme()
	_load_high_score()
	MusicManager.set_title_volume()
	_add_settings_button()

func _build_idle_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.add_animation("Idle")
	frames.set_animation_loop("Idle", true)
	frames.set_animation_speed("Idle", 11.0)

	# Row 1 forward (frames 0-9) then backward (8-1) — ping-pong like the player
	for x in range(10):
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = jelly_sheet
		atlas_tex.region = Rect2(x * 32, 0, 32, 32)
		frames.add_frame("Idle", atlas_tex)
	for x in range(8, 0, -1):
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = jelly_sheet
		atlas_tex.region = Rect2(x * 32, 0, 32, 32)
		frames.add_frame("Idle", atlas_tex)

	return frames

func _spawn_bloom():
	_spawn_jellies(JELLY_BEHIND_COUNT, $JellyBloomBehind, 0.2, 0.45)
	_spawn_jellies(JELLY_FRONT_COUNT, $JellyBloom, 0.4, 0.7)

func _spawn_jellies(count: int, container: Node2D, alpha_min: float, alpha_max: float):
	for i in range(count):
		var jelly = AnimatedSprite2D.new()
		jelly.sprite_frames = idle_frames
		var s = randf_range(1.5, 3.0)
		jelly.scale = Vector2(s, s)
		jelly.position = Vector2(
			randf_range(60, VIEWPORT_WIDTH - 60),
			randf_range(0, VIEWPORT_HEIGHT)
		)
		jelly.modulate = Color(1, 1, 1, randf_range(alpha_min, alpha_max))
		jelly.play("Idle")
		jelly.frame = randi_range(0, 17)

		container.add_child(jelly)

		jellies.append({
			"node": jelly,
			"speed": randf_range(30.0, 80.0),
			"sway_offset": randf_range(0, TAU),
			"sway_speed": randf_range(0.5, 1.5),
			"sway_amount": randf_range(15.0, 40.0),
			"base_x": jelly.position.x,
		})

func _process(delta):
	for j in jellies:
		var node: AnimatedSprite2D = j.node
		# Burst of speed at the pulse peak (frames 8-11), drift slowly otherwise
		var frame = node.frame
		var is_pulsing = frame >= 6 and frame <= 11
		if is_pulsing:
			node.position.y -= j.speed * 3.0 * delta
		else:
			node.position.y += j.speed * BLOOM_SINK_RATE * delta
		# Gentle side-to-side sway
		j.sway_offset += j.sway_speed * delta
		node.position.x = j.base_x + sin(j.sway_offset) * j.sway_amount

		# Wrap around — when a jelly floats off the top, respawn at the bottom
		if node.position.y < -100:
			node.position.y = VIEWPORT_HEIGHT + 100
			j.base_x = randf_range(60, VIEWPORT_WIDTH - 60)
			node.position.x = j.base_x

func _apply_theme():
	$Title.add_theme_font_override("font", bungee_font)
	$Title.add_theme_font_size_override("font_size", 88)
	$Title.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0))
	$Title.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.5, 0.6))
	$Title.add_theme_constant_override("shadow_offset_x", 5)
	$Title.add_theme_constant_override("shadow_offset_y", 5)

	for score_label in [$HighScore, $FreeSwimScore]:
		score_label.add_theme_font_override("font", bungee_font)
		score_label.add_theme_font_size_override("font_size", 40)
		score_label.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0, 0.8))

	for button in [$Start, $Quit]:
		button.add_theme_font_override("font", bungee_font)
		button.add_theme_font_size_override("font_size", 60)
		button.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.4, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.7, 1.0, 1.0))

		var normal = StyleBoxFlat.new()
		normal.bg_color = Color(0.04, 0.08, 0.25, 0.85)
		normal.border_color = Color(0.0, 0.7, 0.9, 0.5)
		normal.set_border_width_all(3)
		normal.set_corner_radius_all(16)
		normal.set_content_margin_all(20)
		button.add_theme_stylebox_override("normal", normal)

		var hover = normal.duplicate()
		hover.bg_color = Color(0.06, 0.12, 0.35, 0.9)
		hover.border_color = Color(0.0, 0.9, 1.0, 0.8)
		button.add_theme_stylebox_override("hover", hover)

		var pressed = normal.duplicate()
		pressed.bg_color = Color(0.1, 0.2, 0.45, 0.95)
		pressed.border_color = Color(0.2, 1.0, 1.0, 0.9)
		button.add_theme_stylebox_override("pressed", pressed)

func _load_high_score():
	var data := {}
	var file = FileAccess.open("user://highscore.save", FileAccess.READ)
	if file:
		var raw = file.get_var()
		file.close()
		if raw is Dictionary:
			data = raw
	_build_score_display($HighScore,
		data.get("best_score", 0),
		data.get("best_distance", 0),
		data.get("best_plankton", 1))
	_build_score_display($FreeSwimScore,
		data.get("free_swim_best_score", 0),
		data.get("free_swim_best_distance", 0),
		data.get("free_swim_best_plankton", 1))

func _build_score_display(placeholder: Label, score: int, distance: int, plankton: int):
	if score == 0:
		placeholder.text = "BEST: —"
		return
	placeholder.hide()
	var plankton_atlas = AtlasTexture.new()
	plankton_atlas.atlas = load("res://assets/sprites/plankton/plankton.png")
	plankton_atlas.region = Rect2(0, 16, 16, 16)
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.size = Vector2(VIEWPORT_WIDTH, 90)
	rtl.position = Vector2(0, placeholder.position.y)
	rtl.add_theme_font_override("normal_font", bungee_font)

	rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	rtl.push_font_size(44)
	rtl.push_color(Color(1.0, 0.85, 0.2, 0.95))
	rtl.add_text("%d pts" % [score])
	rtl.pop()
	rtl.pop()
	rtl.pop()

	rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	rtl.push_font_size(26)
	rtl.push_color(Color(0.5, 0.75, 1.0, 0.8))
	rtl.add_text("%dm  ×  %d  " % [distance, plankton])
	rtl.add_image(plankton_atlas, 24, 24)
	rtl.pop()
	rtl.pop()
	rtl.pop()

	placeholder.get_parent().add_child(rtl)

func _add_settings_button():
	var btn = Button.new()
	btn.text = "Settings"
	btn.add_theme_font_override("font", bungee_font)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color(0.45, 0.72, 1.0, 0.85))
	btn.flat = true
	btn.position = Vector2(VIEWPORT_WIDTH - 180.0, 72.0)
	btn.size = Vector2(160.0, 56.0)
	btn.pressed.connect(func():
		var overlay = load("res://ui/settings_overlay.gd").new()
		get_tree().root.add_child(overlay))
	add_child(btn)

func _on_start_pressed(_p = null):
	get_tree().set_meta("free_swim", false)
	get_tree().change_scene_to_file("res://world.tscn")

func _on_free_swim_pressed(_p = null):
	get_tree().set_meta("free_swim", true)
	get_tree().change_scene_to_file("res://world.tscn")
