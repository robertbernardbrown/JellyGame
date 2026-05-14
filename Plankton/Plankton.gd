extends Area2D

@onready var anim = get_node("AnimatedSprite2D")

func _ready():
	add_to_group("Plankton")
	anim.play('Idle')
	area_entered.connect(_on_area_entered)

func _process(_delta):
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var player_y = players[0].global_position.y
		if global_position.y > player_y + get_viewport_rect().size.y:
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
