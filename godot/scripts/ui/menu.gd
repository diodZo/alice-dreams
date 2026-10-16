extends Control
## Pantalla de título (port de scenes/MenuScene.js).

var starting := false
var reset_armed := false
var clouds_far: TiledSprite
var clouds_near: TiledSprite
var music_btn: CloudButton
var sfx_btn: CloudButton
var reset_btn: CloudButton
var world2_btn: CloudButton


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
	var sub := PixelText.make("Elige un mundo", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
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
	var done_lines: PackedStringArray = []
	for id in [1, 2]:
		var wd := SaveManager.get_world(id)
		if wd.get("completed", false):
			done_lines.append("Mundo %d: %d estrellas" % [id, int(wd.bestStars)])
	if not done_lines.is_empty():
		var done := PixelText.make("* " + " - ".join(done_lines) + " *", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW})
		done.position = Vector2(W / 2, 62)
		art.add_child(done)

	# botones (contenedor vertical centrado): un botón por mundo + opciones
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.position = Vector2(W / 2 - 75, 70)
	box.size = Vector2(150, 120)
	add_child(box)
	var play := CloudButton.make("Mundo 1: Nubes de Algodón", 150)
	play.activated.connect(func(_b): start_game(1))
	world2_btn = CloudButton.make(_world2_label(), 150)
	world2_btn.activated.connect(func(_b): start_game(2))
	music_btn = CloudButton.make(_music_label(), 150)
	music_btn.activated.connect(func(b):
		AudioManager.set_music_enabled(not AudioManager.music_on)
		b.set_label(_music_label())
		AudioManager.play("ui_select"))
	sfx_btn = CloudButton.make(_sfx_label(), 150)
	sfx_btn.activated.connect(func(b):
		AudioManager.set_sfx_enabled(not AudioManager.sfx_on)
		b.set_label(_sfx_label())
		AudioManager.play("ui_select"))
	reset_btn = CloudButton.make("Borrar progreso", 150)
	reset_btn.activated.connect(confirm_reset)
	var buttons: Array[CloudButton] = [play, world2_btn, music_btn, sfx_btn, reset_btn]
	for b in buttons:
		box.add_child(b)
	add_child(MenuList.new().setup(buttons))

	var help := PixelText.make("A/D: mover - ESPACIO: saltar - SHIFT: correr\nJ: disparar - K: arma - W+J: arriba - ESC: pausa", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM, "center": true})
	help.position = Vector2(W / 2, 214)
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


func _world2_label() -> String:
	return "Mundo 2: Crayones" if WorldRegistry.is_playable(2) else "Mundo 2 (bloqueado)"


func start_game(id := 1) -> void:
	if starting:
		return
	if not WorldRegistry.is_playable(id):
		AudioManager.play("no_weapon")
		GameState.show_toast("Completa el Mundo %d para desbloquearlo" % (id - 1))
		_toast("Completa el Mundo %d para desbloquearlo" % (id - 1))
		return
	starting = true
	AudioManager.play("ui_select")
	var key := WorldRegistry.start_run(id)
	GameState.entry = {"introBanner": true}
	await Fader.fade_out(400)
	Router.go(key)


func _process(delta: float) -> void:
	clouds_far.tile_offset.x += delta * 1000.0 * 0.006
	clouds_near.tile_offset.x += delta * 1000.0 * 0.014


var _toast_label: PixelText


func _toast(text: String) -> void:
	if _toast_label == null:
		_toast_label = PixelText.make("", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xff8080)})
		_toast_label.position = Vector2(C.GAME_W / 2.0, 200)
		add_child(_toast_label)
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	var tw := _toast_label.create_tween()
	tw.tween_property(_toast_label, "modulate:a", 0.0, 0.5).set_delay(1.6)
