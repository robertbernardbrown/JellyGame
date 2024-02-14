extends TileMap


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _process(delta):
	position.x += 200 * delta  # Adjust the speed as needed

	if position.x < -get_viewport_rect().size.x:
		queue_free()  # Remove pipes when they are out of the screen
		
	#collision_area.connect("body_entered", _on_area_entered)
