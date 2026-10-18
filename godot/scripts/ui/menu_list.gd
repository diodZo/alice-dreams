class_name MenuList
extends Node
## Navegación con teclado (flechas/W/S + Enter/Espacio/J) sobre una lista de CloudButton
## (port de MenuList en ui/CloudButton.js). El ratón y el táctil seleccionan al pasar por
## encima y activan al pulsar.

var buttons: Array[CloudButton] = []
var index := 0
## Izquierda/derecha (A/D, flechas) también recorren la lista: menús dispuestos en horizontal.
var horizontal := false
## > 0: los botones forman una rejilla de esa anchura y arriba/abajo saltan de fila. Un botón
## sobrante al final (p. ej. «Volver») se alcanza saliendo de la rejilla por arriba o abajo.
var columns := 0


func setup(list: Array[CloudButton]) -> MenuList:
	buttons = list
	for i in buttons.size():
		var k := i
		buttons[i].hovered.connect(func(_b): select(k))
	select(0, true)
	return self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (not event.pressed or event.echo):
		return
	if event.is_action_pressed("menu_up") or event.is_action_pressed("menu_down"):
		var d := -1 if event.is_action_pressed("menu_up") else 1
		if columns > 0:
			move_row(d)
		else:
			move(d)
	elif horizontal and event.is_action_pressed("move_left"):
		move(-1)
	elif horizontal and event.is_action_pressed("move_right"):
		move(1)
	elif event.is_action_pressed("menu_accept"):
		if index < buttons.size():
			buttons[index].activate()
	else:
		return
	get_viewport().set_input_as_handled()


func move(d: int) -> void:
	var n := buttons.size()
	var i := index
	for k in n:
		i = (i + d + n) % n
		if buttons[i].visible:
			break
	select(i)


## Arriba/abajo en una rejilla de `columns` botones por fila.
func move_row(d: int) -> void:
	var n := buttons.size()
	var grid := n - n % columns if n % columns != 0 else n
	var i := index + d * columns
	if index >= grid:
		# desde el botón sobrante: abajo entra por la primera fila, arriba por la última
		i = 0 if d > 0 else grid - columns
	elif i < 0 or i >= grid:
		i = n - 1 if grid < n else (index + d * columns + grid) % grid
	select(i)


func select(i: int, silent := false) -> void:
	if i != index and not silent:
		AudioManager.play("ui_move")
	index = i
	for k in buttons.size():
		buttons[k].set_selected(k == i)
