extends Control
## Mapa de mundos sobre la ilustración imagenes/mapa_mundos.png (preparada por
## tools/menu/prepare_menu_assets.py). Cada isla es una zona interactiva: los mundos
## implementados y desbloqueados se juegan; los demás muestran candado. La barra inferior
## describe el mundo seleccionado (los rótulos de la ilustración son muy pequeños a 480x270).
## Teclado: izquierda/derecha recorren los mundos, arriba/abajo cambian de fila; ESC vuelve.

const BG := preload("res://resources/menu/world_map_bg.png")
## [isla (clic), número y rótulo pintados (marco de selección)] en coordenadas de 480x270.
const ZONES := {
	1: [Rect2(5, 20, 115, 117), Rect2(32, 116, 60, 21)],
	2: [Rect2(125, 55, 110, 87), Rect2(151, 121, 60, 20)],
	3: [Rect2(240, 40, 120, 98), Rect2(270, 117, 57, 21)],
	4: [Rect2(365, 55, 110, 83), Rect2(390, 115, 60, 22)],
	5: [Rect2(5, 140, 115, 90), Rect2(36, 209, 58, 20)],
	6: [Rect2(122, 145, 118, 104), Rect2(146, 226, 62, 22)],
	7: [Rect2(245, 150, 112, 99), Rect2(268, 226, 59, 22)],
	8: [Rect2(360, 140, 115, 109), Rect2(388, 224, 65, 23)],
}

var starting := false
var world_btns: Dictionary = {}
var back_btn: CloudButton
var list: MenuList
var info: PixelText
var _shown := -1


func _ready() -> void:
	AudioManager.play_music("menu")
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var bg := Sprite2D.new()
	bg.texture = BG
	bg.centered = false
	add_child(bg)

	var buttons: Array[CloudButton] = []
	for id in ZONES:
		var z: Array = ZONES[id]
		var b := HotspotButton.make_zone(z[0], z[1])
		b.set_locked(not WorldRegistry.is_playable(id) and not is_pending(id))
		if is_pending(id):
			# desbloqueado pero aún sin escena (Mundo 7 al completar el 6): sin candado, "Pronto"
			b.set_badge("Pronto")
		var wd := SaveManager.get_world(id)
		if wd.get("completed", false):
			b.set_badge("%d" % int(wd.get("bestStars", 0)))
		var k: int = id
		b.activated.connect(func(_b): start_game(k))
		add_child(b)
		world_btns[id] = b
		buttons.append(b)
	back_btn = CloudButton.make("Volver", 56, 18)
	back_btn.position = Vector2(4, 4)
	back_btn.activated.connect(func(_b): go_back())
	add_child(back_btn)
	buttons.append(back_btn)

	var strip := ColorRect.new()
	strip.color = Color(C.INK, 0.7)
	strip.position = Vector2(0, H - 13)
	strip.size = Vector2(W, 13)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	info = PixelText.make("", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	info.position = Vector2(W / 2, H - 6)
	add_child(info)

	list = MenuList.new().setup(buttons)
	list.horizontal = true
	list.columns = 4
	add_child(list)
	# empieza en el mundo más avanzado que se puede jugar
	var start := 1
	for id in ZONES:
		if WorldRegistry.is_playable(id):
			start = id
	list.select(start - 1, true)
	Fader.fade_in(300)


func _process(_delta: float) -> void:
	if list.index != _shown:
		_shown = list.index
		info.text = describe(_shown + 1) if _shown < ZONES.size() else "Volver al menú principal"


## Texto de la barra inferior para el mundo `id`.
func describe(id: int) -> String:
	var w := WorldRegistry.get_world(id)
	var title := "Mundo %d: %s" % [id, w.get("short", w.get("name", ""))]
	if is_pending(id):
		return title + " - Desbloqueado: próximamente"
	if not w.get("implemented", false):
		return title + " - Próximamente"
	if not WorldRegistry.is_playable(id):
		return title + " - Completa el Mundo %d" % (id - 1)
	var wd := SaveManager.get_world(id)
	if wd.get("completed", false):
		return title + " - Completado: %d estrellas" % int(wd.get("bestStars", 0))
	return title + " - ¡A jugar!"


## Desbloqueado en el guardado pero todavía sin implementar: no se intenta abrir ninguna escena.
func is_pending(id: int) -> bool:
	var w := WorldRegistry.get_world(id)
	return not w.is_empty() and not w.get("implemented", false) and id <= SaveManager.unlocked_world()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		go_back()


func go_back() -> void:
	if starting:
		return
	starting = true
	AudioManager.play("ui_select")
	await Fader.fade_out(300)
	Router.go("Menu")


func start_game(id: int) -> void:
	if starting:
		return
	if not WorldRegistry.is_playable(id):
		AudioManager.play("no_weapon")
		var tw := info.create_tween()
		info.tint = C.rgb(0xff8080)
		tw.tween_interval(0.6)
		tw.tween_callback(func(): info.tint = C.CREAM)
		return
	starting = true
	AudioManager.play("ui_select")
	var key := WorldRegistry.start_run(id)
	GameState.entry = {"introBanner": true}
	await Fader.fade_out(400)
	Router.go(key)
