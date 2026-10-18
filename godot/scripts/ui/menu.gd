extends Control
## Pantalla de título sobre la ilustración imagenes/menu_principal.png (preparada por
## tools/menu/prepare_menu_assets.py). Las islas de los tres mundos y los recuadros de audio
## son zonas interactivas; el «SÍ/NO» del audio lo escribe el juego según la configuración.
## Orden de navegación: Mundo 1, 2, 3, Música, Efectos, Mapa de mundos, Borrar progreso.

const BG := preload("res://resources/menu/menu_bg.png")
## Zonas en coordenadas de 480x270: [isla (clic), rótulo pintado (marco de selección)].
const WORLD_ZONES := {
	1: [Rect2(20, 50, 145, 128), Rect2(45, 146, 108, 30)],
	2: [Rect2(172, 58, 130, 127), Rect2(196, 152, 90, 28)],
	3: [Rect2(326, 56, 150, 124), Rect2(344, 147, 103, 30)],
}
const MUSIC_ZONE := Rect2(276, 216, 79, 24)
const SFX_ZONE := Rect2(362, 216, 84, 24)
## Centro del «SÍ/NO» dentro de cada recuadro (tras «MÚSICA:» / «EFECTOS:» pintados).
const MUSIC_TEXT := Vector2(339, 228)
const SFX_TEXT := Vector2(433, 228)
## Destellos sobre estrellas de la ilustración.
const TWINKLES := [Vector2(240, 13), Vector2(240, 46), Vector2(44, 22), Vector2(87, 24), Vector2(164, 60), Vector2(415, 33), Vector2(470, 41), Vector2(52, 50), Vector2(392, 68)]

var starting := false
var reset_armed := false
var world_btns: Dictionary = {}
var music_btn: HotspotButton
var sfx_btn: HotspotButton
var map_btn: CloudButton
var reset_btn: CloudButton
var list: MenuList


func _ready() -> void:
	AudioManager.play_music("menu")
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var bg := Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	add_child(bg)
	_twinkles()

	for id in WORLD_ZONES:
		var z: Array = WORLD_ZONES[id]
		var b := HotspotButton.make_zone(z[0], z[1])
		b.set_locked(not WorldRegistry.is_playable(id))
		var wd := SaveManager.get_world(id)
		if wd.get("completed", false):
			b.set_badge("%d estrellas" % int(wd.get("bestStars", 0)))
		var k: int = id
		b.activated.connect(func(_b): start_game(k))
		add_child(b)
		world_btns[id] = b

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
	map_btn = CloudButton.make("Mapa de mundos", 100, 18)
	map_btn.position = Vector2(168, 191)
	map_btn.activated.connect(func(_b): open_map())
	add_child(map_btn)
	reset_btn = CloudButton.make("Borrar progreso", 100, 18)
	reset_btn.position = Vector2(168, 211)
	reset_btn.activated.connect(confirm_reset)
	add_child(reset_btn)

	var buttons: Array[CloudButton] = [world_btns[1], world_btns[2], world_btns[3], music_btn, sfx_btn, map_btn, reset_btn]
	list = MenuList.new().setup(buttons)
	list.horizontal = true
	add_child(list)

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


func _twinkles() -> void:
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	for p in TWINKLES:
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


func open_map() -> void:
	if starting:
		return
	starting = true
	AudioManager.play("ui_select")
	await Fader.fade_out(300)
	Router.go("WorldMap")


func start_game(id := 1) -> void:
	if starting:
		return
	if not WorldRegistry.is_playable(id):
		AudioManager.play("no_weapon")
		_toast("Completa el Mundo %d para desbloquearlo" % (id - 1))
		return
	starting = true
	AudioManager.play("ui_select")
	var key := WorldRegistry.start_run(id)
	GameState.entry = {"introBanner": true}
	await Fader.fade_out(400)
	Router.go(key)


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
