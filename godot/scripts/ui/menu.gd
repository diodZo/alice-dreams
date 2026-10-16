extends Control
## Pantalla de título (port de scenes/MenuScene.js).

var starting := false
var reset_armed := false
var clouds_far: TiledSprite
var clouds_near: TiledSprite
var music_btn: CloudButton
var sfx_btn: CloudButton
var reset_btn: CloudButton


func _ready() -> void:
	AudioManager.play_music("menu")
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var art := Node2D.new()
	add_child(art)

	var sky := Sprite2D.new()
	sky.texture = Assets.image("sky")
	sky.centered = false
	art.add_child(sky)
	art.add_child(_sprite(Assets.frame("world1_bg", "castle"), Vector2(W / 2 + 120, 120), 1.0, 0.9))
	art.add_child(_sprite(Assets.frame("world1_bg", "island_big"), Vector2(70, 92), 0.8))
	var far := Assets.image("clouds_far")
	clouds_far = TiledSprite.new().setup(far, Vector2(W, far.get_height()))
	clouds_far.position = Vector2(0, H - far.get_height() + 10)
	art.add_child(clouds_far)
	var near := Assets.image("clouds_near")
	clouds_near = TiledSprite.new().setup(near, Vector2(W, near.get_height()))
	clouds_near.position = Vector2(0, H - near.get_height() + 24)
	art.add_child(clouds_near)

	var title := PixelText.make("Guardiana de los Sueños", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 26)
	art.add_child(title)
	var tt := title.create_tween().set_loops()
	tt.tween_property(title, "position:y", 29.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tt.tween_property(title, "position:y", 26.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var world := WorldRegistry.get_world(1)
	var sub := PixelText.make("Mundo 1: %s" % world.name, {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	sub.position = Vector2(W / 2, 50)
	art.add_child(sub)

	# personajes
	art.add_child(_char("player", "idle", Vector2(60, H - 8), 2.0, false))
	art.add_child(_char("scratch", "idle", Vector2(W - 120, H - 6), 1.0, false))
	art.add_child(_char("spit", "idle", Vector2(W - 86, H - 6), 1.0, true))
	art.add_child(_char("flea", "idle", Vector2(W - 52, H - 6), 1.0, true))
	var boss := AnimatedSprite2D.new()
	boss.sprite_frames = Assets.sprite_frames("nubarron")
	boss.position = Vector2(W - 80, 92)
	boss.scale = Vector2(0.6, 0.6)
	boss.flip_h = true
	boss.play("idle")
	art.add_child(boss)
	var bt := boss.create_tween().set_loops()
	bt.tween_property(boss, "position:y", 98.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bt.tween_property(boss, "position:y", 92.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# progreso guardado
	var w1 := SaveManager.get_world(1)
	if w1.get("completed", false):
		var done := PixelText.make("* Mundo 1 completado - Mejor marca: %d estrellas *" % int(w1.bestStars), {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW})
		done.position = Vector2(W / 2, 62)
		art.add_child(done)

	# botones (contenedor vertical centrado: y = 88, 114, 140, 166)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(W / 2 - 70, 77)
	box.size = Vector2(140, 100)
	add_child(box)
	var play := CloudButton.make("Jugar")
	play.activated.connect(func(_b): start_game())
	music_btn = CloudButton.make(_music_label())
	music_btn.activated.connect(func(b):
		AudioManager.set_music_enabled(not AudioManager.music_on)
		b.set_label(_music_label())
		AudioManager.play("ui_select"))
	sfx_btn = CloudButton.make(_sfx_label())
	sfx_btn.activated.connect(func(b):
		AudioManager.set_sfx_enabled(not AudioManager.sfx_on)
		b.set_label(_sfx_label())
		AudioManager.play("ui_select"))
	reset_btn = CloudButton.make("Borrar progreso")
	reset_btn.activated.connect(confirm_reset)
	var buttons: Array[CloudButton] = [play, music_btn, sfx_btn, reset_btn]
	for b in buttons:
		box.add_child(b)
	add_child(MenuList.new().setup(buttons))

	var help := PixelText.make("A/D: mover - ESPACIO: saltar - SHIFT: correr\nJ: disparar - K: arma - W+J: arriba - ESC: pausa", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM, "center": true})
	help.position = Vector2(W / 2, 198)
	add_child(help)

	if Assets.used_placeholders.size() > 0:
		var warn := PixelText.make("Aviso: %d recurso(s) provisional(es). Ver consola." % Assets.used_placeholders.size(), {"tint": C.rgb(0xff8080)})
		warn.position = Vector2(4, H - 12)
		add_child(warn)
	if not SaveManager.is_storage_available():
		var warn2 := PixelText.make("Aviso: no se puede guardar el progreso", {"tint": C.rgb(0xff8080)})
		warn2.position = Vector2(4, 4)
		add_child(warn2)
	Fader.fade_in(400)


func _sprite(tex: Texture2D, pos: Vector2, s := 1.0, alpha := 1.0) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.position = pos
	sp.scale = Vector2(s, s)
	sp.modulate.a = alpha
	return sp


func _char(key: String, anim_name: String, pos: Vector2, s: float, flip: bool) -> AnimatedSprite2D:
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = Assets.sprite_frames(key)
	Anim.set_origin(sp, Assets.cell_size(key), 0.5, 1.0)
	sp.position = pos
	sp.scale = Vector2(s, s)
	sp.flip_h = flip
	sp.play(anim_name)
	return sp


func _music_label() -> String:
	return "Música: %s" % ("Sí" if AudioManager.music_on else "No")


func _sfx_label() -> String:
	return "Efectos: %s" % ("Sí" if AudioManager.sfx_on else "No")


func confirm_reset(btn: CloudButton) -> void:
	if not reset_armed:
		reset_armed = true
		btn.set_label("¿Seguro? Pulsa otra vez")
		AudioManager.play("ui_move")
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(btn):
				reset_armed = false
				btn.set_label("Borrar progreso"))
		return
	SaveManager.reset_progress()
	AudioManager.play("ui_select")
	get_tree().reload_current_scene()


func start_game() -> void:
	if starting:
		return
	starting = true
	AudioManager.play("ui_select")
	var key := WorldRegistry.start_run(1)
	GameState.entry = {"introBanner": true}
	await Fader.fade_out(400)
	Router.go(key)


func _process(delta: float) -> void:
	clouds_far.tile_offset.x += delta * 1000.0 * 0.006
	clouds_near.tile_offset.x += delta * 1000.0 * 0.014
