extends Node

const PIXELS_PER_METER = 50.0  # Tune this to control how fast depth ticks up

var score: int = 0
var score_label: Label
var depth_label: Label
var start_y: float = 0.0
var max_depth: float = 0.0
var _player: Node = null

func _ready():
	depth_label = get_node("/root/World/HUD/DepthDisplay")
	_player = get_node_or_null("/root/World/Player")
	if _player:
		start_y = _player.global_position.y

func _process(_delta):
	if _player:
		# Player moves upward (negative Y), so depth = how far above start
		var depth = max((start_y - _player.global_position.y) / PIXELS_PER_METER, 0.0)
		if depth > max_depth:
			max_depth = depth
		depth_label.text = str(int(max_depth)) + "m"

func increment_score(amount: int = 1):
	score += amount
	if not score_label:
		score_label = get_node_or_null("/root/World/HUD/ScoreDisplay")
	if score_label:
		score_label.text = str(score)

func save_if_high_score():
	var is_free_swim: bool = get_tree().get_meta("free_swim", false)
	var data = _load_save_data()
	var changed = false
	if is_free_swim:
		if score > data.get("free_swim_best_score", 0):
			data["free_swim_best_score"] = score
			changed = true
		if max_depth > data.get("free_swim_best_depth", 0.0):
			data["free_swim_best_depth"] = max_depth
			changed = true
	else:
		if score > data.get("best_score", 0):
			data["best_score"] = score
			changed = true
		if max_depth > data.get("best_depth", 0.0):
			data["best_depth"] = max_depth
			changed = true
	if changed:
		var file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
		if file:
			file.store_var(data)
			file.close()

func _load_save_data() -> Dictionary:
	var file = FileAccess.open("user://highscore.save", FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			return data
	return {"best_score": 0, "best_depth": 0.0, "free_swim_best_score": 0, "free_swim_best_depth": 0.0}
