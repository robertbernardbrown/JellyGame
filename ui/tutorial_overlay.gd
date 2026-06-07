extends Node2D

# Placed in world space below the player start position.
# The player naturally rises above it when they launch.

var _time: float = 0.0
var _bungee: Font

const W = 720.0   # viewport width
const LX = -360.0 # left edge in local space (node sits at x=360)

func _ready():
	_bungee = load("res://assets/fonts/bungee/Bungee-Regular.ttf")

func _process(delta):
	_time += delta
	queue_redraw()

func _draw():
	var shadow = Color(0.0, 0.15, 0.35, 0.55)
	var cyan   = Color(0.0, 0.88, 1.0, 0.95)

	# Draw shadow pass then colour pass for each line
	draw_string(_bungee, Vector2(LX + 3, 3),  "Hold & pull back", HORIZONTAL_ALIGNMENT_CENTER, W, 64, shadow)
	draw_string(_bungee, Vector2(LX,     0),   "Hold & pull back", HORIZONTAL_ALIGNMENT_CENTER, W, 64, cyan)

	draw_string(_bungee, Vector2(LX + 3, 75),  "to launch", HORIZONTAL_ALIGNMENT_CENTER, W, 64, shadow)
	draw_string(_bungee, Vector2(LX,     72),   "to launch", HORIZONTAL_ALIGNMENT_CENTER, W, 64, cyan)

	_draw_arrows()

func _draw_arrows():
	var cx     = 0.0
	var base_y = 155.0
	var gap    = 55.0
	var aw     = 55.0
	var ah     = 28.0

	for i in range(3):
		var t     = fmod(_time * 1.3 - i * 0.28, 1.6) / 1.6
		var alpha = clampf(sin(t * PI), 0.05, 1.0)
		var y     = base_y + i * gap
		var color = Color(0.0, 0.85, 1.0, alpha * 0.88)
		var pts   = PackedVector2Array([
			Vector2(cx - aw, y - ah * 0.5),
			Vector2(cx,      y + ah * 0.5),
			Vector2(cx + aw, y - ah * 0.5),
		])
		draw_polyline(pts, color, 5.5, true)

