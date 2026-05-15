extends Area2D

const SPEED = 220.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _on_left: bool = true
var _player: Node = null

func setup(on_left: bool):
	_on_left = on_left

func _ready():
	anim.flip_h = not _on_left
	anim.play("Roll")
	_player = get_tree().get_first_node_in_group("Player")

func _process(delta):
	position.y += SPEED * delta
	if _player and position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		body.restart_game()
