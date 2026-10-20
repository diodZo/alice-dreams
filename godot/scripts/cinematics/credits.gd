extends Control
## Créditos finales de Alice Dreams: texto con desplazamiento suave (data/world8/credits.json,
## sólo nombres confirmados por el propietario), estrellas y corazones que flotan, el gato
## morado y Alice saludando. No hay controles de juego: sólo Saltar / Disparar / Enter / Esc
## (o el botón) para volver al menú principal, que también se abre solo al terminar.

const SCROLL_SPEED := 16.0

var scroller: Node2D
var content_h := 0.0
var leaving := false
var _float_acc := 0.0
var back_btn: CloudButton


func _ready() -> void:
	GameState.entry = {}
	AudioManager.play_music("alice_credits")
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var sky := Sprite2D.new()
	sky.texture = Assets.image("w8_sky")
	sky.centered = false
	sky.modulate = Color(1.15, 1.08, 1.2)
	add_child(sky)
	var clouds := Assets.image("w8_clouds_near")
	var band := TiledSprite.new().setup(clouds, Vector2(W, clouds.get_height()))
	band.position = Vector2(0, H - clouds.get_height() + 10)
	add_child(band)
	var bt := band.create_tween().set_loops()
	bt.tween_property(band, "tile_offset:x", float(clouds.get_width()), 30.0).from(0.0)

	scroller = Node2D.new()
	scroller.position = Vector2(W / 2.0, H + 10)
	add_child(scroller)
	var data: Variant = C.load_json("res://data/world8/credits.json")
	var y := 0.0
	y = _add(str(data.get("title", "Alice Dreams")), y, 3, C.YELLOW) + 6
	y = _add(str(data.get("subtitle", "")), y, 2, C.PINK) + 26
	for s in data.get("sections", []):
		var lines: Array = s.get("lines", [])
		if lines.is_empty():
			continue  # sin nombres confirmados no se muestra la sección
		y = _add(str(s.title), y, 1, C.YELLOW) + 4
		for l in lines:
			y = _add(str(l), y, 1, C.CREAM) + 2
		y += 18
	y += 10
	y = _add(str(data.get("ending", "¡Gracias por jugar!")), y, 2, C.YELLOW)
	content_h = y

	# Alice saluda y el gato morado ronronea a su lado
	var alice := AnimatedSprite2D.new()
	alice.sprite_frames = Assets.sprite_frames("player")
	Anim.set_origin(alice, Assets.cell_size("player"), 0.5, 1.0)
	alice.scale = Vector2(1.5, 1.5)
	alice.position = Vector2(W - 34, H - 14)
	alice.play("victory")
	add_child(alice)
	var cat := AnimatedSprite2D.new()
	cat.sprite_frames = Assets.sprite_frames("gato_morado")
	Anim.set_origin(cat, Assets.cell_size("gato_morado"), 0.5, 1.0)
	cat.scale = Vector2(1.2, 1.2)
	cat.position = Vector2(W - 80, H - 14)
	cat.play("purr")
	add_child(cat)

	back_btn = CloudButton.make("Menú principal", 110, 18)
	back_btn.position = Vector2(8, H - 26)
	back_btn.activated.connect(func(_b): back_to_menu())
	add_child(back_btn)
	var buttons: Array[CloudButton] = [back_btn]
	add_child(MenuList.new().setup(buttons))
	Fader.fade_in(900)


func _add(text: String, y: float, scale: int, tint: Color) -> float:
	if text == "":
		return y
	var t := PixelText.make(text, {"origin": Vector2(0.5, 0), "tint": tint, "scale": scale, "center": true})
	t.position = Vector2(0, y)
	scroller.add_child(t)
	return y + 10.0 * scale


func _process(delta: float) -> void:
	scroller.position.y -= SCROLL_SPEED * delta
	_float_acc += delta
	if _float_acc > 0.45:
		_float_acc = 0.0
		_floater()
	if scroller.position.y + content_h < 60 and not leaving:
		back_to_menu()
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("jump"):
		back_to_menu()


## Estrellas y corazones que suben flotando.
func _floater() -> void:
	var s := Sprite2D.new()
	var heart := randf() < 0.35
	s.texture = Assets.frame("world8_objects", "heart_dream" if heart else ("star_w8" if randf() < 0.7 else "star_rainbow"))
	s.position = Vector2(randf_range(10, C.GAME_W - 10), C.GAME_H + 10)
	s.scale = Vector2.ONE * randf_range(0.6, 1.0)
	add_child(s)
	move_child(s, 2)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "position:y", -20.0, randf_range(7.0, 11.0))
	tw.tween_property(s, "position:x", s.position.x + randf_range(-30, 30), 9.0).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(s.queue_free)


func back_to_menu() -> void:
	if leaving:
		return
	leaving = true
	AudioManager.play("ui_select")
	await Fader.fade_out(600)
	if is_inside_tree():
		Router.go("Menu")
