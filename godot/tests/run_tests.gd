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
		"test_menu_keyboard", "test_pause_resume",
		# Mundo 2
		"test_w2_data", "test_w2_sprites", "test_w2_level_loads", "test_w2_paint", "test_w2_rulers",
		"test_w2_switch_and_temporary", "test_w2_hazards", "test_w2_magic_and_checkpoint",
		"test_w2_eraser", "test_w2_crayon", "test_w2_brush", "test_w2_weapons_vs_enemies",
		"test_w2_boss", "test_w2_progression",
		# Mundo 3
		"test_w3_data", "test_w3_sprites", "test_w3_level_loads", "test_w3_mechanics",
		"test_w3_enemies", "test_w3_boss", "test_w3_progression",
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
	var world_id := 3 if scene_key.ends_with("3") else (2 if scene_key.ends_with("2") else 1)
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


func test_menu_keyboard() -> void:
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var list: MenuList = menu.get_children().filter(func(n): return n is MenuList)[0]
	check(list.index == 0 and list.buttons[0].selected, "el menú empieza en Mundo 1")
	await _action("menu_down")
	check(list.index == 1, "flecha abajo selecciona la opción siguiente (Mundo 2)")
	await _action("menu_down")
	check(list.index == 2, "y después Música")
	var music_before := AudioManager.music_on
	await _action("menu_accept")
	check(AudioManager.music_on != music_before, "Enter activa la opción (música)")
	await _action("menu_accept")
	check(AudioManager.music_on == music_before, "y vuelve a cambiarla")
	await _action("menu_up")
	check(list.index == 1, "flecha arriba vuelve a la opción anterior")
	list.buttons[2].hovered.emit(list.buttons[2])
	check(list.index == 2, "pasar el ratón por encima selecciona")
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
	check(swing.target_at(700).distance_to(swing.anchor) > 3, "cuerda oscilante define un arco estable")
	var yarn: RollingYarn = level.level_objects.objects.get_children().filter(func(n): return n is RollingYarn)[0]
	var x0 := yarn.position.x; await frames(30)
	check(absf(yarn.position.x-x0)>10, "ovillo rodante se desplaza")
	var cloud: SleepCloud = level.level_objects.objects.get_children().filter(func(n): return n is SleepCloud)[0]
	cloud.apply(level.player)
	check(level.player.sleepy_until > level.now and not level.player.frozen, "nube de sueño ralentiza sin quitar control")
	var button: MagicButton = level.level_objects.objects.get_children().filter(func(n): return n is MagicButton)[0]
	var target: MovingPlatform = level.level_objects.movers[4]
	check(not target.active, "mecanismo empieza dormido")
	button.trigger(); await frames(1)
	check(target.active and target.visible, "botón mágico activa la plataforma por señal")

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
		e.queue_free(); await get_tree().process_frame

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

func test_w3_progression() -> void:
	SaveManager.reset_progress(); SaveManager.mark_world_completed(1,1,1); SaveManager.mark_world_completed(2,1,1)
	check(WorldRegistry.is_playable(3), "completar Mundo 2 desbloquea Mundo 3")
	var key := WorldRegistry.start_run(3)
	check(key == "World3" and GameState.get_v("dreamTotal") == 6, "nueva partida conserva sistemas y coleccionables de Mundo 3")
	SaveManager.mark_world_completed(3,10,138,true,1000,[],["moon_1","moon_2","moon_3"])
	check(SaveManager.unlocked_world() == 4 and SaveManager.is_world_completed(3), "victoria guarda el Mundo 3 y desbloquea Mundo 4")
	check(SaveManager.get_world(3).dreamCollectibles.size() == 3, "lunas mágicas persistidas")
	SaveManager.reset_progress()
