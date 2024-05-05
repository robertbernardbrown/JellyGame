extends Node2D

const PIPE_SPAWN_INTERVAL = 3.0
var PLANKTON_SPAWN_INTERVAL = 4.0

func start_timer(spawn_interval, timer_func, one_shot):
	var new_timer = Timer.new()
	add_child(new_timer)
	new_timer.wait_time = spawn_interval
	new_timer.connect('timeout', timer_func)
	if one_shot:
		new_timer.one_shot = true
	new_timer.start()

func _ready():
	start_timer(PIPE_SPAWN_INTERVAL, _on_PipeSpawnTimer_timeout, false)
	start_timer(PLANKTON_SPAWN_INTERVAL, _on_PlanktonSpawnTimer_timeout, true)
	var score_tracker = preload("res://ScoreTracker/score_tracker.tscn")
	var score_tracker_instance = score_tracker.instantiate() as Node2D
	add_child(score_tracker_instance)
	print_all_paths(self)
	
func print_all_paths(node):
	print(node.get_path())
	for child in node.get_children():
		print_all_paths(child)

func _on_PipeSpawnTimer_timeout():
	spawn_pipe()
	
func _on_PlanktonSpawnTimer_timeout():
	spawn_plankton()
	PLANKTON_SPAWN_INTERVAL = randf_range(3, 4)
	var plankton_spawn_timer = get_node('plankton_spawn_timer')
	plankton_spawn_timer.wait_time = PLANKTON_SPAWN_INTERVAL
	if not plankton_spawn_timer.is_connected('timeout', _on_PlanktonSpawnTimer_timeout):
		plankton_spawn_timer.connect('timeout', _on_PlanktonSpawnTimer_timeout)
	plankton_spawn_timer.start()
	
func get_random_spawn_position():
	var spawn_x = get_viewport_rect().size.x - 300
	var spawn_y = get_viewport_rect().size.y - randf_range(125, 600)
	return Vector2(spawn_x, spawn_y)
	
func spawn_plankton():
	var plankton_scene = preload("res://Plankton/Plankton.tscn")
	var plankton_instance = plankton_scene.instantiate() as Node2D
	var spawn_position = get_random_spawn_position()
	while will_collide(spawn_position):
		spawn_position = get_random_spawn_position()
	add_child(plankton_instance)
	plankton_instance.global_position = spawn_position

func will_collide(potential_position):
	#var query_parameters = PhysicsPointQueryParameters2D.new()
	var query_parameters = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 2
	query_parameters.set_shape(circle_shape)
	#query_parameters.position = potential_position
	query_parameters.transform.origin = potential_position
	query_parameters.collide_with_areas = true
	query_parameters.collide_with_bodies = true
	var results = get_world_2d().direct_space_state.intersect_shape(query_parameters)
	for result in results:
		print('true')
		return true
	print('false')
	return false

func spawn_pipe():
	var on_ceiling = randi() % 2 == 0
	var random_length = randf_range(1, 2)
	var spawn_x = get_viewport_rect().size.x - 300
	var spawn_pipe_instance
	var global_position
	
	if on_ceiling:
		print('on_cieling')
		var upside_down_pipe_scene = preload("res://UpsideDownPipe/upsideDownPipe.tscn")
		var upside_down_pipe_instance = upside_down_pipe_scene.instantiate() as Node2D
		upside_down_pipe_instance.scale = Vector2(1, random_length)
		global_position = Vector2(spawn_x, upside_down_pipe_instance.global_position.y)
		print('before collide')
		while will_collide(global_position):
			print('sd1')
			random_length = randf_range(-2, 2)
			upside_down_pipe_instance.scale = Vector2(1, random_length)
			#spawn_x += 2
			global_position = Vector2(spawn_x, upside_down_pipe_instance.global_position.y)
		spawn_pipe_instance = upside_down_pipe_instance
	else:
		print('on_ground')
		var pipe_scene = preload("res://Pipe/pipe.tscn")
		var pipe_instance = pipe_scene.instantiate() as Node2D
		pipe_instance.scale = Vector2(1, random_length)
		global_position = Vector2(spawn_x, get_viewport_rect().size.y - 75)
		#while will_collide(global_position):
		#	print('sd2')
		#	random_length = randf_range(1, 2)
		#	pipe_instance.scale = Vector2(1, random_length)
		#	#spawn_x += 2
		#	global_position = Vector2(spawn_x, get_viewport_rect().size.y - 75)
		spawn_pipe_instance = pipe_instance

	add_child(spawn_pipe_instance)
	spawn_pipe_instance.global_position = global_position
