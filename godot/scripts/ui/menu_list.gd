class_name MenuList
extends Node
## Navegación con teclado (flechas/W/S + Enter/Espacio/J) sobre una lista de CloudButton
## (port de MenuList en ui/CloudButton.js). El ratón y el táctil seleccionan al pasar por
## encima y activan al pulsar.

var buttons: Array[CloudButton] = []
var index := 0


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
	if event.is_action_pressed("menu_up"):
		move(-1)
	elif event.is_action_pressed("menu_down"):
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


func select(i: int, silent := false) -> void:
	if i != index and not silent:
		AudioManager.play("ui_move")
	index = i
	for k in buttons.size():
		buttons[k].set_selected(k == i)
