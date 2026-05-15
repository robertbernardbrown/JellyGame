extends ParallaxBackground

var _layer_sprites: Array = []
var _time: float = 0.0

# Per-layer wave settings [strength, speed] — front layers slightly stronger
const WAVE_SETTINGS = [
	[0.006863, 1.0],
	[0.0057192, 0.85],
	[0.0045753, 0.7],
	[0.0034315, 0.6],
	[0.0022878, 0.5],
]

func _ready():
	var shader = load("res://assets/sprites/backgrounds/wave.gdshader")
	var paths = [
		"ParallaxLayer1/Layer1",
		"ParallaxLayer2/Layer2",
		"ParallaxLayer3/Layer3",
		"ParallaxLayer4/Layer4",
		"ParallaxLayer5/Layer5",
	]
	for i in paths.size():
		var sprite = get_node(paths[i])
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("wave_strength", WAVE_SETTINGS[i][0])
		mat.set_shader_parameter("wave_speed", WAVE_SETTINGS[i][1])
		sprite.material = mat
		_layer_sprites.append(sprite)

func _process(delta):
	_time += delta
	for sprite in _layer_sprites:
		(sprite.material as ShaderMaterial).set_shader_parameter("time_val", _time)
