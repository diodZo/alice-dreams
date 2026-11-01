extends Control
## Pantalla de título sobre la ilustración imagenes/menu_principal.png (preparada por
## tools/menu/prepare_menu_assets.py). La selección de mundos es un carrusel de los ocho
## mundos (WorldCarousel); los recuadros de audio son zonas interactivas y el «SÍ/NO» lo
## escribe el juego según la configuración.
## Orden de navegación (arriba/abajo): Carrusel, Música, Efectos, Borrar progreso. Con el carrusel seleccionado, izquierda/derecha cambian de mundo.

const BG := preload("res://resources/menu/menu_bg.png")
## Fondo definitivo sin las tres islas pintadas (aún no existe). Mientras falte, las islas de
## la ilustración quedan detrás de un velo difuminado (CAROUSEL_BAND) bajo el carrusel.
const CLEAN_BG_PATH := "res://resources/menu/menu_bg_clean.png"
## Franja de la ilustración que ocupa el carrusel (filas de 480x270): entre el logo y Alice.
const CAROUSEL_BAND := Vector2(48, 186)
const VEIL_SHADER := """
shader_type canvas_item;
uniform float top;
uniform float bottom;
uniform float feather = 12.0;
uniform vec4 tint : source_color = vec4(0.55, 0.62, 0.98, 1.0);
uniform float tint_amount = 0.4;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 acc = vec3(0.0);
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			acc += texture(TEXTURE, UV + vec2(float(x), float(y)) * px * 2.0).rgb;
		}
	}
	float row = UV.y / px.y;
	float a = smoothstep(top, top + feather, row) * (1.0 - smoothstep(bottom - feather, bottom, row));
	COLOR = vec4(mix(acc / 81.0, tint.rgb, tint_amount), a);
}
"""
const MUSIC_ZONE := Rect2(276, 216, 79, 24)
const SFX_ZONE := Rect2(362, 216, 84, 24)
## Centro del «SÍ/NO» dentro de cada recuadro (tras «MÚSICA:» / «EFECTOS:» pintados).
const MUSIC_TEXT := Vector2(339, 228)
const SFX_TEXT := Vector2(433, 228)
## Destellos sobre estrellas de la ilustración.
const TWINKLES := [Vector2(240, 13), Vector2(240, 46), Vector2(44, 22), Vector2(87, 24), Vector2(164, 60), Vector2(415, 33), Vector2(470, 41), Vector2(52, 50), Vector2(392, 68)]

var starting := false
var reset_armed := false
var carousel: WorldCarousel
var music_btn: HotspotButton
var sfx_btn: HotspotButton
var reset_btn: CloudButton
## Tras terminar la aventura (Mundo 8): volver a ver la cinemática final y los créditos.
var ending_btn: CloudButton
## Diario de Sueños (abre la página del mundo seleccionado en el carrusel).
var journal_btn: CloudButton
var journal_badge: PixelText
var volume_btn: CloudButton
var list: MenuList
## Pregunta «Continuar / Empezar de nuevo» de un mundo con partida a medias (IMP-016).
var resume_prompt: ResumePrompt


func _ready() -> void:
	AudioManager.play_music("menu")
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var bg := Sprite2D.new()
	bg.centered = false
	if ResourceLoader.exists(CLEAN_BG_PATH):
		bg.texture = load(CLEAN_BG_PATH)
		add_child(bg)
	else:
		bg.texture = BG
		add_child(bg)
		_carousel_veil()
	_twinkles()

	# empieza en el mundo más avanzado que se puede jugar (como el mapa de mundos)
	var worlds := WorldData.catalog()
	var start := 0
	for i in worlds.size():
		if worlds[i].can_enter():
			start = i
	carousel = WorldCarousel.new().setup(worlds, start)
	carousel.world_chosen.connect(func(d: WorldData): start_game(d.id))

	music_btn = HotspotButton.make_zone(MUSIC_ZONE, MUSIC_ZONE, _music_label())
	music_btn.label_pos = MUSIC_TEXT - MUSIC_ZONE.position
	music_btn.activated.connect(func(b):
		AudioManager.set_music_enabled(not AudioManager.music_on)
		b.set_label(_music_label())
		AudioManager.play("ui_select"))
	add_child(music_btn)
	sfx_btn = HotspotButton.make_zone(SFX_ZONE, SFX_ZONE, _sfx_label())
	sfx_btn.label_pos = SFX_TEXT - SFX_ZONE.position
	sfx_btn.activated.connect(func(b):
		AudioManager.set_sfx_enabled(not AudioManager.sfx_on)
		b.set_label(_sfx_label())
		AudioManager.play("ui_select"))
	add_child(sfx_btn)

	# opciones que no están en la ilustración: en el cielo, entre Alice y el audio
	reset_btn = CloudButton.make("Borrar progreso", 100, 18)
	reset_btn.position = Vector2(168, 196)
	reset_btn.activated.connect(confirm_reset)
	add_child(reset_btn)

	journal_btn = CloudButton.make("Diario de Sueños", 100, 18)
	journal_btn.position = Vector2(300, 195)
	journal_btn.activated.connect(func(_b): open_journal())
	add_child(journal_btn)
	journal_badge = PixelText.make("¡Nuevo!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW})
	journal_badge.position = Vector2(398, 192)
	add_child(journal_badge)
	var bt := journal_badge.create_tween().set_loops()
	bt.tween_property(journal_badge, "scale", Vector2(1.2, 1.2), 0.4)
	bt.tween_property(journal_badge, "scale", Vector2.ONE, 0.4)
	_refresh_journal_badge()

	volume_btn = CloudButton.make("Volumen", 100, 18)
	volume_btn.position = Vector2(168, 218)
	volume_btn.activated.connect(func(_b):
		VolumePanel.open(self).closed.connect(func():
			music_btn.set_label(_music_label())
			sfx_btn.set_label(_sfx_label())))
	add_child(volume_btn)

	var buttons: Array[CloudButton] = [carousel.focus_slot, music_btn, sfx_btn, reset_btn, journal_btn, volume_btn]
	if SaveManager.is_adventure_completed():
		ending_btn = CloudButton.make("Ver el final", 100, 18)
		ending_btn.position = Vector2(168, 239)
		ending_btn.activated.connect(func(_b): watch_ending())
		add_child(ending_btn)
		buttons.append(ending_btn)
	list = MenuList.new().setup(buttons)
	list.horizontal = true
	add_child(list)
	# después de la lista: con el foco, el carrusel recibe antes izquierda/derecha
	add_child(carousel)

	var strip := ColorRect.new()
	strip.color = Color(C.INK, 0.55)
	strip.position = Vector2(0, H - 11)
	strip.size = Vector2(W, 11)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var help := PixelText.make("A/D mover  ESPACIO saltar  SHIFT correr  J disparar  K arma  ESC pausa", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	help.position = Vector2(W / 2, H - 5)
	add_child(help)

	if Assets.used_placeholders.size() > 0:
		var warn := PixelText.make("Aviso: %d recurso(s) provisional(es). Ver consola." % Assets.used_placeholders.size(), {"tint": C.rgb(0xff8080)})
		warn.position = Vector2(4, H - 22)
		add_child(warn)
	if not SaveManager.is_storage_available():
		var warn2 := PixelText.make("Aviso: no se puede guardar el progreso", {"tint": C.rgb(0xff8080)})
		warn2.position = Vector2(4, 4)
		add_child(warn2)
	Fader.fade_in(400)


## Provisional (sin menu_bg_clean.png): copia difuminada de la franja central de la
## ilustración sobre las islas pintadas, para que no compitan con las del carrusel.
func _carousel_veil() -> void:
	var shader := Shader.new()
	shader.code = VEIL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("top", CAROUSEL_BAND.x)
	mat.set_shader_parameter("bottom", CAROUSEL_BAND.y)
	var veil := Sprite2D.new()
	veil.name = "CarouselVeil"
	veil.texture = BG
	veil.centered = false
	veil.region_enabled = true
	veil.region_rect = Rect2(0, CAROUSEL_BAND.x, C.GAME_W, CAROUSEL_BAND.y - CAROUSEL_BAND.x)
	veil.position = Vector2(0, CAROUSEL_BAND.x)
	veil.material = mat
	add_child(veil)


func _twinkles() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	for p in TWINKLES:
		if p.y > CAROUSEL_BAND.x:
			continue # sobre el carrusel distraerían de las islas
		var s := Sprite2D.new()
		s.texture = Assets.frame("fx", "sparkle")
		s.position = p
		s.scale = Vector2(0.5, 0.5)
		s.modulate.a = 0.0
		add_child(s)
		var tw := s.create_tween().set_loops()
		tw.tween_interval(rnd.randf_range(0.2, 2.5))
		tw.tween_property(s, "modulate:a", 0.9, 0.35)
		tw.tween_property(s, "modulate:a", 0.0, 0.5)


func _music_label() -> String:
	return "SÍ" if AudioManager.music_on else "NO"


func _sfx_label() -> String:
	return "SÍ" if AudioManager.sfx_on else "NO"


func confirm_reset(btn: CloudButton) -> void:
	if not reset_armed:
		reset_armed = true
		btn.set_label("¿Seguro? Otra vez")
		AudioManager.play("ui_move")
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(btn):
				reset_armed = false
				btn.set_label("Borrar progreso"))
		return
	SaveManager.reset_progress()
	AudioManager.play("ui_select")
	get_tree().reload_current_scene()


func start_game(id := 1) -> void:
	if starting or resume_prompt != null:
		return
	if not WorldRegistry.is_playable(id):
		AudioManager.play("no_weapon")
		_toast("Completa el Mundo %d para desbloquearlo" % (id - 1))
		return
	if not SaveManager.get_resume(id).is_empty():
		_ask_resume(id)
		return
	_launch(id, false)


## Abre el mundo (reanudando su partida guardada si `resume`).
func _launch(id: int, resume: bool) -> void:
	starting = true
	AudioManager.play("ui_select")
	carousel.play_enter()
	var key := WorldRegistry.resume_run(id) if resume else WorldRegistry.start_run(id)
	if key == "":
		key = WorldRegistry.start_run(id)
	GameState.entry = {"introBanner": true}
	await Fader.fade_out(400)
	Router.go(key)


func _ask_resume(id: int) -> void:
	AudioManager.play("ui_select")
	resume_prompt = ResumePrompt.new().setup(id)
	resume_prompt.chosen.connect(func(resume: bool):
		resume_prompt.queue_free()
		resume_prompt = null
		if not resume:
			SaveManager.clear_resume()
		_launch(id, resume))
	resume_prompt.cancelled.connect(func():
		resume_prompt.queue_free()
		resume_prompt = null)
	add_child(resume_prompt)


func open_journal() -> void:
	if starting:
		return
	var id: int = carousel.worlds[carousel.index].id if carousel != null else 0
	var j := DreamJournal.open(self, id)
	j.closed.connect(_refresh_journal_badge)


func _refresh_journal_badge() -> void:
	if journal_badge != null:
		journal_badge.visible = DreamJournalManager.has_new_pages()


func watch_ending() -> void:
	if starting:
		return
	starting = true
	AudioManager.play("ui_select")
	GameState.entry = {"replay": true}
	await Fader.fade_out(500, Color8(255, 240, 250))
	Router.go("Awakening")


var _toast_label: PixelText


func _toast(text: String) -> void:
	if _toast_label == null:
		_toast_label = PixelText.make("", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xff8080)})
		_toast_label.position = Vector2(C.GAME_W / 2.0, 186)
		add_child(_toast_label)
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tw := _toast_label.create_tween()
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.5).set_delay(1.6)


## Cuadro sobre el menú para un mundo con partida a medias: «Continuar» (desde el último
## checkpoint) o «Empezar de nuevo». Esc lo cierra sin elegir. Su lista de botones recibe las
## flechas antes que el carrusel (se añade después), así que el carrusel no cambia de mundo.
class ResumePrompt:
	extends CanvasLayer
	signal chosen(resume: bool)
	signal cancelled

	func setup(world_id: int) -> ResumePrompt:
		# capa propia por encima del carrusel; se cierra antes del fundido al abrir el mundo
		layer = 12
		var W := float(C.GAME_W)
		var H := float(C.GAME_H)
		var dim := ColorRect.new()
		dim.color = Color(C.INK, 0.75)
		dim.size = Vector2(W, H)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(dim)
		var text := PixelText.make("Mundo %d: tienes una partida a medias.
¿Sigues desde el último punto de control?" % world_id, {"origin": Vector2(0.5, 0.5), "tint": C.CREAM, "center": true})
		text.position = Vector2(W / 2, H / 2 - 26)
		add_child(text)
		var go_on := CloudButton.make("Continuar", 120)
		go_on.activated.connect(func(_b): chosen.emit(true))
		var fresh := CloudButton.make("Empezar de nuevo", 120)
		fresh.activated.connect(func(_b): chosen.emit(false))
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.position = Vector2(W / 2 - 124, H / 2)
		box.add_child(go_on)
		box.add_child(fresh)
		add_child(box)
		var list := MenuList.new()
		list.horizontal = true
		list.setup([go_on, fresh] as Array[CloudButton])
		add_child(list)
		return self

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			cancelled.emit()
