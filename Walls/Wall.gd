extends Node2D

const SOURCE_ID = 2
const TILE_SCALE = 4
const BASE_TILE_SIZE = 16
const EFFECTIVE_TILE_SIZE = BASE_TILE_SIZE * TILE_SCALE  # 64px per tile
const WALL_THICKNESS = 3  # rows of tiles (visual height/depth of the wall)

@onready var tile_map: TileMap = $TileMap
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var tile_columns: int = 3

func setup(columns: int):
	tile_columns = columns

func _ready():
	add_to_group("Wall")
	_build_wall()

func _build_wall():
	tile_map.clear()

	for col in range(tile_columns):
		for row in range(WALL_THICKNESS):
			# Use row 1 atlas tiles — all 4 have physics collision shapes.
			# Offset by row to create a staggered visual pattern.
			var atlas_x = ((col + row) % 4) + 1
			tile_map.set_cell(0, Vector2i(col, row), SOURCE_ID, Vector2i(atlas_x, 1))

	# Size the Area2D collision shape to cover the full wall with a small buffer
	# so the player triggers death slightly before visually clipping into tiles.
	var wall_pixel_width = tile_columns * EFFECTIVE_TILE_SIZE
	var wall_pixel_height = WALL_THICKNESS * EFFECTIVE_TILE_SIZE
	var buffer = 8.0
	var rect = RectangleShape2D.new()
	rect.size = Vector2(wall_pixel_width + buffer, wall_pixel_height + buffer)
	collision_shape.shape = rect
	collision_shape.position = Vector2(wall_pixel_width / 2.0, wall_pixel_height / 2.0)

func _process(_delta):
	# Free when the wall has scrolled well past the bottom of the visible area
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var player_y = players[0].global_position.y
		if global_position.y > player_y + get_viewport_rect().size.y:
			queue_free()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		var tracker = get_node_or_null("/root/World/ScoreTracker")
		if tracker:
			tracker.save_if_high_score()
		queue_free()
		get_tree().change_scene_to_file("res://main.tscn")
