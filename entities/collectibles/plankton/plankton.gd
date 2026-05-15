extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _player: Node = null

func _ready():
	add_to_group("Plankton")
	anim.play('Idle')
	area_entered.connect(_on_area_entered)
	_player = get_tree().get_first_node_in_group("Player")

func _process(_delta):
	if _player and global_position.y > _player.global_position.y + get_viewport_rect().size.y:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		var scoreTracker = get_node("/root/World/ScoreTracker")
		scoreTracker.increment_score()
		body.restore_energy(0.25)
		queue_free()

func _on_area_entered(area):
	if area.get_parent().is_in_group("Wall"):
		queue_free()
