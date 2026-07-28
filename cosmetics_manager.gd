extends Node

const SAVE_PATH = "user://cosmetics.save"

const STOCK_TOP_COLOR = Color(0.8588, 0.2078, 0.5882)
const STOCK_DOT_COLOR = Color(0.1725, 0.0157, 0.0667)
const STOCK_TENTACLE_COLOR = Color(0.5412, 0.1216, 0.7490)

var top_color: Color = STOCK_TOP_COLOR
var tentacle_color: Color = STOCK_TENTACLE_COLOR

func _ready():
	_load()

# Single seam for the future $1 unlock — swap this for a real purchase-state check
# once IAP billing is wired up. Everything else reads through this function.
func is_unlocked() -> bool:
	return true

func get_effective_colors() -> Dictionary:
	if not is_unlocked():
		return {"top": STOCK_TOP_COLOR, "dot": STOCK_DOT_COLOR, "tentacle": STOCK_TENTACLE_COLOR}
	return {"top": top_color, "dot": STOCK_DOT_COLOR, "tentacle": tentacle_color}

func set_colors(top: Color, tentacle: Color) -> void:
	if not is_unlocked():
		return
	top_color = top
	tentacle_color = tentacle
	_save()

func _save():
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({"top_color": top_color, "tentacle_color": tentacle_color})
		f.close()

func _load():
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var data = f.get_var()
	f.close()
	if data is Dictionary:
		top_color = data.get("top_color", STOCK_TOP_COLOR)
		tentacle_color = data.get("tentacle_color", STOCK_TENTACLE_COLOR)
