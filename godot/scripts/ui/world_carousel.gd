class_name WorldCarousel
extends Control
## Carrusel horizontal de los ocho mundos del menú principal. Muestra tres islas: la central
## (seleccionada, escala 1, flotando) y una a cada lado (escala 0.75, opacidad 0.8); el resto
## espera oculto fuera de los lados. La lista es circular.
##
## Teclado: ui_left/ui_right (también A/D) cambian de mundo; ui_accept/menu_accept entran.
## Ratón/táctil: una isla lateral se desplaza al centro; la central entra.
## Mientras dura una animación se ignora la entrada (sin Tweens superpuestos).
## Se integra en MenuList mediante `focus_slot`: sólo responde al teclado cuando es la opción
## seleccionada del menú. Debe añadirse al árbol después de la MenuList para recibir antes
## las flechas (Godot reparte _unhandled_input empezando por el último nodo).

signal selection_changed(data: WorldData)
## El mundo central es jugable y el jugador lo ha elegido.
signal world_chosen(data: WorldData)
## El mundo central está bloqueado.
signal world_refused(data: WorldData)

const DURATION := 0.45
const SIDE_SCALE := 0.75
const SIDE_ALPHA := 0.8
const SPACING := 132.0

## Centro de la isla seleccionada (coordenadas de 480x270).
var center := Vector2(240, 106)
## Línea de texto bajo el carrusel.
var info_y := 175.0
var worlds: Array[WorldData] = []
var cards: Array[WorldCard] = []
var index := 0
var focused := true
var busy := false
var focus_slot: FocusSlot
var info: PixelText
var _tween: Tween
var _info_tween: Tween


## Representa al carrusel dentro de MenuList (no se dibuja ni recibe el ratón).
class FocusSlot extends CloudButton:
	var carousel: WorldCarousel

	func _ready() -> void:
		super()
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_selected(sel: bool) -> CloudButton:
		selected = sel
		carousel.focused = sel
		carousel.queue_redraw()
		return self

	func activate() -> void:
		carousel.activate_center()

	func _draw() -> void:
		pass


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(C.GAME_W, C.GAME_H)
	focus_slot = FocusSlot.new()
	focus_slot.carousel = self
	focus_slot.focus_mode = Control.FOCUS_NONE


func setup(list: Array[WorldData], start := 0) -> WorldCarousel:
	worlds = list
	index = clampi(start, 0, maxi(0, list.size() - 1))
	return self


func _ready() -> void:
	add_child(focus_slot)
	for d in worlds:
		var card := WorldCard.make(d)
		card.clicked.connect(_on_card_clicked)
		card.hovered.connect(func(_c): focus_slot.hovered.emit(focus_slot))
		add_child(card)
		cards.append(card)
	info = PixelText.make("", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	info.position = Vector2(center.x, info_y).floor()
	add_child(info)
	_layout(false)
	_update_info()


func selected_world() -> WorldData:
	return worlds[index]


func refresh() -> void:
	for c in cards:
		c.refresh()
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if not focused or not is_visible_in_tree() or worlds.is_empty():
		return
	if event is InputEventKey and not event.pressed:
		return
	if MenuList.is_stick_repeat(event):
		return
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("move_left", true):
		step(-1)
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("move_right", true):
		step(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("menu_accept"):
		activate_center()
	else:
		return
	get_viewport().set_input_as_handled()


## Mundo anterior (-1) o siguiente (+1). Devuelve false si una animación sigue en curso.
func step(d: int) -> bool:
	if busy:
		return false
	select(wrapi(index + d, 0, worlds.size()))
	return true


func select(i: int, animated := true) -> void:
	if i == index and animated:
		return
	if i != index and animated:
		AudioManager.play("ui_move")
	index = i
	_layout(animated)
	_update_info()
	selection_changed.emit(worlds[index])


## Entrar en el mundo central (o avisar de que está bloqueado).
func activate_center() -> void:
	if busy or worlds.is_empty():
		return
	var d := worlds[index]
	if d.can_enter():
		world_chosen.emit(d)
	else:
		_refuse()
		world_refused.emit(d)


## Transición de ingreso: la isla central crece y las laterales se desvanecen.
func play_enter() -> void:
	busy = true
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in cards.size():
		var c := cards[i]
		if i == index:
			_tween.tween_property(c, "scale", Vector2.ONE * 1.15, 0.35)
		elif c.visible:
			_tween.tween_property(c, "modulate:a", 0.0, 0.3)
	_tween.tween_property(info, "modulate:a", 0.0, 0.2)


## Desplazamiento circular de la isla i respecto a la central, en [-n/2, n/2).
func offset_of(i: int) -> int:
	var n := worlds.size()
	return wrapi(i - index + n / 2, 0, n) - n / 2


func _layout(animated: bool) -> void:
	_kill_tween()
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	if animated:
		busy = true
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in cards.size():
		var c := cards[i]
		var o := offset_of(i)
		var shown := absi(o) <= 1
		var side := signi(o)
		var pos := _slot_pos(c, clampi(o, -2, 2))
		var s := Vector2.ONE * (1.0 if o == 0 else SIDE_SCALE)
		var a := 1.0 if o == 0 else (SIDE_ALPHA if shown else 0.0)
		c.floating = o == 0
		c.z_index = 2 if o == 0 else (1 if shown else 0)
		c.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
		if not animated or (not shown and not c.visible):
			_place(c, pos, s, a)
			c.visible = shown
			continue
		if shown and not c.visible:
			# entra desde fuera, por su lado
			_place(c, _slot_pos(c, side * 2), Vector2.ONE * SIDE_SCALE, 0.0)
			c.visible = true
		_tween.tween_property(c, "position", pos, DURATION)
		_tween.tween_property(c, "scale", s, DURATION)
		_tween.tween_property(c, "modulate:a", a, DURATION)
	if animated:
		_tween.chain().tween_callback(_on_settled)


func _on_settled() -> void:
	busy = false
	for i in cards.size():
		cards[i].visible = absi(offset_of(i)) <= 1


func _slot_pos(c: WorldCard, slot: int) -> Vector2:
	return (center + Vector2(slot * SPACING, 0) - c.size / 2.0).floor()


func _place(c: WorldCard, pos: Vector2, s: Vector2, a: float) -> void:
	c.position = pos
	c.scale = s
	c.modulate.a = a


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	busy = false


func _on_card_clicked(card: WorldCard) -> void:
	focus_slot.hovered.emit(focus_slot)
	if busy:
		return
	var o := offset_of(cards.find(card))
	if o == 0:
		activate_center()
	else:
		step(signi(o))


func _update_info() -> void:
	if info == null or worlds.is_empty():
		return
	info.text = worlds[index].describe()
	info.tint = C.CREAM
	queue_redraw()


## Aviso de mundo bloqueado: la isla tiembla y el texto se tiñe de rojo un instante.
func _refuse() -> void:
	AudioManager.play("no_weapon")
	var c := cards[index]
	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()
	var x := c.position.x
	_info_tween = create_tween()
	info.tint = C.rgb(0xff8080)
	for dx in [3.0, -3.0, 2.0, 0.0]:
		_info_tween.tween_property(c, "position:x", x + dx, 0.05)
	_info_tween.tween_interval(0.4)
	_info_tween.tween_callback(func(): info.tint = C.CREAM)


func _draw() -> void:
	# franja del texto
	if info:
		var w := info.get_size().x + 12.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(C.INK, 0.72)
		sb.set_corner_radius_all(4)
		sb.anti_aliasing = false
		draw_style_box(sb, Rect2(Vector2(center.x - w / 2.0, info_y - 7.0).floor(), Vector2(ceilf(w), 13)))
	# flechas a los lados (más vivas cuando el carrusel tiene el foco del teclado)
	var col := Color(C.YELLOW, 1.0 if focused else 0.55)
	for d in [-1, 1]:
		var tip := Vector2(center.x + d * 214.0, center.y)
		var pts := PackedVector2Array([tip, tip + Vector2(-d * 7, -7), tip + Vector2(-d * 7, 7)])
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, C.INK, 1.0)
