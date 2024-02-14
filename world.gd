extends Node2D

const PIPE_SPAWN_INTERVAL = 3.0  # Adjust this to control the spawn frequency
const PLANKTON_SPAWN_INTERVAL = 3.0  # Adjust this to control the spawn frequency
var pipe_spawn_timer
var plankton_spawn_timer

func _ready():
	pipe_spawn_timer = Timer.new()
	add_child(pipe_spawn_timer)
	pipe_spawn_timer.wait_time = PIPE_SPAWN_INTERVAL
	pipe_spawn_timer.connect("timeout", _on_PipeSpawnTimer_timeout)
	pipe_spawn_timer.start()
	plankton_spawn_timer = Timer.new()
	add_child(plankton_spawn_timer)
	plankton_spawn_timer.wait_time = PLANKTON_SPAWN_INTERVAL
	plankton_spawn_timer.connect("timeout", _on_PlanktonSpawnTimer_timeout)
	plankton_spawn_timer.start()

func _on_PipeSpawnTimer_timeout():
	spawn_pipe()
	pipe_spawn_timer.start()
	
func _on_PlanktonSpawnTimer_timeout():
	spawn_plankton()
	plankton_spawn_timer.start()
	
func spawn_plankton():
	var spawn_x = get_viewport_rect().size.x + 100
	var plankton_scene = preload("res://Plankton/Plankton.tscn")
	var plankton_instance = plankton_scene.instantiate() as Node2D
	add_child(plankton_instance)
	plankton_instance.global_position = Vector2(spawn_x, get_viewport_rect().size.y - 200)

func spawn_pipe():
	# PIPE SPAWN
	var on_ceiling = randi() % 2 == 0
	var random_length = randf_range(1, 2)
	var spawn_x = get_viewport_rect().size.x + 100

	#on_ceiling = false
	
	if on_ceiling:
		var upside_down_pipe_scene = preload("res://UpsideDownPipe/upsideDownPipe.tscn")
		var upside_down_pipe_instance = upside_down_pipe_scene.instantiate() as Node2D
		add_child(upside_down_pipe_instance)
		upside_down_pipe_instance.scale = Vector2(1.0, random_length)
		upside_down_pipe_instance.global_position = Vector2(get_viewport_rect().size.x + 40, upside_down_pipe_instance.global_position.y)
	else:
		var pipe_scene = preload("res://Pipe/pipe.tscn")
		var pipe_instance = pipe_scene.instantiate() as Node2D
		add_child(pipe_instance)
		pipe_instance.scale = Vector2(1.0, random_length)
		pipe_instance.global_position = Vector2(spawn_x, get_viewport_rect().size.y - 75)
	
	# PIPE SPAWN
	#var on_ceiling = randi() % 2 == 0
	#var spawn_x = get_viewport_rect().size.x + 100
	#var random_length = randf_range(2.5, 4.2)
	#pipe_instance.scale = Vector2(1.0, random_length)
	#if on_ceiling:
		#pipe_instance.global_position = Vector2(spawn_x, random_length)  # Ground level
	#else:
	#	pipe_instance.global_position = Vector2(spawn_x, get_viewport_rect().size.y)  # Ceiling level
