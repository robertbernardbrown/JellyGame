extends Area2D

func _process(delta):
	position.x -= 200 * delta  # Adjust the speed as needed

	if position.x < -get_viewport_rect().size.x - 500:
		queue_free()  # Remove pipes when they are out of the screen

func _on_body_entered(body):
	if body.is_in_group("Player"):
		queue_free()  # or handle collision as needed
		restart_game()
		
func restart_game():
	var new_scene_path = "res://main.tscn"
	get_tree().change_scene_to_file(new_scene_path)
