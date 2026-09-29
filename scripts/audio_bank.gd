extends Node
## Музыка озера, фоновая атмосфера и звуковые эффекты.

const SFX_NAMES := ["click", "hover", "back", "cast", "splash", "splash_small", "bite", "hook", "reel", "warn", "catch", "new_species",
	"coin", "buy", "fail", "escape", "flap", "thunder", "open", "reelin"]

var music_volume := 0.55
var sfx_volume := 0.8
var ambient_volume := 0.7

var sfx: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var reel_player: AudioStreamPlayer
var music_tween: Tween
var ambient_tween: Tween
var current_music := ""
var current_ambient := ""


func _ready() -> void:
	for n in SFX_NAMES:
		var s := load("res://audio/sfx/%s.wav" % n) as AudioStream
		if s != null:
			sfx[n] = s
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Музыка"
	add_child(music_player)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "Атмосфера"
	add_child(ambient_player)
	reel_player = AudioStreamPlayer.new()
	reel_player.name = "Катушка"
	add_child(reel_player)
	var reel := sfx.get("reel") as AudioStreamWAV
	if reel != null:
		var loop := reel.duplicate() as AudioStreamWAV
		_make_loop(loop)
		reel_player.stream = loop
	reel_player.volume_db = -80.0


func _make_loop(stream: AudioStreamWAV) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(round(stream.get_length() * float(stream.mix_rate)))


func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


func play(name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	var s: AudioStream = sfx.get(name)
	if s == null or sfx_volume <= 0.001:
		return
	var chosen: AudioStreamPlayer = null
	for p in players:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = players[0]
	chosen.stream = s
	chosen.volume_db = _db(volume * sfx_volume)
	chosen.pitch_scale = pitch
	chosen.play()


func play_random_pitch(name: String, volume: float = 1.0, spread: float = 0.08) -> void:
	play(name, volume, 1.0 + randf_range(-spread, spread))


func set_reeling(active: bool, intensity: float = 1.0) -> void:
	if reel_player.stream == null:
		return
	if active:
		if not reel_player.playing:
			reel_player.play()
		reel_player.volume_db = _db(0.5 * sfx_volume)
		reel_player.pitch_scale = 0.9 + intensity * 0.5
	else:
		reel_player.volume_db = -80.0
		if reel_player.playing:
			reel_player.stop()


func _load_loop(path: String) -> AudioStreamWAV:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return null
	stream = stream.duplicate() as AudioStreamWAV
	_make_loop(stream)
	return stream


func play_music(path: String) -> void:
	if path == current_music and music_player.playing:
		return
	current_music = path
	var stream := _load_loop(path)
	if stream == null:
		return
	if music_tween != null:
		music_tween.kill()
	music_tween = create_tween()
	if music_player.playing:
		music_tween.tween_property(music_player, "volume_db", -60.0, 0.6)
	music_tween.tween_callback(func():
		music_player.stream = stream
		music_player.volume_db = -60.0
		music_player.play())
	music_tween.tween_property(music_player, "volume_db", _db(music_volume), 1.2)


func play_ambient(kind: String) -> void:
	var path := "res://audio/ambient_%s.wav" % kind
	if path == current_ambient and ambient_player.playing:
		return
	current_ambient = path
	var stream := _load_loop(path)
	if stream == null:
		return
	if ambient_tween != null:
		ambient_tween.kill()
	ambient_tween = create_tween()
	if ambient_player.playing:
		ambient_tween.tween_property(ambient_player, "volume_db", -60.0, 0.5)
	ambient_tween.tween_callback(func():
		ambient_player.stream = stream
		ambient_player.volume_db = -60.0
		ambient_player.play())
	ambient_tween.tween_property(ambient_player, "volume_db", _db(ambient_volume * 0.75), 1.0)


func set_music_volume(v: float) -> void:
	music_volume = v
	if music_tween != null:
		music_tween.kill()
	music_player.volume_db = _db(v) if v > 0.001 else -80.0


func set_ambient_volume(v: float) -> void:
	ambient_volume = v
	if ambient_tween != null:
		ambient_tween.kill()
	ambient_player.volume_db = _db(v * 0.75) if v > 0.001 else -80.0


func set_sfx_volume(v: float) -> void:
	sfx_volume = v


func duck_music(amount: float, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(music_player, "volume_db", _db(music_volume * amount), 0.15)
	t.tween_interval(seconds)
	t.tween_property(music_player, "volume_db", _db(music_volume), 0.8)
