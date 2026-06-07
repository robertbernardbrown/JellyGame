extends Node2D

const WALL_SPAWN_INTERVAL = 3.5
var PLANKTON_SPAWN_INTERVAL = 2.0
const URCHIN_SPAWN_INTERVAL = 13.0
const PUFFERFISH_SPAWN_INTERVAL = 12.0
const ANGLERFISH_SPAWN_INTERVAL = 28.0
const EEL_SPAWN_INTERVAL = 18.0
const HYDROVENT_SPAWN_INTERVAL = 20.0
const BRINE_POOL_SPAWN_INTERVAL = 18.0

const TIER_DEPTH_M = 150
const MAX_DIFFICULTY_TIER = 5
const TIER_SPAWN_MULT: Array = [1.0, 0.85, 0.72, 0.62, 0.54, 0.48]

# Adjust this to control the minimum darkness colour (deep blue = darker/moodier, lighter = more visible)
const AMBIENT_FLOOR  = Color(0.02, 0.04, 0.18, 1.0)
const AMBIENT_START  = Color(0.55, 0.75, 0.95, 1.0)
const AMBIENT_DARK   = Color(0.05, 0.09, 0.25, 1.0)
const DARK_START_DEPTH = 12.0    # metres before darkening kicks in
const DARK_FULL_DEPTH  = 28.0    # metres where max darkness is reached

var _canvas_modulate: CanvasModulate
var _bg: Node
var _player: Node
var _player_start_y: float
var _peak_depth: float = 0.0
var _difficulty_tier: int = 0
var _wall_timer: Timer
var _urchin_timer: Timer
var _pufferfish_timer: Timer
var _angler_timer: Timer
var _eel_timer: Timer
var _hydrovent_timer: Timer
var _brine_pool_timer: Timer

# Fixed x positions aligned with the centre of Layer 5's black side strips
const URCHIN_LEFT_X  = 25.0
const URCHIN_RIGHT_X = 695.0

const WALL_SCENE = preload("res://entities/obstacles/wall/wall.tscn")
const PLANKTON_SCENE = preload("res://entities/collectibles/plankton/plankton.tscn")
const URCHIN_SCENE = preload("res://entities/obstacles/urchin/urchin.tscn")
const PUFFERFISH_SCENE = preload("res://entities/obstacles/pufferfish/pufferfish.tscn")
const ANGLERFISH_SCENE = preload("res://entities/obstacles/anglerfish/anglerfish.tscn")
const EEL_SCENE = preload("res://entities/obstacles/eel/eel.tscn")
const HYDROVENT_SCENE = preload("res://entities/obstacles/hydrovent/hydrovent.tscn")
const BRINE_POOL_SCENE = preload("res://entities/obstacles/brine_pool/brine_pool.tscn")
const SCORE_TRACKER_SCENE = preload("res://ui/score_tracker/score_tracker.tscn")

# Wall tiles are 16px at 4x scale = 64px each.
# Viewport is 720px wide = ~11 tiles across.
const EFFECTIVE_TILE_SIZE = 64.0
const MIN_WALL_COLUMNS = 3
const MAX_WALL_COLUMNS = 7

func start_timer(spawn_interval, timer_func, one_shot) -> Timer:
	var new_timer = Timer.new()
	add_child(new_timer)
	new_timer.wait_time = spawn_interval
	new_timer.timeout.connect(timer_func)
	if one_shot:
		new_timer.one_shot = true
	new_timer.start()
	return new_timer

func _ready():
	_wall_timer       = start_timer(WALL_SPAWN_INTERVAL, _on_WallSpawnTimer_timeout, false)
	start_timer(PLANKTON_SPAWN_INTERVAL, _on_PlanktonSpawnTimer_timeout, true)
	_urchin_timer     = start_timer(URCHIN_SPAWN_INTERVAL, _on_UrchinSpawnTimer_timeout, false)
	_pufferfish_timer = start_timer(PUFFERFISH_SPAWN_INTERVAL, _on_PufferfishSpawnTimer_timeout, false)
	_angler_timer     = start_timer(ANGLERFISH_SPAWN_INTERVAL, _on_AnglerSpawnTimer_timeout, false)
	_eel_timer        = start_timer(EEL_SPAWN_INTERVAL, _on_EelSpawnTimer_timeout, false)
	_hydrovent_timer  = start_timer(HYDROVENT_SPAWN_INTERVAL, _on_HydroventSpawnTimer_timeout, false)
	_brine_pool_timer = start_timer(BRINE_POOL_SPAWN_INTERVAL, _on_BrinePoolSpawnTimer_timeout, false)
	var score_tracker_instance = SCORE_TRACKER_SCENE.instantiate() as Node
	add_child(score_tracker_instance)
	_canvas_modulate = $CanvasModulate
	_canvas_modulate.color = AMBIENT_START
	_bg = get_node_or_null("BG")
	_player = get_node_or_null("Player")
	if _player:
		_player_start_y = _player.global_position.y
	call_deferred("_spawn_starter_plankton")
	call_deferred("_show_tutorial_if_needed")
	MusicManager.set_gameplay_volume()

func _process(_delta):
	if not _player:
		return
	var depth = (_player_start_y - _player.global_position.y) / 50.0
	_peak_depth = maxf(_peak_depth, depth)
	var tier = clampi(int(_peak_depth / TIER_DEPTH_M), 0, MAX_DIFFICULTY_TIER)
	if tier != _difficulty_tier:
		_difficulty_tier = tier
		_apply_difficulty_tier(tier)
	var t = clamp((_peak_depth - DARK_START_DEPTH) / (DARK_FULL_DEPTH - DARK_START_DEPTH), 0.0, 1.0)
	var ambient = AMBIENT_START.lerp(AMBIENT_DARK, t)
	_canvas_modulate.color = ambient
	if _bg:
		_bg.set_ambient(ambient)

func _apply_difficulty_tier(tier: int):
	var m: float = TIER_SPAWN_MULT[tier]
	_wall_timer.wait_time       = WALL_SPAWN_INTERVAL * m
	_urchin_timer.wait_time     = URCHIN_SPAWN_INTERVAL * m
	_pufferfish_timer.wait_time = PUFFERFISH_SPAWN_INTERVAL * m
	_angler_timer.wait_time     = ANGLERFISH_SPAWN_INTERVAL * m
	_eel_timer.wait_time        = EEL_SPAWN_INTERVAL * m
	_hydrovent_timer.wait_time  = HYDROVENT_SPAWN_INTERVAL * m
	_brine_pool_timer.wait_time = BRINE_POOL_SPAWN_INTERVAL * m

	var bump: int = (1 if tier >= 2 else 0) + (1 if tier >= 4 else 0)
	MAX_WALLS       = 4 + (1 if tier >= 2 else 0) + (1 if tier >= 5 else 0)
	MAX_URCHINS     = 2 + (1 if tier >= 2 else 0) + (1 if tier >= 4 else 0)
	MAX_PUFFERFISH  = 2 + (1 if tier >= 3 else 0)
	MAX_EELS        = 2 + (1 if tier >= 3 else 0) + (1 if tier >= 5 else 0)
	MAX_HYDROVENTS  = 4 + (1 if tier >= 2 else 0)
	MAX_BRINE_POOLS = 2 + (1 if tier >= 4 else 0)
	MAX_ANGLERFISH  = 2 if tier >= 3 else 1

func _tutorial_save_path() -> String:
	var free_swim = get_tree().get_meta("free_swim", false)
	return "user://tutorial_seen_free_swim.save" if free_swim else "user://tutorial_seen.save"

func _show_tutorial_if_needed():
	var file = FileAccess.open(_tutorial_save_path(), FileAccess.READ)
	if file:
		var val = file.get_var()
		file.close()
		if val == true:
			return
	if not _player:
		return
	var hint = load("res://ui/tutorial_overlay.gd").new()
	# Centre horizontally; sit below the player's start so it's visible on screen
	hint.global_position = Vector2(360.0, _player_start_y + 210.0)
	add_child(hint)

func _spawn_starter_plankton():
	var plankton = PLANKTON_SCENE.instantiate() as Node2D
	add_child(plankton)
	plankton.global_position = Vector2(360.0, _player_start_y - 220.0)

func _on_WallSpawnTimer_timeout():
	spawn_wall()

func _on_UrchinSpawnTimer_timeout():
	spawn_urchin()

func _on_PufferfishSpawnTimer_timeout():
	spawn_pufferfish()

func spawn_urchin():
	if get_tree().get_nodes_in_group("Urchin").size() >= MAX_URCHINS:
		return
	var on_left = randi() % 2 == 0
	var bounds = get_screen_bounds()
	var urchin = URCHIN_SCENE.instantiate()
	urchin.setup(on_left)
	add_child(urchin)
	var x = URCHIN_LEFT_X if on_left else URCHIN_RIGHT_X
	urchin.global_position = Vector2(x, bounds.top - 50.0)

func _on_AnglerSpawnTimer_timeout():
	spawn_anglerfish()

func spawn_anglerfish():
	if get_tree().get_nodes_in_group("Anglerfish").size() >= MAX_ANGLERFISH:
		return
	var bounds = get_screen_bounds()
	var spawn_x = randf_range(bounds.left + 180.0, bounds.right - 180.0)
	var angler = ANGLERFISH_SCENE.instantiate()
	add_child(angler)
	angler.global_position = Vector2(spawn_x, bounds.top - 50.0)

func spawn_pufferfish():
	if get_tree().get_nodes_in_group("Pufferfish").size() >= MAX_PUFFERFISH:
		return
	var bounds = get_screen_bounds()
	var spawn_x = randf_range(bounds.left + 180.0, bounds.right - 180.0)
	var pufferfish = PUFFERFISH_SCENE.instantiate()
	add_child(pufferfish)
	pufferfish.global_position = Vector2(spawn_x, bounds.top - 50.0)

func _on_PlanktonSpawnTimer_timeout():
	spawn_plankton()
	PLANKTON_SPAWN_INTERVAL = randf_range(1.8, 2.5)
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
const MAX_PLANKTON  = 4
var MAX_WALLS       = 4
var MAX_URCHINS     = 2
var MAX_PUFFERFISH  = 2
var MAX_ANGLERFISH  = 1
var MAX_EELS        = 2
var MAX_HYDROVENTS  = 4
var MAX_BRINE_POOLS = 2

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
		var h = 4 * EFFECTIVE_TILE_SIZE  # max wall height (2 + MAX_MIDDLE_FILLS)
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

var _next_wall_left: bool = true

const PLAYER_RADIUS = 42.0  # matches CapsuleShape2D radius in player.tscn

func spawn_wall():
	if get_tree().get_nodes_in_group("Wall").size() >= MAX_WALLS:
		return
	var on_left = _next_wall_left
	_next_wall_left = !_next_wall_left

	var bounds = get_screen_bounds()
	var viewport_width = bounds.right - bounds.left

	# Find the widest visible wall on the opposite side
	var widest_opposite := 0
	for child in get_children():
		if child.is_in_group("Wall") and "is_left_wall" in child and "tile_columns" in child:
			if child.is_left_wall != on_left:
				widest_opposite = maxi(widest_opposite, child.tile_columns - 2)

	# Guarantee the passage between any left/right pair fits 2 player widths.
	# Using MIN_WALL_COLUMNS as the floor ensures even the first wall (no opposite yet)
	# leaves room for a future opposite wall of at least minimum size.
	var min_gap := 4.0 * PLAYER_RADIUS  # 2 × diameter = 168 px
	var max_combined := int((viewport_width - min_gap) / EFFECTIVE_TILE_SIZE)
	var effective_opposite := maxi(widest_opposite, MIN_WALL_COLUMNS)
	var col_upper := clampi(max_combined - effective_opposite, MIN_WALL_COLUMNS, MAX_WALL_COLUMNS)
	var visible_columns := randi_range(MIN_WALL_COLUMNS, col_upper)

	# Add 2 extra columns that extend off-screen to guarantee flush edges
	var total_columns = visible_columns + 2

	var wall_pixel_width = total_columns * EFFECTIVE_TILE_SIZE
	var wall_pixel_height = 4 * EFFECTIVE_TILE_SIZE  # max wall height (2 + MAX_MIDDLE_FILLS)

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
	wall.setup(total_columns, on_left)
	add_child(wall)
	wall.global_position = spawn_pos

func _on_BrinePoolSpawnTimer_timeout():
	if get_tree().get_nodes_in_group("BrinePool").size() >= MAX_BRINE_POOLS:
		return
	var bounds = get_screen_bounds()
	var spawn_x: float = randf_range(bounds.left + 160.0, bounds.right - 160.0)
	var pool = BRINE_POOL_SCENE.instantiate()
	add_child(pool)
	pool.global_position = Vector2(spawn_x, bounds.top - 120.0)

func _on_EelSpawnTimer_timeout():
	spawn_eel()

func _on_HydroventSpawnTimer_timeout():
	spawn_hydrovent()

func spawn_hydrovent():
	if get_tree().get_nodes_in_group("Hydrovent").size() >= MAX_HYDROVENTS:
		return
	_try_spawn_vent_side(true)
	_try_spawn_vent_side(false)

func _try_spawn_vent_side(on_left: bool):
	var bounds = get_screen_bounds()
	var spawn_y := 0.0
	var attempts := 0
	while attempts < 10:
		spawn_y = randf_range(bounds.top - 600.0, bounds.top - 100.0)
		if _eel_y_clear(on_left, spawn_y):
			break
		attempts += 1
	if attempts >= 10:
		return
	var vent = HYDROVENT_SCENE.instantiate()
	vent.setup(on_left)
	add_child(vent)
	var x = URCHIN_LEFT_X if on_left else URCHIN_RIGHT_X
	vent.global_position = Vector2(x, spawn_y)

func spawn_eel():
	if get_tree().get_nodes_in_group("Eel").size() >= MAX_EELS:
		return
	var bounds = get_screen_bounds()
	var on_left = randi() % 2 == 0
	var spawn_y := 0.0
	var attempts := 0
	while attempts < 10:
		spawn_y = randf_range(bounds.top + 150.0, bounds.top + 550.0)
		if _eel_y_clear(on_left, spawn_y):
			break
		attempts += 1
	if attempts >= 10:
		return
	var eel = EEL_SCENE.instantiate()
	eel.setup(on_left)
	add_child(eel)
	eel.global_position.y = spawn_y

# Returns true if spawn_y doesn't overlap any wall on the given side.
func _eel_y_clear(on_left: bool, spawn_y: float) -> bool:
	var eel_half_h = 64.0  # 32px sprite * 4x scale / 2
	for child in get_children():
		if not child.is_in_group("Wall"):
			continue
		if "is_left_wall" not in child or child.is_left_wall != on_left:
			continue
		var wall_top    = child.global_position.y
		var wall_bottom = wall_top + 4.0 * EFFECTIVE_TILE_SIZE
		if spawn_y + eel_half_h > wall_top and spawn_y - eel_half_h < wall_bottom:
			return false
	return true
