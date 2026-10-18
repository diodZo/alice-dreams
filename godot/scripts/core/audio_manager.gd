extends Node
## Sistema de audio desacoplado (autoload "AudioManager"; port de systems/AudioManager.js).
## El juego sólo emite eventos por nombre (AudioManager.play("jump")). Si hay un archivo
## asignado en AudioConfig se reproduce; si no, el sonido provisional sintetizado.
## La música sintetizada se genera en segundo plano: si aún no está lista, empieza al terminar.

const SFX_VOICES := 10

var music_on := true
var sfx_on := true
var current_track := ""
var ducked := false

var _sfx_streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _music_pending: Dictionary = {}
var _last_play: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_task := -1
var _music_bus := 0
var _sfx_bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_on = SaveManager.get_setting("music") != false
	sfx_on = SaveManager.get_setting("sfx") != false
	_music_bus = _ensure_bus("Music")
	_sfx_bus = _ensure_bus("SFX")
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_apply_music_volume()
	# Efectos: cortos, se generan al arrancar. Música: en segundo plano (tarda unos segundos).
	for ev in Synth.SFX:
		_sfx_streams[ev] = _load_file(AudioConfig.SFX_FILES.get(ev, ""))
		if _sfx_streams[ev] == null:
			_sfx_streams[ev] = Synth.render_sfx(ev)
	for track in Synth.MUSIC:
		var file := _load_file(AudioConfig.MUSIC_FILES.get(track, ""))
		var optional: String = AudioConfig.OPTIONAL_MUSIC.get(track, "")
		if file == null and optional != "" and ResourceLoader.exists(optional):
			file = load(optional) as AudioStream
		if file:
			_music_streams[track] = file
		else:
			_music_pending[track] = true
	if not _music_pending.is_empty():
		# el orden prioriza la música que suena primero
		var order := ["menu", "world1", "boss", "world2", "garabato", "world2_victory", "world3", "sieston", "world3_victory", "world4", "patoburbuja", "world4_victory", "world5", "luna_estelar", "world5_victory"].filter(func(t): return _music_pending.has(t))
		_music_task = WorkerThreadPool.add_task(_render_music_tracks.bind(order), false, "Música provisional")


func _exit_tree() -> void:
	# al cerrar el juego se interrumpe la generación de música en segundo plano
	if _music_task != -1:
		Synth.abort = true
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func _load_file(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		if path != "":
			push_warning("[AudioManager] No existe %s: se usa el sonido provisional" % path)
		return null
	var stream := load(path) as AudioStream
	# la música grabada (ogg/mp3) se importa sin bucle: se repite como la sintetizada
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream


func _render_music_tracks(order: Array) -> void:
	for track in order:
		var stream := Synth.render_music(track)
		if Synth.abort:
			return
		_on_music_ready.call_deferred(track, stream)


func _on_music_ready(track: String, stream: AudioStream) -> void:
	_music_streams[track] = stream
	_music_pending.erase(track)
	if track == current_track and music_on and not _music.playing:
		_start_current()


## ¿Está generada toda la música? (la pantalla de carga espera a la primera pista)
func is_music_ready(track := "") -> bool:
	if track != "":
		return _music_streams.has(track)
	return _music_pending.is_empty()


func play(event: String) -> void:
	if not sfx_on:
		return
	# evita acumulaciones del mismo efecto en el mismo instante
	var now := Time.get_ticks_msec()
	if _last_play.has(event) and now - int(_last_play[event]) < 35:
		return
	_last_play[event] = now
	var stream: AudioStream = _sfx_streams.get(event)
	if stream == null:
		push_warning("[AudioManager] Evento de sonido desconocido: %s" % event)
		return
	var voice: AudioStreamPlayer = null
	for v in _voices:
		if not v.playing:
			voice = v
			break
	if voice == null:
		voice = _voices[0]
		_voices.push_back(_voices.pop_front())
	voice.stream = stream
	voice.play()


func play_music(track: String) -> void:
	if current_track == track:
		return
	stop_music()
	current_track = track
	# cada pista puede ser grabada o sintetizada: el volumen depende de cuál suena
	_apply_music_volume()
	if music_on:
		_start_current()


func _start_current() -> void:
	if current_track == "" or not _music_streams.has(current_track):
		return
	_music.stream = _music_streams[current_track]
	_music.play()


func stop_music() -> void:
	_music.stop()


func set_music_enabled(on: bool) -> void:
	music_on = on
	SaveManager.set_setting("music", on)
	_apply_music_volume()
	if on:
		if not _music.playing:
			_start_current()
	else:
		stop_music()


func set_sfx_enabled(on: bool) -> void:
	sfx_on = on
	SaveManager.set_setting("sfx", on)


## Atenúa la música (pausa) o la restaura.
func duck(on: bool) -> void:
	ducked = on
	_apply_music_volume()


func _apply_music_volume() -> void:
	var stream: Variant = _music_streams.get(current_track)
	var file_music: bool = stream is AudioStreamOggVorbis or stream is AudioStreamMP3
	var vol := 1.0 if not file_music else 0.5
	if ducked:
		vol = 0.35 if not file_music else 0.2
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(vol) if music_on else -80.0)
