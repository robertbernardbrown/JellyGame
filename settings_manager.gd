extends Node

const SAVE_PATH = "user://settings.save"
const MUSIC_BUS = "Music"
const SFX_BUS   = "SFX"

var music_volume: float = 1.0
var sfx_volume:   float = 0.45
var music_muted:  bool  = false
var sfx_muted:    bool  = false
var _brine_lpf: AudioEffectLowPassFilter
var _brine_music_lpf: AudioEffectLowPassFilter
var _brine_tween: Tween

func _ready():
	_setup_buses()
	_load()
	_apply_all()

func _setup_buses():
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var sfx_idx = AudioServer.get_bus_index(SFX_BUS)
	if sfx_idx != -1 and AudioServer.get_bus_effect_count(sfx_idx) == 0:
		_brine_lpf = AudioEffectLowPassFilter.new()
		_brine_lpf.cutoff_hz = 20000.0
		_brine_lpf.resonance = 0.5
		AudioServer.add_bus_effect(sfx_idx, _brine_lpf)
	var music_idx = AudioServer.get_bus_index(MUSIC_BUS)
	if music_idx != -1 and AudioServer.get_bus_effect_count(music_idx) == 0:
		_brine_music_lpf = AudioEffectLowPassFilter.new()
		_brine_music_lpf.cutoff_hz = 20000.0
		_brine_music_lpf.resonance = 0.5
		AudioServer.add_bus_effect(music_idx, _brine_music_lpf)

func set_brine_lpf(active: bool) -> void:
	if _brine_tween:
		_brine_tween.kill()
	_brine_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	var target = 400.0 if active else 20000.0
	if _brine_lpf:
		_brine_tween.tween_method(func(v: float): _brine_lpf.cutoff_hz = v, _brine_lpf.cutoff_hz, target, 0.5)
	if _brine_music_lpf:
		_brine_tween.tween_method(func(v: float): _brine_music_lpf.cutoff_hz = v, _brine_music_lpf.cutoff_hz, target, 0.5)

func set_music_volume(value: float):
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music()
	_save()

func set_sfx_volume(value: float):
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx()
	_save()

func toggle_music_mute():
	music_muted = not music_muted
	_apply_music()
	_save()

func toggle_sfx_mute():
	sfx_muted = not sfx_muted
	_apply_sfx()
	_save()

func _apply_all():
	_apply_music()
	_apply_sfx()

func _apply_music():
	var idx = AudioServer.get_bus_index(MUSIC_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, music_muted)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(music_volume, 0.001)) if not music_muted else -80.0)

func _apply_sfx():
	var idx = AudioServer.get_bus_index(SFX_BUS)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, sfx_muted)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(sfx_volume, 0.001)) if not sfx_muted else -80.0)

func _save():
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var({"music_volume": music_volume, "sfx_volume": sfx_volume,
					 "music_muted": music_muted,   "sfx_muted": sfx_muted})
		f.close()

func _load():
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var data = f.get_var()
	f.close()
	if data is Dictionary:
		music_volume = data.get("music_volume", 1.0)
		sfx_volume   = data.get("sfx_volume",   1.0)
		music_muted  = data.get("music_muted",  false)
		sfx_muted    = data.get("sfx_muted",    false)
