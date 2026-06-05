extends Node

const PIXELS_PER_METER = 50.0

var score: int = 0
var score_label: Label
var depth_label: Label
var start_y: float = 0.0
var max_depth: float = 0.0
var _player: Node = null
var _final_plankton: int = 1

func _ready():
	depth_label = get_node("/root/World/HUD/DepthDisplay")
	_player = get_node_or_null("/root/World/Player")
	if _player:
		start_y = _player.global_position.y

func _process(_delta):
	if _player:
		var depth = max((start_y - _player.global_position.y) / PIXELS_PER_METER, 0.0)
		if depth > max_depth:
			max_depth = depth
		depth_label.text = str(int(max_depth)) + "m"

func finalize_score(plankton_count: int):
	_final_plankton = max(1, plankton_count)
	score = int(max_depth) * _final_plankton

func increment_score(amount: int = 1):
	score += amount
	if not score_label:
		score_label = get_node_or_null("/root/World/HUD/ScoreDisplay")
	if score_label:
		score_label.text = str(score)

func get_best_score_data() -> Dictionary:
	var data = _load_save_data()
	var is_free_swim: bool = get_tree().get_meta("free_swim", false)
	if is_free_swim:
		return {
			"score":    data.get("free_swim_best_score", 0),
			"distance": data.get("free_swim_best_distance", 0),
			"plankton": data.get("free_swim_best_plankton", 1)
		}
	return {
		"score":    data.get("best_score", 0),
		"distance": data.get("best_distance", 0),
		"plankton": data.get("best_plankton", 1)
	}

func save_if_high_score():
	var is_free_swim: bool = get_tree().get_meta("free_swim", false)
	var data = _load_save_data()
	var changed = false
	var dist_int: int = int(max_depth)
	if is_free_swim:
		if score > data.get("free_swim_best_score", 0):
			data["free_swim_best_score"]    = score
			data["free_swim_best_distance"] = dist_int
			data["free_swim_best_plankton"] = _final_plankton
			changed = true
	else:
		if score > data.get("best_score", 0):
			data["best_score"]    = score
			data["best_distance"] = dist_int
			data["best_plankton"] = _final_plankton
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
	return {
		"best_score": 0, "best_distance": 0, "best_plankton": 1,
		"free_swim_best_score": 0, "free_swim_best_distance": 0, "free_swim_best_plankton": 1
	}
