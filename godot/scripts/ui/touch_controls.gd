class_name TouchControls
extends Node2D
## Botones virtuales para pantallas táctiles (port de ui/TouchControls.js). Usan
## TouchScreenButton, que emite las mismas acciones que el teclado: InputController no
## distingue el origen. Cada botón admite su propio dedo (multitáctil).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var H := C.GAME_H
	var W := C.GAME_W
	var r := 17.0
	_make(30, H - 30, r, "[", "move_left")
	_make(76, H - 30, r, "]", "move_right")
	_make(53, H - 70, 13, "^", "aim_up")
	_make(W - 34, H - 34, r + 2, "A", "jump")
	_make(W - 80, H - 26, r, "B", "fire")
	_make(W - 72, H - 70, 14, "ARMA", "switch_weapon")
	_make(W - 116, H - 22, 14, "RUN", "run")
	_make(W - 18, 52, 11, "II", "pause")


func _make(x: float, y: float, radius: float, text: String, action: String) -> void:
	var btn := TouchScreenButton.new()
	var shape := CircleShape2D.new()
	shape.radius = radius + 6
	btn.shape = shape
	btn.shape_centered = true
	btn.action = action
	btn.passby_press = false
	btn.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	btn.position = Vector2(x, y)
	var face := TouchFace.new()
	face.radius = radius
	btn.add_child(face)
	var label := PixelText.make(text, {"origin": Vector2(0.5, 0.5), "tint": C.BLUE})
	label.modulate.a = 0.85
	btn.add_child(label)
	btn.pressed.connect(func(): face.set_pressed(true))
	btn.released.connect(func(): face.set_pressed(false))
	add_child(btn)


func _exit_tree() -> void:
	for a in ["move_left", "move_right", "aim_up", "jump", "fire", "switch_weapon", "run", "pause"]:
		Input.action_release(a)


## Círculo del botón (relleno translúcido y borde azul).
class TouchFace:
	extends Node2D
	var radius := 17.0
	var pressed := false

	func set_pressed(on: bool) -> void:
		pressed = on
		queue_redraw()

	func _draw() -> void:
		var fill := Color(C.YELLOW, 0.6) if pressed else Color(C.CREAM, 0.35)
		draw_circle(Vector2.ZERO, radius, fill, true, -1.0, false)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(C.BLUE, 0.7), 2.0, false)
