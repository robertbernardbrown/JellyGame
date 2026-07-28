extends CanvasLayer

const VW = 720.0
const VH = 1280.0
const PANEL_W = 660.0
const PANEL_H = 760.0

var _bungee: Font
var _preview: AnimatedSprite2D
var _preview_mat: ShaderMaterial
var _save_btn: Button
var _reset_btn: Button
var _top_picker: ColorPickerButton
var _tentacle_picker: ColorPickerButton
var _pending_top: Color
var _pending_tentacle: Color

func _ready():
	layer = 200
	_bungee = load("res://assets/fonts/bungee/Bungee-Regular.ttf")
	var colors = CosmeticsManager.get_effective_colors()
	_pending_top = colors.top
	_pending_tentacle = colors.tentacle
	_build_ui()

func _build_ui():
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	backdrop.size = Vector2(VW, VH)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel = _make_panel()
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "CUSTOMIZE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", _bungee)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.0, 0.88, 1.0))
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.add_theme_font_override("font", _bungee)
	close_btn.add_theme_font_size_override("font_size", 32)
	close_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.85))
	close_btn.pressed.connect(queue_free)
	title_row.add_child(close_btn)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.0, 0.5, 0.7, 0.4))
	vbox.add_child(sep)

	var preview_wrap = CenterContainer.new()
	preview_wrap.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(preview_wrap)
	_build_preview(preview_wrap)

	_top_picker = _add_color_row(vbox, "HIGHLIGHTS", _pending_top, func(c):
		_pending_top = c
		_preview_mat.set_shader_parameter("top_color", c))
	_tentacle_picker = _add_color_row(vbox, "BASE", _pending_tentacle, func(c):
		_pending_tentacle = c
		_preview_mat.set_shader_parameter("tentacle_color", c))

	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 18)
	vbox.add_child(button_row)

	_reset_btn = Button.new()
	_reset_btn.text = "RESET TO DEFAULT"
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_btn.custom_minimum_size = Vector2(0, 64)
	_reset_btn.add_theme_font_override("font", _bungee)
	_reset_btn.add_theme_font_size_override("font_size", 24)
	_reset_btn.add_theme_color_override("font_color", Color(0.55, 0.72, 0.85))
	_reset_btn.pressed.connect(_on_reset_pressed)
	button_row.add_child(_reset_btn)

	_save_btn = Button.new()
	_save_btn.text = "SAVE"
	_save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_btn.custom_minimum_size = Vector2(0, 64)
	_save_btn.add_theme_font_override("font", _bungee)
	_save_btn.add_theme_font_size_override("font_size", 32)
	_save_btn.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	_save_btn.pressed.connect(_on_save_pressed)
	button_row.add_child(_save_btn)

func _make_panel() -> Control:
	var panel = PanelContainer.new()
	panel.position = Vector2((VW - PANEL_W) / 2.0, (VH - PANEL_H) / 2.0)
	panel.size = Vector2(PANEL_W, PANEL_H)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.22, 0.97)
	style.border_color = Color(0.0, 0.7, 0.9, 0.55)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _build_preview(parent: Control) -> void:
	var jelly_sheet = load("res://assets/sprites/player/jelly_animations-Sheet.png")
	var frames = SpriteFrames.new()
	frames.add_animation("Idle")
	frames.set_animation_loop("Idle", true)
	frames.set_animation_speed("Idle", 11.0)
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

	_preview = AnimatedSprite2D.new()
	_preview.sprite_frames = frames
	_preview.scale = Vector2(5, 5)
	_preview.position = Vector2(PANEL_W / 2.0 - 80.0, 100.0)
	_preview.play("Idle")

	_preview_mat = ShaderMaterial.new()
	_preview_mat.shader = load("res://entities/player/jelly_recolor.gdshader")
	_preview_mat.set_shader_parameter("region_mask", load("res://assets/sprites/player/jelly_region_mask.png"))
	_preview_mat.set_shader_parameter("top_color", _pending_top)
	_preview_mat.set_shader_parameter("dot_color", CosmeticsManager.STOCK_DOT_COLOR)
	_preview_mat.set_shader_parameter("tentacle_color", _pending_tentacle)
	_preview_mat.set_shader_parameter("custom_amount", 1.0)
	_preview.material = _preview_mat

	parent.add_child(_preview)

func _add_color_row(parent: Control, label_text: String, init_color: Color, on_change: Callable) -> ColorPickerButton:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	parent.add_child(hbox)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", _bungee)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	hbox.add_child(lbl)

	var picker = ColorPickerButton.new()
	picker.color = init_color
	picker.custom_minimum_size = Vector2(120, 56)
	picker.color_changed.connect(on_change)
	hbox.add_child(picker)
	return picker

func _on_save_pressed():
	CosmeticsManager.set_colors(_pending_top, _pending_tentacle)
	_save_btn.text = "SAVED!"
	var t = create_tween()
	t.tween_interval(1.0)
	t.tween_callback(func(): _save_btn.text = "SAVE")

func _on_reset_pressed():
	_pending_top = CosmeticsManager.STOCK_TOP_COLOR
	_pending_tentacle = CosmeticsManager.STOCK_TENTACLE_COLOR
	_top_picker.color = _pending_top
	_tentacle_picker.color = _pending_tentacle
	_preview_mat.set_shader_parameter("top_color", _pending_top)
	_preview_mat.set_shader_parameter("tentacle_color", _pending_tentacle)
	CosmeticsManager.set_colors(_pending_top, _pending_tentacle)
	_reset_btn.text = "RESET!"
	var t = create_tween()
	t.tween_interval(1.0)
	t.tween_callback(func(): _reset_btn.text = "RESET TO DEFAULT")
