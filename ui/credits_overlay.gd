extends CanvasLayer

const VW = 720.0
const VH = 1280.0
const PANEL_W = 660.0
const PANEL_H = 620.0

var _bungee: Font

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
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title = Label.new()
	title.text = "CREDITS"
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

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_add_section(content, "MUSIC")
	_add_entry(content, "Underwater Theme", "Cleyton Kauffman", "opengameart.org/content/underwater-theme", "CC0")

	_add_section(content, "SOUND EFFECTS")
	_add_entry(content, "Underwater / Breathing", "ryanconway", "freesound.org/s/183893", "CC BY 4.0")
	_add_entry(content, "Sonar Ping (Sine Wave)", "marb7e", "freesound.org/s/620321", "CC BY 4.0")
	_add_entry(content, "Notif-1", "HTN4ever", "freesound.org/s/240943", "CC BY 4.0")
	_add_entry(content, "Underwater Impact", "deleted_user_7709760", "freesound.org/s/400793", "CC BY 3.0")
	_add_entry(content, "Underwater Ambience", "Tim_Verberne", "freesound.org/s/482167", "CC0")
	_add_entry(content, "underwater.wav", "lezaarth", "freesound.org/s/232821", "CC0")
	_add_entry(content, "Toon Splat", "cribbler", "freesound.org/s/380390", "CC0")
	_add_entry(content, "Crunch", "qubodup", "freesound.org/s/816237", "CC0")
	_add_entry(content, "DSGNSynth Bubble Echoes", "Funky_Audio", "freesound.org/s/698817", "CC0")

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

func _add_section(parent: Control, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _bungee)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	parent.add_child(lbl)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.0, 0.5, 0.7, 0.3))
	parent.add_child(sep)

func _add_entry(parent: Control, title: String, author: String, url: String, license: String) -> void:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)

	var title_lbl = Label.new()
	title_lbl.text = '"%s"' % title
	title_lbl.add_theme_font_override("font", _bungee)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	row.add_child(title_lbl)

	var meta_lbl = Label.new()
	meta_lbl.text = "%s  ·  %s  ·  %s" % [author, url, license]
	meta_lbl.add_theme_font_override("font", _bungee)
	meta_lbl.add_theme_font_size_override("font_size", 14)
	meta_lbl.add_theme_color_override("font_color", Color(0.45, 0.65, 0.85, 0.85))
	meta_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(meta_lbl)
