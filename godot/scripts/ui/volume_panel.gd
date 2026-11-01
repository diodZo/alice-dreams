class_name VolumePanel
extends CanvasLayer
## Panel de volumen de música y efectos, sobre el menú principal o la pausa. Izquierda/derecha
## cambian el valor; activar el botón (Enter, A, clic o toque) lo sube y al pasar de 100 vuelve a 0.

signal closed

const STEP := 10

var music_btn: CloudButton
var sfx_btn: CloudButton
var list: MenuList


static func open(parent: Node) -> VolumePanel:
	var p := VolumePanel.new()
	parent.add_child(p)
	return p


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var W := float(C.GAME_W)
	var dim := ColorRect.new()
	dim.color = Color(C.INK, 0.75)
	dim.size = Vector2(W, C.GAME_H)
	add_child(dim)
	var title := PixelText.make("Volumen", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 70)
	add_child(title)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(W / 2 - 85, 95)
	box.size = Vector2(170, 74)
	add_child(box)
	music_btn = CloudButton.make(_music_label(), 170)
	music_btn.activated.connect(func(_b): change_music(_next(AudioManager.music_volume)))
	sfx_btn = CloudButton.make(_sfx_label(), 170)
	sfx_btn.activated.connect(func(_b): change_sfx(_next(AudioManager.sfx_volume)))
	var back := CloudButton.make("Volver", 170)
	back.activated.connect(func(_b): close())
	var buttons: Array[CloudButton] = [music_btn, sfx_btn, back]
	for b in buttons:
		box.add_child(b)
	list = MenuList.new().setup(buttons)
	add_child(list)
	var help := PixelText.make("Izquierda / derecha: cambiar", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	help.position = Vector2(W / 2, 185)
	add_child(help)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (not event.pressed or event.echo):
		return
	if MenuList.is_stick_repeat(event):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_left"):
		_adjust(-STEP)
	elif event.is_action_pressed("move_right"):
		_adjust(STEP)
	else:
		return # arriba, abajo y aceptar los lleva la lista, que recibe antes que la de debajo
	get_viewport().set_input_as_handled()


func _adjust(d: int) -> void:
	if list.buttons[list.index] == music_btn:
		change_music(AudioManager.music_volume + d)
	elif list.buttons[list.index] == sfx_btn:
		change_sfx(AudioManager.sfx_volume + d)


func _next(value: int) -> int:
	return 0 if value >= 100 else value + STEP


func change_music(value: int) -> void:
	AudioManager.set_music_volume(value)
	music_btn.set_label(_music_label())


func change_sfx(value: int) -> void:
	AudioManager.set_sfx_volume(value)
	sfx_btn.set_label(_sfx_label())
	AudioManager.play("ui_select") # para oír el volumen elegido


func _music_label() -> String:
	return "< Música: %d %% >" % AudioManager.music_volume


func _sfx_label() -> String:
	return "< Efectos: %d %% >" % AudioManager.sfx_volume


func close() -> void:
	AudioManager.play("ui_select")
	closed.emit()
	queue_free()
