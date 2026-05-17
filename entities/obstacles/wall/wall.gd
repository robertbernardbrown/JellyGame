extends Node2D

const SOURCE_ID = 2
const TILE_SCALE = 4
const BASE_TILE_SIZE = 16
const EFFECTIVE_TILE_SIZE = BASE_TILE_SIZE * TILE_SCALE  # 64px per tile
const MAX_MIDDLE_FILLS = 2  # 0–2 random middle rows; total height = 2–4 tiles

const ATLAS_ROW_TOP    = 18
const ATLAS_ROW_MID    = 19
const ATLAS_ROW_BOTTOM = 20

# Left-wall piece atlas columns
const L_MIDDLE = 3
const L_TIP    = 5

# Right-wall piece atlas columns (separate art, no flip needed)
const R_TIP    = 7
const R_MIDDLE = 9

# Decorative plant face — safe to touch, no collision
const FACE_ATLAS_COL  = 4
const FACE_ATLAS_ROWS = [10, 11, 12, 13]  # one per possible row (up to 4)

const WALL_PLANT_SCENE = preload("res://entities/obstacles/wall/wall_plant.tscn")

@onready var tile_map: TileMap = $TileMap
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var tile_columns: int = 3
var is_left_wall: bool = true
var wall_thickness: int = 2
var _player: Node = null

func setup(columns: int, on_left: bool):
	tile_columns = columns
	is_left_wall = on_left

func _ready():
	add_to_group("Wall")
	_build_wall()
	_player = get_tree().get_first_node_in_group("Player")

func _build_wall():
	tile_map.clear()
	wall_thickness = 2 + randi_range(0, MAX_MIDDLE_FILLS)

	var middle_piece = L_MIDDLE if is_left_wall else R_MIDDLE
	var tip_piece    = L_TIP    if is_left_wall else R_TIP

	var face_col = (tile_columns - 1) if is_left_wall else 0
	var tip_col  = (tile_columns - 2) if is_left_wall else 1

	for col in range(tile_columns):
		for row in range(wall_thickness):
			var atlas_y = ATLAS_ROW_TOP if row == 0 else (ATLAS_ROW_BOTTOM if row == wall_thickness - 1 else ATLAS_ROW_MID)

			if col == face_col:
				tile_map.set_cell(0, Vector2i(col, row), SOURCE_ID,
					Vector2i(FACE_ATLAS_COL, FACE_ATLAS_ROWS[row]))
				continue

			var atlas_x: int
			if col == tip_col:
				atlas_x = tip_piece
			else:
				atlas_x = middle_piece

			tile_map.set_cell(0, Vector2i(col, row), SOURCE_ID, Vector2i(atlas_x, atlas_y))

	# Collision covers all body columns — plant face column is decorative only.
	var body_cols = tile_columns - 1
	var body_w = body_cols * EFFECTIVE_TILE_SIZE
	var body_h = wall_thickness * EFFECTIVE_TILE_SIZE
	var rect = RectangleShape2D.new()
	rect.size = Vector2(body_w + 8.0, body_h + 8.0)
	collision_shape.shape = rect

	if is_left_wall:
		collision_shape.position = Vector2(body_w / 2.0, body_h / 2.0)
	else:
		collision_shape.position = Vector2(EFFECTIVE_TILE_SIZE + body_w / 2.0, body_h / 2.0)

	_spawn_wall_plants(body_w, body_h)

func _spawn_wall_plants(body_w: float, body_h: float):
	var count = randi_range(0, 3)
	for i in range(count):
		_add_plant(body_w, body_h)

func _add_plant(body_w: float, body_h: float):
	var plant = WALL_PLANT_SCENE.instantiate()
	var half = EFFECTIVE_TILE_SIZE / 2.0
	# Right walls have an invisible face column at x=0..64, so offset into visible tiles
	var x_min: float = 0.0 if is_left_wall else float(EFFECTIVE_TILE_SIZE)
	var x_max: float = body_w if is_left_wall else float(EFFECTIVE_TILE_SIZE) + body_w

	match randi_range(0, 1):
		0:
			plant.position = Vector2(randf_range(x_min, x_max), -half)
			plant.rotation_degrees = 0.0
		1:
			plant.position = Vector2(randf_range(x_min, x_max), body_h + half)
			plant.rotation_degrees = 180.0
		2:
			if is_left_wall:
				plant.position = Vector2(body_w, randf_range(0.0, body_h))
				plant.rotation_degrees = 90.0
			else:
				plant.position = Vector2(EFFECTIVE_TILE_SIZE, randf_range(0.0, body_h))
				plant.rotation_degrees = -90.0

	add_child(plant)

func _process(_delta):
	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		var tracker = get_node_or_null("/root/World/ScoreTracker")
		if tracker:
			tracker.save_if_high_score()
		queue_free()
		get_tree().change_scene_to_file("res://main.tscn")
