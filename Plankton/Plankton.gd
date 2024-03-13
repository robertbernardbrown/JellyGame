extends Area2D

@onready var anim = get_node("AnimatedSprite2D")

func _process(delta):
	anim.play('Idle')
	position.x -= 200 * delta  # Adjust the speed as needed

	if position.x < -get_viewport_rect().size.x - 300:
		queue_free()  # Remove pipes when they are out of the screen

func _on_body_entered(body):
	if body.is_in_group("Player"):
		var scoreTracker = get_node("/root/World/ScoreTracker")
		scoreTracker.increment_score()
		queue_free()
		
