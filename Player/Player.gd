extends CharacterBody2D

@onready var anim = get_node("AnimatedSprite2D")

func _process(delta):
	velocity.y += 400 * delta  # Apply gravity
	position += velocity * delta
	
	if is_on_ceiling():
		print('is on ceiling')
	
	if is_on_floor():
		print('is on floor')
		queue_free()
		restart_game()
	
	if Input.is_action_just_pressed("ui_up") and position.y > 0:
		anim.play('Set')
	elif Input.is_action_just_released('ui_up'):
		velocity.y = -200
		anim.play('Float')
		
	move_and_slide()
	
func restart_game():
	var new_scene_path = "res://main.tscn"
	get_tree().change_scene_to_file(new_scene_path)
