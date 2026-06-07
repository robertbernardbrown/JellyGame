extends Node

const MUSIC = preload("res://audio/dire_dire_docks.mp3")
const TITLE_VOLUME_DB    = -8.0
const GAMEPLAY_VOLUME_DB = -8.0
const FADE_DURATION      = 1.2

var _player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer

func _ready():
	_player = AudioStreamPlayer.new()
	_player.stream = MUSIC
	(_player.stream as AudioStreamMP3).loop = true
	_player.bus = "Music"
	_player.volume_db = TITLE_VOLUME_DB
	_player.autoplay = true
	add_child(_player)
	_player.play()

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = load("res://audio/ambiance.wav")
	_ambient_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	_ambient_player.volume_db = -3.0
	_ambient_player.finished.connect(func(): _ambient_player.play())
	add_child(_ambient_player)
	print("[OceanAmbient] stream loaded: ", _ambient_player.stream != null, " | bus: ", _ambient_player.bus)

func set_title_volume():
	_fade_to(TITLE_VOLUME_DB)
	if _ambient_player.playing:
		_ambient_player.stop()

func set_gameplay_volume():
	_fade_to(GAMEPLAY_VOLUME_DB)
	if not _ambient_player.playing:
		_ambient_player.play()
		print("[OceanAmbient] play() called | playing: ", _ambient_player.playing)

func _fade_to(target_db: float):
	var tween = create_tween()
	tween.tween_property(_player, "volume_db", target_db, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
