extends Area2D

@onready var anim = get_node("AnimatedSprite2D")

func _process(delta):
	anim.play('default')
	position.x -= 200 * delta  # Adjust the speed as needed

	if position.x < -get_viewport_rect().size.x - 500:
		queue_free()  # Remove pipes when they are out of the screen
