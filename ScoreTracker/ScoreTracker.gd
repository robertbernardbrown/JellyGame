extends Node2D

var score = 0
var score_label

func _ready():
	score_label = get_node("/root/World/ScoreDisplay")

func increment_score(amount: int = 1):
	score += amount
	score_label.text = str(score)
