extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _player: Node = null
var _origin: Vector2
var _origin_set: bool = false
var _time: float = 0.0
var _phase: float
var _freq_x: float
var _freq_y: float
var _radius_x: float
var _radius_y: float

func _ready():
	add_to_group("Plankton")
	anim.play('Idle')
	area_entered.connect(_on_area_entered)
	_player = get_tree().get_first_node_in_group("Player")
	_phase = randf() * TAU
	_freq_x = randf_range(0.4, 0.7)
	_freq_y = randf_range(0.45, 0.75)
	_radius_x = randf_range(10.0, 20.0)
	_radius_y = randf_range(8.0, 16.0)

func _process(delta):
	if not _origin_set:
		_origin = global_position
		_origin_set = true

	_time += delta
	global_position = _origin + Vector2(
		sin(_time * _freq_x + _phase) * _radius_x,
		cos(_time * _freq_y + _phase * 0.7) * _radius_y
	)

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
