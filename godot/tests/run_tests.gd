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
	WorldRegistry.start_run(1)
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
	check(list.index == 0 and list.buttons[0].selected, "el menú empieza en Jugar")
	await _action("menu_down")
	check(list.index == 1, "flecha abajo selecciona la opción siguiente")
	var music_before := AudioManager.music_on
	await _action("menu_accept")
	check(AudioManager.music_on != music_before, "Enter activa la opción (música)")
	await _action("menu_accept")
	check(AudioManager.music_on == music_before, "y vuelve a cambiarla")
	await _action("menu_up")
	check(list.index == 0, "flecha arriba vuelve a Jugar")
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
