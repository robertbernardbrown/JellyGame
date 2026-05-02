extends Area2D

@onready var anim = get_node("AnimatedSprite2D")

func _process(delta):
	anim.play('default')
	position.x -= 200 * delta

	if global_position.x < -get_viewport_rect().size.x:
		queue_free()
