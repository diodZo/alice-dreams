extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 2. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w2_data", "test_w2_sprites", "test_w2_level_loads", "test_w2_paint",
	"test_w2_rulers", "test_w2_switch_and_temporary", "test_w2_hazards", "test_w2_magic_and_checkpoint",
	"test_w2_eraser", "test_w2_crayon", "test_w2_brush", "test_w2_weapons_vs_enemies",
	"test_w2_boss", "test_w2_progression",
]


func test_w2_data() -> void:
	var w: Dictionary = C.load_json("res://data/world2/world2.json")
	var b: Dictionary = C.load_json("res://data/world2/world2_boss.json")
	check(w.progress.total == 9000, "recorrido total de 9.000 px")
	near(float(w.widthTiles * 16) + float(b.widthTiles * 16) * float(b.progress.scale), 9000, 1, "nivel + arena = 9.000 px")
	var froms: Array = w.sections.map(func(x): return int(x.from))
	check(froms == [0, 1500, 3300, 5200, 6900], "cinco secciones A-E en 0/1.500/3.300/5.200/6.900")
	# IMP-026: la sección E ocupa al menos 600 px del nivel
	check(float(w.widthTiles) * 16 - 6900 >= 600, "la sección E ocupa al menos 600 px")
	check(w.magicCrayons.size() == 3, "tres crayones mágicos (rojo, azul, amarillo)")
	var types := {}
	for e in w.enemies:
		types[e.type] = true
	check(types.keys().size() == 3 and types.has("eraser") and types.has("crayon") and types.has("brush"), "los tres enemigos del Mundo 2")
	check(w.checkpoints.size() == 4, "cuatro checkpoints")
	check(String(b.boss.scene).ends_with("Garabato.tscn"), "la arena usa a Garabato")
	var manifest: Dictionary = C.load_json("res://data/world2/world2_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "ningún recurso pendiente en el manifiesto (%s)" % str(manifest.summary.pending))
	var complete := true
	for r in manifest.resources:
		if r.type == "frame":
			complete = complete and r.has("crop") and r.has("duration_ms") and r.has("origin") and r.has("offset") and r.has("status") and r.has("animation") and r.has("frame")
	check(complete, "el manifiesto registra caja, animación, fotograma, duración, offset, origen y estado")


func test_w2_sprites() -> void:
	var expected := {
		"eraser": {"idle": 4, "walk": 4, "jump": 2, "attack": 3, "hurt": 2, "defeated": 2},
		"crayon": {"idle": 4, "walk": 4, "charge": 3, "attack": 3, "hurt": 2, "defeated": 2},
		"brush": {"idle": 4, "walk": 4, "attack": 3, "hurt": 2, "defeated": 1},
		"garabato": {"idle": 3, "move": 6, "shoot": 4, "swirl": 4, "spin": 4, "stun": 2, "hurt": 1, "defeated": 2},
	}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		var cell := Assets.cell_size(key)
		var total := 0
		var aligned := true
		var uncut := true
		for a in expected[key]:
			check(sf.has_animation(a) and sf.get_frame_count(a) == expected[key][a], "%s_%s tiene %d fotogramas" % [key, a, expected[key][a]])
			for i in sf.get_frame_count(a):
				total += 1
				var tex := sf.get_frame_texture(a, i)
				check(tex.get_size() == cell, "%s_%s_%d ocupa la celda común %s" % [key, a, i, cell])
				var img := tex.get_image()
				# alineación: el punto de apoyo (fila más baja con píxeles) es el mismo en todos los fotogramas
				var lowest := -1
				for y in range(img.get_height() - 1, -1, -1):
					for x in img.get_width():
						if img.get_pixel(x, y).a > 0.5:
							lowest = y
							break
					if lowest != -1:
						break
				if lowest != int(cell.y) - 2:
					aligned = false
					printerr("  %s_%s_%d apoyo en fila %d" % [key, a, i, lowest])
				# sin recortes: el dibujo no toca los bordes laterales ni el superior de la celda
				for y in img.get_height():
					if img.get_pixel(0, y).a > 0.5 or img.get_pixel(img.get_width() - 1, y).a > 0.5:
						uncut = false
				for x in img.get_width():
					if img.get_pixel(x, 0).a > 0.5:
						uncut = false
		check(aligned, "%s: todos los fotogramas comparten la línea de los pies" % key)
		check(uncut, "%s: ningún fotograma queda recortado por su celda" % key)
		if key == "garabato":
			check(total == 26, "Garabato usa los 26 fotogramas de jefemundo2.png")
	for t in ["world2_objects", "world2_bg", "w2_fx", "eraser", "crayon", "brush", "garabato"]:
		var tex := Assets.texture(Assets.atlases[t].texture)
		check(tex != null and tex.get_width() > 0, "PNG %s íntegro" % t)
	check(Assets.tileset("world2_tiles") != null, "TileSet del Mundo 2")


func test_w2_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World2")
	await settle()
	check(level.data.key == "world2", "el Mundo 2 carga")
	check(Assets.used_placeholders.is_empty(), "sin recursos provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(level.player.grounded, "la protagonista se apoya en el terreno del Mundo 2 (colisión real de las teselas)")
	check(GameState.get_v("weaponsOwned").size() == 3, "empieza con las tres armas")
	check(level.level_objects.rulers.size() == 7, "siete puentes de reglas")


func _surface_speed_test(x: float, y: float) -> float:
	place(x, y)
	await settle()
	hold(["move_right"])
	await frames(30)
	return level.player.velocity.x


func test_w2_paint() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	# rosa (pegajosa): 330-338
	var pink := await _surface_speed_test(330, 19)
	near(pink, 47.5, 0.5, "la pintura rosa reduce la velocidad a la mitad")
	hold([])
	var normal := await _surface_speed_test(320, 19)
	near(normal, 95, 0.5, "fuera de la pintura la velocidad se restaura")
	hold([])
	# azul (resbaladiza): al soltar, frena mucho más despacio
	place(100, 20)
	await settle()
	hold(["move_right", "run"])
	await frames(40)
	hold([])
	await frames(10)
	check(level.player.velocity.x > 60, "la pintura azul resbala (sigue a %.0f px/s tras 10 fotogramas)" % level.player.velocity.x)
	await frames(120)
	# amarilla (elástica): al caer encima rebota
	level.player.position = Vector2(239 * C.TILE, 19 * C.TILE - 40)
	level.player.velocity = Vector2.ZERO
	level.camera.snap_to_target()
	var min_vy := 0.0
	for i in 40:
		await frames(1)
		min_vy = minf(min_vy, level.player.velocity.y)
	check(min_vy < -400, "la pintura amarilla hace rebotar (%.0f)" % min_vy)
	near(level.player.surface_speed, 1.0, 0.001, "en el aire no queda ningún efecto aplicado")


func test_w2_rulers() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	# recto (39-47, superficie 320)
	place(42, 18)
	await frames(30)
	check(level.player.grounded and absf(level.player.position.y - 321) < 1.5, "se camina sobre el puente de reglas recto")
	# inclinado (60,20) -> (66,17): subir caminando
	place(57, 20)
	await settle()
	hold(["move_right"])
	var top_y := 999.0
	for i in 110:
		await frames(1)
		top_y = minf(top_y, level.player.position.y)
	check(top_y < 17 * C.TILE + 4, "se sube por la regla inclinada hasta el escritorio (y mínima %.0f)" % top_y)
	hold([])
	# articulado (187 -> 204, pasa por 21)
	place(184, 19)
	await settle()
	hold(["move_right"])
	var reached := false
	var max_y := 0.0
	for i in 240:
		await frames(1)
		max_y = maxf(max_y, level.player.position.y)
		if level.player.position.x > 205 * C.TILE:
			reached = true
			break
	check(reached, "se cruza el puente articulado")
	check(max_y > 20 * C.TILE and max_y < 22 * C.TILE + 2, "el puente articulado baja y vuelve a subir (y máx %.0f)" % max_y)


func test_w2_switch_and_temporary() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	var activable: RulerBridge = level.level_objects.rulers[3]
	check(not activable.solid, "el puente activable empieza sin dibujar")
	place(160, 19)
	await frames(10)
	check(activable.solid, "el molinillo dibuja el puente")
	var temp: RulerBridge = level.level_objects.rulers[2]
	var seen_on := false
	var seen_off := false
	for i in 300:
		await frames(1)
		if temp.solid:
			seen_on = true
		else:
			seen_off = true
	check(seen_on and seen_off, "el puente temporal aparece y desaparece")


func test_w2_hazards() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	var roller: RollingPencil = level.level_objects.objects.get_children().filter(func(n): return n is RollingPencil)[0]
	var x0 := roller.position.x
	await frames(30)
	check(absf(roller.position.x - x0) > 10, "el lápiz rodante se mueve")
	level.player.position = roller.position + Vector2(0, -2)
	level.player.velocity = Vector2.ZERO
	await frames(3)
	check(level.player.hp < 3, "el lápiz rodante hace daño")
	var bouncer: BouncingEraser = level.level_objects.objects.get_children().filter(func(n): return n is BouncingEraser)[0]
	var ys := []
	for i in 80:
		await frames(1)
		ys.append(bouncer.position.y)
	check(ys.max() - ys.min() > 30, "el borrador rebota en su sitio")
	var drops := 0
	for i in 160:
		await frames(1)
		for p in level.enemy_projectiles.get_children():
			if p.kind == "drop" and not p.has_meta("seen"):
				p.set_meta("seen", true)
				drops += 1
	check(drops >= 1, "la pintura gotea (%d gotas)" % drops)


func test_w2_magic_and_checkpoint() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	place(150, 11)
	await frames(30)
	check("red" in GameState.get_v("magicCrayons"), "se recoge el crayón mágico rojo")
	place(125, 19)
	await frames(10)
	var cp: Variant = GameState.get_v("checkpoint")
	check(cp is Dictionary and cp.index == 0 and cp.scene == "World2", "checkpoint 1 del Mundo 2 (antes del puente dibujado)")
	place(357, 19)
	await frames(10)
	check(GameState.get_v("checkpoint").index == 2, "checkpoint 3 del Mundo 2")
	place(352, 23)
	await frames(80)
	near(level.player.position.x, 357 * C.TILE + 8, 1.0, "reaparece en la última bandera")


func test_w2_eraser() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	place(40, 20)
	var e := _spawn_enemy("eraser", 46, 20)
	var jumped := false
	var dashed := false
	for i in 240:
		await frames(1)
		level.player.invulnerable_until = level.now + 1000
		if not is_instance_valid(e):
			break
		if e.velocity.y < -200:
			jumped = true
		if e.get("phase") == "dash" and absf(e.velocity.x) > 150:
			dashed = true
	check(jumped, "el Borrador salta hacia la protagonista")
	check(dashed, "al caer embiste con un deslizamiento")
	# borra un puente dibujado cercano
	var drawn: RulerBridge = level.level_objects.rulers[5]
	_clear_spawner()
	place(344, 19)
	var e2 := _spawn_enemy("eraser", 347, 19)
	await frames(5)
	e2._erase_bridges()
	check(not drawn.solid, "el Borrador borra el puente dibujado")
	await frames(220)
	check(drawn.solid, "el puente se vuelve a dibujar al rato")


func test_w2_crayon() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	place(100, 20)
	var e := _spawn_enemy("crayon", 105, 20)
	var charged := false
	var dashed := false
	for i in 200:
		await frames(1)
		if e.fsm.current == Enemy.ATTACK and e.get("phase") == "charge":
			charged = true
		if e.get("phase") == "dash" and absf(e.velocity.x) > 150:
			dashed = true
	check(charged, "el Crayón guerrero prepara la embestida")
	check(dashed, "y embiste")
	check(level.player.hp < 3, "el ataque hace daño")


func test_w2_brush() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	place(308, 19)
	var e := _spawn_enemy("brush", 322, 19)
	var shots := 0
	for i in 720:
		await frames(1)
		level.player.invulnerable_until = level.now + 1000
		for p in level.enemy_projectiles.get_children():
			if p.kind == "brushpaint" and not p.has_meta("seen"):
				p.set_meta("seen", true)
				shots += 1
	check(shots >= 4, "el Pincel dispara pintura y alterna ráfagas (%d disparos)" % shots)
	place(e.position.x / C.TILE - 2, 19)
	var x0 := e.position.x
	await frames(60)
	check(e.position.x > x0, "se aparta cuando la protagonista se acerca")


func test_w2_weapons_vs_enemies() -> void:
	await load_level("World2")
	await settle()
	_clear_spawner()
	place(258, 19)
	for type in ["eraser", "crayon", "brush"]:
		var e := _spawn_enemy(type, 264, 19)
		e.def = e.def.duplicate()
		e.def.detect_range = 0
		await frames(5)
		level.weapons.current_id = "bubble"
		level.weapons.ready_at = 0
		level.player.facing = 1
		press("fire")
		await frames(30)
		check(e.is_trapped(), "la burbuja atrapa al %s" % type)
		e.convert_to_star()
		await frames(5)
		var e2 := _spawn_enemy(type, 264, 19)
		e2.def = e2.def.duplicate()
		e2.def.detect_range = 0
		await frames(5)
		level.weapons.current_id = "paint"
		level.weapons.ready_at = 0
		press("fire")
		await frames(30)
		check(e2.hp == e2.def.hp - 1, "la pintura daña al %s" % type)
		level.weapons.current_id = "sling"
		for k in 3:
			level.weapons.ready_at = 0
			press("fire")
			await frames(45)
		check(not is_instance_valid(e2) or not e2.is_alive(), "el tirachinas derrota al %s" % type)
		await frames(90)
		for n in level.bonus_root.get_children():
			n.queue_free()


func test_w2_boss() -> void:
	await load_level("Boss2", func(): GameState.set_v("weapon", "sling"))
	await settle()
	SaveManager.reset_progress()
	var boss: Node2D = level.boss
	check(boss is Garabato, "el jefe es Garabato")
	place(12, 14)
	await frames(5)
	check(level.fight_started, "empieza el combate")
	check(GameState.get_v("bossName") == "Garabato", "la barra muestra a Garabato")
	await frames(120)
	check(boss.fsm.current == "IDLE" and not boss.invulnerable, "tras la entrada es vulnerable")
	check(absf(boss.position.y - 224) < 1, "Garabato está sobre el suelo de la arena")
	var seen := {}
	level.player.max_hp = 99
	level.player.hp = 99
	var guard := 0
	var prev_state := ""
	while not boss.is_defeated() and guard < 20000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		# un golpe de tirachinas en cada ventana de descanso
		var entered_rest: bool = boss.fsm.current == "REST" and prev_state != "REST"
		prev_state = boss.fsm.current
		if entered_rest:
			var p: Projectile = level.spawn_projectile("player", {"x": boss.position.x, "y": boss.position.y - 25, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
			p.weapon = Assets.weapon("sling")
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(boss.is_defeated(), "Garabato es derrotado (golpeándole sólo en sus descansos)")
	check(seen.has("phase2") and seen.has("phase3"), "pasa por las tres fases")
	for s in ["SHOOT", "SPLASH", "REST", "PHASE_CHANGE", "SWIRL", "ORBIT", "RAIN", "BIG_SWIRL", "PAINT_FLOOR"]:
		check(seen.has(s), "usa el ataque %s" % s)
	# la protagonista se aparta para ver caer la estrella
	level.player.position.x = 20 * C.TILE
	await frames(260)
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(star.size() == 1 or GameState.get_v("specialStar") == true, "suelta la estrella especial")
	if star.size() == 1:
		level.player.position = star[0].position + Vector2(0, 10)
	await frames(60)
	check(GameState.get_v("specialStar") == true, "se recoge la estrella especial")
	if true:
		check(level.portal != null, "se abre el portal al Mundo 3")
		if level.portal:
			level.player.position = level.portal.position
			await frames(5)
			check(SaveManager.is_world_completed(2), "el Mundo 2 queda guardado como completado")
			check(SaveManager.unlocked_world() == 3, "el Mundo 3 queda desbloqueado")
	SaveManager.reset_progress()


func test_w2_progression() -> void:
	SaveManager.reset_progress()
	check(not WorldRegistry.is_playable(2), "el Mundo 2 empieza bloqueado")
	SaveManager.mark_world_completed(1, 10, 144)
	check(WorldRegistry.is_playable(2), "completar el Mundo 1 desbloquea el Mundo 2")
	var key := WorldRegistry.start_run(2)
	check(key == "World2" and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 2 con las tres armas")
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 1, "stars": 1, "total": 2}
	add_child(v)
	await frames(2)
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(list.buttons[0].label.text == "Ir al Mundo 2", "la victoria del Mundo 1 ofrece ir al Mundo 2")
	v.queue_free()
	var v2: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 2, "stars": 1, "total": 2, "magic": ["red"], "magicTotal": 3}
	add_child(v2)
	await frames(2)
	check(v2.world_id == 2, "pantalla de victoria del Mundo 2")
	v2.queue_free()
	SaveManager.reset_progress()
