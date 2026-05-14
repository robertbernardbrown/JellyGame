extends Area2D

const SPEED = 220.0

@onready var anim = $AnimatedSprite2D

var _on_left: bool = true

func setup(on_left: bool):
	_on_left = on_left

func _ready():
	anim.flip_h = not _on_left
	anim.play("Roll")

func _process(delta):
	position.y += SPEED * delta

	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		if position.y > players[0].global_position.y + get_viewport_rect().size.y:
			queue_free()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.restart_game()
