extends Control
## Cinemática de introducción (vídeo Ogg Theora con su audio). Se ve una sola vez por sesión, al
## arrancar el juego: Boot -> Intro -> Menú. Volver al menú desde una partida o la victoria va
## directo al menú (Router.go("Menu")), nunca pasa por aquí.
##
## Se omite con menu_accept (Enter, Espacio, A del mando), pause (Esc, P, Start), ui_accept /
## ui_cancel o tocando la pantalla. Al terminar u omitirse funde al azul de las transiciones del
## juego (el menú aparece desde ese mismo color) y abre el menú, que pone su música.
##
## Para cambiar el vídeo basta con sustituir VIDEO_PATH (ver README_GODOT.md).

signal intro_finished

const VIDEO_PATH := "res://resources/video/intro_alice_dreams.ogv"
const FADE_MS := 400.0
const HINT_DELAY := 0.8
## Si el vídeo deja de avanzar (decodificador sin datos) se pasa al menú en lugar de dejar la
## pantalla negra: segundos sin avanzar y margen máximo sobre su duración.
const STALL_LIMIT := 2.0
const WATCHDOG_MARGIN := 3.0

## Vídeo a reproducir (las pruebas lo cambian para comprobar el caso de un archivo ausente).
var video_path := VIDEO_PATH
## false en las pruebas automáticas: emite intro_finished sin cambiar de escena.
var go_to_menu := true
var leaving := false

@onready var background: ColorRect = $Background
@onready var video: VideoStreamPlayer = $VideoPlayer
@onready var skip_hint: Control = $SkipHint

var _saved_scale := {}
var _length := 0.0
var _time := 0.0
var _last_pos := -1.0
var _stalled := 0.0


func _ready() -> void:
	if GameState.intro_played:
		# ya se vio en esta sesión: no se repite
		_leave(true)
		return
	GameState.intro_played = true
	_use_full_resolution(true)
	var stream: VideoStream = load(video_path) if ResourceLoader.exists(video_path) else null
	if stream == null:
		push_error("[Intro] No se pudo cargar el vídeo de introducción: %s" % video_path)
		_leave(true)
		return
	# el audio del vídeo va por el bus de música: respeta «Música: NO» y su volumen
	video.bus = &"Music"
	video.stream = stream
	video.finished.connect(func(): _leave())
	AudioManager.stop_music()
	video.play()
	_length = video.get_stream_length()
	var label := PixelText.make("Presiona ENTER o ESC para omitir", {"origin": Vector2(1, 1), "tint": C.CREAM})
	# fondo oscuro detrás del texto: se lee sobre cualquier zona del vídeo
	var size := label.get_size()
	var back := ColorRect.new()
	back.color = Color(C.INK, 0.55)
	back.position = -size - Vector2(4, 3)
	back.size = size + Vector2(7, 5)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_hint.add_child(back)
	skip_hint.add_child(label)
	skip_hint.modulate.a = 0.0
	var tw := skip_hint.create_tween()
	tw.tween_interval(HINT_DELAY)
	tw.tween_property(skip_hint, "modulate:a", 0.8, 0.5)
	Fader.fade_in(FADE_MS)


func _process(delta: float) -> void:
	if leaving:
		return
	_time += delta
	var pos := video.stream_position
	# fin del vídeo también por su posición: no todas las plataformas emiten `finished`
	# (sin dispositivo de audio, p. ej. en las pruebas headless, nunca llega)
	if _length > 0.0 and pos >= _length - 0.05:
		_leave()
		return
	if pos > _last_pos:
		_last_pos = pos
		_stalled = 0.0
	else:
		_stalled += delta
	if _stalled > STALL_LIMIT or _time > (_length if _length > 0.0 else 60.0) + WATCHDOG_MARGIN:
		push_warning("[Intro] El vídeo no avanza: se abre el menú")
		_leave()


func _input(event: InputEvent) -> void:
	if leaving:
		get_viewport().set_input_as_handled()
		return
	var pressed := event.is_pressed() and not event.is_echo()
	var skip := pressed and (event.is_action("menu_accept") or event.is_action("pause") or event.is_action("ui_accept") or event.is_action("ui_cancel"))
	if pressed and (event is InputEventScreenTouch or event is InputEventMouseButton):
		skip = true
	# la pulsación que omite la intro no llega al menú (ni ninguna otra mientras se ve)
	get_viewport().set_input_as_handled()
	if skip:
		_leave()


## Termina la intro una sola vez (vídeo acabado, omitido, ausente o atascado).
func _leave(immediate := false) -> void:
	if leaving:
		return
	leaving = true
	set_process(false)
	if is_instance_valid(video):
		video.stop()
	if is_instance_valid(skip_hint):
		skip_hint.visible = false
	if not immediate:
		await Fader.fade_out(FADE_MS)
	else:
		await get_tree().process_frame
	_use_full_resolution(false)
	intro_finished.emit()
	if go_to_menu:
		Router.go("Menu")


## El juego se dibuja a 480x270 y se escala por factor entero (IMP-002): el vídeo de 1280x720 se
## vería a 480x270. Mientras dura la intro, la ventana dibuja a su resolución real (manteniendo
## 16:9 con bandas negras) y al salir se restaura la configuración del proyecto.
func _use_full_resolution(on: bool) -> void:
	var win := get_window()
	if win == null:
		return
	if on:
		_saved_scale = {"mode": win.content_scale_mode, "stretch": win.content_scale_stretch, "aspect": win.content_scale_aspect}
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	elif not _saved_scale.is_empty():
		win.content_scale_mode = _saved_scale.mode
		win.content_scale_stretch = _saved_scale.stretch
		win.content_scale_aspect = _saved_scale.aspect
		_saved_scale = {}


func _exit_tree() -> void:
	# nunca dejar la ventana con la escala de la intro
	_use_full_resolution(false)
