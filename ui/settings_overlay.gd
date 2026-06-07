extends CanvasLayer

const VW = 720.0
const VH = 1280.0
const PANEL_W = 660.0
const PANEL_H = 520.0

var _bungee: Font
var _mute_music_btn: Button
var _mute_sfx_btn: Button

func _ready():
	layer = 200
	_bungee = load("res://assets/fonts/bungee/Bungee-Regular.ttf")
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
	vbox.add_theme_constant_override("separation", 40)
	margin.add_child(vbox)

	# Title + close
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "SETTINGS"
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

	_mute_music_btn = _add_row(vbox, "MUSIC",
		SettingsManager.music_volume, SettingsManager.music_muted,
		func(v): SettingsManager.set_music_volume(v),
		func():
			SettingsManager.toggle_music_mute()
			_refresh_mute_btn(_mute_music_btn, SettingsManager.music_muted))

	_mute_sfx_btn = _add_row(vbox, "SOUND FX",
		SettingsManager.sfx_volume, SettingsManager.sfx_muted,
		func(v): SettingsManager.set_sfx_volume(v),
		func():
			SettingsManager.toggle_sfx_mute()
			_refresh_mute_btn(_mute_sfx_btn, SettingsManager.sfx_muted))

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

func _add_row(parent: Control, label_text: String, init_vol: float, init_muted: bool,
			  on_slide: Callable, on_mute: Callable) -> Button:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", _bungee)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	row.add_child(lbl)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	row.add_child(hbox)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = init_vol
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 44)
	slider.value_changed.connect(on_slide)
	hbox.add_child(slider)

	var mute_btn = Button.new()
	mute_btn.custom_minimum_size = Vector2(120, 44)
	mute_btn.add_theme_font_override("font", _bungee)
	mute_btn.add_theme_font_size_override("font_size", 22)
	mute_btn.pressed.connect(on_mute)
	_refresh_mute_btn(mute_btn, init_muted)
	hbox.add_child(mute_btn)

	return mute_btn

func _refresh_mute_btn(btn: Button, muted: bool):
	btn.text = "MUTED" if muted else "MUTE"
	btn.add_theme_color_override("font_color",
		Color(1.0, 0.3, 0.3) if muted else Color(0.55, 0.82, 1.0))
