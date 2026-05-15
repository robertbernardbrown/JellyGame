extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	anim.play('default')

func _process(delta):
	position.x -= 200 * delta
	if global_position.x < -get_viewport_rect().size.x:
		queue_free()
