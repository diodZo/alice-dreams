extends Control
## Pantalla de victoria del Mundo 1 (port de scenes/VictoryScene.js). El progreso ya se
## guardó al cruzar el portal.

var clouds: TiledSprite
var effects: Effects
var _confetti_acc := 0.0


func _ready() -> void:
	var stats := GameState.entry
	GameState.entry = {}
	AudioManager.play_music("menu")
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var sky := Sprite2D.new()
	sky.texture = Assets.image("sky")
	sky.centered = false
	add_child(sky)
	var near := Assets.image("clouds_near")
	clouds = TiledSprite.new().setup(near, Vector2(W, near.get_height()))
	clouds.position = Vector2(0, H - near.get_height() + 24)
	add_child(clouds)

	var title := PixelText.make("¡Mundo 1 completado!", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 28)
	add_child(title)
	var sub := PixelText.make("Nubarrón vuelve a ser una nube feliz", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	sub.position = Vector2(W / 2, 50)
	add_child(sub)

	var hero := AnimatedSprite2D.new()
	hero.sprite_frames = Assets.sprite_frames("player")
	Anim.set_origin(hero, Assets.cell_size("player"), 0.5, 1.0)
	hero.position = Vector2(110, 190)
	hero.scale = Vector2(2, 2)
	hero.play("victory")
	add_child(hero)
	var cloud := AnimatedSprite2D.new()
	cloud.sprite_frames = Assets.sprite_frames("nubarron")
	Anim.show_frame(cloud, "idle", 1)
	cloud.position = Vector2(W - 52, 150)
	cloud.scale = Vector2(0.5, 0.5)
	add_child(cloud)
	var ct := cloud.create_tween().set_loops()
	ct.tween_property(cloud, "position:y", 144.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ct.tween_property(cloud, "position:y", 150.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var secs := int(float(stats.get("time", 0)) / 1000.0)
	var time := "%d:%02d" % [secs / 60, secs % 60]
	var lines := [
		"Estrellas: %d de %d" % [int(stats.get("stars", 0)), int(stats.get("total", 0))],
		"Estrella dorada especial: %s" % ("conseguida" if stats.get("special", false) else "no"),
		"Tiempo: %s" % time,
		"Portal al Mundo 2: abierto (próximamente)",
	]
	var info := PixelText.make("\n".join(lines), {"origin": Vector2(0.5, 0), "tint": C.CREAM, "center": true})
	info.position = Vector2(W / 2 + 10, 76)
	add_child(info)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(W / 2 + 10 - 75, 139)
	box.size = Vector2(150, 48)
	add_child(box)
	var again := CloudButton.make("Jugar otra vez", 150)
	again.activated.connect(func(_b): replay())
	var menu := CloudButton.make("Menú principal", 150)
	menu.activated.connect(func(_b): Router.go("Menu"))
	var buttons: Array[CloudButton] = [again, menu]
	for b in buttons:
		box.add_child(b)
	add_child(MenuList.new().setup(buttons))

	var fx := Node2D.new()
	fx.z_index = 5
	add_child(fx)
	effects = Effects.new(fx)
	effects.confetti(W / 2, 20, 90)
	Fader.fade_in(600, Color8(255, 247, 255))


func replay() -> void:
	var key := WorldRegistry.start_run(1)
	GameState.entry = {"introBanner": true}
	Router.go(key)


func _process(delta: float) -> void:
	clouds.tile_offset.x += delta * 1000.0 * 0.012
	_confetti_acc += delta * 1000.0
	if _confetti_acc >= 1600:
		_confetti_acc -= 1600
		effects.confetti(randi_range(60, C.GAME_W - 60), 10, 40)
