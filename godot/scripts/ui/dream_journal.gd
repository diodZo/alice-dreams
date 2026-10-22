class_name DreamJournal
extends CanvasLayer
## Diario de Sueños: libro ilustrado con una portada y una doble página por mundo
## (DreamJournalManager). Se abre encima de cualquier pantalla (menú principal / carrusel de
## mundos, pantalla de victoria) y bloquea la entrada de la pantalla de debajo mientras está
## abierto.
## Controles (acciones existentes, así sirven teclado y, si se añade al Input Map, mando):
##   izquierda / derecha (move_left / move_right, menu_up / menu_down): pasar página
##   Saltar / Enter: página siguiente (en la última, cerrar)    Esc / P (pause): cerrar
##   ratón o táctil: flechas y botón «Cerrar».
## El papel, las esquinas y la portada se dibujan por código (PROVISIONAL: no hay ilustraciones
## del diario en los recursos oficiales).

signal closed

const SCENE_PATH := "res://scenes/ui/DreamJournal.tscn"
const PAGE_SCENE := preload("res://scenes/ui/DreamJournalPage.tscn")
const BOOK := Rect2(24, 12, 432, 240)
const COVER_COLOR := Color("3d3277")
const PAPER := Color("fff4e2")
const PAPER_EDGE := Color("e9d6b8")
const FLIP_TIME := 0.12

## 0 = portada; 1..N = mundos en el orden de WorldRegistry.
var page := 0
var ids: Array = []
var book: Node2D
var page_root: Node2D
var page_label: PixelText
var prev_btn: CloudButton
var next_btn: CloudButton
var close_btn: CloudButton
var flipping := false
var is_open := true


## Abre el diario sobre `parent`. world_id > 0 abre directamente esa página (o la portada si la
## página aún está bloqueada y `cover_if_locked`).
static func open(parent: Node, world_id := 0, cover_if_locked := true) -> DreamJournal:
	var j: DreamJournal = load(SCENE_PATH).instantiate()
	j.ids = DreamJournalManager.world_ids()
	var i := j.ids.find(world_id)
	if i >= 0 and (SaveManager.is_world_completed(world_id) or not cover_if_locked):
		j.page = i + 1
	parent.add_child(j)
	return j


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ids.is_empty():
		ids = DreamJournalManager.world_ids()
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var shade := ColorRect.new()
	shade.color = Color(C.INK, 0.82)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	book = BookArt.new()
	add_child(book)
	page_root = Node2D.new()
	add_child(page_root)
	page_label = PixelText.make("", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	page_label.position = Vector2(W / 2, H - 8)
	add_child(page_label)
	prev_btn = CloudButton.make("<", 22, 22)
	prev_btn.position = Vector2(2, H / 2 - 11)
	prev_btn.activated.connect(func(_b): turn(-1))
	add_child(prev_btn)
	next_btn = CloudButton.make(">", 22, 22)
	next_btn.position = Vector2(W - 24, H / 2 - 11)
	next_btn.activated.connect(func(_b): turn(1))
	add_child(next_btn)
	close_btn = CloudButton.make("Cerrar", 56, 16)
	close_btn.position = Vector2(W - 60, 0)
	close_btn.activated.connect(func(_b): close())
	add_child(close_btn)
	_show_page()
	AudioManager.play("ui_select")
	book.scale = Vector2(0.9, 0.9)
	book.position = Vector2(W, H) * 0.05
	var tw := book.create_tween().set_parallel()
	tw.tween_property(book, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(book, "position", Vector2.ZERO, 0.18)


func page_count() -> int:
	return ids.size() + 1


func current_world() -> int:
	return int(ids[page - 1]) if page > 0 else 0


func _show_page() -> void:
	for c in page_root.get_children():
		c.queue_free()
	var e: DreamJournalEntry = null
	if page > 0:
		e = DreamJournalManager.entry(current_world())
		if e.is_new:
			DreamJournalManager.mark_seen(e.world_id)
	(book as BookArt).cover = page == 0
	book.queue_redraw()
	var p: DreamJournalPage = PAGE_SCENE.instantiate()
	page_root.add_child(p)
	p.build(e)
	if e != null and e.is_new:
		var badge := PixelText.make("¡Página nueva!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW})
		badge.position = Vector2(240, 6)
		page_root.add_child(badge)
		var bt := badge.create_tween().set_loops()
		bt.tween_property(badge, "modulate:a", 0.4, 0.35)
		bt.tween_property(badge, "modulate:a", 1.0, 0.35)
	page_label.text = "Portada" if page == 0 else "Página %d de %d" % [page, ids.size()]
	prev_btn.visible = page > 0
	next_btn.visible = page < page_count() - 1


## Pasa página con una animación breve (la página se pliega y se despliega).
func turn(d: int) -> void:
	var to := page + d
	if flipping or to < 0 or to >= page_count():
		return
	flipping = true
	AudioManager.play("ui_move")
	var tw := create_tween()
	tw.tween_property(page_root, "scale:x", 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(page_root, "position:x", 240.0, FLIP_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		page = to
		_show_page())
	tw.tween_property(page_root, "scale:x", 1.0, FLIP_TIME).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(page_root, "position:x", 0.0, FLIP_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): flipping = false)


func close() -> void:
	if not is_open:
		return
	is_open = false
	AudioManager.play("ui_select")
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouse:
		return  # el ratón lo gestionan los botones y la capa oscura
	if not event.is_pressed() or event.is_echo() or MenuList.is_stick_repeat(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action("move_left") or event.is_action("menu_up") or event.is_action("ui_left"):
		turn(-1)
	elif event.is_action("move_right") or event.is_action("menu_down") or event.is_action("ui_right"):
		turn(1)
	elif event.is_action("pause"):
		close()
	elif event.is_action("jump") or event.is_action("menu_accept") or event.is_action("ui_accept"):
		if page >= page_count() - 1:
			close()
		else:
			turn(1)
	get_viewport().set_input_as_handled()


## Libro abierto (papel, lomo, esquinas con estrellas) o portada cerrada.
class BookArt extends Node2D:
	var cover := true

	func _draw() -> void:
		var r := DreamJournal.BOOK
		if cover:
			draw_rect(r.grow(2), C.INK)
			draw_rect(r, DreamJournal.COVER_COLOR)
			draw_rect(r.grow(-8), C.LAVENDER, false, 2.0)
			draw_rect(Rect2(r.position.x + 196, r.position.y, 40, r.size.y), Color(DreamJournal.COVER_COLOR.darkened(0.25)))
			for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
				var p: Vector2 = c + Vector2(10 if c.x < 240 else -10, 10 if c.y < 135 else -10)
				_star(p, 6, C.YELLOW)
			return
		draw_rect(r.grow(3), C.INK)
		draw_rect(r.grow(1), DreamJournal.PAPER_EDGE)
		draw_rect(r, DreamJournal.PAPER)
		# textura de papel: motas suaves deterministas
		var rnd := RandomNumberGenerator.new()
		rnd.seed = 1234
		for i in 340:
			var p := Vector2(rnd.randf_range(r.position.x, r.end.x), rnd.randf_range(r.position.y, r.end.y))
			draw_rect(Rect2(p.floor(), Vector2.ONE), Color(DreamJournal.PAPER_EDGE, 0.7))
		# lomo
		draw_rect(Rect2(238, r.position.y, 4, r.size.y), Color(DreamJournal.PAPER_EDGE.darkened(0.15)))
		# esquinas decorativas
		for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var d := Vector2(1 if c.x < 240 else -1, 1 if c.y < 135 else -1)
			draw_line(c + d * 4, c + d * Vector2(18, 4), C.PINK, 2.0)
			draw_line(c + d * 4, c + d * Vector2(4, 18), C.PINK, 2.0)
			_star(c + d * 9, 3, C.YELLOW)

	func _star(p: Vector2, s: float, col: Color) -> void:
		draw_rect(Rect2(p - Vector2(s / 2, 0.5).floor(), Vector2(s, 1).ceil()), col)
		draw_rect(Rect2(p - Vector2(0.5, s / 2).floor(), Vector2(1, s).ceil()), col)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), col)
