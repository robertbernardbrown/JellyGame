extends Node2D

var _velocity: Vector2 = Vector2.ZERO
var _life: float = 1.0
var _max_life: float = 1.0
var _radius: float = 4.0
var _color: Color = Color(0.4, 0.9, 1.0)

func setup(vel: Vector2, radius: float, col: Color, lifetime: float) -> void:
	_velocity = vel
	_radius = radius
	_color = col
	_life = lifetime
	_max_life = lifetime

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_velocity.y -= 28.0 * delta  # bubbles drift upward in water
	_velocity.x = move_toward(_velocity.x, 0.0, abs(_velocity.x) * 3.0 * delta)
	global_position += _velocity * delta
	queue_redraw()

func _draw() -> void:
	var t: float = _life / _max_life
	var alpha: float = t * _color.a
	draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, alpha * 0.12))
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 10, Color(_color.r, _color.g, _color.b, alpha), 1.2, true)
	draw_circle(Vector2(-_radius * 0.3, -_radius * 0.35), _radius * 0.2, Color(1.0, 1.0, 1.0, alpha * 0.5))
