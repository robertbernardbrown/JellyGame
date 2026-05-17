extends Node2D

const WALL_SPAWN_INTERVAL = 3.0
var PLANKTON_SPAWN_INTERVAL = 4.0
const URCHIN_SPAWN_INTERVAL = 10.0

const AMBIENT_START  = Color(1.0, 1.0, 1.0, 1.0)  # slightly lighter than default
const AMBIENT_DARK   = Color(0.02, 0.015, 0.07, 1.0)  # near-black at max depth
const DARK_START_DEPTH = 50.0    # metres before darkening kicks in
const DARK_FULL_DEPTH  = 500.0    # metres where max darkness is reached

var _canvas_modulate: CanvasModulate
var _bg: Node
var _player: Node
var _player_start_y: float
var _peak_depth: float = 0.0

# Fixed x positions aligned with the centre of Layer 5's black side strips
const URCHIN_LEFT_X  = 25.0
const URCHIN_RIGHT_X = 695.0

const WALL_SCENE = preload("res://entities/obstacles/wall/wall.tscn")
const PLANKTON_SCENE = preload("res://entities/collectibles/plankton/plankton.tscn")
const URCHIN_SCENE = preload("res://entities/obstacles/urchin/urchin.tscn")
const SCORE_TRACKER_SCENE = preload("res://ui/score_tracker/score_tracker.tscn")

# Wall tiles are 16px at 4x scale = 64px each.
# Viewport is 720px wide = ~11 tiles across.
const EFFECTIVE_TILE_SIZE = 64.0
const MIN_WALL_COLUMNS = 3
const MAX_WALL_COLUMNS = 7

func start_timer(spawn_interval, timer_func, one_shot):
	var new_timer = Timer.new()
	add_child(new_timer)
	new_timer.wait_time = spawn_interval
	new_timer.timeout.connect(timer_func)
	if one_shot:
		new_timer.one_shot = true
	new_timer.start()

func _ready():
	start_timer(WALL_SPAWN_INTERVAL, _on_WallSpawnTimer_timeout, false)
	start_timer(PLANKTON_SPAWN_INTERVAL, _on_PlanktonSpawnTimer_timeout, true)
	start_timer(URCHIN_SPAWN_INTERVAL, _on_UrchinSpawnTimer_timeout, false)
	var score_tracker_instance = SCORE_TRACKER_SCENE.instantiate() as Node
	add_child(score_tracker_instance)
	_canvas_modulate = $CanvasModulate
	_canvas_modulate.color = AMBIENT_START
	_bg = get_node_or_null("BG")
	_player = get_node_or_null("Player")
	if _player:
		_player_start_y = _player.global_position.y

func _process(_delta):
	if not _player:
		return
	var depth = (_player_start_y - _player.global_position.y) / 50.0
	_peak_depth = maxf(_peak_depth, depth)
	var t = clamp((_peak_depth - DARK_START_DEPTH) / (DARK_FULL_DEPTH - DARK_START_DEPTH), 0.0, 1.0)
	var ambient = AMBIENT_START.lerp(AMBIENT_DARK, t)
	_canvas_modulate.color = ambient
	if _bg:
		_bg.set_ambient(ambient)

func _on_WallSpawnTimer_timeout():
	spawn_wall()

func _on_UrchinSpawnTimer_timeout():
	spawn_urchin()

func spawn_urchin():
	var on_left = randi() % 2 == 0
	var bounds = get_screen_bounds()
	var urchin = URCHIN_SCENE.instantiate()
	urchin.setup(on_left)
	add_child(urchin)
	var x = URCHIN_LEFT_X if on_left else URCHIN_RIGHT_X
	urchin.global_position = Vector2(x, bounds.top - 50.0)

func _on_PlanktonSpawnTimer_timeout():
	spawn_plankton()
	PLANKTON_SPAWN_INTERVAL = randf_range(3, 4)
	var plankton_spawn_timer = get_node('plankton_spawn_timer')
	plankton_spawn_timer.wait_time = PLANKTON_SPAWN_INTERVAL
	if not plankton_spawn_timer.timeout.is_connected(_on_PlanktonSpawnTimer_timeout):
		plankton_spawn_timer.timeout.connect(_on_PlanktonSpawnTimer_timeout)
	plankton_spawn_timer.start()

func get_random_plankton_position():
	var bounds = get_screen_bounds()
	# Random X within the visible screen width, with some padding from edges
	var padding = 80.0
	var spawn_x = randf_range(bounds.left + padding, bounds.right - padding)
	# Spawn above the visible area
	var spawn_y = bounds.top - randf_range(100, 300)
	return Vector2(spawn_x, spawn_y)

func spawn_plankton():
	if get_tree().get_nodes_in_group("Plankton").size() >= MAX_PLANKTON:
		return
	var plankton_instance = PLANKTON_SCENE.instantiate() as Node2D
	var plankton_size = Vector2(64, 64)  # Approximate plankton bounds (16px sprite at 4x)
	var spawn_position = get_random_plankton_position()
	var attempts = 0
	while overlaps_existing(spawn_position, plankton_size) and attempts < 10:
		spawn_position = get_random_plankton_position()
		attempts += 1
	add_child(plankton_instance)
	plankton_instance.global_position = spawn_position

# Buffer added around each entity so they don't spawn touching
const SPAWN_BUFFER = 40.0
const MAX_PLANKTON = 3

func overlaps_existing(pos: Vector2, size: Vector2) -> bool:
	var rect = Rect2(pos - size / 2.0, size).grow(SPAWN_BUFFER)
	for child in get_children():
		var child_rect = _get_entity_rect(child)
		if child_rect != null and rect.intersects(child_rect):
			return true
	return false

func _get_entity_rect(node: Node) -> Variant:
	if node.is_in_group("Wall"):
		var cols = node.tile_columns if "tile_columns" in node else 5
		var w = cols * EFFECTIVE_TILE_SIZE
		var h = 3 * EFFECTIVE_TILE_SIZE  # WALL_THICKNESS
		return Rect2(node.global_position, Vector2(w, h))
	if node.is_in_group("Plankton"):
		var s = Vector2(64, 64)
		return Rect2(node.global_position - s / 2.0, s)
	return null

func get_screen_bounds() -> Dictionary:
	# Use the actual canvas transform to get real visible bounds in world space.
	# This accounts for camera position, stretch mode, zoom, etc.
	var ctf = get_canvas_transform()
	var viewport_size = get_viewport_rect().size
	var inv = ctf.affine_inverse()
	var top_left = inv * Vector2.ZERO
	var bottom_right = inv * viewport_size
	return {"left": top_left.x, "right": bottom_right.x, "top": top_left.y, "bottom": bottom_right.y}

func spawn_wall():
	var on_left = randi() % 2 == 0
	var visible_columns = randi_range(MIN_WALL_COLUMNS, MAX_WALL_COLUMNS)
	# Add 2 extra columns that extend off-screen to guarantee flush edges
	var total_columns = visible_columns + 2

	var bounds = get_screen_bounds()
	var wall_pixel_width = total_columns * EFFECTIVE_TILE_SIZE
	var wall_pixel_height = 3 * EFFECTIVE_TILE_SIZE  # WALL_THICKNESS

	# Spawn above the top of the visible area
	var spawn_y = bounds.top - 300.0

	var spawn_x: float
	if on_left:
		spawn_x = bounds.left - 2 * EFFECTIVE_TILE_SIZE
	else:
		spawn_x = bounds.right - wall_pixel_width + 2 * EFFECTIVE_TILE_SIZE

	var spawn_pos = Vector2(spawn_x, spawn_y)
	var wall_size = Vector2(wall_pixel_width, wall_pixel_height)

	# Skip spawning if it would overlap an existing wall or plankton
	if overlaps_existing(spawn_pos + wall_size / 2.0, wall_size):
		return

	var wall = WALL_SCENE.instantiate() as Node2D
	wall.setup(total_columns)
	add_child(wall)
	wall.global_position = spawn_pos

