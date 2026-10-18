extends Node
## Pruebas automáticas (headless). Uso desde la carpeta del repositorio:
##   godot --headless --path godot --fixed-fps 60 res://tests/Tests.tscn
## Cada prueba crea su propio nivel, simula fotogramas de física con controles programados
## y comprueba el resultado. Los valores esperados salen del código Phaser (tuning.js,
## weaponDefs.js, enemyDefs.js, world1.js, Nubarron.js).

var passed := 0
var failed := 0
var current := ""
var level: Level


func _ready() -> void:
	SaveManager.save_path = "user://test_save.json"
	SaveManager.load_state()
	AudioManager.sfx_on = false # sin persistir: no toca el guardado del usuario
	var tests := [
		"test_data_parity", "test_resources", "test_save_manager",
		"test_player_rests_on_ground", "test_walk_and_run_speeds", "test_jump_height_and_variable_jump",
		"test_coyote_time", "test_jump_buffer", "test_one_way_cloud", "test_moving_platform_carries",
		"test_crumble_platform", "test_bounce_pad", "test_bouncy_cloud", "test_wind_zone", "test_hazard_damage",
		"test_fall_respawn_checkpoint", "test_star_and_pickup", "test_weapons",
		"test_bubble_traps_and_star", "test_paint_and_sling_damage", "test_stomp", "test_scratch_ai",
		"test_spit_ai", "test_flea_ai", "test_enemy_spawner_distance", "test_boss_phases_and_victory",
		"test_menu_keyboard", "test_menu_art", "test_world_map", "test_pause_resume",
		# Mundo 2
		"test_w2_data", "test_w2_sprites", "test_w2_level_loads", "test_w2_paint", "test_w2_rulers",
		"test_w2_switch_and_temporary", "test_w2_hazards", "test_w2_magic_and_checkpoint",
		"test_w2_eraser", "test_w2_crayon", "test_w2_brush", "test_w2_weapons_vs_enemies",
		"test_w2_boss", "test_w2_progression",
		# Mundo 3
		"test_w3_data", "test_w3_sprites", "test_w3_level_loads", "test_w3_mechanics",
		"test_w3_enemies", "test_w3_boss", "test_w3_progression",
		# Mundo 4
		"test_w4_data", "test_w4_sprites", "test_w4_level_loads", "test_w4_layout", "test_w4_slopes",
		"test_w4_water", "test_w4_geyser_and_column", "test_w4_obstacles", "test_w4_enemies",
		"test_w4_weapons_vs_enemies", "test_w4_boss", "test_w4_boss_victory", "test_w4_progression",
		# Mundo 5
		"test_w5_data", "test_w5_sprites", "test_w5_level_loads", "test_w5_layout", "test_w5_slopes",
		"test_w5_platforms", "test_w5_slide", "test_w5_light_fall", "test_w5_falling_star", "test_w5_explosive_cloud",
		"test_w5_enemies", "test_w5_weapons_vs_enemies", "test_w5_boss", "test_w5_boss_victory", "test_w5_progression",
	]
	# "-- only=test_x,test_y" ejecuta sólo esas pruebas
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			tests = Array(a.substr(5).split(","))
	for t in tests:
		current = t
		var before := failed
		await call(t)
		if is_instance_valid(level):
			level.queue_free()
			level = null
			await get_tree().process_frame
		get_tree().paused = false
		print("%s %s" % ["OK  " if failed == before else "FALLO", t])
	print("\n[tests] %d comprobaciones correctas, %d fallidas" % [passed, failed])
	for f in ["user://test_save.json", "user://test_save.json.bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.load_state()
	get_tree().quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ utilidades
func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  [%s] %s" % [current, msg])


func near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (obtenido %.2f, esperado %.2f ± %.2f)" % [msg, a, b, tol])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func load_level(scene_key := "World1", setup := Callable()) -> Level:
	if is_instance_valid(level):
		level.queue_free()
		await get_tree().process_frame
	var world_id := int(scene_key.right(1)) if scene_key.right(1).is_valid_int() else 1
	WorldRegistry.start_run(world_id)
	if setup.is_valid():
		setup.call()
	level = load(Router.SCENES[scene_key]).instantiate()
	add_child(level)
	level.controls.scripted = true
	await frames(2)
	return level


func place(tx: float, ty: float) -> void:
	level.player.position = Vector2(tx * C.TILE + 8, ty * C.TILE)
	level.player.velocity = Vector2.ZERO
	level.camera.snap_to_target()


func hold(actions: Array) -> void:
	level.controls.script_held.clear()
	for a in actions:
		level.controls.script_held[a] = true


func press(action: String) -> void:
	level.controls.script_pressed[action] = true


func settle() -> void:
	await frames(20)


# ---------------------------------------------------------------------- datos
func test_data_parity() -> void:
	var w: Dictionary = C.load_json("res://data/worlds/world1.json")
	var b: Dictionary = C.load_json("res://data/worlds/world1_boss.json")
	check(w.widthTiles == 475 and w.heightTiles == 25, "Mundo 1 mide 475x25 teselas (7.600 px)")
	check(w.progress.total == 8000, "recorrido total de 8.000 px")
	check(w.sections.size() == 5 and w.sections[4].from == 6500, "cinco secciones A-E")
	check(w.terrain.size() == 16, "16 rectángulos de terreno")
	check(w.stars.size() == 138, "138 estrellas en el mapa")
	check(w.enemies.size() == 13, "13 enemigos")
	check(w.checkpoints.size() == 2 and w.pickups.size() == 3, "2 checkpoints y 3 armas")
	check(w.clouds.size() == 9 and w.bridges.size() == 4 and w.movers.size() == 2 and w.crumbles.size() == 4, "nubes, puentes, móviles y de vapor")
	check(w.pads.size() == 1 and w.winds.size() == 1 and w.hazards.size() == 2, "cojín, corriente y burbujas con pinchos")
	check(b.widthTiles == 40 and b.boss.floorY == 224 and b.stars.size() == 6, "arena del jefe 40x17 con 6 estrellas")
	var bubble := Assets.weapon("bubble")
	var paint := Assets.weapon("paint")
	var sling := Assets.weapon("sling")
	check(bubble.cooldown == 230 and bubble.proj_speed == 185 and bubble.effect == "trap" and bubble.boss_damage == 1, "lanzaburbujas")
	check(paint.cooldown == 380 and paint.proj_speed == 255 and paint.damage == 1 and paint.boss_damage == 2, "lanzapintura")
	check(sling.cooldown == 650 and sling.proj_gravity == 520 and sling.damage == 2 and sling.boss_damage == 3 and sling.recoil == 160, "tirachinas")
	check(Assets.enemy_def("scratch").hp == 2 and Assets.enemy_def("spit").hp == 3 and Assets.enemy_def("flea").hp == 3, "vida de los monstruos")
	check(Assets.player_tuning().walkSpeed == 95 and Assets.player_tuning().jumpVelocity == -335, "ajustes de la protagonista")


func test_resources() -> void:
	var p := Assets.sprite_frames("player")
	for a in ["idle", "blink", "walk", "run", "jump", "fall", "hurt", "victory", "bubble", "paint", "sling"]:
		check(p.has_animation(a), "animación player_%s" % a)
	check(p.get_frame_count("walk") == 6 and p.get_animation_speed("run") == 15, "caminar 6 fotogramas, correr a 15 fps")
	check(p.get_frame_texture("idle", 0).get_size() == Vector2(42, 44), "celda 42x44 de la protagonista")
	var n := Assets.sprite_frames("nubarron")
	var unique := {}
	for a in n.get_animation_names():
		for i in n.get_frame_count(a):
			unique[n.get_frame_texture(a, i)] = true
	check(unique.size() == 26, "Nubarrón tiene 26 fotogramas (obtenidos %d)" % unique.size())
	for k in ["scratch", "spit", "flea"]:
		var e := Assets.sprite_frames(k)
		check(e.has_animation("attack") and e.has_animation("defeated"), "animaciones de %s" % k)
	check(Assets.tileset() != null, "TileSet del terreno")
	check(Assets.used_placeholders.is_empty(), "sin recursos provisionales (%s)" % str(Assets.used_placeholders.keys()))


func test_save_manager() -> void:
	SaveManager.reset_progress()
	check(not SaveManager.is_world_completed(1), "progreso borrado")
	SaveManager.mark_world_completed(1, 100, 144, true, 300000)
	SaveManager.mark_world_completed(1, 80, 144, false, 400000)
	SaveManager.load_state()
	var w := SaveManager.get_world(1)
	check(w.completed and w.bestStars == 100 and w.specialStar and w.bestTime == 300000, "mejor marca conservada tras recargar")
	check(SaveManager.unlocked_world() == 2, "se desbloquea el Mundo 2")
	# archivo mal formado -> valores por defecto sin fallar
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string("{esto no es json")
	f.close()
	SaveManager.load_state()
	check(not SaveManager.is_world_completed(1) and SaveManager.get_setting("music") == true, "archivo dañado -> valores por defecto")
	SaveManager.reset_progress()


# ------------------------------------------------------------------ protagonista
func test_player_rests_on_ground() -> void:
	await load_level()
	await settle()
	check(level.player.grounded, "la protagonista se apoya en el suelo al empezar")
	# como en Phaser: el origen del sprite queda 1 px por debajo de la hitbox (footPadding)
	near(level.player.position.y, 321, 0.5, "hitbox apoyada en la superficie y=320")


func test_walk_and_run_speeds() -> void:
	await load_level()
	await settle()
	hold(["move_right"])
	await frames(30)
	near(level.player.velocity.x, 95, 0.01, "velocidad al caminar")
	hold(["move_right", "run"])
	await frames(30)
	near(level.player.velocity.x, 150, 0.01, "velocidad al correr")
	hold([])
	await frames(30)
	near(level.player.velocity.x, 0, 0.01, "desaceleración hasta parar")


func _jump_apex(hold_frames: int) -> float:
	var start_y := level.player.position.y
	press("jump")
	hold(["jump"])
	var min_y := start_y
	for i in 90:
		if i == hold_frames:
			hold([])
		await frames(1)
		min_y = minf(min_y, level.player.position.y)
	return start_y - min_y


func test_jump_height_and_variable_jump() -> void:
	await load_level()
	await settle()
	var full := await _jump_apex(60)
	# v0=335, g=900 -> 335²/(2·900) = 62 px (Arcade integra igual: semi-implícito a 60 Hz)
	near(full, 61.5, 2.0, "altura del salto completo")
	await settle()
	var short := await _jump_apex(3)
	check(short < full * 0.5, "salto variable: soltar pronto salta menos (%.1f px)" % short)


func test_coyote_time() -> void:
	await load_level()
	await settle()
	# caminar fuera del borde del terreno x=0..29 (hueco en 30-32)
	place(28, 20)
	await settle()
	hold(["move_right"])
	while level.player.grounded:
		await frames(1)
	await frames(3) # 50 ms en el aire: dentro de los 100 ms de coyote time
	press("jump")
	hold(["move_right", "jump"])
	await frames(2)
	check(level.player.velocity.y < -250, "se puede saltar justo después de dejar el borde")
	await load_level()
	await settle()
	place(28, 20)
	await settle()
	hold(["move_right"])
	while level.player.grounded:
		await frames(1)
	await frames(9) # 150 ms: fuera del coyote time
	press("jump")
	hold(["move_right", "jump"])
	await frames(2)
	check(level.player.velocity.y > 0, "pasado el coyote time ya no salta")


func test_jump_buffer() -> void:
	await load_level()
	await settle()
	level.player.position.y -= 40
	# pulsar el salto poco antes de aterrizar (buffer de 120 ms)
	while level.player.position.y < 320 - 8:
		await frames(1)
	press("jump")
	hold(["jump"])
	var jumped := false
	for i in 10:
		await frames(1)
		if level.player.velocity.y < -250:
			jumped = true
	check(jumped, "el salto pulsado justo antes de aterrizar se ejecuta")


func test_one_way_cloud() -> void:
	await load_level()
	await settle()
	# nube pequeña en x=85, superficie y=18 (288 px); suelo en y=20 (320 px)
	place(84.5, 20)
	await settle()
	press("jump")
	hold(["jump"])
	await frames(70)
	near(level.player.position.y, 288, 1.0, "atraviesa la nube desde abajo y aterriza encima")
	check(level.player.grounded, "apoyada sobre la nube")
	hold([])


func test_moving_platform_carries() -> void:
	await load_level()
	await settle()
	var mover: MovingPlatform = level.level_objects.movers[0]
	level.player.position = Vector2(mover.position.x, mover.position.y - 10)
	level.camera.snap_to_target()
	await frames(20)
	var dx0 := level.player.position.x - mover.position.x
	var x0 := mover.position.x
	await frames(60)
	check(absf(mover.position.x - x0) > 20, "la plataforma se mueve")
	near(level.player.position.x - mover.position.x, dx0, 2.0, "la protagonista viaja sobre la plataforma")
	check(level.player.grounded, "sigue apoyada")


func test_crumble_platform() -> void:
	await load_level()
	await settle()
	var c: CrumblePlatform = level.level_objects.crumbles[0]
	level.player.position = Vector2(c.position.x, c.position.y - 6)
	level.camera.snap_to_target()
	var stepped := false
	for i in 20:
		await frames(1)
		stepped = stepped or c.crumbling
		if c.crumbling:
			break
	check(stepped, "la nube de vapor empieza a deshacerse al pisarla")
	await frames(36)
	check(c.shape.disabled, "a los 560 ms deja de sostener")
	await frames(30)
	check(not level.player.grounded or level.player.position.y > c.position.y + 10, "la protagonista cae")
	await frames(200)
	check(not c.shape.disabled and not c.crumbling, "reaparece al rato")


func test_bounce_pad() -> void:
	await load_level()
	await settle()
	level.player.position = Vector2(360 * C.TILE + 8, 19 * C.TILE - 30)
	var min_vy := 0.0
	for i in 40:
		await frames(1)
		min_vy = minf(min_vy, level.player.velocity.y)
	check(min_vy <= -580, "el cojín lanza hacia arriba con -600 (%.0f)" % min_vy)


func test_bouncy_cloud() -> void:
	await load_level()
	await settle()
	level.player.position = Vector2(374 * C.TILE, 21 * C.TILE - 30)
	var min_vy := 0.0
	for i in 40:
		await frames(1)
		min_vy = minf(min_vy, level.player.velocity.y)
	check(min_vy <= -520, "la nube elástica rebota con -540 (%.0f)" % min_vy)


func test_wind_zone() -> void:
	await load_level()
	await settle()
	level.player.position = Vector2(326 * C.TILE, 22 * C.TILE)
	level.camera.snap_to_target()
	await frames(30)
	near(level.player.velocity.y, -190 + 15, 16, "la corriente eleva hasta 190 px/s")


func test_hazard_damage() -> void:
	await load_level()
	await settle()
	var hz: Hazard = level.level_objects.objects.get_children().filter(func(n): return n is Hazard)[0]
	level.player.position = hz.position + Vector2(0, 14)
	level.player.gravity_enabled = false
	await frames(3)
	level.player.gravity_enabled = true
	check(level.player.hp == 2, "la burbuja con pinchos quita un corazón")
	check(level.player.is_invulnerable(), "invulnerable tras el golpe")


func test_fall_respawn_checkpoint() -> void:
	await load_level()
	await settle()
	place(138, 19)
	await frames(10)
	var cp: Variant = GameState.get_v("checkpoint")
	check(cp is Dictionary and cp.index == 0, "se activa el checkpoint 1")
	place(161, 21) # hueco 160-162
	await frames(80)
	check(level.player.hp == 2, "caer al vacío quita un corazón")
	near(level.player.position.x, 138 * C.TILE + 8, 1.0, "reaparece en la bandera")


func test_star_and_pickup() -> void:
	await load_level()
	await settle()
	place(6, 19)
	await frames(20)
	check(int(GameState.get_v("stars")) >= 1, "recoge estrellas")
	check(GameState.get_v("collectedStars").size() >= 1, "las estrellas recogidas se recuerdan")
	place(78, 20)
	await frames(5)
	check("bubble" in GameState.get_v("weaponsOwned"), "recoge el lanzaburbujas")
	check(GameState.get_v("weapon") == "bubble", "el arma recogida queda seleccionada")


func _with_weapons() -> void:
	GameState.set_v("weaponsOwned", ["bubble", "paint", "sling"])
	GameState.set_v("weapon", "bubble")


func test_weapons() -> void:
	await load_level("World1", _with_weapons)
	await settle()
	press("fire")
	await frames(2)
	var p: Projectile = level.player_projectiles.get_child(0)
	check(p.kind == "bubble" and absf(p.velocity.x - 185) < 0.1, "burbuja a 185 px/s")
	press("switch_weapon")
	await frames(20)
	check(level.weapons.current_id == "paint", "K cambia a la pintura")
	press("fire")
	await frames(2)
	var pp: Projectile = level.player_projectiles.get_children().filter(func(n): return n.kind == "paint")[0]
	check(absf(pp.velocity.x - 255) < 0.1, "pintura a 255 px/s")
	press("switch_weapon")
	await frames(30)
	press("fire")
	await frames(2)
	var sp: Projectile = level.player_projectiles.get_children().filter(func(n): return n.kind == "sling")[0]
	var vy0 := sp.velocity.y
	await frames(30)
	check(vy0 < -100 and sp.velocity.y > vy0 + 200, "tirachinas en parábola (vy %.0f -> %.0f)" % [vy0, sp.velocity.y])
	# cadencia: dos disparos seguidos del tirachinas están separados por 650 ms
	var count := level.player_projectiles.get_children().filter(func(n): return n.kind == "sling" and n.active).size()
	press("fire")
	await frames(2)
	var count2 := level.player_projectiles.get_children().filter(func(n): return n.kind == "sling" and n.active).size()
	check(count2 == count, "respeta el tiempo de recarga")
	# disparo hacia arriba
	await frames(40)
	hold(["aim_up"])
	press("fire")
	await frames(2)
	var up: Array = level.player_projectiles.get_children().filter(func(n): return n.active and n.velocity.y < -150)
	check(up.size() > 0, "W + J dispara hacia arriba")


func _spawn_enemy(type: String, tx: float, ty: float) -> Enemy:
	var e: Enemy = EnemySpawner.SCENES[type].instantiate()
	e.setup(level, {"id": "test:%s" % type, "type": type, "x": tx * C.TILE + 8, "y": ty * C.TILE, "patrol": [(tx - 3) * C.TILE, (tx + 3) * C.TILE]})
	level.enemies_root.add_child(e)
	return e


func _clear_spawner() -> void:
	level.spawner.pending = []
	level.spawner.reset_active()


func test_bubble_traps_and_star() -> void:
	await load_level("World1", _with_weapons)
	await settle()
	_clear_spawner()
	place(60, 20)
	var e := _spawn_enemy("scratch", 66, 20)
	e.def = e.def.duplicate()
	e.def.detect_range = 0 # que no se mueva durante la prueba
	await frames(5)
	press("fire")
	await frames(30)
	check(e.is_trapped(), "la burbuja atrapa al monstruo")
	# tocarlo lo convierte en estrella
	level.player.position.x = e.position.x
	await frames(5)
	check(not is_instance_valid(e) or not e.is_alive(), "al tocarlo se convierte en estrella")
	check(level.bonus_root.get_child_count() == 1, "aparece una estrella extra")
	var stars_before := int(GameState.get_v("stars"))
	var bonus: Star = level.bonus_root.get_child(0)
	var collected := false
	# la protagonista sigue ahí: la recoge en cuanto se puede (350 ms) o al caer
	for i in 120:
		await frames(1)
		if not is_instance_valid(bonus) or not bonus.active:
			collected = true
			break
		level.player.position.x = bonus.position.x
	check(collected, "la estrella extra se recoge")
	check(int(GameState.get_v("stars")) > stars_before, "suma al contador de estrellas")


func test_paint_and_sling_damage() -> void:
	await load_level("World1", func():
		_with_weapons()
		GameState.set_v("weapon", "paint"))
	await settle()
	_clear_spawner()
	place(60, 20)
	var e := _spawn_enemy("spit", 68, 20)
	e.def = e.def.duplicate()
	e.def.detect_range = 0
	await frames(5)
	press("fire")
	await frames(40)
	check(e.hp == 2, "la pintura quita 1 punto (vida %d)" % e.hp)
	check(e.now < e.painted_until, "el monstruo queda pintado")
	check(e.speed_factor() == 0.55, "la pintura ralentiza")
	await frames(30)
	press("switch_weapon")
	await frames(2)
	check(level.weapons.current_id == "sling", "cambia al tirachinas")
	press("fire")
	await frames(60)
	check(not e.is_alive(), "el tirachinas (2 de daño) lo derrota (vida %d)" % e.hp)


func test_stomp() -> void:
	await load_level()
	await settle()
	_clear_spawner()
	var e := _spawn_enemy("scratch", 50, 20)
	await frames(5)
	level.player.position = Vector2(e.position.x, e.position.y - 40)
	level.player.velocity = Vector2(0, 150)
	await frames(15)
	check(e.hp == 1, "pisar quita 1 punto")
	check(level.player.hp == 3, "pisar no hace daño a la protagonista")


func test_scratch_ai() -> void:
	await load_level()
	await settle()
	_clear_spawner()
	place(40, 20)
	var e := _spawn_enemy("scratch", 52, 20)
	await frames(5)
	check(e.fsm.current == Enemy.IDLE or e.fsm.current == Enemy.PATROL, "empieza en reposo/patrulla")
	place(46, 20)
	await frames(5)
	check(e.fsm.current == Enemy.ALERT, "detecta a la protagonista a menos de 130 px")
	var saw_attack := false
	for i in 180:
		await frames(1)
		if e.fsm.current == Enemy.ATTACK:
			saw_attack = true
	check(saw_attack, "se acerca y ataca con el arañazo")
	check(level.player.hp < 3, "el arañazo hace daño")


func test_spit_ai() -> void:
	await load_level()
	await settle()
	_clear_spawner()
	place(204, 19)
	var e := _spawn_enemy("spit", 211, 19)
	var shots := 0
	for i in 200:
		await frames(1)
		for p in level.enemy_projectiles.get_children():
			if p.kind == "spit" and not p.has_meta("seen"):
				p.set_meta("seen", true)
				shots += 1
	check(shots >= 1, "Escupitín escupe gotas verdes (%d)" % shots)
	check(e.fsm.current in [Enemy.ALERT, Enemy.ATTACK], "mantiene la alerta")


func test_flea_ai() -> void:
	await load_level()
	await settle()
	_clear_spawner()
	place(347, 19)
	var e := _spawn_enemy("flea", 352, 19)
	var x0 := e.position.x
	var arc := false
	for i in 150:
		await frames(1)
		for p in level.enemy_projectiles.get_children():
			if p.kind == "flea" and p.velocity.y > 50:
				arc = true
	check(arc, "Pulgoso lanza pulgas en parábola")
	check(e.position.x > x0, "retrocede al estar cerca")


func test_enemy_spawner_distance() -> void:
	await load_level()
	await settle()
	check(level.enemies_root.get_child_count() == 0, "ningún enemigo activo lejos de la cámara")
	# aparece justo fuera del encuadre (nunca de golpe delante de la protagonista)
	place(33, 20)
	await frames(10)
	check(level.enemies_root.get_children().any(func(n): return n.spawn.id == "world1:e0"), "el primer Arañitas aparece al acercarse")
	place(300, 19)
	await frames(20)
	check(not level.enemies_root.get_children().any(func(n): return is_instance_valid(n) and not n.finished and n.spawn.id == "world1:e0"), "se retira al quedar lejos")


func test_boss_phases_and_victory() -> void:
	await load_level("Boss", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle()
	SaveManager.reset_progress()
	var boss: Nubarron = level.boss
	place(12, 14)
	await frames(5)
	check(level.fight_started, "empieza el combate al cruzar la puerta")
	check(level.terrain_solid_at(Vector2(5 * C.TILE + 8, 12 * C.TILE + 8)), "la puerta se cierra")
	check(GameState.get_v("bossVisible") == true and int(GameState.get_v("bossMaxHp")) == 40, "barra de vida de 40")
	await frames(110)
	check(boss.fsm.current == "IDLE" and not boss.invulnerable, "tras la entrada es vulnerable")
	var seen := {}
	level.player.hp = 99 # la prueba mide al jefe, no la supervivencia
	level.player.max_hp = 99
	var guard := 0
	while not boss.is_defeated() and guard < 6000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		if boss.fsm.current in ["IDLE", "REST"] and not boss.invulnerable and guard % 20 == 0:
			# golpe directo de tirachinas (3 de daño), como si acertara
			var p: Projectile = level.spawn_projectile("player", {"x": boss.position.x, "y": boss.position.y, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
			p.weapon = Assets.weapon("sling")
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(boss.is_defeated(), "Nubarrón es derrotado")
	check(seen.has("phase2") and seen.has("phase3"), "pasa por las fases 2 y 3")
	for s in ["WIND", "SHOOT", "REST", "PHASE_CHANGE"]:
		check(seen.has(s), "usa el estado %s" % s)
	check(seen.has("RAIN") or seen.has("SUMMON") or seen.has("DASH") or seen.has("TRIPLE"), "usa ataques de fase 2/3")
	await frames(200)
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(star.size() == 1, "suelta la estrella dorada especial")
	if star.size() == 1:
		level.player.position = star[0].position + Vector2(0, 10)
		await frames(60)
		check(GameState.get_v("specialStar") == true, "estrella especial recogida")
		check(level.portal != null, "se abre el portal")
		if level.portal:
			level.player.position = level.portal.position
			await frames(5)
			check(level.leaving and level.player.celebrating, "cruza el portal y celebra")
			check(SaveManager.is_world_completed(1), "el Mundo 1 queda guardado como completado")
	SaveManager.reset_progress()


func _action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func test_menu_art() -> void:
	SaveManager.reset_progress()
	SaveManager.mark_world_completed(1, 97, 144)
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	check(not menu.world_btns[1].locked and not menu.world_btns[2].locked and menu.world_btns[3].locked, "islas: Mundo 1 y 2 abiertos, Mundo 3 con candado")
	check(menu.world_btns[1].badge != null and menu.world_btns[1].badge.text == "97 estrellas", "el mundo completado muestra sus estrellas")
	var music_before := AudioManager.music_on
	menu.music_btn.activate()
	check(menu.music_btn.label.text == ("NO" if music_before else "SÍ"), "el recuadro de música escribe SÍ/NO según la configuración")
	menu.music_btn.activate()
	check(AudioManager.music_on == music_before and menu.music_btn.label.text == ("SÍ" if music_before else "NO"), "y vuelve a cambiar")
	menu.start_game(3)
	check(not menu.starting, "un mundo bloqueado no se abre")
	var menu_song: AudioStream = AudioManager._music_streams.get("menu")
	check(menu_song is AudioStreamMP3 and menu_song.loop and menu_song.get_length() > 10, "el menú suena con menu_principal.mp3 en bucle")
	check(AudioManager.current_track == "menu" and AudioManager._music.stream == menu_song, "la canción del menú es la pista actual")
	for track in ["world1", "boss"]:
		var song: AudioStream = AudioManager._music_streams.get(track)
		check(song is AudioStreamMP3 and song.loop and song.get_length() > 10, "la pista %s usa su mp3 en bucle" % track)
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


func test_world_map() -> void:
	SaveManager.reset_progress()
	var wm: Control = load(Router.SCENES.WorldMap).instantiate()
	add_child(wm)
	await frames(2)
	var list: MenuList = wm.list
	check(list.buttons.size() == 9 and list.index == 0, "mapa con ocho mundos y «Volver»; empieza en el Mundo 1")
	check(wm.world_btns[2].locked and wm.world_btns[5].locked and not wm.world_btns[1].locked, "sólo el Mundo 1 abierto al empezar")
	check(wm.info.text.begins_with("Mundo 1: Nubes de Algodón"), "la barra describe el mundo seleccionado")
	await _action("menu_down")
	check(list.index == 4, "abajo baja de fila (Mundo 5)")
	await frames(1)
	check(wm.info.text.ends_with("Completa el Mundo 4"), "el Mundo 5 (implementado) explica cómo abrirlo")
	await _action("move_right")
	check(list.index == 5, "derecha avanza al Mundo 6")
	await frames(1)
	check(wm.info.text.ends_with("Próximamente"), "los mundos sin implementar dicen «Próximamente»")
	await _action("menu_down")
	check(list.index == 8, "saliendo de la rejilla se llega a «Volver»")
	await _action("menu_down")
	check(list.index == 0, "y desde «Volver» se entra por la primera fila")
	await _action("move_right")
	await frames(1)
	check(wm.info.text.contains("Completa el Mundo 1"), "un mundo bloqueado explica cómo abrirlo")
	wm.queue_free()
	await get_tree().process_frame
	SaveManager.mark_world_completed(1, 10, 144); SaveManager.mark_world_completed(2, 10, 144)
	var wm2: Control = load(Router.SCENES.WorldMap).instantiate()
	add_child(wm2)
	await frames(2)
	check(wm2.list.index == 2 and not wm2.world_btns[3].locked, "con progreso empieza en el mundo más avanzado")
	wm2.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


func test_menu_keyboard() -> void:
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var list: MenuList = menu.get_children().filter(func(n): return n is MenuList)[0]
	check(list.index == 0 and list.buttons[0].selected, "el menú empieza en Mundo 1")
	await _action("menu_down")
	check(list.index == 1, "flecha abajo selecciona la opción siguiente (Mundo 2)")
	await _action("menu_down")
	check(list.index == 2, "y después Mundo 3")
	await _action("menu_down")
	check(list.index == 3, "y después Música")
	var music_before := AudioManager.music_on
	await _action("menu_accept")
	check(AudioManager.music_on != music_before, "Enter activa la opción (música)")
	await _action("menu_accept")
	check(AudioManager.music_on == music_before, "y vuelve a cambiarla")
	await _action("menu_up")
	check(list.index == 2, "flecha arriba vuelve a la opción anterior")
	list.buttons[3].hovered.emit(list.buttons[3])
	check(list.index == 3, "pasar el ratón por encima selecciona")
	menu.queue_free()
	await get_tree().process_frame


func test_pause_resume() -> void:
	await load_level()
	await settle()
	level.pause_game()
	await get_tree().process_frame
	check(get_tree().paused, "la pausa detiene el juego")
	var t := level.now
	await get_tree().process_frame
	await get_tree().process_frame
	check(level.now == t, "el reloj del nivel no avanza en pausa")
	await _action("pause")
	check(not get_tree().paused, "Esc/P reanuda")
	await frames(3)
	check(not get_tree().paused, "la misma pulsación no vuelve a pausar")
	check(level.now > t, "el reloj vuelve a avanzar")


# ======================================================================= MUNDO 2
func test_w2_data() -> void:
	var w: Dictionary = C.load_json("res://data/world2/world2.json")
	var b: Dictionary = C.load_json("res://data/world2/world2_boss.json")
	check(w.progress.total == 9000, "recorrido total de 9.000 px")
	near(float(w.widthTiles * 16) + float(b.widthTiles * 16) * float(b.progress.scale), 9000, 1, "nivel + arena = 9.000 px")
	var froms: Array = w.sections.map(func(x): return int(x.from))
	check(froms == [0, 1500, 3300, 5200, 7300], "cinco secciones A-E en 0/1.500/3.300/5.200/7.300")
	check(w.magicCrayons.size() == 3, "tres crayones mágicos (rojo, azul, amarillo)")
	var types := {}
	for e in w.enemies:
		types[e.type] = true
	check(types.keys().size() == 3 and types.has("eraser") and types.has("crayon") and types.has("brush"), "los tres enemigos del Mundo 2")
	check(w.checkpoints.size() == 2, "dos checkpoints")
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
	place(146, 19)
	await frames(10)
	var cp: Variant = GameState.get_v("checkpoint")
	check(cp is Dictionary and cp.index == 0 and cp.scene == "World2", "checkpoint 1 del Mundo 2")
	place(357, 19)
	await frames(10)
	check(GameState.get_v("checkpoint").index == 1, "checkpoint 2 del Mundo 2")
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


# ======================================================================= MUNDO 3
func test_w3_data() -> void:
	var w: Dictionary = C.load_json("res://data/world3/world3.json")
	var b: Dictionary = C.load_json("res://data/world3/world3_boss.json")
	check(w.progress.total == 10000 and w.widthTiles * 16 + b.widthTiles * 16 == 10000, "recorrido total de 10.000 px")
	check(w.sections.map(func(x): return int(x.from)) == [0,1700,3500,5500,7800], "cinco secciones del Mundo 3")
	check(w.checkpoints.size() == 2 and w.dreamCollectibles.filter(func(x): return x.kind == "moon").size() == 3, "dos checkpoints y tres lunas mágicas")
	check(w.swings.size() >= 4 and w.pads.size() >= 4 and w.yarnRollers.size() >= 4 and w.sleepClouds.size() >= 4, "mecánicas exclusivas distribuidas")
	var types := {}
	for e in w.enemies: types[e.type] = true
	check(types.has("rabbit") and types.has("wool") and types.has("pillow"), "los tres enemigos oficiales")
	check(String(b.boss.scene).ends_with("ReySieston.tscn"), "arena con Rey Siestón")
	var manifest: Dictionary = C.load_json("res://data/world3/world3_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "manifiesto de recursos sin pendientes")

func test_w3_sprites() -> void:
	var expected := {"rabbit":{"idle":4,"walk":5,"jump":3,"attack":3,"hurt":2,"defeated":3},"wool":{"idle":4,"walk":4,"jump":3,"attack":3,"hurt":2,"defeated":3},"pillow":{"idle":4,"walk":4,"dash":3,"attack":3,"hurt":2,"defeated":3},"sieston":{"idle":4,"move":6,"pillow":4,"jump":3,"special":3,"hurt":2,"defeated":3}}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		for a in expected[key]: check(sf.get_frame_count(a) == expected[key][a], "%s/%s conserva sus fotogramas" % [key,a])
	check(Assets.tileset("world3_tiles") != null, "TileSet nativo del Mundo 3")
	for atlas in ["world3_objects","world3_bg","w3_fx"]: check(Assets.atlases.has(atlas), "atlas %s cargado" % atlas)

func test_w3_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World3")
	await settle()
	check(level.data.key == "world3" and level.player.grounded, "Mundo 3 carga con Alice sobre terreno real")
	check(Assets.used_placeholders.is_empty(), "Mundo 3 no usa marcadores provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(level.level_objects.movers.size() == 9, "cinco plataformas móviles y cuatro cuerdas oscilantes")
	check(GameState.get_v("weaponsOwned").size() == 3, "reutiliza las tres armas")

func test_w3_mechanics() -> void:
	await load_level("World3")
	await settle(); _clear_spawner()
	var pillow_pad: BouncePad = level.level_objects.objects.get_children().filter(func(n): return n is BouncePad)[0]
	level.player.position = pillow_pad.position + Vector2(0,-4); level.player.velocity.y = 80
	await frames(3)
	check(level.player.velocity.y < -400, "almohada elástica impulsa a Alice")
	var swing: SwingPlatform = level.level_objects.movers.filter(func(n): return n is SwingPlatform)[0]
	var quarter := swing.duration / 4.0
	check(swing.target_at(quarter).distance_to(swing.rest) > 20, "cuerda oscilante define un arco estable")
	check(swing.target_at(quarter).y < swing.rest.y, "el asiento sube en los extremos (cuelga bajo el anclaje)")
	check(swing.rest.y - swing.pivot.y > 40 and swing.rope.points.size() == 2, "el asiento cuelga de una cuerda visible")
	check(swing.rest.y + 3 - level.player.position.y > -64, "las cuerdas se alcanzan de un salto desde el suelo")
	var yarn: RollingYarn = level.level_objects.objects.get_children().filter(func(n): return n is RollingYarn)[0]
	var x0 := yarn.position.x; await frames(30)
	check(absf(yarn.position.x-x0)>10, "ovillo rodante se desplaza")
	var cloud: SleepCloud = level.level_objects.objects.get_children().filter(func(n): return n is SleepCloud)[0]
	cloud.apply(level.player)
	check(level.player.sleepy_until > level.now and not level.player.frozen, "nube de sueño ralentiza sin quitar control")
	var button: MagicButton = level.level_objects.objects.get_children().filter(func(n): return n is MagicButton)[0]
	var target: MovingPlatform = level.level_objects.movers[4]
	check(not target.active and target.visible and target.modulate.a < 0.5, "mecanismo empieza dormido (translúcido)")
	button.trigger(); await frames(1)
	check(target.active and target.visible, "botón mágico activa la plataforma por señal")
	check(target.start.y + target.delta_px.y < 12 * C.TILE, "el ascensor del botón llega a lo alto del muro")

func test_w3_enemies() -> void:
	await load_level("World3")
	await settle(); _clear_spawner()
	for type in ["rabbit","wool","pillow"]:
		var scene: PackedScene = EnemySpawner.SCENES[type]
		var e: Enemy = scene.instantiate()
		e.setup(level,{"id":"test_"+type,"x":level.player.position.x+70,"y":level.player.position.y,"patrol":[level.player.position.x+20,level.player.position.x+120]})
		level.enemies_root.add_child(e); await frames(2)
		check(e.def != null and e.hp > 0 and e.is_alive(), "%s usa Enemy y recibe definición" % type)
		e.fsm.set_state(Enemy.ATTACK); await frames(35)
		check(e.fsm.current == Enemy.ATTACK or e.fsm.current == Enemy.ALERT, "%s ejecuta ataque con anticipación" % type)
		if e is RabbitMonster:
			check(e.jumps_left >= 0 and e.timers._items.size() < 12, "el conejito no acumula saltos mientras se agacha")
		if e is WoolMonster:
			check(e.rotation == 0.0, "el ovillo no gira su hitbox")
		e.queue_free(); await get_tree().process_frame
	# la almohada vuela: patrulla sin suelo y no cae tras escapar de la burbuja
	var pillow: Enemy = EnemySpawner.SCENES.pillow.instantiate()
	var py := level.player.position.y - 120
	pillow.setup(level, {"id": "test_pillow_fly", "x": level.player.position.x + 260, "y": py, "patrol": [level.player.position.x + 200, level.player.position.x + 320]})
	level.enemies_root.add_child(pillow); await frames(2)
	pillow.fsm.set_state(Enemy.PATROL); await frames(40)
	check(absf(pillow.position.y - py) < 16 and absf(pillow.velocity.x) > 1, "la almohada patrulla en el aire")
	pillow.fsm.set_state(Enemy.TRAPPED); await frames(2)
	pillow.trap_until = level.now; await frames(30)
	check(not pillow.gravity_enabled and pillow.position.y < py + 16, "la almohada sigue volando tras la burbuja")
	pillow.queue_free(); await get_tree().process_frame
	# todos los monstruos de suelo aparecen sobre terreno real (no dentro ni sobre un hueco)
	var bad: Array = []
	for d in level.data.enemies:
		if d.type == "pillow":
			continue
		var x := float(d.x) * C.TILE + 8
		var y := float(d.y) * C.TILE
		if not level.terrain_solid_at(Vector2(x, y + 4)) or level.terrain_solid_at(Vector2(x, y - 4)):
			bad.append("%s@%d" % [d.type, d.x])
	check(bad.is_empty(), "monstruos colocados sobre el suelo (%s)" % str(bad))

func test_w3_boss() -> void:
	await load_level("Boss3", func(): GameState.set_v("weapon","sling"))
	await settle(); place(12,14); await frames(130)
	var boss: ReySieston = level.boss
	check(boss != null and boss.max_hp == 50 and not boss.invulnerable, "Rey Siestón entra vulnerable con 50 HP")
	var p: Projectile = level.spawn_projectile("player",{"x":boss.position.x,"y":boss.position.y-20,"vx":0,"vy":0,"kind":"sling","frame":"pellet","lifespan":100})
	p.weapon=Assets.weapon("sling"); boss.hp=34; boss.hit_by(p)
	check(boss.phase == 2, "cambia a fase 2 al 65%")
	boss.invulnerable=false; boss.hp=16; boss.hit_by(p)
	check(boss.phase == 3, "cambia a fase 3 al 30%")
	boss.invulnerable=false; boss.hp=1; boss.hit_by(p)
	check(boss.is_defeated(), "puede ser derrotado y entra en sueño final")

	# derrotado en pleno salto: sigue dormido, en el suelo y sin lanzar ondas
	await load_level("Boss3", func(): GameState.set_v("weapon","sling"))
	await settle(); place(12,14); await frames(130)
	boss = level.boss
	boss.fsm.set_state("HOP"); await frames(45)
	var waves := func() -> int:
		return level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == "cotton").size()
	var waves_before: int = waves.call()
	var p2: Projectile = level.spawn_projectile("player",{"x":boss.position.x,"y":boss.position.y-20,"vx":0,"vy":0,"kind":"sling","frame":"pellet","lifespan":100})
	p2.weapon=Assets.weapon("sling")
	boss.invulnerable=false; boss.hp=1; boss.hit_by(p2)
	await frames(70)
	check(boss.is_defeated() and is_equal_approx(boss.position.y, boss.floor_y), "derrotado durante el salto: se queda dormido en el suelo")
	check(waves.call() <= waves_before, "y no lanza la onda del aterrizaje")

func test_w3_progression() -> void:
	SaveManager.reset_progress(); SaveManager.mark_world_completed(1,1,1); SaveManager.mark_world_completed(2,1,1)
	check(WorldRegistry.is_playable(3), "completar Mundo 2 desbloquea Mundo 3")
	var key := WorldRegistry.start_run(3)
	check(key == "World3" and GameState.get_v("dreamTotal") == 6, "nueva partida conserva sistemas y coleccionables de Mundo 3")
	SaveManager.mark_world_completed(3,10,138,true,1000,[],["moon_1","moon_2","moon_3"])
	check(SaveManager.unlocked_world() == 4 and SaveManager.is_world_completed(3), "victoria guarda el Mundo 3 y desbloquea Mundo 4")
	check(SaveManager.get_world(3).dreamCollectibles.size() == 3, "lunas mágicas persistidas")
	SaveManager.reset_progress()


# ======================================================================= MUNDO 4
func _w4_objects(cls: Variant) -> Array:
	return level.level_objects.objects.get_children().filter(func(n): return is_instance_of(n, cls))


func test_w4_data() -> void:
	var w: Dictionary = C.load_json("res://data/world4/world4.json")
	var b: Dictionary = C.load_json("res://data/world4/world4_boss.json")
	check(w.progress.total == 10000 and w.widthTiles * 16 + b.widthTiles * 16 == 10000, "recorrido total de 10.000 px")
	check(w.sections.map(func(x): return int(x.from)) == [0, 1800, 3600, 5600, 7900], "cinco secciones del Mundo 4")
	check(w.checkpoints.size() == 2, "dos checkpoints")
	check(w.dreamCollectibles.filter(func(x): return x.kind == "shell").size() == 3, "tres conchas token principales")
	for k in ["starfish", "rainbow", "duck"]:
		check(w.dreamCollectibles.any(func(x): return x.kind == k), "coleccionable temático %s" % k)
	check(w.waters.size() >= 4 and w.geysers.size() >= 2 and w.bubbleColumns.size() >= 3, "agua, géiseres y columnas de burbujas")
	check(w.spongeRollers.size() >= 3 and w.soaps.size() >= 1 and w.paints.any(func(p): return p.color == "foam"), "rodillos, jabones y espuma resbaladiza")
	check(w.waters.any(func(x): return x.h >= 6), "un tramo submarino hondo")
	check(w.crumbles.all(func(c): return c.get("pop", false)), "las burbujas frágiles revientan")
	var types := {}
	for e in w.enemies: types[e.type] = true
	check(types.has("bubble_fish") and types.has("sponge_crab") and types.has("pompa"), "los tres enemigos oficiales")
	check(String(b.boss.scene).ends_with("ReyPatoburbuja.tscn"), "arena con Rey Patoburbuja")
	var manifest: Dictionary = C.load_json("res://data/world4/world4_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "manifiesto de recursos sin pendientes")
	for src in ["imagenes/word_4.png", "imagenes/tilesets_world_4.png", "imagenes/enemies_world_4.png", "imagenes/jefemundo4.png"]:
		check(manifest.resources.any(func(r): return r.get("source") == src), "usa la referencia oficial %s" % src)


func test_w4_sprites() -> void:
	var expected := {
		"bubble_fish": {"idle": 2, "walk": 3, "attack": 2, "hurt": 1, "defeated": 2},
		"sponge_crab": {"idle": 2, "walk": 3, "attack": 2, "hurt": 1, "defeated": 1},
		"pompa": {"idle": 2, "walk": 3, "attack": 2, "hurt": 1, "defeated": 1},
		"patoburbuja": {"idle": 4, "move": 6, "spit": 4, "wave": 4, "whirl": 4, "hurt": 2, "defeated": 3},
	}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		for a in expected[key]:
			check(sf.has_animation(a) and sf.get_frame_count(a) == expected[key][a], "%s/%s conserva sus fotogramas" % [key, a])
	check(Assets.tileset("world4_tiles") != null, "TileSet nativo del Mundo 4")
	for atlas in ["world4_objects", "world4_bg", "w4_fx"]:
		check(Assets.atlases.has(atlas), "atlas %s cargado" % atlas)
	# pixel art nítido: filtro nearest en todo el proyecto
	check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0, "texturas sin suavizado (nearest)")


func test_w4_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World4")
	await settle()
	check(level.data.key == "world4" and level.player.grounded, "Mundo 4 carga con Alice sobre terreno real")
	check(Assets.used_placeholders.is_empty(), "Mundo 4 no usa marcadores provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(GameState.get_v("weaponsOwned").size() == 3, "reutiliza las tres armas")
	check(level.level_objects.waters.size() == level.data.waters.size(), "crea los tramos de agua")
	check(_w4_objects(BubbleGeyser).size() == level.data.geysers.size() and _w4_objects(BubbleColumn).size() == level.data.bubbleColumns.size(), "crea géiseres y columnas")
	check(_w4_objects(SpongeRoller).size() >= 3 and _w4_objects(SlidingSoap).size() >= 1, "crea rodillos y jabones")
	var ts: Dictionary = Assets.tileset_data("world4_tiles")
	# el suelo de la salida es de azulejo y el de la segunda parte de la sección A de esponja
	var idx := func(c: Vector2i) -> int: return c.y * 8 + c.x
	var ints := func(a: Array) -> Array: return a.map(func(v): return int(v))
	var cell_tile: int = idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 20)))
	var cell_sponge: int = idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(44, 20)))
	check(cell_tile in ints.call(ts.materials.tile.cap0) and cell_sponge in ints.call(ts.materials.sponge.cap0), "autotiling con espuma sobre azulejo y esponja")
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 23))) in ints.call(ts.materials.tile.body), "bajo la superficie se repite el bloque base")
	check(GameState.get_v("dreamHud")[1] == "shell_token" and level.hud.get("moon_icons")[0].texture != null, "el HUD muestra las conchas token")


func test_w4_layout() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	var bad_stars: Array = []
	for s in level.data.stars:
		if level.terrain_solid_at(Vector2(float(s.x) * C.TILE + 8, float(s.y) * C.TILE + 8)):
			bad_stars.append("%s,%s" % [s.x, s.y])
	check(bad_stars.is_empty(), "ninguna estrella dentro del terreno (%s)" % str(bad_stars))
	var bad: Array = []
	for d in level.data.enemies:
		var x := float(d.x) * C.TILE + 8
		var y := float(d.y) * C.TILE
		if d.type == "sponge_crab":
			if not level.terrain_solid_at(Vector2(x, y + 4)) or level.terrain_solid_at(Vector2(x, y - 4)):
				bad.append("%s@%s" % [d.type, d.x])
		elif level.terrain_solid_at(Vector2(x, y - 8)):
			bad.append("%s@%s" % [d.type, d.x])
	check(bad.is_empty(), "monstruos colocados en sitios libres (%s)" % str(bad))
	# toda balsa tiene fondo real y una salida: borde a 1 tesela de la superficie o columna de burbujas
	for w in level.data.waters:
		var floor_ok := level.terrain_solid_at(Vector2((float(w.x) + 1) * C.TILE, (float(w.y) + float(w.h)) * C.TILE + 8))
		var exit_low := false
		for side in [float(w.x) - 1, float(w.x) + float(w.w)]:
			if level.terrain_solid_at(Vector2(side * C.TILE + 8, (float(w.y) - 1) * C.TILE + 8)) and not level.terrain_solid_at(Vector2(side * C.TILE + 8, (float(w.y) - 2) * C.TILE + 8)):
				exit_low = true
		var column: bool = level.data.bubbleColumns.any(func(c): return c.x >= w.x and c.x < w.x + w.w)
		check(floor_ok and (exit_low or column), "balsa en %s con fondo y salida" % w.x)
	for c in level.data.dreamCollectibles:
		check(not level.terrain_solid_at(Vector2(float(c.x) * C.TILE + 8, float(c.y) * C.TILE + 8)), "%s accesible (fuera del terreno)" % c.id)


func test_w4_slopes() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	var ts: Dictionary = Assets.tileset_data("world4_tiles")
	var c: Vector2i = level.builder.layer.get_cell_atlas_coords(Vector2i(17, 19))
	check(c.y * 8 + c.x == int(ts.slopes.sponge_up), "rampa de esponja colocada")
	var td: TileData = level.builder.layer.get_cell_tile_data(Vector2i(17, 19))
	check(td != null and td.get_collision_polygon_points(0, 0).size() == 3, "la rampa tiene colisión triangular")
	place(14, 20); await frames(4)
	hold(["move_right"])
	await frames(56)
	hold([])
	check(level.player.position.y <= 19 * C.TILE + 1 and level.player.position.x > 18 * C.TILE, "Alice sube la rampa andando, sin saltar")
	hold(["move_right"])
	await frames(60)
	hold([])
	await frames(10)
	check(level.player.grounded and level.player.position.y >= 20 * C.TILE - 1 and level.player.position.x > 23 * C.TILE, "y baja por la rampa del otro lado")


func test_w4_water() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	# balsa honda de la sección A (86-95, superficie 21, 3 teselas)
	place(90, 22); await frames(3)
	check(level.player.in_water(), "dentro del agua Alice nada")
	await frames(30)
	check(level.player.velocity.y <= Player.WATER_MAX_FALL + 0.1, "se hunde despacio")
	await frames(60)
	var y0 := level.player.position.y
	press("jump"); hold(["jump"]); await frames(10); hold([])
	check(level.player.position.y < y0 - 6, "la brazada la hace subir")
	# sale del agua y sube al borde con los controles normales (salto repetido + derecha)
	var out := false
	for i in 240:
		hold(["move_right"])
		if i % 14 == 0:
			press("jump")
		await frames(1)
		if level.player.position.x > 96.5 * C.TILE and level.player.grounded and not level.player.in_water():
			out = true
			break
	hold([])
	check(out, "Alice sale de la balsa nadando y saltando")
	place(5, 20); await frames(3)
	check(not level.player.in_water() and level.player.sprite.self_modulate == Color.WHITE, "fuera del agua vuelve la física normal")
	# tramo submarino: también se sale (columna de burbujas junto al muro)
	place(440, 22); await frames(3)
	var left := false
	for i in 600:
		hold(["move_right"])
		if i % 14 == 0:
			press("jump")
		await frames(1)
		if level.player.position.x > 447.5 * C.TILE and level.player.grounded:
			left = true
			break
	hold([])
	check(left, "Alice sale del tramo submarino")


func _w4_force_eruption(g: BubbleGeyser) -> void:
	# coloca el ciclo justo al principio de la erupción
	var start := g.period - BubbleGeyser.ERUPT_MS
	g.delay = fposmod(start - level.now + 20, g.period)


func test_w4_geyser_and_column() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	var g: BubbleGeyser = _w4_objects(BubbleGeyser)[0]
	place(137, 20); await frames(3)
	_w4_force_eruption(g)
	await frames(10)
	check(g.is_erupting() and level.player.velocity.y < -150, "el géiser en erupción impulsa a Alice")
	var top := level.player.position.y
	for i in 50:
		top = minf(top, level.player.position.y)
		await frames(1)
	check(top < 15 * C.TILE - 8, "sube por encima del muro alto que el salto no alcanza")
	# fuera de la erupción no empuja
	g.delay = fposmod(-level.now + 10, g.period)
	place(137, 20); await frames(6)
	check(not g.is_erupting() and level.player.grounded, "en reposo el géiser no empuja (aviso legible)")
	# columna de la cascada gigante (sección D)
	place(368, 20); await frames(40)
	check(level.player.position.y < 18 * C.TILE and level.player.velocity.y < 0, "la columna de burbujas eleva a Alice en el hueco")
	var reached := false
	for i in 200:
		hold(["move_right"])
		await frames(1)
		if level.player.grounded and level.player.position.x > 373 * C.TILE and level.player.position.y <= 13 * C.TILE + 1:
			reached = true
			break
	hold([])
	check(reached, "la columna lleva a la meseta de esponja")


func test_w4_obstacles() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	# espuma resbaladiza: menos fricción mientras se pisa, normal al salir
	place(119, 20); await frames(4)
	check(level.player.surface_friction < 0.5 and level.player.surface_friction > 0.0, "la espuma resbala sin quitar el control")
	place(100, 20); await frames(4)
	check(is_equal_approx(level.player.surface_friction, 1.0), "fuera de la espuma se recupera la fricción")
	# rodillo de esponja: empuja sin dañar
	var roller: SpongeRoller = _w4_objects(SpongeRoller)[0]
	place(roller.position.x / C.TILE - 1.5, 20); await frames(2)
	var hp := level.player.hp
	roller.push(level.player)
	check(level.player.push_x != 0 and level.player.hp == hp, "el rodillo empuja a Alice sin quitarle vida")
	var x0 := roller.position.x
	await frames(40)
	check(absf(roller.position.x - x0) > 4, "el rodillo se desplaza con un patrón fijo")
	# jabón deslizante: obstáculo que hace daño
	var soap: SlidingSoap = _w4_objects(SlidingSoap)[0]
	check(soap.get_meta("kind") == "hazard", "el jabón deslizante es un obstáculo")
	# burbuja frágil: revienta tras pisarla y se vuelve a inflar
	var bub: CrumblePlatform = level.level_objects.crumbles[0]
	bub.step_on(); await frames(45)
	check(bub.shape.disabled, "la burbuja frágil revienta (aviso previo de 0,5 s)")
	await frames(190)
	check(not bub.shape.disabled, "y se vuelve a inflar")
	# jabón móvil: plataforma que transporta
	var soap_mover: MovingPlatform = level.level_objects.movers[1]
	var p0 := soap_mover.position
	await frames(30)
	check(soap_mover.position.distance_to(p0) > 1, "el jabón móvil se desliza")
	# burbuja de salto
	var pad: BouncePad = _w4_objects(BouncePad)[0]
	level.player.position = pad.position + Vector2(0, -4); level.player.velocity.y = 80
	await frames(3)
	check(level.player.velocity.y < -400, "la burbuja de salto impulsa a Alice")


func _w4_spawn(type: String, dx: float, dy := 0.0) -> Enemy:
	var e: Enemy = EnemySpawner.SCENES[type].instantiate()
	var p := level.player.position
	e.setup(level, {"id": "test_" + type + str(randi()), "x": p.x + dx, "y": p.y + dy, "patrol": [p.x + dx - 40, p.x + dx + 40]})
	level.enemies_root.add_child(e)
	return e


func test_w4_enemies() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	place(110, 20); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	# Pez Burbuja: flota, avisa y dispara una burbuja
	var fish := _w4_spawn("bubble_fish", 90, -30)
	await frames(2)
	check(fish is BubbleFishMonster and not fish.gravity_enabled and fish.def.hp == 2, "el pez burbuja flota y tiene vida ligera")
	var y0 := fish.position.y
	var shots := func() -> int: return level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == "bubble_w4").size()
	fish.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(fish.sprite.animation == "attack" and shots.call() == 0, "el pez infla las mejillas antes de disparar")
	await frames(30)
	check(shots.call() >= 1, "el pez lanza burbujas")
	await frames(60)
	check(absf(fish.position.y - y0) < 16, "el pez no cae: nada a su altura")
	fish.queue_free()
	# Cangrejito: anda por el suelo y da un pinzazo corto
	var crab := _w4_spawn("sponge_crab", 30)
	await frames(30)
	check(crab is SpongeCrabMonster and crab.grounded, "el cangrejito anda sobre el suelo")
	crab.fsm.set_state(Enemy.ATTACK); await frames(8)
	check(crab.sprite.animation == "attack" and crab.sprite.frame == 0, "levanta la pinza como aviso")
	await frames(20)
	check(level.enemy_projectiles.get_children().any(func(n): return n is Projectile and n.kind == "foam"), "da el pinzazo con estela de espuma")
	crab.queue_free()
	# Pompa Traviesa: se acerca flotando y estalla en ráfaga
	var pompa := _w4_spawn("pompa", 120, -40)
	await frames(2)
	pompa.fsm.set_state(Enemy.ALERT)
	var d0 := absf(pompa.position.x - level.player.position.x)
	await frames(60)
	check(not pompa.gravity_enabled and absf(pompa.position.x - level.player.position.x) < d0, "la pompa flota y se acerca despacio")
	pompa.fsm.set_state(Enemy.ATTACK); await frames(50)
	var burst := level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.kind == "pompa_bubble").size()
	check(burst >= PompaMonster.BURST, "la pompa estalla en una ráfaga de burbujas")
	pompa.queue_free()
	await get_tree().process_frame


func test_w4_weapons_vs_enemies() -> void:
	await load_level("World4")
	await settle(); _clear_spawner()
	place(110, 20); await frames(3)
	for type in ["bubble_fish", "sponge_crab", "pompa"]:
		for wid in ["bubble", "paint", "sling"]:
			var e := _w4_spawn(type, 60, -6.0 if type != "sponge_crab" else 0.0)
			await frames(2)
			var hp0 := e.hp
			var p: Projectile = level.spawn_projectile("player", {"x": e.position.x, "y": e.position.y - 8, "vx": 0, "vy": 0, "kind": wid, "frame": "pellet", "lifespan": 200})
			p.weapon = Assets.weapon(wid)
			e.hit_by(p)
			if wid == "bubble":
				check(e.is_trapped(), "%s queda atrapado en la burbuja" % type)
				e.hit_by(p)
				check(not e.is_alive(), "%s atrapado se convierte en estrella" % type)
			elif wid == "paint":
				check(e.painted_until > level.now and e.hp < hp0, "%s recibe la pintura" % type)
			else:
				check(e.hp < hp0 or not e.is_alive(), "%s recibe el tirachinas" % type)
			e.queue_free()
			await get_tree().process_frame


func test_w4_boss() -> void:
	await load_level("Boss4", func(): GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(130)
	var boss: ReyPatoburbuja = level.boss
	check(boss != null and boss.max_hp == 50 and not boss.invulnerable, "Rey Patoburbuja entra vulnerable con 50 HP")
	check(level.terrain_solid_at(Vector2(5 * C.TILE + 8, 12 * C.TILE + 8)), "la arena queda cerrada durante el combate")
	# proyectil inactivo: sólo se usa para llamar a hit_by (no golpea por solapamiento)
	var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
	p.weapon = Assets.weapon("sling")
	p.active = false
	boss.hp = 34; boss.hit_by(p)
	check(boss.phase == 2, "cambia a la fase 2 (Oleaje juguetón) al 65%")
	boss.invulnerable = false; boss.hp = 16; boss.hit_by(p)
	check(boss.phase == 3, "cambia a la fase 3 (Tormenta de espuma) al 30%")
	# cada ataque avisa antes de soltar proyectiles y termina en un descanso vulnerable
	for phase in [1, 2, 3]:
		for atk in ReyPatoburbuja.PHASES[phase].pattern:
			boss.phase = phase
			boss.invulnerable = false
			boss.timers.clear()
			level.kill_enemy_projectiles()
			boss.fsm.set_state(atk)
			await frames(12)
			var early := level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active).size()
			check(early == 0, "%s tiene anticipación (sin proyectiles al empezar)" % atk)
			var guard := 0
			var shot := false
			while boss.fsm.current == atk and guard < 400:
				guard += 1
				if level.enemy_projectiles.get_children().any(func(n): return n is Projectile and n.active):
					shot = true
				level.player.invulnerable_until = level.now + 100000
				await frames(1)
			check(shot, "%s lanza su ataque" % atk)
			check(boss.fsm.current == "REST", "%s termina en un descanso vulnerable" % atk)
	boss.invulnerable = false; boss.hp = 1; boss.hit_by(p)
	check(boss.is_defeated(), "puede ser derrotado")


func test_w4_boss_victory() -> void:
	SaveManager.reset_progress()
	await load_level("Boss4", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(130)
	var boss: ReyPatoburbuja = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	var seen := {}
	var guard := 0
	var prev := ""
	while not boss.is_defeated() and guard < 12000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		# un acierto de tirachinas en cada descanso vulnerable (así se ven todos los ataques)
		if boss.fsm.current == "REST" and prev != "REST" and not boss.invulnerable:
			var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
			p.weapon = Assets.weapon("sling")
			p.active = false
			boss.hit_by(p)
		prev = boss.fsm.current
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(boss.is_defeated() and seen.has("phase2") and seen.has("phase3"), "combate completo con las tres fases")
	for s in ["SPIT", "SLAP", "BIG_BUBBLE", "WAVE", "SMALL_WHIRL", "WHIRL", "RAIN", "COMBO"]:
		check(seen.has(s), "usa el ataque %s" % s)
	# derrota no violenta: mareo, corona ladeada, flota, se hunde y queda dormido
	await frames(20)
	check(boss.sprite.animation == "hurt", "pierde energía (mareado)")
	await frames(80)
	check(boss.sprite.animation == "defeated" and boss.position.y < boss.floor_y, "queda dormido y flota despacio")
	await frames(160)
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(star.size() == 1 and boss.sprite.animation == "defeated" and boss.sprite.frame == 0, "pose dormida final y estrella dorada")
	if star.size() == 1:
		level.player.position = star[0].position + Vector2(0, 10)
		await frames(60)
		check(GameState.get_v("specialStar") == true and level.portal != null, "recoge la estrella dorada y se abre el portal")
		if level.portal:
			level.player.position = level.portal.position
			await frames(5)
			check(level.leaving and SaveManager.is_world_completed(4), "cruza el portal y guarda el Mundo 4")
			check(SaveManager.unlocked_world() == 5, "desbloquea el Mundo 5")
	SaveManager.reset_progress()


func test_w4_progression() -> void:
	SaveManager.reset_progress()
	for i in [1, 2]:
		SaveManager.mark_world_completed(i, 1, 1)
	check(not WorldRegistry.is_playable(4), "el Mundo 4 empieza bloqueado")
	SaveManager.mark_world_completed(3, 1, 1)
	check(WorldRegistry.is_playable(4), "completar el Mundo 3 desbloquea el Mundo 4")
	var key := WorldRegistry.start_run(4)
	check(key == "World4" and GameState.get_v("dreamTotal") == 6 and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 4")
	SaveManager.mark_world_completed(4, 150, 203, true, 1000, [], ["shell_1", "shell_2", "shell_3", "duck_1"])
	check(SaveManager.unlocked_world() == 5 and SaveManager.get_world(4).dreamCollectibles.size() == 4, "victoria guarda estrellas y coleccionables del Mundo 4")
	check(WorldRegistry.is_playable(5), "completar el Mundo 4 desbloquea el Mundo 5 (ya implementado)")
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 4, "stars": 150, "total": 203, "dream": ["shell_1"], "dreamTotal": 6}
	add_child(v)
	await frames(2)
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(v.world_id == 4 and list.buttons[0].label.text == "Ir al Mundo 5", "la victoria del Mundo 4 ofrece ir al Mundo 5")
	v.queue_free()
	# el mapa de mundos abre el Mundo 4
	var wm: Control = load(Router.SCENES.WorldMap).instantiate()
	add_child(wm)
	await frames(2)
	check(not wm.world_btns[4].locked and not wm.world_btns[5].locked and wm.world_btns[6].locked, "el mapa abre los Mundos 4 y 5 y mantiene cerrado el 6")
	wm.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


# ======================================================================= MUNDO 5
func _w5_objects(cls: Variant) -> Array:
	return level.level_objects.objects.get_children().filter(func(n): return is_instance_of(n, cls))


func _w5_movers(cls: Variant) -> Array:
	return level.level_objects.movers.filter(func(n): return is_instance_of(n, cls))


func test_w5_data() -> void:
	var w: Dictionary = C.load_json("res://data/world5/world5.json")
	var b: Dictionary = C.load_json("res://data/world5/world5_boss.json")
	check(w.progress.total == 10496 and w.widthTiles * 16 + b.widthTiles * 16 == 10496, "recorrido total de unos 10.500 px")
	check(w.sections.map(func(x): return int(x.from)) == [0, 2000, 4000, 6200, 8500], "cinco secciones del Mundo 5")
	check(w.checkpoints.size() == 2, "dos checkpoints")
	check(w.dreamCollectibles.filter(func(x): return x.kind == "moon_token").size() == 3, "tres fichas de luna principales")
	for k in ["special", "constellation", "rocket"]:
		check(w.dreamCollectibles.any(func(x): return x.kind == k), "coleccionable temático %s" % k)
	check(w.slides.size() >= 2 and w.rockets.size() >= 2 and w.orbits.size() >= 1, "toboganes, cohetes móviles y lunas en órbita")
	check(w.fallingStars.size() >= 3 and w.explosiveClouds.size() >= 3 and w.lightFalls.size() >= 1, "estrellas que caen, nubes explosivas y cascadas de luz")
	check(w.pads.any(func(p): return p.frame == "star_spring") and w.pads.any(func(p): return p.frame == "launch_pad"), "trampolines de estrella y plataforma de lanzamiento")
	check(w.clouds.any(func(c): return c.frame == "star_plat") and w.clouds.any(func(c): return String(c.frame).begins_with("moon_plat")), "plataformas de estrella sólidas y de luna creciente")
	var types := {}
	for e in w.enemies: types[e.type] = true
	check(types.has("estrellita") and types.has("meteorito") and types.has("cohetito"), "los tres enemigos oficiales")
	check(String(b.boss.scene).ends_with("LunaEstelar.tscn"), "arena con Luna Estelar")
	var manifest: Dictionary = C.load_json("res://data/world5/world5_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "manifiesto de recursos sin pendientes")
	for src in ["imagenes/word_5.png", "imagenes/tilesets_world_5.png", "imagenes/enemies_world_5.png", "imagenes/jefemundo5.png"]:
		check(manifest.resources.any(func(r): return r.get("source") == src), "usa la referencia oficial %s" % src)


func test_w5_sprites() -> void:
	var expected := {
		"estrellita": {"idle": 4, "walk": 4, "attack": 2, "hurt": 2, "defeated": 4},
		"meteorito": {"idle": 4, "walk": 4, "attack": 3, "hurt": 2, "defeated": 4},
		"cohetito": {"idle": 4, "walk": 4, "attack": 2, "hurt": 2, "defeated": 4},
		"luna_estelar": {"idle": 4, "move": 6, "shoot": 4, "spin": 4, "cosmic": 4, "hurt": 2, "defeated": 2},
	}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		for a in expected[key]:
			check(sf.has_animation(a) and sf.get_frame_count(a) == expected[key][a], "%s/%s conserva sus fotogramas" % [key, a])
	check(Assets.tileset("world5_tiles") != null, "TileSet nativo del Mundo 5")
	for atlas in ["world5_objects", "world5_bg", "w5_fx"]:
		check(Assets.atlases.has(atlas), "atlas %s cargado" % atlas)
	check(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")) == 0, "texturas sin suavizado (nearest)")


func test_w5_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World5")
	await settle()
	check(level.data.key == "world5" and level.player.grounded, "Mundo 5 carga con Alice sobre terreno real")
	check(Assets.used_placeholders.is_empty(), "Mundo 5 no usa marcadores provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(GameState.get_v("weaponsOwned").size() == 3, "reutiliza las tres armas")
	check(level.level_objects.slides.size() == level.data.slides.size(), "crea los toboganes arcoíris")
	check(_w5_movers(RocketPlatform).size() == level.data.rockets.size() and _w5_movers(OrbitPlatform).size() == level.data.orbits.size(), "crea cohetes y lunas en órbita")
	check(_w5_objects(FallingStar).size() == level.data.fallingStars.size() and _w5_objects(ExplosiveCloud).size() == level.data.explosiveClouds.size(), "crea estrellas que caen y nubes explosivas")
	check(_w5_objects(LightFall).size() == level.data.lightFalls.size(), "crea las cascadas de luz que suben")
	var ts: Dictionary = Assets.tileset_data("world5_tiles")
	var idx := func(c: Vector2i) -> int: return c.y * 8 + c.x
	var ints := func(a: Array) -> Array: return a.map(func(v): return int(v))
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 20))) in ints.call(ts.materials.cosmic.cap0), "autotiling: nube sobre la roca estrellada")
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 23))) in ints.call(ts.materials.cosmic.body), "bajo la superficie se repite la roca")
	var td: TileData = level.builder.layer.get_cell_tile_data(Vector2i(4, 20))
	check(td != null and td.get_collision_polygons_count(0) == 1, "las teselas tienen colisión del TileSet")
	check(GameState.get_v("dreamHud")[1] == "moon_token" and level.hud.get("moon_icons")[0].texture != null, "el HUD muestra las fichas de luna")
	# capas: el fondo queda detrás del terreno y la decoración frontal es pequeña (no tapa a Alice)
	check(level.parallax.get_children().all(func(l): return l.z_index < C.Z_TERRAIN), "parallax detrás del terreno")
	var front: Array = level.world_root.get_node("Decor").get_children().filter(func(d): return d.z_index == C.Z_DECOR_FRONT)
	check(front.all(func(d): return d.texture.get_height() <= 20), "la decoración delantera es pequeña y baja")


func test_w5_layout() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	var bad_stars: Array = []
	for s in level.data.stars:
		if level.terrain_solid_at(Vector2(float(s.x) * C.TILE + 8, float(s.y) * C.TILE + 8)):
			bad_stars.append("%s,%s" % [s.x, s.y])
	check(bad_stars.is_empty(), "ninguna estrella dentro del terreno (%s)" % str(bad_stars))
	var bad: Array = []
	for d in level.data.enemies:
		var x := float(d.x) * C.TILE + 8
		var y := float(d.y) * C.TILE
		if d.type == "meteorito":
			if not level.terrain_solid_at(Vector2(x, y + 4)) or level.terrain_solid_at(Vector2(x, y - 4)):
				bad.append("%s@%s" % [d.type, d.x])
		elif level.terrain_solid_at(Vector2(x, y - 8)):
			bad.append("%s@%s" % [d.type, d.x])
	check(bad.is_empty(), "monstruos colocados en sitios libres (%s)" % str(bad))
	for c in level.data.dreamCollectibles:
		check(not level.terrain_solid_at(Vector2(float(c.x) * C.TILE + 8, float(c.y) * C.TILE + 8)), "%s accesible (fuera del terreno)" % c.id)
	for cp in level.data.checkpoints:
		check(level.terrain_solid_at(Vector2(float(cp.x) * C.TILE + 8, float(cp.y) * C.TILE + 8)), "checkpoint en %s sobre suelo" % cp.x)


func test_w5_slopes() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	var ts: Dictionary = Assets.tileset_data("world5_tiles")
	var c: Vector2i = level.builder.layer.get_cell_atlas_coords(Vector2i(76, 18))
	check(c.y * 8 + c.x == int(ts.slopes.cosmic_up), "rampa de roca estrellada colocada")
	var td: TileData = level.builder.layer.get_cell_tile_data(Vector2i(76, 18))
	check(td != null and td.get_collision_polygon_points(0, 0).size() == 3, "la rampa tiene colisión triangular")
	place(73, 19); await frames(4)
	hold(["move_right"])
	await frames(50)
	hold([])
	await frames(6)
	check(level.player.grounded and level.player.position.y <= 18 * C.TILE + 1 and level.player.position.x > 77 * C.TILE, "Alice sube la rampa andando, sin saltar")


func test_w5_platforms() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	# estrella sólida: se pisa desde arriba (unidireccional)
	place(31, 14); await frames(40)
	check(level.player.grounded and absf(level.player.position.y - 16 * C.TILE) < 2, "la estrella sólida sostiene a Alice")
	# trampolín de estrella
	var spring: BouncePad = _w5_objects(BouncePad).filter(func(p): return p.position.x < 40 * C.TILE)[0]
	level.player.position = spring.position + Vector2(0, -4); level.player.velocity.y = 80
	await frames(3)
	check(level.player.velocity.y < -400, "el trampolín de estrella impulsa a Alice")
	# luna creciente móvil y luna en órbita (ruta curva)
	var moon: MovingPlatform = level.level_objects.movers[0]
	var m0 := moon.position
	var orbit: OrbitPlatform = _w5_movers(OrbitPlatform)[0]
	var o0 := orbit.position
	await frames(40)
	check(moon.position.distance_to(m0) > 2, "la luna creciente se desplaza")
	check(absf(orbit.position.x - o0.x) > 2 and absf(orbit.position.y - o0.y) > 1, "la luna en órbita recorre una curva")
	# cohete móvil: transporta a Alice
	var rocket: RocketPlatform = _w5_movers(RocketPlatform)[0]
	level.player.position = rocket.position + Vector2(0, 1)
	level.player.velocity = Vector2.ZERO
	await frames(10)
	var p0 := level.player.position.x
	var r0 := rocket.position.x
	await frames(40)
	check(level.player.grounded and absf((level.player.position.x - p0) - (rocket.position.x - r0)) < 3 and absf(rocket.position.x - r0) > 4, "el cohete móvil transporta a Alice")
	# cohete ascensor: trayectoria vertical estable
	var lift: RocketPlatform = _w5_movers(RocketPlatform).filter(func(r): return not r.horizontal)[0]
	var ys: Array = []
	for i in 6:
		ys.append(lift.target_at(i * 700.0).y)
	check(ys.max() - ys.min() > 4 * C.TILE and is_equal_approx(lift.target_at(0).x, lift.target_at(1700).x), "el cohete ascensor sube y baja en vertical")


func _w5_slide_run(axis: Array) -> float:
	var sl: RainbowSlide = level.level_objects.slides[0]
	var x := sl.from.x + 24
	var y := sl.from.y + (x - sl.from.x) / (sl.to.x - sl.from.x) * (sl.to.y - sl.from.y)
	level.player.position = Vector2(x, y - 1)
	level.player.velocity = Vector2.ZERO
	hold([])
	await frames(4)
	hold(axis)
	var x0 := level.player.position.x
	await frames(30)
	hold([])
	return level.player.position.x - x0


func test_w5_slide() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	var free := await _w5_slide_run([])
	var faster := await _w5_slide_run(["move_right"])
	var slower := await _w5_slide_run(["move_left"])
	check(free > 60, "el tobogán arcoíris desliza a Alice rápido sin pulsar nada (%.0f px)" % free)
	check(faster > free and slower < free and slower > 20, "Alice mantiene algo de control: acelera o frena sin pararse (%.0f / %.0f / %.0f)" % [slower, free, faster])
	# fuera del tobogán vuelve el movimiento normal
	place(290, 20); await frames(10)
	check(level.player.slide_speed == 0.0 and absf(level.player.velocity.x) < 1, "fuera del tobogán no hay deslizamiento")
	# baja hasta el final sin caerse
	var sl: RainbowSlide = level.level_objects.slides[0]
	level.player.position = sl.from + Vector2(8, -2)
	level.player.velocity = Vector2.ZERO
	await frames(140)
	check(level.player.position.x > sl.to.x and level.player.position.y <= sl.to.y + 1 and not level.player.dead, "el tobogán lleva a Alice hasta la isla de abajo")


func test_w5_light_fall() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	place(176, 19); await frames(50)
	check(level.player.position.y < 14 * C.TILE and level.player.velocity.y < 0, "la cascada de luz eleva a Alice")
	var reached := false
	for i in 200:
		hold(["move_right"])
		await frames(1)
		if level.player.grounded and level.player.position.x > 178 * C.TILE and level.player.position.y <= 13 * C.TILE + 1:
			reached = true
			break
	hold([])
	check(reached, "la cascada de luz lleva al acantilado alto")


func test_w5_falling_star() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	var fs: FallingStar = _w5_objects(FallingStar)[0]
	place(fs.position.x / C.TILE - 0.5, 17); await frames(3)
	level.player.invulnerable_until = 0
	fs.delay = fposmod(level.now + 30, fs.period)  # el ciclo empieza dentro de 30 ms: primero el aviso
	await frames(6)
	var hp := level.player.hp
	check(fs.phase_at(level.now) == "warn" and fs.marker.modulate.a > 0.2, "la estrella avisa con un destello en el suelo")
	await frames(40)
	check(level.player.hp == hp and not fs.is_falling(), "durante el aviso no hace daño (hay tiempo para apartarse)")
	var hit := false
	for i in 60:
		await frames(1)
		hit = hit or level.player.hp < hp
	check(hit, "si Alice se queda debajo, la estrella que cae le quita un corazón")
	# esquivable: apartada dos teselas no la toca
	await frames(200)
	place(fs.position.x / C.TILE + 1.5, 17); await frames(3)
	level.player.invulnerable_until = 0
	hp = level.player.hp
	fs.delay = fposmod(level.now + 30, fs.period)
	var fell := false
	for i in 110:
		await frames(1)
		fell = fell or fs.is_falling()
	check(fell and level.player.hp == hp, "apartándose dos teselas la estrella no la toca")


func test_w5_explosive_cloud() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	place(400, 17); await frames(4)
	level.player.invulnerable_until = 0
	var cloud: ExplosiveCloud = _w5_objects(ExplosiveCloud)[0]
	cloud.base_y = level.player.position.y - 30
	cloud.position = level.player.position + Vector2(12, -30)
	await frames(2)
	var hp := level.player.hp
	cloud.touch(level.player)
	check(cloud.state == "fuse", "al tocarla la nube se hincha (aviso)")
	await frames(20)
	check(cloud.state == "fuse" and level.player.hp == hp, "la mecha deja tiempo para alejarse")
	await frames(30)
	check(cloud.state == "gone" and level.player.hp < hp, "estalla en luz y nube y daña si Alice sigue cerca")
	# Alice se aparta (si siguiera debajo, la nube nueva volvería a hincharse al tocarla)
	cloud.base_y = level.player.position.y - 60
	cloud.position = level.player.position + Vector2(90, -60)
	await frames(int(ExplosiveCloud.REFORM_MS / 1000.0 * 60) + 40)
	check(cloud.is_ready(), "la nube se vuelve a formar")
	# un disparo la hace estallar al momento (desde lejos es seguro)
	level.player.invulnerable_until = 0
	hp = level.player.hp
	cloud.base_y = level.player.position.y - 20
	cloud.position = level.player.position + Vector2(140, -20)
	await frames(2)
	var p: Projectile = level.spawn_projectile("player", {"x": cloud.position.x, "y": cloud.position.y, "vx": 0, "vy": 0, "kind": "paint", "frame": "pellet", "lifespan": 300})
	p.weapon = Assets.weapon("paint")
	await frames(4)
	check(cloud.state == "gone" and level.player.hp == hp, "el disparo la hace estallar sin dañar a Alice")


func _w5_spawn(type: String, dx: float, dy := 0.0, extra := {}) -> Enemy:
	var e: Enemy = EnemySpawner.SCENES[type].instantiate()
	var p := level.player.position
	var s := {"id": "test_" + type + str(randi()), "x": p.x + dx, "y": p.y + dy, "patrol": [p.x + dx - 40, p.x + dx + 40]}
	s.merge(extra, true)
	e.setup(level, s)
	level.enemies_root.add_child(e)
	return e


func _w5_shots(kind: String) -> int:
	return level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == kind).size()


func test_w5_enemies() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	place(400, 17); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	# Estrellita Fugaz: vuela rápido, avisa y lanza una miniestrella
	var star := _w5_spawn("estrellita", 90, -40)
	await frames(2)
	check(star is EstrellitaMonster and not star.gravity_enabled and star.def.hp == 2, "la estrellita vuela y tiene vida ligera")
	level.player.position.x = 300 * C.TILE
	star.fsm.set_state(Enemy.PATROL); await frames(20)
	check(absf(star.velocity.x) >= star.def.speed * 0.9, "la estrellita se mueve rápido por su ruta")
	place(400, 17); await frames(2)
	level.player.invulnerable_until = level.now + 100000
	star.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(star.sprite.animation == "attack" and _w5_shots("mini_star") == 0, "se encoge y brilla antes de disparar")
	await frames(30)
	check(_w5_shots("mini_star") >= 1, "lanza miniestrellas")
	star.queue_free()
	# Meteorito Travieso: rueda por el suelo, avisa y embiste
	var rock := _w5_spawn("meteorito", 70)
	await frames(30)
	check(rock is MeteoritoMonster and rock.grounded, "el meteorito rueda sobre el suelo")
	rock.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(absf(rock.velocity.x) < 1 and rock.sprite.animation == "attack", "tiembla como aviso antes de embestir")
	await frames(40)
	check(rock.charging and absf(rock.velocity.x) > 100, "embiste en línea recta")
	rock.queue_free()
	# en una pendiente rueda cuesta abajo
	place(466, 18); await frames(3)
	# sobre la rampa (470, 17), que sube hacia la derecha; empieza mirando cuesta arriba
	var slope_rock: Enemy = _w5_spawn("meteorito", 470.5 * C.TILE - level.player.position.x, -10, {"patrol": [463 * C.TILE, 484 * C.TILE]})
	level.player.position.x = 440 * C.TILE
	await frames(3)
	slope_rock.facing = 1
	slope_rock.fsm.set_state(Enemy.PATROL)
	var x0 := slope_rock.position.x
	await frames(30)
	check(slope_rock.position.x < x0 - 4, "en la pendiente rueda cuesta abajo")
	slope_rock.queue_free()
	place(400, 17); await frames(3)
	# Cohetito Centinela: patrulla vertical, avisa encendiendo el motor y dispara un rayo estelar
	var rocket := _w5_spawn("cohetito", 100, -40, {"axis": "v", "range": 2})
	await frames(2)
	level.player.position.x = 300 * C.TILE  # lejos: patrulla
	rocket.fsm.set_state(Enemy.PATROL)
	var ys: Array = []
	var rx := rocket.position.x
	for i in 150:
		await frames(1)
		ys.append(rocket.position.y)
	check(ys.max() - ys.min() > 14 and absf(rocket.position.x - rx) < 2, "el cohetito patrulla en vertical")
	place(400, 17); await frames(2)
	level.player.invulnerable_until = level.now + 100000
	rocket.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(rocket.sprite.animation == "attack" and _w5_shots("star_beam") == 0, "el cohetito enciende el motor antes de disparar")
	await frames(40)
	check(_w5_shots("star_beam") >= 1, "dispara proyectiles de energía estelar")
	rocket.queue_free()
	await get_tree().process_frame


func test_w5_weapons_vs_enemies() -> void:
	await load_level("World5")
	await settle(); _clear_spawner()
	place(400, 17); await frames(3)
	for type in ["estrellita", "meteorito", "cohetito"]:
		for wid in ["bubble", "paint", "sling"]:
			var e := _w5_spawn(type, 60, -6.0 if type != "meteorito" else 0.0)
			await frames(2)
			var hp0 := e.hp
			var p: Projectile = level.spawn_projectile("player", {"x": e.position.x, "y": e.position.y - 8, "vx": 0, "vy": 0, "kind": wid, "frame": "pellet", "lifespan": 200})
			p.weapon = Assets.weapon(wid)
			e.hit_by(p)
			if wid == "bubble":
				check(e.is_trapped(), "%s queda atrapado en la burbuja" % type)
				e.hit_by(p)
				check(not e.is_alive(), "%s atrapado se convierte en estrella" % type)
			elif wid == "paint":
				check(e.painted_until > level.now and e.hp < hp0, "%s recibe la pintura" % type)
			else:
				check(e.hp < hp0 or not e.is_alive(), "%s recibe el tirachinas" % type)
			e.queue_free()
			await get_tree().process_frame


func test_w5_boss() -> void:
	await load_level("Boss5", func(): GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(140)
	var boss: LunaEstelar = level.boss
	check(boss != null and boss.max_hp == 50 and not boss.invulnerable, "Luna Estelar entra vulnerable con 50 HP")
	check(level.terrain_solid_at(Vector2(5 * C.TILE + 8, 12 * C.TILE + 8)), "la arena queda cerrada durante el combate")
	var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
	p.weapon = Assets.weapon("sling")
	p.active = false
	boss.hp = 34; boss.hit_by(p)
	check(boss.phase == 2, "cambia a la fase 2 (Órbita celestial) al 65%")
	boss.invulnerable = false; boss.hp = 16; boss.hit_by(p)
	check(boss.phase == 3, "cambia a la fase 3 (Tormenta de constelaciones) al 30%")
	for phase in [1, 2, 3]:
		for atk in LunaEstelar.PHASES[phase].pattern:
			boss.phase = phase
			boss.invulnerable = false
			boss.timers.clear()
			boss.orbiters.clear()
			level.kill_enemy_projectiles()
			boss.fsm.set_state(atk)
			await frames(12)
			var early := level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active).size()
			check(early == 0 and absf(boss.velocity.x) < 1, "%s tiene anticipación (nada sale al empezar)" % atk)
			var guard := 0
			var acted := false
			while boss.fsm.current == atk and guard < 400:
				guard += 1
				if level.enemy_projectiles.get_children().any(func(n): return n is Projectile and n.active) or absf(boss.velocity.x) > 100:
					acted = true
				level.player.invulnerable_until = level.now + 100000
				await frames(1)
			check(acted, "%s lanza su ataque" % atk)
			check(boss.fsm.current == "REST", "%s termina en un descanso vulnerable" % atk)
	boss.invulnerable = false; boss.hp = 1; boss.hit_by(p)
	check(boss.is_defeated(), "puede ser derrotada")


func test_w5_boss_victory() -> void:
	SaveManager.reset_progress()
	await load_level("Boss5", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(140)
	var boss: LunaEstelar = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	var seen := {}
	var guard := 0
	var prev := ""
	while not boss.is_defeated() and guard < 14000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		if boss.fsm.current == "REST" and prev != "REST" and not boss.invulnerable:
			var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
			p.weapon = Assets.weapon("sling")
			p.active = false
			boss.hit_by(p)
		prev = boss.fsm.current
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(boss.is_defeated() and seen.has("phase2") and seen.has("phase3"), "combate completo con las tres fases")
	for s in ["STAR_SHOT", "DASH", "SPIN", "ORBIT", "WAVE", "COSMIC", "STARFALL", "SPIN_RING", "MULTI_SHOT"]:
		check(seen.has(s), "usa el ataque %s" % s)
	var spin0 := boss.orbit_speed
	await frames(20)
	check(boss.sprite.animation == "hurt", "pierde energía")
	await frames(80)
	check(boss.orbit_speed < spin0, "sus estrellas giran más lento")
	check(boss.sprite.animation == "defeated" and boss.sprite.frame == 0, "su expresión se suaviza")
	await frames(160)
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(boss.sprite.animation == "defeated" and boss.sprite.frame == 1 and boss.position.y >= boss.floor_y - 1, "se recuesta entre nubes, dormida")
	check(star.size() == 1, "entrega la estrella dorada")
	if star.size() == 1:
		level.player.position = star[0].position + Vector2(0, 10)
		await frames(60)
		check(GameState.get_v("specialStar") == true and level.portal != null, "recoge la estrella dorada y se abre el portal")
		if level.portal:
			level.player.position = level.portal.position
			await frames(5)
			check(level.leaving and SaveManager.is_world_completed(5), "cruza el portal y guarda el Mundo 5")
			check(SaveManager.unlocked_world() == 6, "desbloquea el Mundo 6")
	SaveManager.reset_progress()


func test_w5_progression() -> void:
	SaveManager.reset_progress()
	for i in [1, 2, 3]:
		SaveManager.mark_world_completed(i, 1, 1)
	check(not WorldRegistry.is_playable(5), "el Mundo 5 empieza bloqueado")
	SaveManager.mark_world_completed(4, 1, 1)
	check(WorldRegistry.is_playable(5), "completar el Mundo 4 desbloquea el Mundo 5")
	var key := WorldRegistry.start_run(5)
	check(key == "World5" and GameState.get_v("dreamTotal") == 6 and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 5")
	SaveManager.mark_world_completed(5, 180, 246, true, 1000, [], ["moon_1", "moon_2", "moon_3", "special_1"])
	check(SaveManager.unlocked_world() == 6 and SaveManager.get_world(5).dreamCollectibles.size() == 4 and SaveManager.get_world(5).bestStars == 180, "victoria guarda estrellas y coleccionables del Mundo 5")
	check(not WorldRegistry.is_playable(6) and WorldRegistry.start_run(6) == "", "el Mundo 6 aún no existe: no se carga ninguna escena")
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 5, "stars": 180, "total": 246, "dream": ["moon_1"], "dreamTotal": 6}
	add_child(v)
	await frames(2)
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(v.world_id == 5 and list.buttons[0].label.text == "Jugar otra vez", "pantalla de continuación sin botón a un Mundo 6 inexistente")
	v.queue_free()
	var wm: Control = load(Router.SCENES.WorldMap).instantiate()
	add_child(wm)
	await frames(2)
	check(not wm.world_btns[5].locked and wm.world_btns[6].locked, "el mapa abre el Mundo 5 y mantiene cerrado el 6")
	check(wm.describe(5).begins_with("Mundo 5: Sueños Cósmicos"), "el mapa nombra el Mundo 5")
	wm.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()
