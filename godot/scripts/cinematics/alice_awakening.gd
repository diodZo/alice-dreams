extends Node2D
## Cinemática final — El despertar de Alice (escenas 3 a 5).
##  3 La habitación de Alice al amanecer: Alice duerme en su cama, se incorpora despacio, mira a
##    su alrededor y sonríe.
##  4 Un maullido: a los pies de la cama duerme el gato morado; abre los ojos y mueve la cola.
##    Alice sonríe sorprendida.
##  5 Mensaje final: "Los sueños más grandes comienzan con un poquito de valentía.",
##    "Gracias por jugar, Alice." y "FIN". Después, los créditos.
## Alice es SIEMPRE la protagonista oficial (resources/player): acostada es su fotograma de ojos
## cerrados girado; sentada, sus fotogramas normales con la colcha tapándole las piernas. La
## habitación y la colcha se dibujan por código (tools/world8/generate_world8_extras.py).
## Se puede saltar con Saltar / Disparar / Enter tras el primer segundo.

const BEDROOM := preload("res://resources/world8/cinematics/bedroom.png")
const BLANKET := preload("res://resources/world8/cinematics/bedroom_blanket.png")
const ALICE_SCALE := 2.0
## Punto donde la colcha cubre a Alice (cintura) y posiciones de la escena (480x270).
const WAIST := Vector2(176, 154)
const LYING := Vector2(126, 163)
const CAT_POS := Vector2(304, 177)
const LINES := ["Los sueños más grandes comienzan con un poquito de valentía.", "Gracias por jugar, Alice."]

var alice_lying: AnimatedSprite2D
var alice: AnimatedSprite2D
var cat: AnimatedSprite2D
var zzz: PixelText
var text_root: Node2D
var light: Sprite2D
var t := 0.0
var steps: Array = []
var step_i := 0
var leaving := false
var can_skip_at := 1.0


func _ready() -> void:
	GameState.entry = {}
	AudioManager.play_music("alice_awakening")
	var bg := Sprite2D.new()
	bg.texture = BEDROOM
	bg.centered = false
	add_child(bg)
	# luz del amanecer por la ventana
	light = Sprite2D.new()
	light.texture = Assets.generated("glow")
	light.position = Vector2(406, 96)
	light.scale = Vector2(6, 6)
	light.modulate = Color(C.rgb(0xffd8a0), 0.35)
	add_child(light)
	var lt := light.create_tween().set_loops()
	lt.tween_property(light, "modulate:a", 0.5, 2.0).set_trans(Tween.TRANS_SINE)
	lt.tween_property(light, "modulate:a", 0.3, 2.0).set_trans(Tween.TRANS_SINE)
	alice_lying = _alice()
	Anim.show_frame(alice_lying, "blink", 0)
	alice_lying.rotation = -PI / 2.0
	alice_lying.position = LYING
	alice = _alice()
	Anim.show_frame(alice, "idle", 0)
	alice.position = WAIST + Vector2(0, 40)
	alice.modulate.a = 0.0
	var blanket := Sprite2D.new()
	blanket.texture = BLANKET
	blanket.centered = false
	add_child(blanket)
	cat = AnimatedSprite2D.new()
	cat.sprite_frames = Assets.sprite_frames("gato_morado")
	Anim.set_origin(cat, Assets.cell_size("gato_morado"), 0.5, 1.0)
	Anim.show_frame(cat, "sleep", 0)
	cat.scale = Vector2(1.4, 1.4)
	cat.flip_h = true
	cat.position = CAT_POS
	add_child(cat)
	zzz = PixelText.make("Z z z", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0x8f6bc9)})
	zzz.position = LYING + Vector2(-20, -30)
	add_child(zzz)
	var zt := zzz.create_tween().set_loops()
	zt.tween_property(zzz, "position:y", zzz.position.y - 4, 0.8).set_trans(Tween.TRANS_SINE)
	zt.tween_property(zzz, "position:y", zzz.position.y, 0.8).set_trans(Tween.TRANS_SINE)
	text_root = Node2D.new()
	text_root.z_index = 10
	add_child(text_root)
	steps = [
		[2.4, _wake_up], [4.2, _look_left], [5.0, _look_right], [5.8, _smile], [7.2, _meow],
		[8.2, _cat_wakes], [9.4, _surprised], [10.6, _happy], [12.4, func(): _line(LINES[0], 4.0)],
		[16.8, func(): _line(LINES[1], 3.2)], [20.4, _fin], [24.4, _to_credits],
	]
	Fader.fade_in(1400, Color8(255, 240, 250))


func _alice() -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Assets.sprite_frames("player")
	Anim.set_origin(a, Assets.cell_size("player"), 0.5, 0.62)
	a.scale = Vector2(ALICE_SCALE, ALICE_SCALE)
	add_child(a)
	return a


func _process(delta: float) -> void:
	t += delta
	while step_i < steps.size() and t >= float(steps[step_i][0]):
		var fn: Callable = steps[step_i][1]
		step_i += 1
		fn.call()
	if t >= can_skip_at and not leaving and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("fire") or Input.is_action_just_pressed("ui_accept")):
		_to_credits()


## Se incorpora despacio: la Alice acostada se desvanece y la sentada sube tras la colcha.
func _wake_up() -> void:
	zzz.create_tween().tween_property(zzz, "modulate:a", 0.0, 0.5)
	var tw := create_tween().set_parallel()
	tw.tween_property(alice_lying, "modulate:a", 0.0, 0.7)
	tw.tween_property(alice, "modulate:a", 1.0, 0.7)
	tw.tween_property(alice, "position", WAIST, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _look_left() -> void:
	alice.flip_h = true
	Anim.show_frame(alice, "idle", 1)


func _look_right() -> void:
	alice.flip_h = false
	Anim.show_frame(alice, "idle", 2)


func _smile() -> void:
	Anim.show_frame(alice, "blink", 0)
	_sparkle(alice.position + Vector2(10, -60))


func _meow() -> void:
	AudioManager.play("meow")
	Anim.show_frame(alice, "idle", 0)
	var m := PixelText.make("¡Miau!", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xd85cd5)})
	m.position = CAT_POS + Vector2(0, -40)
	add_child(m)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "position:y", m.position.y - 10, 1.2)
	tw.tween_property(m, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.chain().tween_callback(m.queue_free)


## El gato abre los ojos y mueve la cola (balanceo suave del dibujo).
func _cat_wakes() -> void:
	Anim.show_frame(cat, "idle", 1)
	var tw := cat.create_tween().set_loops(3)
	tw.tween_property(cat, "rotation_degrees", 4.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cat, "rotation_degrees", -2.0, 0.25).set_trans(Tween.TRANS_SINE)
	cat.create_tween().tween_property(cat, "rotation_degrees", 0.0, 0.2).set_delay(1.6)
	AudioManager.play("purr")


## Alice mira hacia los pies de la cama y sonríe sorprendida.
func _surprised() -> void:
	alice.flip_h = false
	Anim.show_frame(alice, "jump", 0)
	_sparkle(alice.position + Vector2(18, -62))


func _happy() -> void:
	Anim.show_frame(alice, "victory", 1)
	Anim.show_frame(cat, "purr", 0)
	var h := Sprite2D.new()
	h.texture = Assets.frame("w8_fx", "cat_heart")
	h.position = (alice.position + CAT_POS) / 2.0 + Vector2(0, -40)
	h.scale = Vector2(1.5, 1.5)
	add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position:y", h.position.y - 20, 1.6)
	tw.tween_property(h, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.chain().tween_callback(h.queue_free)


func _sparkle(pos: Vector2) -> void:
	for i in 4:
		var s := Sprite2D.new()
		s.texture = Assets.frame("fx", "sparkle")
		s.position = pos + Vector2(randf_range(-10, 10), randf_range(-8, 8))
		s.scale = Vector2(0.7, 0.7)
		add_child(s)
		var tw := s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.8).set_delay(0.1 * i)
		tw.tween_callback(s.queue_free)


## Rótulo con la tipografía pixel del juego sobre una franja oscura.
func _line(text: String, secs: float) -> void:
	for c in text_root.get_children():
		c.queue_free()
	var band := ColorRect.new()
	band.color = Color(C.INK, 0.7)
	band.position = Vector2(0, 220)
	band.size = Vector2(C.GAME_W, 34)
	text_root.add_child(band)
	var label := PixelText.make(text, {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	label.position = Vector2(C.GAME_W / 2.0, 237)
	text_root.add_child(label)
	text_root.modulate.a = 0.0
	var tw := text_root.create_tween()
	tw.tween_property(text_root, "modulate:a", 1.0, 0.6)
	tw.tween_interval(maxf(0.2, secs - 1.2))
	tw.tween_property(text_root, "modulate:a", 0.0, 0.6)


func _fin() -> void:
	for c in text_root.get_children():
		c.queue_free()
	var band := ColorRect.new()
	band.color = Color(C.INK, 0.75)
	band.size = Vector2(C.GAME_W, C.GAME_H)
	text_root.add_child(band)
	var fin := PixelText.make("FIN", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 4})
	fin.position = Vector2(C.GAME_W / 2.0, C.GAME_H / 2.0)
	text_root.add_child(fin)
	text_root.modulate.a = 0.0
	text_root.create_tween().tween_property(text_root, "modulate:a", 1.0, 1.2)
	AudioManager.play("victory")


func _to_credits() -> void:
	if leaving:
		return
	leaving = true
	await Fader.fade_out(900)
	if is_inside_tree():
		Router.go("Credits")
