extends Control
## Pantalla de victoria (port de scenes/VictoryScene.js), común a todos los mundos: los textos,
## el jefe y la música salen de WorldRegistry. El progreso ya se guardó al cruzar el portal.

var clouds: TiledSprite
var effects: Effects
var _confetti_acc := 0.0
var world_id := 1
var journal_btn: CloudButton
var celebration: RescueCelebration
var _new_page := false


func _ready() -> void:
	var stats := GameState.entry
	GameState.entry = {}
	world_id = int(stats.get("world", 1))
	var info_w := WorldRegistry.get_world(world_id)
	AudioManager.play_music(info_w.get("victoryMusic", "menu"))
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

	var title := PixelText.make(info_w.get("victoryTitle", "¡Mundo completado!"), {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 28)
	add_child(title)
	var sub := PixelText.make(info_w.get("victorySub", ""), {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
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
	cloud.sprite_frames = Assets.sprite_frames(info_w.get("bossFrames", "nubarron"))
	Anim.show_frame(cloud, info_w.get("bossAnim", "idle"), int(info_w.get("bossFrame", 1)))
	cloud.position = Vector2(W - 52, 150)
	var bs: float = info_w.get("bossScale", 0.5)
	cloud.scale = Vector2(bs, bs)
	if world_id != 1:
		# el jefe del Mundo 2 tiene el origen en los pies
		Anim.set_origin(cloud, Assets.cell_size(info_w.bossFrames), 0.5, 0.75)
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
		info_w.get("nextPortal", ""),
	]
	if int(stats.get("magicTotal", 0)) > 0:
		lines.insert(2, "Crayones mágicos: %d de %d" % [stats.get("magic", []).size(), int(stats.magicTotal)])
	if int(stats.get("dreamTotal", 0)) > 0:
		lines.insert(2, "Tesoros del sueño: %d de %d" % [stats.get("dream", []).size(), int(stats.dreamTotal)])
	var info := PixelText.make("\n".join(lines), {"origin": Vector2(0.5, 0), "tint": C.CREAM, "center": true})
	info.position = Vector2(W / 2 + 10, 76)
	add_child(info)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var buttons: Array[CloudButton] = []
	var next := WorldRegistry.get_world(world_id + 1)
	if not next.is_empty() and next.implemented:
		var go := CloudButton.make("Ir al Mundo %d" % (world_id + 1), 150)
		go.activated.connect(func(_b): play_world(world_id + 1))
		buttons.append(go)
	var again := CloudButton.make("Jugar otra vez", 150)
	again.activated.connect(func(_b): play_world(world_id))
	buttons.append(again)
	var menu := CloudButton.make("Menú principal", 150)
	menu.activated.connect(func(_b): Router.go("Menu"))
	buttons.append(menu)
	# Diario de Sueños: la página de este mundo acaba de desbloquearse al cruzar el portal
	journal_btn = CloudButton.make("Diario de Sueños", 150)
	journal_btn.activated.connect(func(_b): open_journal())
	buttons.append(journal_btn)
	box.position = Vector2(W / 2 + 10 - 75, 139 if buttons.size() == 2 else 136 - 13 * (buttons.size() - 3))
	box.size = Vector2(150, 26 * buttons.size() - 4)
	add_child(box)
	for b in buttons:
		box.add_child(b)
	add_child(MenuList.new().setup(buttons))

	var fx := Node2D.new()
	fx.z_index = 5
	add_child(fx)
	effects = Effects.new(fx)
	effects.confetti(W / 2, 20, 90)
	Fader.fade_in(600, Color8(255, 247, 255))
	# Narrativa: celebración de las criaturas liberadas y aviso de página nueva del diario
	_new_page = bool(stats.get("newPage", false))
	celebration = RescueCelebration.make(stats.get("rescued", []))
	if celebration != null:
		celebration.finished.connect(_announce_page)
		add_child(celebration)
	else:
		_announce_page()


func open_journal() -> void:
	var j := DreamJournal.open(self, world_id)
	j.closed.connect(func(): journal_btn.set_label("Diario de Sueños"))


## Página nueva en el diario: el botón late y aparece un aviso breve.
func _announce_page() -> void:
	if not _new_page or not is_instance_valid(journal_btn):
		return
	journal_btn.set_label("¡Página nueva!")
	var tw := journal_btn.create_tween().set_loops(4)
	tw.tween_property(journal_btn, "modulate", Color(1.3, 1.25, 0.9), 0.3)
	tw.tween_property(journal_btn, "modulate", Color.WHITE, 0.3)
	AudioManager.play("pickup")
	effects.sparkle(journal_btn.global_position.x + 75, journal_btn.global_position.y + 11, 10)


func play_world(id: int) -> void:
	var key := WorldRegistry.start_run(id)
	GameState.entry = {"introBanner": true}
	Router.go(key)


func _process(delta: float) -> void:
	clouds.tile_offset.x += delta * 1000.0 * 0.012
	_confetti_acc += delta * 1000.0
	if _confetti_acc >= 1600:
		_confetti_acc -= 1600
		effects.confetti(randi_range(60, C.GAME_W - 60), 10, 40)
