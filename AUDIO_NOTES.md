# Audio Notes — JellyUp

A handoff document covering everything learned about audio setup, patterns, and conventions in this project.

---

## Architecture

All audio buses are created **programmatically at runtime** — there is no AudioBusLayout asset. The chain is:

```
Master
├── Music      ← background music (controlled by SettingsManager)
└── SFX        ← all game sound effects (controlled by SettingsManager)
    ├── SwimSFX    ← jellyfish swim sound (has LPF + Reverb)
    ├── WarningSFX ← low-energy warning (has LPF + Reverb)
    └── PlanktonSFX ← plankton collect sound (has LPF + Reverb)
```

**SettingsManager** (autoload, must be listed FIRST in project.godot autoloads) creates the `Music` and `SFX` buses and persists volume/mute settings to `user://settings.save`.

**MusicManager** (autoload, listed SECOND) owns the background music player and routes it through the `Music` bus.

Each individual SFX with underwater treatment gets its own named child bus (e.g. `SwimSFX`, `WarningSFX`, `PlanktonSFX`) that routes to `SFX`. This lets per-sound effects (LPF, reverb) be applied independently.

---

## Adding a New Sound — Standard Pattern

Always create `AudioStreamPlayer` nodes **programmatically in `_ready()`** rather than via the scene file. Scene-node references can fail silently if the `.tscn` isn't reloaded after edits; code-created players are reliable.

```gdscript
var _my_sfx: AudioStreamPlayer

func _setup_my_sfx() -> void:
    # Optional: create a named child bus with effects
    var bus_name = "MySFX"
    if AudioServer.get_bus_index(bus_name) == -1:
        AudioServer.add_bus()
        var idx = AudioServer.get_bus_count() - 1
        AudioServer.set_bus_name(idx, bus_name)
        AudioServer.set_bus_send(idx, "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master")
        var lpf = AudioEffectLowPassFilter.new()
        lpf.cutoff_hz = 1000.0
        lpf.resonance = 0.5
        AudioServer.add_bus_effect(idx, lpf)
        var reverb = AudioEffectReverb.new()
        reverb.room_size = 0.7
        reverb.damping = 0.6
        reverb.wet = 0.2
        AudioServer.add_bus_effect(idx, reverb)
    _my_sfx = AudioStreamPlayer.new()
    _my_sfx.stream = load("res://audio/my_sound.mp3")
    _my_sfx.bus = bus_name
    add_child(_my_sfx)
```

Call the setup from `_ready()`. Always use the `"SFX"` bus fallback:
```gdscript
_my_sfx.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
```

---

## File Format Gotchas

- **MP3 files** → loaded as `AudioStreamMP3`. To loop: `(player.stream as AudioStreamMP3).loop = true`
- **WAV files** → loaded as `AudioStreamWAV`. To loop: set `edit/loop_mode=1` in the `.import` file (NOT at runtime — modifying the cached shared resource corrupts it). After editing the import file, **reimport the asset** in the Godot editor (right-click → Reimport).
- Never cast and mutate a shared loaded resource. Always set loop via the import file for WAVs.
- If a sound doesn't play: check that a `.import` file exists for it. Without it, Godot can't load the stream.

---

## The Underwater Audio Treatment

Applied to all in-game SFX. Each sound gets its own bus with:

| Effect | Setting | Notes |
|--------|---------|-------|
| `AudioEffectLowPassFilter` | `cutoff_hz`: 600–1100 Hz | Lower = more muffled. 1000–1100 is subtle; 600 is very heavy |
| `AudioEffectLowPassFilter` | `resonance`: 0.3–0.7 | Adds subtle underwater resonance |
| `AudioEffectReverb` | `room_size`: 0.7–0.85 | Larger = more spacious echo |
| `AudioEffectReverb` | `damping`: 0.5–0.7 | Higher = warmer, less metallic |
| `AudioEffectReverb` | `wet`: 0.1–0.35 | How much reverb. 0.1 is subtle; 0.4+ gets hard to hear |

Current per-sound settings:
- **SwimSFX**: cutoff 1100 Hz, resonance 0.5, reverb wet 0.1
- **WarningSFX**: cutoff 600 Hz, resonance 0.3, reverb wet 0.35 (more muffled/ominous)
- **PlanktonSFX**: cutoff 1000 Hz, resonance 0.5, reverb wet 0.2

---

## Playing a Specific Region of a File

Use `player.play(start_seconds)` and a timer to stop at the end point:

```gdscript
# One-shot region (e.g. 0.06 to 0.8 = 0.74s)
player.play(0.06)
get_tree().create_timer(0.74).timeout.connect(func(): player.stop())
```

For sounds triggered frequently (e.g. every swim), use an **ID guard** to prevent stale timers from cutting off a newly-restarted sound:

```gdscript
var _sfx_id: int = 0

func _play_sound():
    _sfx_id += 1
    var id = _sfx_id
    player.play(0.06)
    get_tree().create_timer(0.74).timeout.connect(
        func(): if _sfx_id == id: player.stop()
    )
```

---

## Looping a Region (Warning Sound Pattern)

For a looping sound that repeats only a specific region, use a recursive timer with an ID guard:

```gdscript
var _loop_id: int = 0

func _start_loop() -> void:
    _loop_id += 1
    var id = _loop_id
    player.play(2.3)
    get_tree().create_timer(2.2).timeout.connect(func(): _on_loop_timer(id))

func _on_loop_timer(id: int) -> void:
    if id != _loop_id:
        return
    _loop_id += 1
    var new_id = _loop_id
    player.play(2.3)
    get_tree().create_timer(2.2).timeout.connect(func(): _on_loop_timer(new_id))

func _stop_loop() -> void:
    _loop_id += 1   # invalidates any pending timer
    player.stop()
```

Incrementing the ID in `_stop_loop` is the key — it makes all pending timer callbacks stale so they no-op, preventing double-play when energy fluctuates around a threshold.

---

## Guarding Per-Frame Audio Checks

If you start/stop audio based on game state in `_process`, always guard both branches to avoid calling `stop()` 60× per second:

```gdscript
# BAD — stop() called every frame when condition is false
if condition:
    if not player.playing: player.play()
else:
    player.stop()   # called every frame

# GOOD
if condition:
    if not player.playing: player.play()
elif player.playing:
    player.stop()   # only called when actually playing
```

---

## Volume Conventions (dB)

Halving perceived volume ≈ **−6 dB**. Current levels:

| Sound | volume_db | Notes |
|-------|-----------|-------|
| Background music | −8 dB | Same for title and gameplay |
| SwimSFX | −8 to −12 dB (randomised) | Randomised per swim for variation |
| WarningSFX | −4 dB | After several halving rounds |
| PlanktonSFX | 0 dB (default) | Not yet adjusted |
| SFX bus default | 45% linear | Set in SettingsManager |

---

## Swim Sound Details

File: `jelly_swim_4.mp3`, region 0.06–0.3s  
Each swim randomises pitch and volume for variation:
```gdscript
_swim_sfx.pitch_scale = randf_range(4.0, 5.0)   # start of pitch sweep
_swim_sfx.volume_db   = randf_range(-12.0, -8.0)
_swim_sfx.play(0.06)
# Tween pitch up for arcade "zap" feel
var tween = create_tween()
tween.tween_property(_swim_sfx, "pitch_scale", randf_range(7.0, 8.5), 0.24)
```

---

## iOS Considerations

- Enable **Project Settings → Audio → General → iOS → Mix With Others** to bypass the silent switch.
- Programmatic bus creation works fine on iOS as long as the fallback `"Master"` is included for cases where a bus doesn't exist yet.
- Always include: `_my_sfx.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"`

---

## Debugging Audio That Won't Play

1. Check that a `.import` file exists alongside the audio file. No import = no stream.
2. Print `stream != null` after loading to confirm the resource loaded.
3. Print the bus name and `AudioServer.get_bus_index(bus)` to confirm the bus exists.
4. Temporarily call `player.call_deferred("play")` at the end of setup to test the sound in isolation.
5. If stream loads and play() is called but no sound: check that the bus exists and has non-mute, non-zero volume.
6. For WAV loop issues: do NOT set `loop_mode` on the loaded resource at runtime — set `edit/loop_mode=1` in the `.import` file and reimport.
