extends PointLight2D

var _base_scale: float
var _t: float = 0.0
var _phase: float

func _ready():
	_base_scale = scale.x
	_phase = randf() * TAU

func _process(delta):
	_t += delta
	var f = 1.0 + sin(_t * 0.9 + _phase) * 0.08
	scale = Vector2(_base_scale * f, _base_scale * f)
