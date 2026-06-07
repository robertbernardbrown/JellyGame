extends Area2D

const SEMI_X: float = 190.0
const SEMI_Y: float = 110.0
const COLLISION_RADIUS: float = 150.0
const DRIFT_SPEED: float = 12.0
const SHIMMER_AMP: float = 6.0
const N_PTS: int = 48

var _time: float = 0.0
var _player: Node = null
var _size: float = 1.0

func _ready():
	add_to_group("BrinePool")
	_size = randf_range(0.5, 1.0)
	($CollisionShape2D.shape as CircleShape2D).radius = COLLISION_RADIUS * _size
	_player = get_tree().get_first_node_in_group("Player")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta):
	_time += delta
	position.y += DRIFT_SPEED * delta
	queue_redraw()
	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()

func _draw():
	var sx: float = SEMI_X * _size
	var sy: float = SEMI_Y * _size

	var pts := PackedVector2Array()
	for i in range(N_PTS + 1):
		var angle := float(i) / float(N_PTS) * TAU
		var shimmer := sin(angle * 3.0 + _time * 2.2) * SHIMMER_AMP
		pts.append(Vector2(cos(angle) * (sx + shimmer), sin(angle) * (sy + shimmer * 0.5)))

	# Interior fill
	draw_colored_polygon(pts, Color(0.04, 0.10, 0.38, 0.38))

	# Inner glow layer
	var inner_pts := PackedVector2Array()
	for i in range(N_PTS + 1):
		var angle := float(i) / float(N_PTS) * TAU
		var shimmer := sin(angle * 3.0 + _time * 2.2 + 0.3) * SHIMMER_AMP * 0.5
		inner_pts.append(Vector2(cos(angle) * (sx * 0.68 + shimmer), sin(angle) * (sy * 0.68 + shimmer * 0.4)))
	draw_colored_polygon(inner_pts, Color(0.06, 0.16, 0.50, 0.18))

	# Shimmering border
	var border_cols := PackedColorArray()
	for i in range(N_PTS + 1):
		var t := float(i) / float(N_PTS)
		var alpha := 0.55 + sin(t * TAU * 2.0 + _time * 1.8) * 0.2
		border_cols.append(Color(0.25, 0.65, 1.0, alpha))
	draw_polyline_colors(pts, border_cols, 2.5, true)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.enter_brine_pool()

func _on_body_exited(body):
	if body.is_in_group("Player"):
		body.exit_brine_pool()
