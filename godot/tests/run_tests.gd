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
		"test_menu_keyboard", "test_menu_art", "test_world_carousel", "test_pause_resume", "test_sign_bubbles_inside",
		"test_checkpoint_spacing",
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
		# Mundo 6
		"test_w6_data", "test_w6_sprites", "test_w6_level_loads", "test_w6_layout", "test_w6_train_carry",
		"test_w6_train_slope", "test_w6_train_stations", "test_w6_walk_along_train", "test_w6_switch", "test_w6_bell_train",
		"test_w6_helis", "test_w6_rainbow_arch", "test_w6_falling_block", "test_w6_spring_wheel_bumper", "test_w6_hazard_train",
		"test_w6_collectibles", "test_w6_enemies", "test_w6_weapons_vs_enemies", "test_w6_camera", "test_w6_boss",
		"test_w6_boss_victory", "test_w6_progression",
		# Mundo 7
		"test_w7_data", "test_w7_sprites", "test_w7_level_loads", "test_w7_jelly_bounce", "test_w7_sticky_and_slippery",
		"test_w7_conveyor", "test_w7_hazards", "test_w7_temp_jelly_and_heart", "test_w7_enemies", "test_w7_weapons_vs_enemies",
		"test_w7_boss", "test_w7_boss_victory", "test_w7_progression",
		# Mundo 8 (final)
		"test_w8_data", "test_w8_sprites", "test_w8_level_loads", "test_w8_ghost_platforms", "test_w8_shadow_damage",
		"test_w8_hooks_swings_and_stars", "test_w8_lantern_bridges", "test_w8_chest_and_memories", "test_w8_enemies",
		"test_w8_weapons_vs_enemies", "test_w8_slow_effect", "test_w8_boss_states", "test_w8_boss_attacks",
		"test_w8_boss_defeat_cancels", "test_w8_boss_victory_and_ending", "test_w8_awakening_and_credits", "test_w8_progression",
		# Narrativa (criaturas rescatadas, Diario de Sueños, purificación y final)
		"test_narrative_registry", "test_narrative_save_compat", "test_narrative_rescue_once", "test_narrative_rescue_weapons",
		"test_narrative_boss_purification", "test_narrative_all_bosses_purify", "test_narrative_journal", "test_narrative_celebration_pick",
		"test_narrative_ending",
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
	WorldRegistry.start_run(WorldRegistry.id_for_scene(scene_key))
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
	check(w.checkpoints.size() == 4 and w.pickups.size() == 3, "4 checkpoints y 3 armas")
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
	var cards: Array[WorldCard] = menu.carousel.cards
	check(cards[0].data.state() == WorldData.State.COMPLETED and cards[1].data.state() == WorldData.State.UNLOCKED and cards[2].data.state() == WorldData.State.LOCKED, "carrusel: Mundo 1 completado, Mundo 2 abierto, Mundo 3 con candado")
	check(menu.carousel.index == 1, "el carrusel empieza en el mundo más avanzado que se puede jugar")
	check(cards[0].data.describe().ends_with("97 estrellas"), "el mundo completado muestra sus estrellas")
	check(cards[2].island.self_modulate == WorldCard.LOCKED_TINT and cards[1].island.self_modulate == Color.WHITE, "el mundo bloqueado se atenúa")
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
	for track in ["world1", "boss", "world2", "garabato"]:
		var song: AudioStream = AudioManager._music_streams.get(track)
		check(song is AudioStreamMP3 and song.loop and song.get_length() > 10, "la pista %s usa su mp3 en bucle" % track)
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


func test_world_carousel() -> void:
	SaveManager.reset_progress()
	var names := ["Nubes de Algodón", "Crayones", "Peluches", "Océano de Burbujas", "Juguetes", "Parque de las Estrellas", "Bosque de Caramelos", "Castillo de los Sueños"]
	var c := WorldCarousel.new().setup(WorldData.catalog(), 0)
	var chosen: Array = []
	var refused: Array = []
	c.world_chosen.connect(func(d): chosen.append(d.id))
	c.world_refused.connect(func(d): refused.append(d.id))
	add_child(c)
	await frames(2)
	check(c.cards.size() == 8 and c.cards.map(func(k): return k.data.title) == names, "ocho mundos en el orden fijado")
	var shown := func() -> Array: return range(8).filter(func(i): return c.cards[i].visible)
	check(shown.call() == [0, 1, 7], "tres islas a la vista: la central y una a cada lado")
	var mid := c.cards[0]
	var right := c.cards[1]
	check(mid.scale == Vector2.ONE and mid.modulate.a == 1.0 and right.scale == Vector2.ONE * 0.75 and is_equal_approx(right.modulate.a, 0.8), "centro 1.0/opaca, laterales 0.75/0.8")
	check(mid.floating and not right.floating, "sólo la isla central flota")
	near(mid.position.x + mid.size.x / 2.0, c.center.x, 1, "la isla seleccionada está centrada")
	await _action("ui_right")
	check(c.index == 1 and c.busy, "derecha avanza al Mundo 2 con animación")
	await _action("ui_right")
	check(c.index == 1, "durante la animación se ignora la entrada")
	await frames(32)
	check(not c.busy and shown.call() == [0, 1, 2], "al terminar se aceptan órdenes y se ven los mundos 1-2-3")
	near(right.position.x + right.size.x / 2.0, c.center.x, 1, "el Mundo 2 llega al centro")
	check(right.scale == Vector2.ONE and is_equal_approx(c.cards[0].scale.x, 0.75) and is_equal_approx(c.cards[0].modulate.a, 0.8), "las escalas y opacidades se intercambian")
	await _action("ui_accept")
	check(refused == [2] and chosen.is_empty(), "un mundo bloqueado no se abre")
	await frames(20)
	await _action("ui_left")
	await frames(32)
	await _action("ui_left")
	await frames(32)
	check(c.index == 7 and shown.call() == [0, 6, 7], "la lista es circular (del 1 se pasa al 8)")
	c.cards[0].clicked.emit(c.cards[0])
	check(c.index == 0, "clic en una isla lateral la lleva al centro")
	await frames(32)
	c.cards[0].clicked.emit(c.cards[0])
	check(chosen == [1], "clic en la isla central entra en el mundo")
	await _action("ui_accept")
	check(chosen == [1, 1], "Enter también entra")
	c.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


func test_menu_keyboard() -> void:
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var list: MenuList = menu.get_children().filter(func(n): return n is MenuList)[0]
	var carousel: WorldCarousel = menu.carousel
	check(list.index == 0 and list.buttons[0] == carousel.focus_slot and carousel.focused, "el menú empieza en el carrusel de mundos")
	var world_before := carousel.index
	await _action("ui_right")
	check(list.index == 0 and carousel.index == (world_before + 1) % 8, "derecha cambia de mundo sin salir del carrusel")
	await frames(32)
	await _action("menu_down")
	check(list.index == 1 and not carousel.focused, "flecha abajo pasa a Música")
	await _action("move_right")
	check(list.index == 2 and carousel.index == (world_before + 1) % 8, "fuera del carrusel, derecha recorre las opciones y no cambia de mundo")
	await _action("menu_up")
	var music_before := AudioManager.music_on
	await _action("menu_accept")
	check(AudioManager.music_on != music_before, "Enter activa la opción (música)")
	await _action("menu_accept")
	check(AudioManager.music_on == music_before, "y vuelve a cambiarla")
	await _action("menu_up")
	check(list.index == 0 and carousel.focused, "flecha arriba vuelve al carrusel")
	list.buttons[3].hovered.emit(list.buttons[3])
	check(list.index == 3, "pasar el ratón por encima selecciona")
	carousel.cards[carousel.index].hovered.emit(carousel.cards[carousel.index])
	check(list.index == 0 and carousel.focused, "pasar el ratón por una isla devuelve el foco al carrusel")
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


# ======================================================================= MUNDO 3
func test_w3_data() -> void:
	var w: Dictionary = C.load_json("res://data/world3/world3.json")
	var b: Dictionary = C.load_json("res://data/world3/world3_boss.json")
	check(w.progress.total == 10000 and w.widthTiles * 16 + b.widthTiles * 16 == 10000, "recorrido total de 10.000 px")
	check(w.sections.map(func(x): return int(x.from)) == [0,1700,3500,5500,7800], "cinco secciones del Mundo 3")
	check(w.checkpoints.size() == 5 and w.dreamCollectibles.filter(func(x): return x.kind == "moon").size() == 3, "cinco checkpoints y tres lunas mágicas")
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
	check(w.checkpoints.size() == 5, "cinco checkpoints")
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
	# el carrusel del menú abre el Mundo 4
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var cards: Array[WorldCard] = menu.carousel.cards
	check(cards[3].data.can_enter() and cards[4].data.can_enter() and not cards[5].data.can_enter(), "el carrusel abre los Mundos 4 y 5 y mantiene cerrado el 6")
	menu.queue_free()
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
	check(w.checkpoints.size() == 5, "cinco checkpoints")
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
			check(level.leaving and SaveManager.is_world_completed(6), "cruza el portal y guarda el Mundo 6 (Parque de las Estrellas)")
			check(SaveManager.unlocked_world() == 7, "desbloquea el Mundo 7")
	SaveManager.reset_progress()


func test_w5_progression() -> void:
	# Sueños Cósmicos (escena World5) es el Mundo 6: Parque de las Estrellas
	SaveManager.reset_progress()
	for i in [1, 2, 3, 4]:
		SaveManager.mark_world_completed(i, 1, 1)
	check(not WorldRegistry.is_playable(6), "el Mundo 6 empieza bloqueado")
	SaveManager.mark_world_completed(5, 1, 1)
	check(WorldRegistry.is_playable(6), "completar el Mundo 5 desbloquea el Mundo 6")
	var key := WorldRegistry.start_run(6)
	check(key == "World5" and GameState.get_v("dreamTotal") == 6 and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 6 (Sueños Cósmicos)")
	check(WorldRegistry.id_for_scene("World5") == 6 and WorldRegistry.id_for_scene("Boss5") == 6, "la escena World5 corresponde al Mundo 6")
	SaveManager.mark_world_completed(6, 180, 246, true, 1000, [], ["moon_1", "moon_2", "moon_3", "special_1"])
	check(SaveManager.unlocked_world() == 7 and SaveManager.get_world(6).dreamCollectibles.size() == 4 and SaveManager.get_world(6).bestStars == 180, "victoria guarda estrellas y coleccionables del Mundo 6")
	check(WorldRegistry.is_playable(7), "la victoria del Mundo 6 abre el Mundo 7")
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 6, "stars": 180, "total": 246, "dream": ["moon_1"], "dreamTotal": 6}
	add_child(v)
	await frames(2)
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(v.world_id == 6 and list.buttons[0].label.text == "Ir al Mundo 7", "la pantalla de victoria ofrece ir al Mundo 7")
	v.queue_free()
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var cards: Array[WorldCard] = menu.carousel.cards
	check(cards[5].data.title == "Parque de las Estrellas" and cards[5].data.state() == WorldData.State.COMPLETED, "la isla Parque de las Estrellas muestra el Mundo 6 completado")
	check(cards[6].data.can_enter() and cards[6].data.describe().ends_with("¡A jugar!"), "el Mundo 7 queda abierto")
	check(cards[7].data.state() == WorldData.State.LOCKED, "el Mundo 8 sigue cerrado")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


# ------------------------------------------------------------------ Mundo 6
func _w6_line(i: int) -> TrainLine:
	return level.level_objects.trains[i]


func _w6_objects(cls: Variant) -> Array:
	return level.level_objects.objects.get_children().filter(func(n): return is_instance_of(n, cls))


func _w6_platforms(cls: Variant) -> Array:
	return level.level_objects.platforms.get_children().filter(func(n): return is_instance_of(n, cls))


func test_w6_train_carry() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(0)
	line.wait_left = 2000
	var car: TrainCar = line.cars[1]
	level.player.position = Vector2(car.position.x, car.surface_y() - 2)
	level.player.velocity = Vector2.ZERO
	await frames(30)
	check(level.player.grounded and level.get("riding_car") != null and level.riding_car() == car, "Alice queda de pie sobre el vagón parado")
	var p0 := level.player.position.x
	var c0 := car.position.x
	var max_err := 0.0
	var fell := false
	for i in 240:
		await frames(1)
		max_err = maxf(max_err, absf((level.player.position.x - p0) - (car.position.x - c0)))
		if not level.player.grounded:
			fell = true
	print("  train: car moved %.1f px, player moved %.1f, err %.2f, fell %s, v=%.1f" % [car.position.x - c0, level.player.position.x - p0, max_err, fell, line.v])
	check(car.position.x - c0 > 40, "el tren arranca y avanza")
	check(not fell and max_err < 3, "el vagón transporta a Alice sin que se caiga ni resbale")


func _w6_ride(line: TrainLine, car_i: int, max_frames: int) -> Dictionary:
	var car: TrainCar = line.cars[car_i]
	level.player.position = Vector2(car.position.x, car.surface_y() - 2)
	level.player.velocity = Vector2.ZERO
	var out := {"fell": false, "max_err": 0.0, "min_y": INF, "arrived": false}
	await frames(20)
	var p0 := level.player.position
	var c0 := car.position
	for i in max_frames:
		await frames(1)
		var e := (level.player.position - p0) - (car.position - c0)
		if e.length() > out.max_err:
			out["worst"] = [e, line.s, level.player.grounded]
		if OS.get_cmdline_user_args().has("ride_log") and i % 20 == 0:
			print("    s=%.0f v=%.1f err=(%.2f,%.2f) g=%s pv=%.1f wait=%.0f" % [line.s, line.v, e.x, e.y, level.player.grounded, level.player.velocity.x, line.wait_left])
		out.max_err = maxf(out.max_err, e.length())
		out.min_y = minf(out.min_y, car.position.y)
		# se cae si deja de estar encima del vagón (unos fotogramas sin apoyo al arrancar no cuentan)
		if absf(level.player.position.y - car.surface_y()) > 14 or level.player.position.y > level.world_h:
			out.fell = true
			out["fell_at"] = level.player.position
			break
		if line.is_waiting() and line.s >= line.s_max() - 1:
			out.arrived = true
			break
	return out


func test_w6_train_slope() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(4)
	line.wait_left = 300
	var r := await _w6_ride(line, 1, 1400)
	check(r.arrived and not r.fell and r.max_err < 4, "Alice viaja en el tren por las pendientes hasta el final sin resbalar (%.1f px)" % r.max_err)
	check(r.min_y < 15 * C.TILE, "el recorrido sube la pendiente")


func test_w6_train_stations() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(4)
	var waits := []
	line.wait_left = 10
	var was := false
	for i in 1400:
		await frames(1)
		if line.is_waiting() and not was:
			waits.append(snappedf(line.cars[0].position.x / C.TILE, 0.1))
		was = line.is_waiting()
	check(waits.size() >= 2 and absf(waits[0] - 367) < 1.5, "el tren se detiene en la estación intermedia (%s)" % str(waits))


func test_w6_walk_along_train() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(4)
	line.wait_left = 100000
	var rear: TrainCar = line.cars[line.cars.size() - 1]
	level.player.position = Vector2(rear.position.x, rear.surface_y() - 2)
	await frames(15)
	hold(["move_right"])
	var ok := true
	for i in 70:
		await frames(1)
		if absf(level.player.position.y - rear.surface_y()) > 3:
			ok = false
	hold([])
	check(ok and level.player.position.x > line.cars[0].position.x - 10, "Alice camina por todo el tren hasta la locomotora sin caerse entre vagones (%.0f / %.0f)" % [level.player.position.x, line.cars[0].position.x])
	var tops: Array = line.cars.map(func(c): return snappedf(c.surface_y(), 0.5))
	check(tops.all(func(t): return t == tops[0]), "todos los vagones tienen el techo a la misma altura (%s)" % str(tops))


func test_w6_data() -> void:
	var w: Dictionary = C.load_json("res://data/world6/world6.json")
	var b: Dictionary = C.load_json("res://data/world6/world6_boss.json")
	check(w.progress.total == 11008 and w.widthTiles * 16 + b.widthTiles * 16 == 11008, "recorrido total de unos 11.000 px")
	check(w.sections.map(func(x): return int(x.from)) == [0, 1800, 4000, 6300, 8600], "cinco secciones del Mundo 6")
	check(w.checkpoints.size() == 4, "cuatro checkpoints")
	check(w.dreamCollectibles.filter(func(x): return x.kind == "ticket").size() == 3 and w.dreamMain == "ticket", "tres billetes mágicos")
	check(w.trains.size() >= 5 and w.trains.any(func(t): return t.has("branches")) and w.trains.any(func(t): return t.get("bellWait", false)), "trenes con desvíos y tren que espera a la campana")
	check(w.trains.any(func(t): return t.points.any(func(p): return p[1] != t.points[0][1])), "hay vías con pendiente")
	check(w.levers.size() >= 2 and w.bells.size() >= 2 and w.starBlocks.size() >= 3, "palancas, campanas y bloques de estrella")
	check(w.helis.any(func(h): return h.get("dx", 0) == 0 and h.get("dy", 0) == 0) and w.helis.any(func(h): return h.get("dx", 0) != 0) and w.helis.any(func(h): return h.get("dy", 0) != 0), "hélices fija, horizontal y vertical")
	check(w.rainbowArches.size() >= 2 and w.fallingBlocks.size() >= 3 and w.rollingWheels.size() >= 2 and w.bumpers.size() >= 1, "puentes arcoíris, bloques que caen, ruedas y barreras")
	check(w.pads.any(func(p): return p.frame == "toy_spring") and w.hazardTrains.size() >= 1, "resortes de juguete y tren enemigo")
	check(w.hazards.all(func(h): return h.get("spin", false)), "las hélices que dañan están marcadas como obstáculo")
	var types := {}
	for e in w.enemies: types[e.type] = true
	check(types.has("payasito") and types.has("bloquecito") and types.has("vagoncito"), "los tres enemigos oficiales")
	check(String(b.boss.scene).ends_with("Locomostro.tscn"), "arena con Locomostro")
	var manifest: Dictionary = C.load_json("res://data/world6/world6_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "manifiesto de recursos sin pendientes")
	for src in ["imagenes/word_6.png", "imagenes/tilesets_world_6.png", "imagenes/enemies_world_6.png", "imagenes/jefemundo6.png"]:
		check(manifest.resources.any(func(r): return r.get("source") == src), "usa la referencia oficial %s" % src)
	check(manifest.resources.any(func(r): return r.has("reused")), "el manifiesto documenta los cuadros reutilizados")


func test_w6_sprites() -> void:
	var expected := {
		"payasito": {"idle": 3, "jump": 3, "walk": 2, "attack": 3, "hurt": 3, "defeated": 2},
		"bloquecito": {"idle": 3, "walk": 4, "attack": 4, "hurt": 3, "defeated": 3},
		"vagoncito": {"idle": 3, "walk": 3, "attack": 3, "hurt": 2, "defeated": 3},
		"locomostro": {"idle": 4, "move": 6, "wind_attack": 4, "block_attack": 4, "charge": 4, "stunned": 2, "hurt": 1, "defeated": 3},
	}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		for a in expected[key]:
			check(sf.has_animation(a) and sf.get_frame_count(a) == expected[key][a], "%s/%s conserva sus fotogramas" % [key, a])
	check(Assets.tileset("world6_tiles") != null, "TileSet nativo del Mundo 6")
	for atlas in ["world6_objects", "world6_bg", "w6_fx"]:
		check(Assets.atlases.has(atlas), "atlas %s cargado" % atlas)
	for d in ["payasito", "bloquecito", "vagoncito"]:
		check(Assets.enemy_def(d) != null, "EnemyDef de %s" % d)


func test_w6_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World6")
	await settle()
	check(level.data.key == "world6" and level.player.grounded, "Mundo 6 carga con Alice sobre terreno real")
	check(Assets.used_placeholders.is_empty(), "Mundo 6 no usa marcadores provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(GameState.get_v("weaponsOwned").size() == 3, "reutiliza las tres armas")
	check(level.level_objects.trains.size() == level.data.trains.size(), "crea los trenes")
	var cars := 0
	for t in level.data.trains: cars += t.cars.size()
	check(level.level_objects.movers.filter(func(m): return m is TrainCar).size() == cars, "cada vagón es una plataforma móvil (AnimatableBody2D)")
	check(level.level_objects.trains.all(func(t): return t.path is Path2D and t.path.curve.get_baked_length() > 0), "las vías son rutas Path2D")
	check(level.level_objects.movers.filter(func(m): return m is HeliPlatform).size() == level.data.helis.size(), "crea las plataformas con hélice")
	check(_w6_platforms(RainbowArch).size() == level.data.rainbowArches.size() and _w6_platforms(FallingBlock).size() == level.data.fallingBlocks.size(), "crea puentes arcoíris y bloques que caen")
	check(_w6_objects(RollingWheel).size() == level.data.rollingWheels.size() and _w6_objects(StarBumper).size() == level.data.bumpers.size() and _w6_objects(HazardTrain).size() == level.data.hazardTrains.size(), "crea ruedas, barreras y trenes enemigos")
	check(level.level_objects.levers.size() == level.data.levers.size() and level.level_objects.bells.size() == level.data.bells.size(), "crea palancas y campanas")
	var ts: Dictionary = Assets.tileset_data("world6_tiles")
	var idx := func(c: Vector2i) -> int: return c.y * 8 + c.x
	var ints := func(a: Array) -> Array: return a.map(func(v): return int(v))
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 20))) in ints.call(ts.materials.cloud.cap0), "autotiling: nube rosada sobre los bloques azules")
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 23))) in ints.call(ts.materials.cloud.body), "bajo la superficie se repite el bloque azul")
	var td: TileData = level.builder.layer.get_cell_tile_data(Vector2i(4, 20))
	check(td != null and td.get_collision_polygons_count(0) == 1, "las teselas tienen colisión del TileSet")
	check(GameState.get_v("dreamHud")[1] == "ticket" and level.hud.get("moon_icons")[0].texture != null, "el HUD muestra los billetes")
	check(level.parallax.get_children().all(func(l): return l.z_index < C.Z_TERRAIN), "parallax detrás del terreno")
	var scrolls := {}
	for l in level.parallax.get_children():
		scrolls[snappedf(l.scroll_scale.x, 0.01)] = true
	check(scrolls.size() >= 5, "capas de fondo con velocidades distintas (%d)" % scrolls.size())
	var front: Array = level.world_root.get_node("Decor").get_children().filter(func(d): return d.z_index == C.Z_DECOR_FRONT)
	check(front.all(func(d): return d.texture.get_height() <= 20), "la decoración delantera es pequeña y baja")


func test_w6_layout() -> void:
	await load_level("World6")
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
		if not level.terrain_solid_at(Vector2(x, y + 4)) or level.terrain_solid_at(Vector2(x, y - 8)):
			bad.append("%s@%s" % [d.type, d.x])
	check(bad.is_empty(), "monstruos colocados sobre suelo libre (%s)" % str(bad))
	for c in level.data.dreamCollectibles:
		check(not level.terrain_solid_at(Vector2(float(c.x) * C.TILE + 8, float(c.y) * C.TILE + 8)), "%s accesible (fuera del terreno)" % c.id)
	# las vías tienen el paso libre: nada sólido por encima del carril (los vagones no chocan)
	var blocked: Array = []
	for line in level.level_objects.trains:
		var d := 0.0
		while d < line.length():
			var p: Vector2 = line.rail_point(d)
			for dy in [-8, -18, -30]:
				if level.terrain_solid_at(p + Vector2(0, dy)):
					blocked.append("%d" % int(p.x / C.TILE))
			d += 8.0
	check(blocked.is_empty(), "las vías tienen el paso libre por encima (%s)" % str(blocked))
	# ningún enemigo cerca de la estación de un tren que cruza un hueco (no empujan al vacío)
	var near_station: Array = []
	for line in level.level_objects.trains:
		var x0: float = line.common[0].x
		for d in level.data.enemies:
			if absf(float(d.x) * C.TILE - x0) < 5 * C.TILE:
				near_station.append("%s@%s" % [d.type, d.x])
	check(near_station.is_empty(), "las estaciones donde se espera el tren están libres de monstruos (%s)" % str(near_station))


func test_w6_switch() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(1)
	var lever: RailLever = level.level_objects.levers[0]
	check(line.branch == 0 and lever.train == line, "la primera palanca controla el tren de la pendiente")
	var end_a: Vector2 = line.rail_point(line.length())
	# el tren va por el ramal: el cambio queda pendiente hasta el punto seguro
	line.wait_left = 0
	line.s = line.decision_s + 40
	line.dir = 1
	lever.ready_at = 0
	lever.toggle()
	check(lever.state == 1 and line.pending_branch == 1 and line.branch == 0, "con el tren en el ramal el desvío no cambia de golpe")
	check(lever.sprite.flip_h and line.rails[2].modulate.a < 0.5, "la palanca cambia de posición; el ramal nuevo aún no está activo")
	await frames(2)
	check(line.branch == 0, "no cambia de ruta a mitad de la curva")
	line.s = line.decision_s - 10
	await frames(2)
	check(line.branch == 1 and line.rails[2].modulate.a > 0.9, "toma el ramal nuevo en el punto seguro y se actualiza la vía")
	var end_b: Vector2 = line.rail_point(line.length())
	check(end_b.distance_to(end_a) > 3 * C.TILE and end_b.y > end_a.y, "el ramal B lleva a la isla baja")
	# tocar la palanca también la acciona, una sola vez por contacto
	await frames(30)
	var st := lever.state
	level.player.position = lever.position
	await frames(10)
	check(lever.state != st, "al tocarla se acciona")
	var st2 := lever.state
	await frames(40)
	check(lever.state == st2, "quedarse encima no la vuelve a mover")


func test_w6_bell_train() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(3)
	check(line.bell_wait, "el tren rápido espera a la campana")
	await frames(240)
	check(line.is_waiting() and line.s <= line.s_min() + 1, "sin campana no sale de su estación")
	var bell: StationBell = level.level_objects.bells[1]
	check(bell.train == line, "la campana de la isla llama a ese tren")
	bell.ring()
	check(line.called, "la campana avisa al tren")
	await frames(30)
	check(line.is_waiting(), "deja tiempo para subir antes de salir")
	await frames(110)
	check(not line.is_waiting() and line.s > line.s_min() + 4, "después de la campana el tren sale")
	var found_end := false
	for i in 600:
		await frames(1)
		if line.is_waiting() and line.s >= line.s_max() - 1:
			found_end = true
			break
	check(found_end, "llega a la estación del otro lado")
	for i in 900:
		await frames(1)
		if line.is_waiting() and line.s <= line.s_min() + 1:
			break
	check(line.s <= line.s_min() + 1, "vuelve solo a su estación (nunca se queda al otro lado)")


func test_w6_helis() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var helis: Array = level.level_objects.movers.filter(func(m): return m is HeliPlatform)
	var fixed: HeliPlatform = helis.filter(func(h): return h.is_static())[0]
	var horiz: HeliPlatform = helis.filter(func(h): return h.delta_px.x != 0)[0]
	var vert: HeliPlatform = helis.filter(func(h): return h.delta_px.y != 0)[0]
	var f0 := fixed.position
	var h0 := horiz.position
	var v0 := vert.position
	var s0: float = fixed.prop.scale.x
	await frames(30)
	check(fixed.position == f0 and absf(fixed.prop.scale.x - s0) > 0.01, "la hélice fija no se mueve pero su hélice gira")
	check(absf(horiz.position.x - h0.x) > 2 and absf(horiz.position.y - h0.y) < 0.5, "la hélice horizontal se desplaza de lado")
	check(absf(vert.position.y - v0.y) > 2 and absf(vert.position.x - v0.x) < 0.5, "la hélice vertical sube y baja")
	level.player.invulnerable_until = 0
	var hp := level.player.hp
	level.player.position = fixed.position + Vector2(0, 2)
	level.player.velocity = Vector2.ZERO
	await frames(30)
	check(level.player.grounded and level.player.hp == hp, "Alice se apoya en la plataforma con hélice sin recibir daño")


func test_w6_rainbow_arch() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var arch: RainbowArch = _w6_platforms(RainbowArch)[0]
	var mid := (arch.points[0].x + arch.points[arch.points.size() - 1].x) / 2.0
	level.player.position = Vector2(mid, arch.surface_at(mid) - 30)
	level.player.velocity = Vector2.ZERO
	await frames(40)
	check(level.player.grounded and absf(level.player.position.y - arch.surface_at(mid)) < 3, "Alice camina sobre la curva del puente arcoíris")
	var space := level.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.position = Vector2(mid, arch.surface_at(mid) + 20)
	q.collision_mask = C.L_ONE_WAY | C.L_WORLD
	check(space.intersect_point(q).is_empty(), "el espacio bajo el arco está libre (sin rectángulos grandes)")
	var high: RainbowArch = _w6_platforms(RainbowArch)[1]
	var train: HazardTrain = _w6_objects(HazardTrain)[0]
	var top := INF
	for x in range(int(train.x0) + 8, int(train.x1) - 8, 8):
		top = minf(top, train.rail_y - high.surface_at(x))
	check(top > train.train.texture.get_height(), "el segundo arco pasa por encima del tren enemigo")


func test_w6_falling_block() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var fb: FallingBlock = _w6_platforms(FallingBlock)[0]
	place(fb.position.x / C.TILE - 0.5, 19); await frames(3)
	level.player.invulnerable_until = 0
	var hp := level.player.hp
	await frames(4)
	check(fb.state == "WARNING", "el bloque avisa al pasar por debajo (tiembla)")
	await frames(int(FallingBlock.WARN_MS / 1000.0 * 60) - 12)
	check(fb.state == "WARNING" and level.player.hp == hp, "durante el aviso no hace daño (tiempo para apartarse)")
	var hit := false
	for i in 60:
		await frames(1)
		hit = hit or level.player.hp < hp
	check(hit, "si Alice se queda debajo, el bloque le quita un corazón")
	for i in 60:
		await frames(1)
		if fb.state == "RESTING": break
	check(fb.state == "RESTING", "el bloque se queda en el suelo")
	await frames(int((FallingBlock.REST_MS + FallingBlock.RESET_MS + 600) / 1000.0 * 60) + 20)
	check(fb.state == "IDLE" and is_equal_approx(fb.position.y, fb.top_y), "vuelve a su sitio (IDLE -> WARNING -> FALLING -> RESTING -> RESET)")
	level.player.invulnerable_until = 0
	hp = level.player.hp
	place(fb.position.x / C.TILE - 0.5, 19); await frames(4)
	place(fb.position.x / C.TILE + 3, 19)
	await frames(120)
	check(level.player.hp == hp, "apartándose durante el aviso el bloque no la toca")


func test_w6_spring_wheel_bumper() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var spring: BouncePad = _w6_objects(BouncePad).filter(func(p): return p.position.x > 420 * C.TILE)[0]
	level.player.position = spring.position + Vector2(0, -20); level.player.velocity.y = 80
	await frames(3)
	check(level.player.velocity.y < -400, "el resorte de juguete impulsa a Alice hacia arriba")
	check(spring.sprite.scale.y < 1.0, "el resorte se comprime")
	await frames(20)
	check(is_equal_approx(spring.sprite.scale.y, 1.0), "y recupera su forma")
	var wheel: RollingWheel = _w6_objects(RollingWheel)[0]
	var a := wheel.point_at(wheel.distance_at(1234.0))
	var b := wheel.point_at(wheel.distance_at(1234.0 + wheel.period()))
	check(a.is_equal_approx(b) and wheel.total > 0, "la rueda repite siempre el mismo recorrido")
	var r0 := wheel.sprite.rotation
	await frames(20)
	check(absf(wheel.sprite.rotation - r0) > 0.1 or not wheel.visible, "la rueda gira al rodar")
	var bumper: StarBumper = _w6_objects(StarBumper)[0]
	place(bumper.position.x / C.TILE - 1.5, 17); await frames(3)
	level.player.invulnerable_until = 0
	var hp := level.player.hp
	level.player.position = bumper.position + Vector2(-8, -2)
	await frames(3)
	check(level.player.velocity.x < 0 and level.player.velocity.y < 0 and level.player.hp == hp, "la barrera de estrella aparta a Alice sin quitarle corazones")


func test_w6_hazard_train() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var ht: HazardTrain = _w6_objects(HazardTrain)[0]
	place(ht.x0 / C.TILE + 3, 19); await frames(3)
	level.player.invulnerable_until = 0
	ht.delay = fposmod(level.now + 30, ht.period)
	await frames(6)
	var hp := level.player.hp
	check(ht.phase_at(level.now) == "warn" and not ht.train.visible, "el tren enemigo avisa con señal roja y silbato antes de salir")
	await frames(int(HazardTrain.WARN_MS / 1000.0 * 60) - 12)
	check(level.player.hp == hp, "durante el aviso no hace daño")
	var hit := false
	for i in 120:
		await frames(1)
		hit = hit or level.player.hp < hp
	check(hit, "si Alice se queda en la vía, el tren le quita un corazón")
	await frames(400)
	place(ht.x0 / C.TILE - 3, 19); await frames(3)
	level.player.invulnerable_until = 0
	hp = level.player.hp
	ht.delay = fposmod(level.now + 30, ht.period)
	await frames(int((HazardTrain.WARN_MS + ht.run_ms()) / 1000.0 * 60) + 20)
	check(level.player.hp == hp, "esperando antes del túnel el tren no la toca")
	check(ht.phase_at(level.now) == "clear" and ht.time_to_warn(level.now) > 2000, "después queda la vía libre con tiempo para cruzar")


func test_w6_collectibles() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var sb: StarBlock = level.level_objects.star_blocks[0]
	var bonus0 := level.bonus_root.get_child_count()
	level.player.position = sb.position + Vector2(0, 40)
	level.player.velocity = Vector2(0, -330)
	await frames(20)
	check(level.bonus_root.get_child_count() > bonus0, "el bloque de estrella suelta una estrella al golpearlo desde abajo")
	var left := sb.left
	sb.ready_at = 0
	var p: Projectile = level.spawn_projectile("player", {"x": sb.position.x - 40, "y": sb.position.y, "vx": 250, "vy": 0, "kind": "paint", "frame": "pellet", "lifespan": 600})
	p.weapon = Assets.weapon("paint")
	await frames(20)
	check(sb.left < left or sb.is_empty(), "un disparo también lo activa")
	var bell: StationBell = level.level_objects.bells[0]
	var b0 := level.bonus_root.get_child_count()
	bell.ring()
	check(bell.rung_once and level.bonus_root.get_child_count() > b0, "la campana suena y regala una estrella")
	var tickets: Array = _w6_objects(DreamCollectible).filter(func(d): return d.kind == "ticket")
	check(tickets.size() == 3, "tres billetes en el mapa")
	level.player.position = tickets[0].position
	await frames(4)
	check("ticket_1" in GameState.get_v("dreamCollectibles", []), "el billete queda registrado")


func _w6_spawn(type: String, dx: float, dy := 0.0, extra := {}) -> Enemy:
	var e: Enemy = EnemySpawner.SCENES[type].instantiate()
	var p := level.player.position
	var s := {"id": "test_" + type + str(randi()), "x": p.x + dx, "y": p.y + dy, "patrol": [p.x + dx - 40, p.x + dx + 40]}
	s.merge(extra, true)
	e.setup(level, s)
	level.enemies_root.add_child(e)
	return e


func test_w6_enemies() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	place(90, 19); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	# Payasito Resorte: tiembla, salta en parábola, lanza estrellas y vuelve a su caja
	var clown := _w6_spawn("payasito", 60)
	await frames(20)
	var home := clown.position
	clown.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(clown is PayasitoMonster and clown.sprite.animation == "jump" and clown.grounded and _w5_shots("clown_star") == 0, "la caja tiembla antes de saltar (aviso)")
	var min_y := clown.position.y
	var shot := false
	for i in 90:
		await frames(1)
		min_y = minf(min_y, clown.position.y)
		shot = shot or _w5_shots("clown_star") > 0
	check(home.y - min_y > 30, "salta hacia arriba con el resorte")
	check(shot, "lanza estrellas desde lo alto")
	await frames(60)
	check(absf(clown.position.x - home.x) < 2 and clown.grounded, "vuelve a su posición")
	check(clown.fsm.current != Enemy.ATTACK and clown.attack_ready_at > level.now, "espera antes de repetir")
	clown.queue_free()
	# Bloquecito Travieso: se detiene, retrocede (aviso) y embiste; no cae por los bordes
	var cube := _w6_spawn("bloquecito", 70)
	await frames(20)
	cube.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(cube is BloquecitoMonster and cube.sprite.animation == "attack" and not cube.charging, "cambia de expresión y retrocede antes de embestir")
	await frames(30)
	check(cube.charging and absf(cube.velocity.x) > 150, "embiste en horizontal")
	cube.queue_free()
	place(110, 19); await frames(3)
	var edge := _w6_spawn("bloquecito", 4 * C.TILE, 0, {"patrol": [100 * C.TILE, 140 * C.TILE], "facing": 1})
	level.player.position.x = 60 * C.TILE
	edge.fsm.set_state(Enemy.PATROL)
	await frames(240)
	check(edge.position.y < level.world_h and edge.position.x < 126 * C.TILE, "patrulla sin caerse por el borde")
	edge.queue_free()
	# Vagoncito Chispa: chispas, aceleración y nube de humo (siempre en ese orden)
	place(90, 19); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	var wagon := _w6_spawn("vagoncito", 70)
	await frames(20)
	wagon.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(wagon is VagoncitoMonster and wagon.current == "SPARKS" and _w5_shots("spark") == 0, "avisa antes de lanzar chispas")
	await frames(40)
	check(_w5_shots("spark") >= 1, "lanza chispas estelares")
	await frames(60)
	wagon.fsm.set_state(Enemy.ATTACK); await frames(45)
	check(wagon.current == "DASH" and absf(wagon.velocity.x) > 120, "acelera en horizontal")
	await frames(80)
	wagon.fsm.set_state(Enemy.ATTACK); await frames(50)
	var smoke: Array = level.fx_root.get_children().filter(func(n): return n.has_meta("smoke"))
	check(wagon.current == "SMOKE" and smoke.size() == 1, "suelta una nube de humo")
	if smoke.size() == 1:
		check(smoke[0].modulate.a < 0.7, "la nube no oculta del todo a Alice (translúcida)")
	wagon.queue_free()
	await get_tree().process_frame


func test_w6_weapons_vs_enemies() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	place(90, 19); await frames(3)
	for type in ["payasito", "bloquecito", "vagoncito"]:
		for wid in ["bubble", "paint", "sling"]:
			var e := _w6_spawn(type, 60)
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
	for type in ["payasito", "bloquecito", "vagoncito"]:
		var cell := Assets.cell_size(type)
		var body: Vector2 = Assets.enemy_def(type).body_size
		check(body.x < cell.x and body.y < cell.y, "%s tiene hitbox propia más pequeña que el dibujo" % type)


func test_w6_camera() -> void:
	await load_level("World6")
	await settle(); _clear_spawner()
	var line := _w6_line(4)
	line.wait_left = 400
	var car: TrainCar = line.cars[1]
	level.player.position = Vector2(car.position.x, car.surface_y() - 2)
	level.camera.snap_to_target()
	await frames(20)
	var max_jump := 0.0
	var prev := level.camera.position
	var looked := false
	for i in 300:
		await frames(1)
		max_jump = maxf(max_jump, level.camera.position.distance_to(prev))
		prev = level.camera.position
		if level.riding_car() != null and line.velocity_x > 30 and level.look_ahead > 10:
			looked = true
	check(max_jump <= 4.0, "la cámara sigue al tren sin saltos bruscos (máx. %.1f px por fotograma)" % max_jump)
	check(looked, "la cámara se anticipa hacia donde avanza el tren")
	var view: Rect2 = level.camera.view_rect()
	check(view.position.x >= 0 and view.end.x <= level.world_w + 1, "la cámara respeta los límites del mundo")


func test_w6_boss() -> void:
	await load_level("Boss6", func(): GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(170)
	var boss: Locomostro = level.boss
	check(boss != null and boss.max_hp == 60 and not boss.invulnerable, "Locomostro entra vulnerable con 60 HP")
	check(level.terrain_solid_at(Vector2(5 * C.TILE + 8, 12 * C.TILE + 8)), "la arena queda cerrada durante el combate")
	var top: float = boss.position.y + boss.shape.position.y - (boss.shape.shape as RectangleShape2D).size.y / 2.0
	check(top > 11 * C.TILE + 2, "el cuerpo de Locomostro es más bajo que las nubes de la arena (la embestida se esquiva arriba)")
	var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
	p.weapon = Assets.weapon("sling")
	p.active = false
	boss.hp = 40; boss.hit_by(p)
	check(boss.phase == 2, "cambia a la fase 2 (La carga del ferrocarril) al 65%")
	boss.invulnerable = false; boss.hp = 19; boss.hit_by(p)
	check(boss.phase == 3, "cambia a la fase 3 (El expreso arcoíris) al 30%")
	for phase in [1, 2, 3]:
		for atk in Locomostro.PHASES[phase].pattern:
			boss.phase = phase
			boss.invulnerable = false
			boss.timers.clear()
			boss.velocity.x = 0
			boss.position.x = (boss.min_x + boss.max_x) / 2.0
			level.kill_enemy_projectiles()
			boss.fsm.set_state(atk)
			await frames(12)
			var early := level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active).size()
			check(early == 0 and absf(boss.velocity.x) < 1, "%s tiene anticipación (nada sale al empezar)" % atk)
			var guard := 0
			var acted := false
			while boss.fsm.current == atk and guard < 900:
				guard += 1
				if level.enemy_projectiles.get_children().any(func(n): return n is Projectile and n.active) or absf(boss.velocity.x) > 140:
					acted = true
				level.player.invulnerable_until = level.now + 100000
				await frames(1)
			check(acted, "%s lanza su ataque" % atk)
			check(boss.fsm.current == "REST", "%s termina en un descanso vulnerable" % atk)
	# la embestida sigue una ruta fija: de un extremo de la arena al otro
	boss.phase = 2
	boss.timers.clear()
	boss.position.x = boss.min_x + 60
	boss.fsm.set_state("CHARGE")
	var xs: Array = []
	while boss.fsm.current == "CHARGE":
		xs.append(boss.position.x)
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(xs.min() <= boss.min_x + 1 and xs.max() >= boss.max_x - 1, "la embestida recorre la arena de un extremo al otro")
	check(boss.sprite.animation == "stunned", "al terminar la embestida queda aturdido (vulnerable)")
	boss.invulnerable = false; boss.hp = 1; boss.hit_by(p)
	check(boss.is_defeated(), "puede ser derrotado")


func test_w6_boss_victory() -> void:
	SaveManager.reset_progress()
	await load_level("Boss6", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(170)
	var boss: Locomostro = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	var seen := {}
	var guard := 0
	var prev := ""
	while not boss.is_defeated() and guard < 16000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		if boss.fsm.current == "REST" and prev != "REST" and not boss.invulnerable:
			for w in ["sling", "paint"]:
				var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": w, "frame": "pellet", "lifespan": 100})
				p.weapon = Assets.weapon(w)
				p.active = false
				boss.hit_by(p)
		prev = boss.fsm.current
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(boss.is_defeated() and seen.has("phase2") and seen.has("phase3"), "combate completo con las tres fases")
	for s in ["SMOKE", "BLOCK_TOSS", "WHIRLS", "CHARGE", "EXPRESS", "MULTI_BLOCKS", "DOUBLE_SMOKE", "COMBO"]:
		check(seen.has(s), "usa el ataque %s" % s)
	await frames(2)
	check(boss.sprite.speed_scale < 1.0, "reduce la velocidad y sus ruedas se van parando")
	await frames(70)
	check(boss.sprite.animation == "defeated" and boss.sprite.frame == 0, "ojos cansados; el humo se vuelve nubecitas blancas")
	await frames(60)
	check(boss.sprite.frame == 1, "caen sus bloques de juguete alrededor")
	await frames(60)
	check(absf(boss.sprite.rotation_degrees) > 1, "la locomotora se inclina un poco")
	await frames(90)
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(boss.sprite.animation == "defeated" and boss.sprite.frame == 2, "Locomostro se queda dormido")
	check(star.size() == 1, "entrega la estrella especial")
	if star.size() == 1:
		level.player.position = star[0].position + Vector2(0, 10)
		await frames(60)
		check(GameState.get_v("specialStar") == true and level.portal != null, "recoge la estrella especial y se abre el portal")
		if level.portal:
			level.player.position = level.portal.position
			await frames(5)
			check(level.leaving and SaveManager.is_world_completed(5), "cruza el portal y guarda el Mundo 5 (Juguetes)")
			check(SaveManager.unlocked_world() == 6, "desbloquea el Mundo 6")
	SaveManager.reset_progress()


func test_w6_progression() -> void:
	# El Reino del Tren de Juguete (escena World6) es el Mundo 5: Juguetes
	SaveManager.reset_progress()
	for i in [1, 2, 3]:
		SaveManager.mark_world_completed(i, 1, 1)
	check(not WorldRegistry.is_playable(5), "el Mundo 5 empieza bloqueado")
	SaveManager.mark_world_completed(4, 1, 1)
	check(WorldRegistry.is_playable(5), "completar el Mundo 4 desbloquea el Mundo 5")
	var key := WorldRegistry.start_run(5)
	check(key == "World6" and GameState.get_v("dreamTotal") == 3 and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 5 (Tren de Juguete)")
	check(WorldRegistry.id_for_scene("World6") == 5 and WorldRegistry.id_for_scene("Boss6") == 5, "la escena World6 corresponde al Mundo 5")
	SaveManager.mark_world_completed(5, 200, 237, true, 1000, [], ["ticket_1", "ticket_3"])
	check(SaveManager.unlocked_world() == 6 and SaveManager.get_world(5).dreamCollectibles.size() == 2 and SaveManager.get_world(5).bestStars == 200, "victoria guarda estrellas y billetes del Mundo 5")
	check(WorldRegistry.is_playable(6), "la victoria del Mundo 5 abre el Mundo 6")
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 5, "stars": 200, "total": 237, "dream": ["ticket_1"], "dreamTotal": 3}
	add_child(v)
	await frames(2)
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(v.world_id == 5 and list.buttons[0].label.text == "Ir al Mundo 6", "la pantalla de victoria ofrece ir al Mundo 6")
	v.queue_free()
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var cards: Array[WorldCard] = menu.carousel.cards
	check(cards[4].data.title == "Juguetes" and cards[4].data.state() == WorldData.State.COMPLETED, "la isla Juguetes muestra el Mundo 5 completado")
	check(cards[5].data.can_enter() and not cards[6].data.can_enter(), "el carrusel abre el Mundo 6 y mantiene cerrado el 7")
	check(menu.carousel.index == 5, "el carrusel empieza en el Mundo 6")
	menu.queue_free()
	await get_tree().process_frame
	# guardado antiguo (versión 1): el 5 era Sueños Cósmicos y el 6 el Tren
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "unlockedWorld": 6, "worlds": {"5": {"completed": true, "bestStars": 77}}}))
	f.close()
	SaveManager.load_state()
	check(SaveManager.is_world_completed(6) and SaveManager.get_world(6).bestStars == 77 and not SaveManager.is_world_completed(5), "un guardado antiguo pasa Sueños Cósmicos al Mundo 6")
	check(WorldRegistry.is_playable(5) and WorldRegistry.is_playable(6), "y conserva abiertos el Tren (5) y Sueños Cósmicos (6)")
	SaveManager.reset_progress()


# ======================================================================= MUNDO 7
func test_w7_data() -> void:
	var w: Dictionary = C.load_json("res://data/world7/world7.json")
	var b: Dictionary = C.load_json("res://data/world7/world7_boss.json")
	check(w.progress.total == 11504 and w.widthTiles * 16 + b.widthTiles * 16 == 11504, "recorrido total de unos 11.500 px")
	check(w.sections.map(func(x): return int(x.from)) == [0, 2000, 4200, 6500, 9000], "cinco secciones A-E en 0/2.000/4.200/6.500/9.000")
	check(w.checkpoints.size() == 6, "seis checkpoints")
	var cp_x: Array = w.checkpoints.map(func(c): return float(c.x) * 16)
	check(cp_x[1] >= 2000 and cp_x[1] < 4200 and cp_x[4] >= 6500 and cp_x[4] < 9000, "los checkpoints originales siguen en las secciones B y D")
	check(w.dreamCollectibles.filter(func(x): return x.kind == "candy").size() == 3 and w.dreamMain == "candy", "tres caramelos especiales")
	check(w.dreamCollectibles.any(func(x): return x.kind == "cherry") and w.dreamCollectibles.any(func(x): return x.kind == "cake") and w.hearts.size() >= 3, "cereza dorada, trozo de pastel y corazones")
	check(w.clouds.filter(func(c): return float(c.get("bouncy", 0)) < 0).size() >= 3, "gelatinas elásticas")
	check(w.paints.any(func(p): return p.color == "caramel") and w.paints.any(func(p): return p.color == "choco"), "caramelo resbaladizo y chocolate pegajoso")
	check(w.belts.size() >= 3 and w.belts.any(func(x): return x.dir < 0), "correas de chocolate en los dos sentidos")
	check(w.lollipops.size() >= 2 and w.launchers.size() >= 2 and w.chocoJets.size() >= 2 and w.crumbles.size() >= 3, "piruletas giratorias, lanzadores, chorros y gelatinas que desaparecen")
	check(w.movers.size() >= 2 and w.starBlocks.size() >= 3 and w.hazards.all(func(h): return h.get("shape", "") == "spikes"), "plataformas móviles, bloques de premio y plataformas con pinchos")
	check(w.slopes.any(func(s): return s.mat == "caramel"), "tobogán de caramelo con rampas")
	var types := {}
	for e in w.enemies: types[e.type] = true
	check(types.has("cuppy") and types.has("gomilito") and types.has("piruleta"), "los tres enemigos oficiales")
	var first_gomi: Array = w.enemies.filter(func(e): return e.type == "gomilito")
	check(float(first_gomi[0].x) * 16 < 2000, "el primer Gomilito aparece en la sección A")
	check(String(b.boss.scene).ends_with("DonChupeton.tscn") and int(b.worldId) == 7, "arena con Don Chupetón")
	var manifest: Dictionary = C.load_json("res://data/world7/world7_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "manifiesto de recursos sin pendientes")
	for src in ["imagenes/word_7.png", "imagenes/tilesets_world_7.png", "imagenes/enemies_world_7.png", "imagenes/jefemundo7.png"]:
		check(manifest.resources.any(func(r): return r.get("source") == src), "usa la referencia oficial %s" % src)
	check(manifest.resources.any(func(r): return r.has("reused")), "el manifiesto documenta los cuadros reutilizados")


func test_w7_sprites() -> void:
	var expected := {
		"cuppy": {"idle": 3, "walk": 3, "jump": 2, "attack": 2, "hurt": 2, "defeated": 1},
		"gomilito": {"idle": 2, "jump": 2, "walk": 2, "attack": 2, "split": 2, "hurt": 1, "defeated": 1},
		"gomilito_mini": {"pink": 1, "blue": 1, "yellow": 1, "green": 1},
		"piruleta": {"idle": 1, "fly": 2, "attack": 1, "shoot": 1, "hurt": 1, "defeated": 1},
		"don_chupeton": {"idle": 4, "move": 6, "candy_attack": 3, "frosting_attack": 3, "spin_attack": 4, "hurt": 3, "stunned": 1, "defeated": 2},
	}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		for a in expected[key]:
			check(sf.has_animation(a) and sf.get_frame_count(a) == expected[key][a], "%s/%s conserva sus fotogramas" % [key, a])
	check(Assets.tileset("world7_tiles") != null, "TileSet nativo del Mundo 7")
	for atlas in ["world7_objects", "world7_bg", "w7_fx"]:
		check(Assets.atlases.has(atlas), "atlas %s cargado" % atlas)
	for d in ["cuppy", "gomilito", "gomilito_mini", "piruleta"]:
		check(Assets.enemy_def(d) != null, "EnemyDef de %s" % d)
	check(Assets.enemy_def("gomilito_mini").hp < Assets.enemy_def("gomilito").hp, "las gomitas pequeñas tienen menos vida")
	var at: AtlasTexture = Assets.sprite_frames("cuppy").get_frame_texture("idle", 0)
	check(at.atlas.get_image().get_pixel(0, 0).a == 0.0, "los sprites conservan la transparencia")


func _w7_objects(cls: Variant) -> Array:
	return level.level_objects.objects.get_children().filter(func(n): return is_instance_of(n, cls))


func _w7_platforms(cls: Variant) -> Array:
	return level.level_objects.platforms.get_children().filter(func(n): return is_instance_of(n, cls))


func test_w7_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World7")
	await settle()
	check(level.data.key == "world7" and level.player.grounded, "Mundo 7 carga con Alice sobre terreno real")
	check(Assets.used_placeholders.is_empty(), "Mundo 7 no usa marcadores provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(GameState.get_v("weaponsOwned").size() == 3, "reutiliza las tres armas")
	check(level.level_objects.belts.size() == level.data.belts.size() and level.level_objects.lollipops.size() == level.data.lollipops.size(), "crea correas y piruletas giratorias")
	check(level.level_objects.launchers.size() == level.data.launchers.size() and level.level_objects.choco_jets.size() == level.data.chocoJets.size(), "crea lanzadores y chorros de chocolate")
	check(_w7_objects(HeartPickup).size() == level.data.hearts.size() and _w7_objects(PaintSurface).size() == level.data.paints.size(), "crea corazones y superficies")
	check(level.level_objects.star_blocks.size() == level.data.starBlocks.size() and level.level_objects.crumbles.size() == level.data.crumbles.size(), "crea bloques de premio y gelatinas que desaparecen")
	var ts: Dictionary = Assets.tileset_data("world7_tiles")
	var idx := func(c: Vector2i) -> int: return c.y * 8 + c.x
	var ints := func(a: Array) -> Array: return a.map(func(v): return int(v))
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 20))) in ints.call(ts.materials.frosting.cap0), "autotiling: glaseado rosa sobre la tierra de chocolate")
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 23))) in ints.call(ts.materials.frosting.body), "bajo la superficie se repite el chocolate")
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(520, 22))) in ints.call(ts.materials.caramel.cap0), "la Fábrica usa el material de caramelo")
	var td: TileData = level.builder.layer.get_cell_tile_data(Vector2i(4, 20))
	check(td != null and td.get_collision_polygons_count(0) == 1, "las teselas tienen colisión del TileSet")
	var slope: TileData = level.builder.layer.get_cell_tile_data(Vector2i(514, 18))
	check(slope != null and slope.get_collision_polygons_count(0) == 1, "las rampas del tobogán tienen colisión")
	check(GameState.get_v("dreamHud")[1] == "candy_heart" and level.hud.get("moon_icons")[0].texture != null, "el HUD muestra los caramelos especiales")
	check(level.parallax.get_children().all(func(l): return l.z_index < C.Z_TERRAIN), "parallax detrás del terreno")
	var scrolls := {}
	for l in level.parallax.get_children():
		scrolls[snappedf(l.scroll_scale.x, 0.01)] = true
	check(scrolls.size() >= 5, "capas de fondo con velocidades distintas (%d)" % scrolls.size())
	var front: Array = level.world_root.get_node("Decor").get_children().filter(func(d): return d.z_index == C.Z_DECOR_FRONT)
	check(front.all(func(d): return d.texture.get_height() <= 20), "la decoración delantera es pequeña y baja")
	var tex: Texture2D = Assets.frame("world7_objects", "tree_big")
	check(level.world_root.get_node("Decor").get_child(0).texture_filter in [CanvasItem.TEXTURE_FILTER_PARENT_NODE, CanvasItem.TEXTURE_FILTER_NEAREST] and tex != null, "filtro nearest (pixel art nítido)")


func test_w7_jelly_bounce() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	var jelly: Array = _w7_platforms(CloudPlatform).filter(func(c): return c.bouncy != 0)
	var j: CloudPlatform = jelly[0]
	level.player.position = Vector2(j.position.x, j.position.y - 60)
	level.player.velocity = Vector2.ZERO
	var squashed := false
	var min_vy := 0.0
	for i in 70:
		await frames(1)
		min_vy = minf(min_vy, level.player.velocity.y)
		squashed = squashed or j.sprite.scale.y < 0.95
	check(min_vy < -400, "al aterrizar en la gelatina Alice sale impulsada hacia arriba (%.0f)" % min_vy)
	check(squashed, "la gelatina se comprime al rebotar")
	await frames(30)
	check(j.sprite.scale.is_equal_approx(Vector2.ONE), "y recupera su forma")
	check(float(level.data.clouds[0].bouncy) == j.bouncy, "la fuerza de rebote sale de los datos (configurable)")


func _w7_run_speed(tx: float, ty: float) -> float:
	place(tx, ty); await frames(4)
	hold(["move_right", "run"])
	await frames(40)
	var v := level.player.velocity.x
	hold([])
	return v


func test_w7_sticky_and_slippery() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	level.player.invulnerable_until = level.now + 100000
	var normal: float = await _w7_run_speed(150, 19)
	var sticky: float = await _w7_run_speed(268, 20)
	check(sticky < normal * 0.65 and sticky > 0, "el chocolate pegajoso reduce la velocidad (%.0f frente a %.0f)" % [sticky, normal])
	hold(["move_right"])
	await frames(150)
	hold([])
	check(level.player.surface_speed == 1.0, "al salir del chocolate se recupera la velocidad normal")
	# frenada: en caramelo se tarda más, pero se acaba frenando
	var stop_dist := func(tx: float, ty: float) -> float:
		place(tx, ty); await frames(4)
		hold(["move_right", "run"]); await frames(40)
		hold([])
		var x0 := level.player.position.x
		await frames(80)
		return level.player.position.x - x0
	var d_normal: float = await stop_dist.call(149, 19)
	var d_caramel: float = await stop_dist.call(176, 18)
	check(d_caramel > d_normal * 1.6, "el caramelo es resbaladizo (frena en %.0f px frente a %.0f)" % [d_caramel, d_normal])
	check(absf(level.player.velocity.x) < 5, "y aun así Alice consigue frenar")


func test_w7_conveyor() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	var belt: ConveyorBelt = level.level_objects.belts[0]
	level.player.position = Vector2(belt.position.x + 20, belt.position.y - 1)
	level.player.velocity = Vector2.ZERO
	await frames(10)
	var x0 := level.player.position.x
	await frames(30)
	check(level.player.grounded and level.player.position.x - x0 > 12, "la correa arrastra a Alice hacia la derecha (%.1f px)" % (level.player.position.x - x0))
	check(level.belt_under_player() > 0, "el nivel sabe sobre qué correa va")
	var back: Array = level.level_objects.belts.filter(func(b): return b.belt_speed() < 0)
	var rb: ConveyorBelt = back[0]
	level.player.position = Vector2(rb.position.x + 40, rb.position.y - 1)
	level.player.velocity = Vector2.ZERO
	await frames(10)
	x0 = level.player.position.x
	await frames(30)
	check(level.player.position.x - x0 < -8, "la correa inversa la lleva hacia la izquierda")
	hold(["move_right", "run"])
	await frames(20)
	check(level.player.velocity.x > 0, "Alice puede avanzar contra la correa")
	hold([])


func test_w7_hazards() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	# piruleta giratoria: la colisión es la cabeza y gira con ella
	var lp: SpinningLollipop = level.level_objects.lollipops[0]
	var h0 := lp.head_position()
	await frames(20)
	var h1 := lp.head_position()
	check(h0.distance_to(h1) > 4 and absf(h0.distance_to(lp.global_position) - h1.distance_to(lp.global_position)) < 0.5, "la cabeza gira alrededor de la base a distancia constante")
	level.player.position = lp.head_position() + Vector2(0, 14)
	level.player.velocity = Vector2.ZERO
	var hp := level.player.hp
	await frames(3)
	check(level.player.hp < hp, "tocar la cabeza de la piruleta hace daño")
	level.player.invulnerable_until = level.now + 100000
	# lanzador: avisa antes de disparar
	var ln: CandyLauncher = level.level_objects.launchers[0]
	level.kill_enemy_projectiles()
	ln.cycle_start = level.now
	ln.warned = false
	var warned_at := -1.0
	var shot_at := -1.0
	var mine := func() -> int:
		return level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == "candy_ball" and n.position.distance_to(ln.global_position + ln.muzzle) < 40).size()
	for i in 240:
		await frames(1)
		if ln.warned and warned_at < 0:
			warned_at = level.now
		if mine.call() > 0 and shot_at < 0:
			shot_at = level.now
	check(warned_at > 0 and shot_at > 0 and shot_at - warned_at >= CandyLauncher.WARN_MS * 0.9, "el lanzador avisa %.0f ms antes de disparar" % (shot_at - warned_at))
	# chorro de chocolate: reposo -> aviso -> chorro (sólo hace daño levantado)
	var jet: ChocoJet = level.level_objects.choco_jets[0]
	var states := []
	var danger_while_warn := false
	var danger := false
	jet.cycle_start = level.now
	for i in 220:
		await frames(1)
		if states.is_empty() or states[-1] != jet.state:
			states.append(jet.state)
		if jet.state == "warn" and jet.is_dangerous():
			danger_while_warn = true
		danger = danger or jet.is_dangerous()
	check(states.slice(0, 3) == ["idle", "warn", "up"] or states.slice(0, 3) == ["warn", "up", "idle"], "el chorro sigue su ciclo con aviso (%s)" % str(states))
	check(danger and not danger_while_warn, "sólo hace daño cuando el chocolate está levantado")
	# plataforma con pinchos de caramelo
	level.player.invulnerable_until = 0
	var spikes: Array = _w7_objects(Hazard)
	level.player.position = spikes[0].position + Vector2(0, -2)
	level.player.velocity = Vector2.ZERO
	hp = level.player.hp
	await frames(3)
	check(level.player.hp < hp, "los pinchos de caramelo hacen daño")


func test_w7_temp_jelly_and_heart() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	level.player.invulnerable_until = level.now + 100000
	var c: CrumblePlatform = level.level_objects.crumbles[0]
	level.player.position = Vector2(c.position.x, c.position.y - 2)
	level.player.velocity = Vector2.ZERO
	await frames(8)
	check(c.crumbling and not c.shape.disabled, "la gelatina tiembla al pisarla (aviso) antes de desaparecer")
	await frames(40)
	check(c.shape.disabled, "y después desaparece")
	await frames(200)
	check(not c.shape.disabled, "vuelve a aparecer al rato")
	var heart: HeartPickup = _w7_objects(HeartPickup)[0]
	level.player.hp = 1
	level.player.position = heart.position + Vector2(0, 12)
	level.player.velocity = Vector2.ZERO
	await frames(3)
	check(level.player.hp == 2, "el corazón dulce devuelve un corazón")


func test_w7_enemies() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	place(100, 20); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	# Cuppy Dulzón: se acerca saltando y prepara la piruleta antes de disparar
	var cuppy := _w6_spawn("cuppy", 120)
	var x0 := cuppy.position.x
	var jumped := false
	for i in 120:
		await frames(1)
		jumped = jumped or (not cuppy.grounded and cuppy.velocity.y < 0)
	check(cuppy is CuppyMonster and jumped and cuppy.position.x < x0 - 10, "Cuppy se aproxima a Alice saltando (%.0f px)" % (x0 - cuppy.position.x))
	cuppy.timers.clear()
	level.kill_enemy_projectiles()
	cuppy.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(cuppy.sprite.animation == "attack" and cuppy.sprite.frame == 0 and _w5_shots("candy") == 0, "levanta la piruleta antes de disparar (preparación)")
	await frames(40)
	check(_w5_shots("candy") == 1, "dispara un caramelo redondo")
	await frames(60)
	check(cuppy.fsm.current != Enemy.ATTACK and cuppy.attack_ready_at > level.now, "se recupera y espera antes de repetir")
	cuppy.queue_free()
	level.kill_enemy_projectiles()
	# Gomilito Saltarín: saltitos, ataque en plancha y división limitada
	var gomi := _w6_spawn("gomilito", 70)
	await frames(10)
	gomi.timers.clear()
	gomi.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(gomi is GomilitoMonster and gomi.grounded and gomi.sprite.animation == "attack", "el Gomilito se agacha antes de saltar (aviso)")
	var min_vy := 0.0
	for i in 60:
		await frames(1)
		min_vy = minf(min_vy, gomi.velocity.y)
	check(min_vy < -200, "salta en plancha hacia Alice")
	gomi.take_damage(2, 1)
	check(gomi.fsm.current == "SPLIT" and not gomi.is_harmful(), "al recibir suficiente daño se divide")
	await frames(40)
	var minis: Array = level.enemies_root.get_children().filter(func(n): return n is GomilitoMini and not n.finished)
	check(minis.size() == 2 and (not is_instance_valid(gomi) or gomi.finished), "se convierte en dos gomitas pequeñas")
	check(minis.all(func(m): return m.hp < Assets.enemy_def("gomilito").hp and not m.can_split()), "las gomitas tienen menos vida y no vuelven a dividirse")
	minis[0].take_damage(1, 1)
	check(not minis[0].is_alive(), "una gomita cae de un golpe")
	# límite: nunca hay más de MAX_MINIS gomitas
	for i in 6:
		var g2 := _w6_spawn("gomilito", 40 + i * 4)
		await frames(2)
		g2.take_damage(2, 1)
		await frames(35)
	var alive: Array = level.enemies_root.get_children().filter(func(n): return is_instance_valid(n) and n is GomilitoMini and not n.finished)
	check(alive.size() <= GomilitoMonster.MAX_MINIS, "el número de gomitas está limitado (%d)" % alive.size())
	for n in level.enemies_root.get_children():
		n.queue_free()
	await frames(2)
	# Piruleta Voladora: flota, cambia de altura y lanza tres caramelitos en abanico
	place(100, 20); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	var piru := _w6_spawn("piruleta", 100, -100, {"fly": [3, 4]})
	await frames(10)
	var y0 := piru.position.y
	await frames(120)
	check(piru is PiruletaMonster and piru.position.y < level.player.position.y - 20, "la Piruleta flota sin caer")
	check(absf(piru.position.y - y0) > 10, "se desplaza a otra altura para atacar (%.0f px)" % (piru.position.y - y0))
	piru.timers.clear()
	level.kill_enemy_projectiles()
	piru.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(_w5_shots("piru_candy") == 0, "se inclina antes de disparar (aviso)")
	await frames(40)
	var shots: Array = level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == "piru_candy")
	check(shots.size() == 3, "lanza tres caramelitos")
	if shots.size() == 3:
		var angles: Array = shots.map(func(s): return rad_to_deg(s.velocity.angle()))
		angles.sort()
		check(angles[1] - angles[0] > 15 and angles[2] - angles[1] > 15 and shots.all(func(s): return s.velocity.length() < 90), "en abanico, lentos y con huecos entre ellos")
	piru.queue_free()
	await get_tree().process_frame


func test_w7_weapons_vs_enemies() -> void:
	await load_level("World7")
	await settle(); _clear_spawner()
	place(100, 20); await frames(3)
	for type in ["cuppy", "gomilito", "piruleta"]:
		for wid in ["bubble", "paint", "sling"]:
			var e := _w6_spawn(type, 60, -40 if type == "piruleta" else 0.0)
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
				check(e.painted_until > level.now and (e.hp < hp0 or e.fsm.current == "SPLIT"), "%s recibe la pintura" % type)
			else:
				check(e.hp < hp0 or not e.is_alive(), "%s recibe el tirachinas" % type)
			e.queue_free()
			await get_tree().process_frame
	for n in level.enemies_root.get_children():
		n.queue_free()
	for type in ["cuppy", "gomilito", "gomilito_mini", "piruleta"]:
		var cell := Assets.cell_size(type)
		var body: Vector2 = Assets.enemy_def(type).body_size
		check(body.x < cell.x and body.y <= cell.y, "%s tiene hitbox propia más pequeña que el dibujo" % type)


func test_w7_boss() -> void:
	await load_level("Boss7", func(): GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(170)
	var boss: DonChupeton = level.boss
	check(boss != null and boss.max_hp == 65 and not boss.invulnerable, "Don Chupetón entra vulnerable con 65 HP")
	check(level.terrain_solid_at(Vector2(5 * C.TILE + 8, 12 * C.TILE + 8)), "la arena queda cerrada durante el combate")
	var top: float = boss.position.y + boss.shape.position.y - (boss.shape.shape as RectangleShape2D).size.y / 2.0
	check(top > 11 * C.TILE + 2, "el cuerpo de Don Chupetón es más bajo que las nubes de crema (el giro se esquiva arriba)")
	var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 100})
	p.weapon = Assets.weapon("sling")
	p.active = false
	boss.hp = 43; boss.hit_by(p)
	check(boss.phase == 2, "cambia a la fase 2 (Tormenta de glaseado) al 65%")
	boss.invulnerable = false; boss.hp = 20; boss.hit_by(p)
	check(boss.phase == 3, "cambia a la fase 3 (El gran remolino dulce) al 30%")
	for phase in [1, 2, 3]:
		for atk in DonChupeton.PHASES[phase].pattern:
			boss.phase = phase
			boss.invulnerable = false
			boss.timers.clear()
			boss.velocity.x = 0
			boss.position.x = (boss.min_x + boss.max_x) / 2.0
			level.kill_enemy_projectiles()
			boss.fsm.set_state(atk)
			await frames(12)
			var early := level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active).size()
			check(early == 0 and absf(boss.velocity.x) < 1, "%s tiene anticipación (nada sale al empezar)" % atk)
			var guard := 0
			var acted := false
			var most := 0
			while boss.fsm.current == atk and guard < 900:
				guard += 1
				var n := level.enemy_projectiles.get_children().filter(func(x): return x is Projectile and x.active).size()
				most = maxi(most, n)
				if n > 0 or absf(boss.velocity.x) > 100:
					acted = true
				level.player.invulnerable_until = level.now + 100000
				await frames(1)
			check(acted, "%s lanza su ataque" % atk)
			check(most <= 8, "%s no satura la arena (%d proyectiles a la vez)" % [atk, most])
			check(boss.fsm.current == "REST", "%s termina en un descanso vulnerable" % atk)
	# los caramelos del abanico van lentos y separados
	boss.phase = 2
	boss.timers.clear()
	level.kill_enemy_projectiles()
	boss.fsm.set_state("CANDY_FAN")
	await frames(60)
	var fan: Array = level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == "boss_candy")
	check(fan.size() == 5 and fan.all(func(s): return s.velocity.length() <= 100), "abanico de cinco caramelos lentos")
	boss.invulnerable = false; boss.hp = 1; boss.fsm.set_state("REST"); boss.hit_by(p)
	check(boss.is_defeated(), "puede ser derrotado")


func test_w7_boss_victory() -> void:
	SaveManager.reset_progress()
	await load_level("Boss7", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle(); place(12, 14); await frames(170)
	var boss: DonChupeton = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	var seen := {}
	var guard := 0
	var prev := ""
	while not boss.is_defeated() and guard < 20000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		if boss.fsm.current == "REST" and prev != "REST" and not boss.invulnerable:
			for w in ["sling", "paint"]:
				var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": w, "frame": "pellet", "lifespan": 100})
				p.weapon = Assets.weapon(w)
				p.active = false
				boss.hit_by(p)
		prev = boss.fsm.current
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	check(boss.is_defeated() and seen.has("phase2") and seen.has("phase3"), "combate completo con las tres fases")
	for s in ["CANDY_SHOT", "LOLLIPOP", "FROSTING_JET", "CANDY_FAN", "SWIRLS", "SPIN", "FROSTING_BURST", "MULTI", "COMBO"]:
		check(seen.has(s), "usa el ataque %s" % s)
	await frames(2)
	check(level.enemy_projectiles.get_children().all(func(n): return not (n is Projectile and n.active)), "deja de atacar")
	check(boss.sprite.animation == "spin_attack" and boss.sprite.speed_scale < 1.0, "sus piruletas dejan de girar poco a poco")
	await frames(72)
	check(boss.sprite.animation == "candy_attack" and boss.sprite.frame == 0, "pone cara de sorpresa")
	await frames(45)
	var drops: Array = level.fx_root.get_children().filter(func(n): return n is Sprite2D and n.texture is AtlasTexture and (n.texture as AtlasTexture).region == (Assets.frame("w7_fx", "frosting_drop") as AtlasTexture).region)
	check(drops.size() >= 2, "el glaseado cae suavemente")
	await frames(60)
	var stars_fx: Array = level.fx_root.get_children().filter(func(n): return n is Sprite2D and n.texture is AtlasTexture and (n.texture as AtlasTexture).region == (Assets.frame("w7_fx", "candy_star") as AtlasTexture).region)
	check(stars_fx.size() >= 3, "aparecen estrellas")
	await frames(90)
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(boss.sprite.animation == "defeated" and boss.sprite.frame == 1, "queda convertido en un pastelito dormido")
	check(star.size() == 1, "entrega la estrella especial")
	if star.size() == 1:
		level.player.position = star[0].position + Vector2(0, 10)
		await frames(60)
		check(GameState.get_v("specialStar") == true and level.portal != null, "recoge la estrella especial y se abre el portal al Mundo 8")
		if level.portal:
			level.player.position = level.portal.position
			await frames(5)
			check(level.leaving and SaveManager.is_world_completed(7), "cruza el portal y guarda el Mundo 7")
			check(SaveManager.unlocked_world() == 8, "desbloquea el Mundo 8")
	SaveManager.reset_progress()


func test_w7_progression() -> void:
	SaveManager.reset_progress()
	for i in [1, 2, 3, 4, 5]:
		SaveManager.mark_world_completed(i, 1, 1)
	check(not WorldRegistry.is_playable(7), "el Mundo 7 empieza bloqueado")
	SaveManager.mark_world_completed(6, 1, 1)
	check(WorldRegistry.is_playable(7), "completar el Mundo 6 desbloquea el Mundo 7")
	var key := WorldRegistry.start_run(7)
	check(key == "World7" and GameState.get_v("dreamTotal") == 5 and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 7")
	check(WorldRegistry.id_for_scene("World7") == 7 and WorldRegistry.id_for_scene("Boss7") == 7, "la escena World7 corresponde al Mundo 7")
	SaveManager.mark_world_completed(7, 220, 300, true, 1000, [], ["candy_1", "candy_2", "cherry_1"])
	check(SaveManager.unlocked_world() == 8 and SaveManager.get_world(7).dreamCollectibles.size() == 3 and SaveManager.get_world(7).bestStars == 220, "victoria guarda estrellas y coleccionables del Mundo 7")
	check(WorldRegistry.is_playable(8), "completar el Mundo 7 desbloquea el Mundo 8 (ya implementado)")
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 7, "stars": 220, "total": 300, "dream": ["candy_1"], "dreamTotal": 5}
	add_child(v)
	await frames(2)
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(v.world_id == 7 and list.buttons[0].label.text == "Ir al Mundo 8", "la pantalla de victoria del Mundo 7 lleva al Mundo 8")
	v.queue_free()
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var cards: Array[WorldCard] = menu.carousel.cards
	check(cards[6].data.title == "Bosque de Caramelos" and cards[6].data.state() == WorldData.State.COMPLETED, "la isla del Bosque de Caramelos muestra el Mundo 7 completado")
	check(cards[7].data.state() == WorldData.State.UNLOCKED and cards[7].data.describe().ends_with("¡A jugar!"), "el Mundo 8 aparece desbloqueado y jugable")
	check(cards[7].island.self_modulate == Color.WHITE, "el Mundo 8 ya no muestra candado")
	menu.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


# IMP-001: en cada nivel, cada sección tiene un checkpoint (o empieza a <= 320 px de uno), ningún
# tramo sin checkpoint supera 2.500 px y cada bandera está sobre suelo
func test_checkpoint_spacing() -> void:
	for w in range(1, 9):
		var key := "World%d" % w
		await load_level(key)
		var data: Dictionary = level.data
		var start := float(data.playerStart.x) * C.TILE
		var cps: Array = data.checkpoints.map(func(c): return float(c.x) * C.TILE)
		var marks: Array = [start] + cps + [level.world_w]
		var longest := 0.0
		for i in marks.size() - 1:
			longest = maxf(longest, marks[i + 1] - marks[i])
		check(longest <= 2500, "Mundo %d: tramo sin checkpoint más largo %.0f px (<= 2.500)" % [w, longest])
		var bare := []
		for s in data.sections:
			var a := float(s.from)
			if a >= level.world_w:
				continue # sección de la arena del jefe
			var b := level.world_w
			for s2 in data.sections:
				if float(s2.from) > a:
					b = minf(b, float(s2.from))
			var ok := ([start] + cps).any(func(x): return (x >= a and x < b) or (x < a and a - x <= 320))
			if not ok:
				bare.append(s.id)
		check(bare.is_empty(), "Mundo %d: secciones sin checkpoint %s" % [w, str(bare)])
		var floating := []
		for c in data.checkpoints:
			if not level.terrain_solid_at(Vector2(float(c.x) * C.TILE + 8, float(c.y) * C.TILE + 8)) or level.terrain_solid_at(Vector2(float(c.x) * C.TILE + 8, float(c.y) * C.TILE - 8)):
				floating.append(c.x)
		check(floating.is_empty(), "Mundo %d: checkpoints sin suelo o dentro del terreno %s" % [w, str(floating)])


# IMP-036: ningún bocadillo de cartel se sale del nivel (el primero de cada mundo está junto al borde)
func test_sign_bubbles_inside() -> void:
	for w in range(1, 9):
		await load_level("World%d" % w)
		var out := []
		var tail_ok := true
		for sign: SignPost in level.level_objects.signs:
			var cx := sign.position.x + sign.bubble.position.x
			var half: float = sign.bubble.box.x / 2.0
			if cx - half < 0 or cx + half > level.world_w:
				out.append(int(sign.position.x / C.TILE))
			# el pico apunta al poste salvo que el poste quede fuera del bocadillo
			if absf(sign.bubble.tail_x + sign.bubble.position.x) > 0.5 and absf(sign.bubble.position.x) < half - 8:
				tail_ok = false
		check(out.is_empty(), "Mundo %d: bocadillos dentro del nivel (se salen en las teselas %s)" % [w, str(out)])
		check(tail_ok, "Mundo %d: el pico del bocadillo apunta al poste" % w)


# ======================================================================= Mundo 8
func test_w8_data() -> void:
	var w: Dictionary = C.load_json("res://data/world8/world8.json")
	var b: Dictionary = C.load_json("res://data/world8/world8_boss.json")
	check(w.progress.total == 12000 and w.widthTiles * 16 + b.widthTiles * 16 == 12000, "recorrido total de 12.000 px (el nivel más grande)")
	check(w.sections.map(func(x): return int(x.from)) == [0, 1800, 3800, 5900, 8000, 10000], "seis secciones A-F en 0/1.800/3.800/5.900/8.000/10.000")
	var cp_x: Array = w.checkpoints.map(func(c): return float(c.x) * 16)
	check(cp_x.size() == 7 and cp_x[0] >= 1800 and cp_x[1] < 3800 and cp_x[4] >= 5900 and cp_x[4] < 8000 and cp_x[6] >= 8000 and cp_x[6] < 10000, "siete checkpoints: dos en B, C, D, E y antes del jefe")
	# IMP-037: el foso de las plataformas colgantes (teselas 128-143) tiene un checkpoint a <= 320 px antes
	check(cp_x[0] < 128 * 16 and 128 * 16 - cp_x[0] <= 320, "checkpoint justo antes de las plataformas colgantes")
	var types := {}
	for e in w.enemies: types[e.type] = true
	check(types.has("fantasmita") and types.has("murcibola") and types.has("bloquito"), "los tres enemigos oficiales")
	var first_bat: Array = w.enemies.filter(func(e): return e.type == "murcibola")
	check(float(first_bat[0].x) * 16 >= 1800 and float(first_bat[0].x) * 16 < 3800, "el primer Murcibola aparece en la sección B")
	check(w.ghostPlatforms.size() >= 3 and w.swings.size() >= 3 and w.crumbles.size() >= 3 and w.fallingStars.size() >= 3, "plataformas fantasma, colgantes, que desaparecen y estrellas que caen")
	check(w.clouds.filter(func(c): return float(c.get("bouncy", 0)) < 0 and String(c.frame).begins_with("shroom")).size() >= 3, "setas fantasma elásticas")
	check(w.shadowZones.any(func(z): return z.kind == "pool") and w.shadowZones.any(func(z): return z.kind == "mist"), "charcos y bruma de sombras")
	check(w.hooks.size() >= 2 and w.movers.size() >= 2 and w.lanterns.size() >= 1 and w.hiddenBridges.size() >= 1, "ganchos, plataformas móviles, faroles mágicos y puentes ocultos")
	for l in w.lanterns:
		check(l.bridges.all(func(id): return w.hiddenBridges.any(func(h): return h.id == id)), "el farol %s tiene sus puentes" % l.id)
	var memories: Array = w.dreamCollectibles.filter(func(d): return d.kind == "memory")
	check(memories.size() == 3 and memories.all(func(m): return float(m.x) * 16 >= 8000 and float(m.x) * 16 < 10000), "tres recuerdos mágicos en el Corazón del Castillo")
	check(memories.map(func(m): return m.memory) == ["courage", "imagination", "friendship"], "valor, imaginación y amistad")
	check(w.dreamCollectibles.filter(func(d): return d.kind == "moon").size() == 3 and w.dreamMain == "moon", "tres fragmentos de luna")
	check(w.dreamCollectibles.any(func(d): return d.kind == "key") and w.dreamCollectibles.any(func(d): return d.kind == "orb") and w.chests.size() == 1, "llave, orbe especial y cofre final")
	check(w.door.get("giant", false) and w.nextScene == "Boss8", "la gran puerta lleva al salón del trono")
	check(String(b.boss.scene).ends_with("ReyPesadelo.tscn") and int(b.worldId) == 8 and b.boss.name == "Rey Pesadelo", "arena con el Rey Pesadelo")
	check(b.clouds.size() >= 3 and b.phaseStars.size() >= 2, "plataformas laterales y obstáculos temporales en la arena")
	var manifest: Dictionary = C.load_json("res://data/world8/world8_asset_manifest.json")
	check(manifest.summary.pending.is_empty(), "manifiesto de recursos sin pendientes")
	for src in ["imagenes/word_8.png", "imagenes/tilesets_world_8.png", "imagenes/enemies_world_8.png", "imagenes/jefemundo8.png"]:
		check(manifest.resources.any(func(r): return r.get("source") == src), "usa la referencia oficial %s" % src)
	check(manifest.resources.any(func(r): return r.has("reused")), "el manifiesto documenta los cuadros reutilizados")
	check(manifest.resources.filter(func(r): return String(r.name).begins_with("rey_pesadelo/")).all(func(r): return r.source == "imagenes/jefemundo8.png"), "el Rey Pesadelo sale sólo de jefemundo8.png")
	check(manifest.resources.filter(func(r): return String(r.name).begins_with("gato_morado/")).all(func(r): return r.source == "imagenes/jefemundo8.png"), "el gato morado sale de la hoja oficial del jefe")


func test_w8_sprites() -> void:
	var expected := {
		"fantasmita": {"idle": 5, "float": 6, "attack": 4, "hurt": 3, "defeat": 2},
		"murcibola": {"idle": 4, "fly": 5, "dive_attack": 4, "hurt": 3, "defeat": 2},
		"bloquito": {"idle": 5, "walk": 4, "jump": 2, "charge": 3, "attack": 1, "hurt": 3, "defeat": 2},
		"rey_pesadelo": {"idle": 4, "move": 4, "spit": 4, "claw": 2, "fart": 3, "fury": 3, "hurt": 2, "stunned": 1, "defeated": 4},
		"gato_morado": {"idle": 2, "blink": 1, "sit": 1, "walk": 2, "purr": 2, "sleep": 1},
	}
	for key in expected:
		var sf := Assets.sprite_frames(key)
		for a in expected[key]:
			check(sf.has_animation(a) and sf.get_frame_count(a) == expected[key][a], "%s/%s conserva sus fotogramas" % [key, a])
	check(Assets.tileset("world8_tiles") != null, "TileSet nativo del Mundo 8")
	for atlas in ["world8_objects", "world8_bg", "w8_fx"]:
		check(Assets.atlases.has(atlas), "atlas %s cargado" % atlas)
	for f in ["spit_ball", "claw_wave", "gas_cloud", "fury_ring", "ghost_star", "cat_heart"]:
		check(Assets.has_frame("w8_fx", f), "efecto %s" % f)
	for d in ["fantasmita", "murcibola", "bloquito"]:
		check(Assets.enemy_def(d) != null, "EnemyDef de %s" % d)
	var at: AtlasTexture = Assets.sprite_frames("rey_pesadelo").get_frame_texture("idle", 0)
	check(at.atlas.get_image().get_pixel(0, 0).a == 0.0, "los sprites conservan la transparencia")
	check(Assets.cell_size("rey_pesadelo").y > Assets.cell_size("player").y * 1.8, "el Rey Pesadelo es imponente (más del doble de alto que Alice)")
	check(ResourceLoader.exists("res://resources/world8/cinematics/bedroom.png") and ResourceLoader.exists("res://resources/world8/cinematics/bedroom_blanket.png"), "habitación de Alice para el final")


func _w8_objects(cls: Variant) -> Array:
	return level.level_objects.objects.get_children().filter(func(n): return is_instance_of(n, cls))


func test_w8_level_loads() -> void:
	Assets.used_placeholders.clear()
	await load_level("World8")
	await settle()
	check(level.data.key == "world8" and level.player.grounded, "Mundo 8 carga con Alice sobre terreno real")
	check(Assets.used_placeholders.is_empty(), "Mundo 8 no usa marcadores provisionales (%s)" % str(Assets.used_placeholders.keys()))
	check(GameState.get_v("weaponsOwned").size() == 3, "reutiliza las tres armas")
	var lo: Dictionary = level.level_objects
	check(lo.ghosts.size() == level.data.ghostPlatforms.size() and lo.hidden_bridges.size() == level.data.hiddenBridges.size(), "crea plataformas fantasma y puentes ocultos")
	check(lo.shadows.size() == level.data.shadowZones.size() and lo.hooks.size() == level.data.hooks.size(), "crea sombras y ganchos")
	check(lo.lanterns.size() == level.data.lanterns.size() and lo.chests.size() == 1, "crea faroles y cofre")
	check(_w8_objects(FallingStar).size() == level.data.fallingStars.size(), "crea las estrellas que caen")
	var ts: Dictionary = Assets.tileset_data("world8_tiles")
	var idx := func(c: Vector2i) -> int: return c.y * 8 + c.x
	var ints := func(a: Array) -> Array: return a.map(func(v): return int(v))
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(4, 20))) in ints.call(ts.materials.lavender.cap0), "autotiling: cobertura lavanda sobre la roca violeta")
	check(idx.call(level.builder.layer.get_cell_atlas_coords(Vector2i(510, 20))) in ints.call(ts.materials.castle.cap0), "el Corazón del Castillo usa la piedra del castillo")
	var td: TileData = level.builder.layer.get_cell_tile_data(Vector2i(4, 20))
	check(td != null and td.get_collision_polygons_count(0) == 1, "las teselas tienen colisión del TileSet")
	check(GameState.get_v("dreamHud")[1] == "moon_gold", "el HUD muestra los fragmentos de luna")
	check(level.parallax.get_children().all(func(l): return l.z_index < C.Z_TERRAIN), "parallax detrás del terreno")
	var front: Array = level.world_root.get_node("Decor").get_children().filter(func(d): return d.z_index == C.Z_DECOR_FRONT)
	check(front.all(func(d): return d.texture.get_height() <= 28), "la decoración delantera es pequeña y baja")


func test_w8_ghost_platforms() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	var g: GhostPlatform = level.level_objects.ghosts[0]
	var seen := []
	var solid_while_invisible := false
	var t0 := level.now
	while level.now - t0 < g.period + 200:
		await frames(1)
		if seen.is_empty() or seen[-1] != g.state:
			seen.append(g.state)
		if g.state == "INVISIBLE" and not g.shape.disabled:
			# set_deferred: la colisión cambia en el fotograma siguiente
			await frames(1)
			solid_while_invisible = solid_while_invisible or (g.state == "INVISIBLE" and not g.shape.disabled)
	var order := ["VISIBLE", "WARNING", "INVISIBLE", "REAPPEAR"]
	var i0 := seen.find("VISIBLE")
	check(i0 >= 0 and seen.slice(i0, i0 + 4) == order, "ciclo VISIBLE -> WARNING -> INVISIBLE -> REAPPEAR (%s)" % str(seen))
	check(not solid_while_invisible, "sólo deja de ser sólida cuando es invisible")
	check(g.state_at(g.delay + g.visible_ms - g.warn_ms + 1) == "WARNING", "avisa antes de desaparecer")
	# las plataformas de un mismo hueco nunca desaparecen a la vez
	var pair: Array = level.level_objects.ghosts.filter(func(x): return x.position.x > 80 * 16 and x.position.x < 96 * 16)
	var never_both := true
	for t in range(0, 7200, 50):
		if pair[0].state_at(t) == "INVISIBLE" and pair[1].state_at(t) == "INVISIBLE":
			never_both = false
	check(pair.size() == 2 and never_both, "nunca desaparecen a la vez las dos plataformas de un hueco")
	# Alice se sostiene sobre ella mientras es visible
	g.delay = level.now
	level.player.position = Vector2(g.position.x, g.position.y - 1)
	level.player.velocity = Vector2.ZERO
	await frames(10)
	check(level.player.grounded and g.state == "VISIBLE", "se puede pisar mientras es visible")


func test_w8_shadow_damage() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	var z: ShadowZone = level.level_objects.shadows[0]
	level.player.max_hp = 99
	level.player.hp = 99
	level.player.position = Vector2(z.position.x + z.width / 2.0, z.position.y)
	level.player.velocity = Vector2.ZERO
	var hp0 := level.player.hp
	await frames(3)
	check(level.player.hp == hp0 - 1, "el charco de sombra hace un daño moderado (1)")
	# sigue dentro: no resta vida en cada fotograma
	var after_first := level.player.hp
	for i in 20:
		level.player.position = Vector2(z.position.x + z.width / 2.0, z.position.y)
		level.player.velocity = Vector2.ZERO
		await frames(1)
	check(level.player.hp == after_first, "durante el intervalo y la invulnerabilidad no vuelve a dañar")
	var hits := 0
	var last := level.player.hp
	for i in 240:
		level.player.position = Vector2(z.position.x + z.width / 2.0, z.position.y)
		level.player.velocity = Vector2.ZERO
		await frames(1)
		if level.player.hp < last:
			hits += 1
		last = level.player.hp
	check(hits >= 1 and hits <= 4000.0 / ShadowZone.DAMAGE_INTERVAL + 1, "daño con intervalo mientras permanece (%d golpes en 4 s)" % hits)
	var mist: Array = level.level_objects.shadows.filter(func(s): return s.kind == "mist")
	check(mist.size() >= 1, "también hay bruma de sombras")


func test_w8_hooks_swings_and_stars() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	var hk: ChainHook = level.level_objects.hooks[0]
	var h0 := hk.head_position()
	await frames(20)
	var h1 := hk.head_position()
	check(h0.distance_to(h1) > 2 and absf(h0.distance_to(hk.global_position) - h1.distance_to(hk.global_position)) < 0.5, "el gancho oscila colgado a distancia constante")
	level.player.invulnerable_until = 0
	level.player.position = hk.head_position() + Vector2(0, 14)
	level.player.velocity = Vector2.ZERO
	var hp := level.player.hp
	await frames(3)
	check(level.player.hp < hp, "tocar el gancho hace daño")
	level.player.invulnerable_until = level.now + 100000
	# plataforma colgante: transporta a Alice sin problemas de física
	var swings: Array = level.level_objects.movers.filter(func(m): return m is SwingPlatform)
	var sw: SwingPlatform = swings[0]
	var sw_shape: CollisionShape2D = sw.get_children().filter(func(n): return n is CollisionShape2D)[0]
	level.player.position = sw.position + Vector2(0, sw_shape.position.y - 6)
	level.player.velocity = Vector2.ZERO
	await frames(6)
	var x0 := level.player.position.x
	var px0 := sw.position.x
	await frames(40)
	check(level.player.grounded and absf((level.player.position.x - x0) - (sw.position.x - px0)) < 3.0, "la plataforma colgante lleva a Alice con ella (Alice %.1f px, plataforma %.1f px)" % [level.player.position.x - x0, sw.position.x - px0])
	var gaps := []
	for t in range(0, 3000, 100):
		gaps.append(swings[1].target_at(t).x - swings[0].target_at(t).x)
	check(gaps.min() > 60, "las plataformas colgantes vecinas nunca se cruzan")
	# estrella que cae: avisa (cuelga de su cadena) antes de caer
	var fs: FallingStar = _w8_objects(FallingStar)[0]
	var warn_tex := Assets.frame(level.data.objectsAtlas, "star_trap")
	var phases := []
	var warned_tex := false
	var start := level.now
	while level.now - start < fs.period + 100:
		await frames(1)
		var ph := fs.phase_at(level.now)
		if phases.is_empty() or phases[-1] != ph:
			phases.append(ph)
		if ph == "warn" and fs.star.visible and (fs.star.texture as AtlasTexture).region == (warn_tex as AtlasTexture).region:
			warned_tex = true
	check("warn" in phases and "fall" in phases and phases.find("warn") < phases.find("fall") or phases.slice(0, 2) == ["fall", "wait"], "la estrella avisa antes de caer (%s)" % str(phases))
	check(warned_tex, "durante el aviso se ve la estrella colgada de su cadena")


func test_w8_lantern_bridges() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	var lantern: MagicLantern = level.level_objects.lanterns[0]
	var bridges: Array = level.level_objects.hidden_bridges.filter(func(b): return b.id in lantern.bridges)
	check(bridges.size() >= 1 and bridges.all(func(b): return not b.is_solid()), "los puentes ocultos empiezan apagados (sin colisión)")
	level.player.invulnerable_until = level.now + 100000
	level.player.position = lantern.position + Vector2(-4, 0)
	level.player.velocity = Vector2.ZERO
	await frames(4)
	check(lantern.on and bridges.all(func(b): return b.lit and b.is_solid()), "al tocar el farol se revelan sus puentes (señal)")
	# disparo a un farol apagado también lo enciende
	var other: MagicLantern = level.level_objects.lanterns[1]
	var p: Projectile = level.spawn_projectile("player", {"x": other.position.x, "y": other.position.y - 20, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 200})
	p.weapon = Assets.weapon("sling")
	await frames(3)
	check(other.on, "un disparo también enciende el farol")
	# la luz de un Fantasmita revela un puente un rato
	await load_level("World8")
	await settle(); _clear_spawner()
	var hb: HiddenBridge = level.level_objects.hidden_bridges[0]
	place(hb.position.x / C.TILE - 8, 20); await frames(2)
	var ghost := _w6_spawn("fantasmita", hb.position.x - level.player.position.x, hb.position.y - level.player.position.y - 20)
	ghost.timers.clear()
	await frames(25)
	check(hb.is_solid() and not hb.lit, "la luz del farol del Fantasmita muestra el puente oculto")
	ghost.queue_free()
	await frames(140)
	check(not hb.is_solid(), "sin luz el puente vuelve a ocultarse")


func test_w8_chest_and_memories() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	level.player.invulnerable_until = level.now + 100000
	var chest: TreasureChest = level.level_objects.chests[0]
	level.player.position = chest.position + Vector2(-6, 0)
	level.player.velocity = Vector2.ZERO
	await frames(4)
	check(not chest.opened, "sin la llave del castillo el cofre no se abre")
	GameState.set_v("dreamCollectibles", ["key_1"])
	var bonus0 := level.bonus_root.get_child_count()
	level.player.hp = 1
	level.player.position = chest.position + Vector2(6, 0)
	await frames(4)
	check(chest.opened and level.bonus_root.get_child_count() > bonus0 and level.player.hp == level.player.max_hp, "con la llave se abre: estrellas y vida")
	check("chest_1" in GameState.get_v("dreamCollectibles"), "el tesoro se registra")
	# recuerdo mágico: se recoge y muestra un motivo de los mundos anteriores
	var mem: Array = level.level_objects.objects.get_children().filter(func(n): return n is DreamCollectible and n.kind == "memory")
	check(mem.size() == 3, "tres recuerdos en el nivel")
	var m: DreamCollectible = mem[0]
	var mem_id := m.id
	level.player.position = m.position + Vector2(0, 10)
	level.player.velocity = Vector2.ZERO
	await frames(3)
	check(mem_id in GameState.get_v("dreamCollectibles"), "el recuerdo se recoge")
	check(level.vision != null and is_instance_valid(level.vision) and level.vision.get_children().filter(func(n): return n is AnimatedSprite2D).size() == 3, "muestra brevemente tres motivos de mundos anteriores")
	check(not level.player.frozen and level.controls.enabled, "no es una cinemática: Alice sigue al mando")
	await frames(200)
	check(not is_instance_valid(level.vision), "la visión es breve")


func test_w8_enemies() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	place(40, 20); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	# Fantasmita Farol: aviso, UNA estrellita y retrocede
	var ghost := _w6_spawn("fantasmita", 90, -40)
	await frames(30)
	check(ghost is FantasmitaMonster and ghost.position.y < level.player.position.y - 10, "el Fantasmita flota sin caer")
	ghost.timers.clear()
	level.kill_enemy_projectiles()
	ghost.fsm.set_state(Enemy.ATTACK); await frames(10)
	check(ghost.sprite.animation == "attack" and _w5_shots("ghost_star") == 0, "levanta el farol antes de disparar (aviso)")
	await frames(40)
	check(_w5_shots("ghost_star") == 1, "lanza una estrellita luminosa")
	var x_before := ghost.position.x
	await frames(40)
	check(absf(ghost.position.x - level.player.position.x) > absf(x_before - level.player.position.x), "retrocede después de disparar")
	ghost.queue_free()
	level.kill_enemy_projectiles()
	# Murcibola: anticipación, picada al punto fijado y vuelta a su zona de descanso
	var bat := _w6_spawn("murcibola", 80, -60)
	var rest_y: float = bat.rest_pos.y
	await frames(5)
	bat.timers.clear()
	bat.position = level.player.position + Vector2(80, -70)
	bat.fsm.set_state(Enemy.ATTACK)
	var target: Vector2 = bat.dive_target
	await frames(20)
	check(bat.phase == "windup" and bat.velocity.length() < 20, "se encoge antes de lanzarse (anticipación)")
	check(absf(target.x - level.player.position.x) < 1, "fija el punto de la picada al avisar")
	var closest := 9999.0
	for i in 80:
		await frames(1)
		closest = minf(closest, bat.position.distance_to(target))
	check(closest < 14, "se lanza en picada hasta el punto marcado")
	await frames(150)
	check(bat.position.y < target.y - 20 and absf(bat.position.y - rest_y) < 40, "vuelve a su zona de descanso")
	check(absf(bat.position.x - level.player.position.x) > 4 or bat.position.y < level.player.position.y - 40, "no aparece justo encima de Alice")
	bat.queue_free()
	# Bloquito Sombra: barrera, embestida y vulnerable al terminar
	place(40, 20); await frames(3)
	level.player.invulnerable_until = level.now + 100000
	var blk := _w6_spawn("bloquito", 60)
	await frames(10)
	blk.timers.clear()
	blk.fsm.set_state(Enemy.ATTACK); await frames(5)
	check(blk is BloquitoSombraMonster and blk.has_barrier(), "levanta una barrera de sombra")
	var hp0 := blk.hp
	var p: Projectile = level.spawn_projectile("player", {"x": blk.position.x, "y": blk.position.y - 8, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 200})
	p.weapon = Assets.weapon("sling")
	blk.hit_by(p)
	check(blk.hp == hp0 and blk.is_alive(), "la barrera detiene los disparos")
	var max_vx := 0.0
	for i in 60:
		await frames(1)
		max_vx = maxf(max_vx, absf(blk.velocity.x))
	check(max_vx > 120, "embiste en horizontal")
	await frames(30)
	check(not blk.has_barrier() and blk.fsm.current == Enemy.ATTACK and not blk.charging, "al terminar queda quieto y sin barrera (vulnerable)")
	p = level.spawn_projectile("player", {"x": blk.position.x, "y": blk.position.y - 8, "vx": 0, "vy": 0, "kind": "sling", "frame": "pellet", "lifespan": 200})
	p.weapon = Assets.weapon("sling")
	blk.hit_by(p)
	check(blk.hp < hp0, "entonces los disparos le hacen daño")
	blk.queue_free()
	await get_tree().process_frame


func test_w8_weapons_vs_enemies() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	place(40, 20); await frames(3)
	for type in ["fantasmita", "murcibola", "bloquito"]:
		for wid in ["bubble", "paint", "sling"]:
			var e := _w6_spawn(type, 60, -40 if type != "bloquito" else 0.0)
			await frames(2)
			e.timers.clear()
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
	for type in ["fantasmita", "murcibola", "bloquito"]:
		var cell := Assets.cell_size(type)
		var body: Vector2 = Assets.enemy_def(type).body_size
		check(body.x < cell.x and body.y <= cell.y, "%s tiene hitbox propia más pequeña que el dibujo" % type)


func test_w8_slow_effect() -> void:
	await load_level("World8")
	await settle(); _clear_spawner()
	level.player.invulnerable_until = level.now + 100000
	var normal: float = await _w7_run_speed(10, 20)
	level.player.apply_slow(3000, 0.5)
	var slow: float = await _w7_run_speed(10, 20)
	check(slow < normal * 0.6 and slow > 0, "la nube ralentiza a Alice (%.0f frente a %.0f)" % [slow, normal])
	# no bloquea el salto
	place(10, 20); await frames(3)
	level.player.apply_slow(3000, 0.5)
	hold(["jump"])
	press("jump")
	await frames(6)
	check(level.player.velocity.y < -100, "puede saltar mientras está ralentizada")
	hold([])
	await frames(40)
	# sin acumulaciones: repetir la nube sólo renueva el plazo (como mucho 4 s)
	for i in 10:
		level.player.apply_slow(3000, 0.5)
	check(level.player.slow_until - level.now <= 4000.0 and level.player.slow_factor == 0.5, "las nubes no se acumulan")
	await frames(250)
	check(not level.player.is_slowed() and level.player.slow_factor == 1.0 and level.player.sprite.modulate.r == 1.0, "al terminar se restaura la velocidad y el color")
	var back: float = await _w7_run_speed(10, 20)
	near(back, normal, 2.0, "vuelve a la velocidad normal")
	# la nube del jefe: sin daño, ralentiza
	var cloud := SlowCloud.new().setup(level, level.player.position, 0.0, 2000)
	level.level_objects.objects.add_child(cloud)
	var hp := level.player.hp
	level.player.invulnerable_until = 0
	await frames(25)
	check(level.player.is_slowed() and level.player.hp == hp, "tocar la nube no hace daño pero ralentiza")


func _w8_boss_ready() -> void:
	await load_level("Boss8", func(): GameState.set_v("weapon", "sling"))
	await settle()
	place(70, 14)
	await frames(200)


func _w8_shot(w := "sling") -> Projectile:
	var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": w, "frame": "pellet", "lifespan": 100})
	p.weapon = Assets.weapon(w)
	p.active = false
	return p


func test_w8_boss_states() -> void:
	await _w8_boss_ready()
	var boss: ReyPesadelo = level.boss
	check(boss != null and boss.max_hp == 80 and not boss.invulnerable, "el Rey Pesadelo entra vulnerable con 80 HP")
	check(level.terrain_solid_at(Vector2(level.data.gate.x * C.TILE + 8, 12 * C.TILE + 8)), "la arena queda cerrada durante el combate")
	check(GameState.get_v("bossVisible") and GameState.get_v("bossMaxHp") == 80, "barra de vida del jefe en el HUD")
	var top: float = boss.position.y + boss.shape.position.y - (boss.shape.shape as RectangleShape2D).size.y / 2.0
	check(top > 11 * C.TILE + 2, "el cuerpo dañino queda por debajo de las plataformas laterales")
	for s in ["IDLE", "MOVE", "TELEGRAPH", "SPIT", "CLAW", "SLOW_CLOUD", "FURY_SCREAM", "HURT", "STUNNED", "DEFEATED", "TRANSFORMING", "CAT"]:
		check(boss.has_method("_enter_" + s) or boss.has_method("_update_" + s), "estado explícito %s" % s)
	# umbrales de vida: 65 % -> fase 2, 30 % -> fase 3 (cada cambio pasa por HURT, invulnerable)
	var p := _w8_shot()
	boss.hp = 54; boss.take_damage(1)
	check(boss.phase == 1 and boss.hp == 53, "por encima del 65 % sigue la fase 1")
	boss.take_damage(1)
	check(boss.phase == 2 and boss.fsm.current == "HURT" and boss.invulnerable, "al bajar del 65 % pasa a la fase 2 (HURT)")
	var hp_hurt := boss.hp
	boss.hit_by(p)
	check(boss.hp == hp_hurt, "invulnerable durante el cambio de fase")
	await frames(100)
	check(boss.fsm.current != "HURT" and not boss.invulnerable, "después vuelve al combate")
	check(level.phase_stars.size() == level.data.phaseStars.size() and level.parallax.modulate.v < 0.95, "fase 2: el cielo se oscurece y caen estrellas con aviso")
	boss.hp = 25; boss.take_damage(1)
	check(boss.phase == 3, "al bajar del 30 % pasa a la fase 3")
	check(AudioManager.current_track == level.data.furyMusic, "fase 3: música de furia")
	# transiciones: IDLE -> MOVE -> TELEGRAPH -> ataque -> STUNNED -> IDLE
	await frames(100)
	boss.phase = 1
	boss.pattern_index = 0
	boss.timers.clear()
	boss.fsm.set_state("IDLE")
	var seq := []
	for i in 600:
		if seq.is_empty() or seq[-1] != boss.fsm.current:
			seq.append(boss.fsm.current)
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	var ok := false
	for i in seq.size() - 4:
		if seq.slice(i, i + 5) == ["IDLE", "MOVE", "TELEGRAPH", "SPIT", "STUNNED"]:
			ok = true
	check(ok, "IDLE -> MOVE -> TELEGRAPH -> SPIT -> STUNNED (%s)" % str(seq.slice(0, 8)))
	check("CLAW" in seq, "alterna con el garrazo")


func _w8_attack(boss: ReyPesadelo, atk: String, phase: int) -> Dictionary:
	boss.phase = phase
	boss.invulnerable = false
	boss.timers.clear()
	boss.velocity.x = 0
	boss.position.x = (boss.min_x + boss.max_x) / 2.0
	level.kill_enemy_projectiles()
	get_tree().call_group("boss_hazard", "queue_free")
	await frames(2)
	boss.fsm.set_state("TELEGRAPH", {"attack": atk})
	await frames(10)
	var r := {"early": level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active).size(), "kinds": {}, "most": 0, "clouds": 0, "end": ""}
	var guard := 0
	var started := false
	while guard < 900:
		guard += 1
		var list: Array = level.enemy_projectiles.get_children().filter(func(x): return x is Projectile and x.active)
		r.most = maxi(r.most, list.size())
		for x in list:
			r.kinds[x.kind] = true
		r.clouds = maxi(r.clouds, get_tree().get_nodes_in_group("boss_hazard").size())
		if boss.fsm.current != "TELEGRAPH":
			started = true
		if started and boss.fsm.current in ["STUNNED", "IDLE"]:
			break
		level.player.invulnerable_until = level.now + 100000
		await frames(1)
	r.end = boss.fsm.current
	return r


func test_w8_boss_attacks() -> void:
	await _w8_boss_ready()
	var boss: ReyPesadelo = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	var spit: Dictionary = await _w8_attack(boss, "SPIT", 1)
	check(spit.early == 0, "SPIT: se detiene y abre la boca antes (nada sale al empezar)")
	check(spit.kinds.has("spit") and spit.end == "STUNNED", "SPIT: escupe el proyectil y termina en una ventana de contraataque")
	var claw: Dictionary = await _w8_attack(boss, "CLAW", 2)
	check(claw.early == 0 and claw.kinds.has("claw_wave") and claw.most >= 2, "CLAW: ráfagas de garras dobles en la fase 2")
	var cloud: Dictionary = await _w8_attack(boss, "SLOW_CLOUD", 2)
	check(cloud.clouds >= 1 and cloud.kinds.is_empty() and cloud.end == "STUNNED", "SLOW_CLOUD: una nube sin proyectiles dañinos")
	var fury: Dictionary = await _w8_attack(boss, "FURY_SCREAM", 3)
	check(fury.early == 0 and fury.kinds.has("fury_ring") and fury.end == "STUNNED", "FURY_SCREAM: aviso largo, ondas y descanso")
	check(fury.most <= 8 and claw.most <= 8, "los ataques no saturan la arena")
	# el grito no empieza mientras Alice está ralentizada
	boss.timers.clear()
	boss.phase = 3
	boss.pattern_index = 0
	level.player.apply_slow(3000, 0.5)
	boss.fsm.set_state("IDLE")
	var screamed := false
	for i in 120:
		screamed = screamed or boss.fsm.current in ["MOVE", "TELEGRAPH", "FURY_SCREAM"]
		await frames(1)
	check(not screamed, "nunca combina la ralentización con el grito: espera a que pase")
	await frames(140)
	check(not level.player.is_slowed() and boss.fsm.current in ["MOVE", "TELEGRAPH"], "cuando se le pasa, sigue el combate")
	# las ráfagas son esquivables: recorren el suelo por debajo de la altura de un salto
	var waves: Array = level.enemy_projectiles.get_children()
	boss.timers.clear()
	level.kill_enemy_projectiles()
	boss.position.x = boss.min_x + 200
	boss.face(-1)
	boss._claw_wave()
	boss._ring(1)
	await frames(2)
	waves = level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active)
	var jump_h := absf(float(level.player.T.jumpVelocity)) ** 2 / (2.0 * C.GRAVITY)
	check(waves.size() == 2 and waves.all(func(w): return boss.floor_y - (w.position.y - w.sprite.texture.get_height() * w.sprite.scale.y / 2.0) < jump_h - 10), "ráfaga y ondas más bajas que un salto (se esquivan saltando)")
	check(_w8_cfg_ok(), "velocidad, daño y vida de las ráfagas configurables")


func _w8_cfg_ok() -> bool:
	return ReyPesadelo.CLAW_WAVE.has("speed") and ReyPesadelo.CLAW_WAVE.has("damage") and ReyPesadelo.CLAW_WAVE.has("lifespan") and ReyPesadelo.FURY.has("warn")


func test_w8_boss_defeat_cancels() -> void:
	await _w8_boss_ready()
	var boss: ReyPesadelo = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	boss.phase = 3
	boss.timers.clear()
	boss.fsm.set_state("TELEGRAPH", {"attack": "FURY_SCREAM"})
	await frames(110)
	boss._ring(1)
	var cloud := SlowCloud.new().setup(level, boss.position, -30, 5000)
	level.level_objects.objects.add_child(cloud)
	await frames(2)
	boss.invulnerable = false
	boss.hp = 1
	boss.hit_by(_w8_shot())
	await frames(2)
	check(boss.fsm.current == "DEFEATED" and boss.is_defeated(), "derrotado al llegar a 0")
	check(level.enemy_projectiles.get_children().all(func(n): return not (n is Projectile and n.active)), "no quedan proyectiles peligrosos")
	check(boss.timers.is_empty(), "los ataques pendientes se cancelan")
	check(boss.shape.disabled and not boss.body_enabled, "las hitboxes ofensivas se desactivan")
	await frames(40)
	check(level.enemy_projectiles.get_children().all(func(n): return not (n is Projectile and n.active)), "no se generan más proyectiles después")
	check(get_tree().get_nodes_in_group("boss_hazard").all(func(c): return c.fading), "las nubes se desvanecen")
	check(not level.controls.combat_enabled, "los controles de combate se desactivan")


func test_w8_boss_victory_and_ending() -> void:
	SaveManager.reset_progress()
	await load_level("Boss8", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle(); place(70, 14); await frames(200)
	var boss: ReyPesadelo = level.boss
	level.player.max_hp = 99; level.player.hp = 99
	var seen := {}
	var guard := 0
	var prev := ""
	while not boss.is_defeated() and guard < 30000:
		guard += 1
		seen[boss.fsm.current] = true
		seen["phase%d" % boss.phase] = true
		if boss.fsm.current == "STUNNED" and prev != "STUNNED" and not boss.invulnerable:
			for w in ["sling", "paint"]:
				boss.hit_by(_w8_shot(w))
		prev = boss.fsm.current
		level.player.invulnerable_until = level.now + 100000
		# Alice se mantiene cerca para que el jefe no se aleje
		await frames(1)
	check(boss.is_defeated() and seen.has("phase2") and seen.has("phase3"), "combate completo con las tres fases")
	for s in ["IDLE", "MOVE", "TELEGRAPH", "SPIT", "CLAW", "SLOW_CLOUD", "FURY_SCREAM", "HURT", "STUNNED"]:
		check(seen.has(s), "pasa por el estado %s" % s)
	var hud_root: Control = level.hud.get_node("Root")
	await frames(90)
	check(boss.fsm.current == "TRANSFORMING", "empieza la transformación")
	var tr: Array = level.world_root.get_children().filter(func(n): return n is NightmareTransformation)
	check(tr.size() == 1 and tr[0].player.is_playing() and tr[0].player.current_animation == "transform", "la transformación usa AnimationPlayer")
	check(not boss.sprite.visible and hud_root.modulate.a < 0.9, "el HUD se oculta poco a poco")
	await frames(60)
	check(tr[0].monster.scale.x < 1.0, "el monstruo disminuye de tamaño")
	await frames(240)
	check(tr[0].cat.modulate.a > 0.9 and tr[0].monster.modulate.a < 0.1, "aparece el gato morado y el monstruo se desvanece")
	await frames(40)
	check(boss.fsm.current == "CAT" and level.cat != null, "el gato morado queda en la arena")
	var cat: PurpleCat = level.cat
	check(cat.sprite.sprite_frames == Assets.sprite_frames("gato_morado"), "es el gato de la hoja oficial")
	await frames(30)
	var d0 := absf(cat.position.x - level.player.position.x)
	await frames(200)
	check(absf(cat.position.x - level.player.position.x) < d0, "el gato se acerca despacio")
	level.player.position.x = cat.position.x - 10
	await frames(6)
	check(cat.done and cat.state == "CUDDLE", "al tocarlo hay una animación de cariño")
	check(level.ending and not level.controls.enabled, "empieza el final")
	check(GameState.get_v("bossPurified") == true, "narrativa: el Rey Pesadelo queda purificado (gato)")
	check(SaveManager.is_world_completed(8) and SaveManager.is_adventure_completed(), "se guarda la victoria final")
	check(SaveManager.unlocked_world() == 8 and WorldRegistry.get_world(9).is_empty(), "no se desbloquea ningún Mundo 9")
	await frames(230)
	check(level.parallax.modulate.r > 0.95 and AudioManager.current_track == "alice_awakening", "el castillo recupera la luz y la música se suaviza")
	SaveManager.reset_progress()


func test_w8_awakening_and_credits() -> void:
	var aw: Node2D = load(Router.SCENES.Awakening).instantiate()
	add_child(aw)
	await frames(10)
	check(aw.alice.sprite_frames == Assets.sprite_frames("player") and aw.alice_lying.sprite_frames == Assets.sprite_frames("player"), "Alice es la protagonista oficial (sus fotogramas)")
	check(aw.cat.sprite_frames == Assets.sprite_frames("gato_morado") and aw.cat.animation == "sleep", "el gato morado duerme a los pies de la cama")
	check(aw.alice.modulate.a < 0.1 and aw.alice_lying.modulate.a > 0.9, "Alice empieza dormida")
	aw.t = 4.0
	await frames(60)
	check(aw.alice.modulate.a > 0.9 and aw.alice_lying.modulate.a < 0.1, "se incorpora")
	aw.t = 8.5
	await frames(4)
	check(aw.cat.animation == "idle", "el gato abre los ojos")
	aw.t = 12.6
	await frames(30)
	var texts: Array = aw.text_root.get_children().filter(func(n): return n is PixelText)
	check(texts.size() == 1 and String(texts[0].text).begins_with("Y cuando Alice despertó"), "mensaje final con la tipografía pixel")
	aw.t = 20.6
	await frames(4)
	texts = aw.text_root.get_children().filter(func(n): return n is PixelText)
	check(texts.size() == 2 and texts[0].text == "ALICE DREAMS" and texts[1].text == "Fin", "y después el título ALICE DREAMS")
	aw.set_process(false)
	aw.queue_free()
	var cr: Control = load(Router.SCENES.Credits).instantiate()
	add_child(cr)
	await frames(10)
	var lines: Array = cr.scroller.get_children().map(func(n): return n.text)
	check("Alice Dreams" in lines and "Guardiana de los Sueños" in lines and "a Alice" in lines, "créditos: Alice Dreams, Guardiana de los Sueños y agradecimiento a Alice")
	check(not "Desarrollo" in lines, "no inventa nombres: las secciones sin nombres confirmados no aparecen")
	var y0: float = cr.scroller.position.y
	await frames(30)
	check(cr.scroller.position.y < y0, "desplazamiento suave")
	var anims: Array = cr.get_children().filter(func(n): return n is AnimatedSprite2D).map(func(n): return n.animation)
	check("victory" in anims and "purr" in anims, "Alice saluda y el gato morado ronronea")
	check(cr.back_btn != null, "botón para volver al menú principal")
	cr.set_process(false)
	cr.queue_free()
	await get_tree().process_frame


func test_w8_progression() -> void:
	SaveManager.reset_progress()
	for i in [1, 2, 3, 4, 5, 6]:
		SaveManager.mark_world_completed(i, 1, 1)
	check(not WorldRegistry.is_playable(8), "el Mundo 8 empieza bloqueado")
	SaveManager.mark_world_completed(7, 1, 1)
	check(WorldRegistry.is_playable(8), "completar el Mundo 7 desbloquea el Mundo 8")
	var key := WorldRegistry.start_run(8)
	check(key == "World8" and GameState.get_v("dreamTotal") == 8 and GameState.get_v("weaponsOwned").size() == 3, "partida nueva del Mundo 8")
	check(WorldRegistry.id_for_scene("World8") == 8 and WorldRegistry.id_for_scene("Boss8") == 8, "la escena World8 corresponde al Mundo 8")
	SaveManager.mark_world_completed(8, 240, 300, true, 1000, [], ["moon_1", "memory_courage"])
	SaveManager.mark_adventure_completed()
	check(SaveManager.unlocked_world() == 8, "no se desbloquea un noveno mundo")
	check(SaveManager.get_world(8).bestStars == 240 and SaveManager.get_world(8).dreamCollectibles.size() == 2, "se guardan estrellas y tesoros")
	SaveManager.load_state()
	check(SaveManager.is_adventure_completed() and SaveManager.is_world_completed(1), "el final se conserva al volver a cargar, sin perder el progreso")
	for i in range(1, 9):
		check(WorldRegistry.is_playable(i), "se puede repetir el Mundo %d" % i)
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	check(menu.carousel.cards.size() == 8 and menu.carousel.cards[7].data.state() == WorldData.State.COMPLETED, "los ocho mundos en el menú; el 8 completado")
	check(menu.ending_btn != null and menu.list.buttons.has(menu.ending_btn), "el menú permite volver a ver el final")
	menu.queue_free()
	# un guardado antiguo (sin los campos del final) se carga igual
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "unlockedWorld": 8, "worlds": {"7": {"completed": true, "bestStars": 5}}}))
	f.close()
	SaveManager.load_state()
	check(not SaveManager.is_adventure_completed() and SaveManager.is_world_completed(7) and SaveManager.unlocked_world() == 8, "compatible con partidas guardadas anteriores")
	await get_tree().process_frame
	SaveManager.reset_progress()


# ===================================================================== NARRATIVA
## Sólo las claves de enemigos de los datos de un mundo (fuente: WorldRegistry).
func _world_enemy_types(world_id: int) -> Array:
	var data: Dictionary = C.load_json(WorldRegistry.get_world(world_id).data)
	var types: Array = []
	for e in data.enemies:
		if not e.type in types:
			types.append(e.type)
	return types


func test_narrative_registry() -> void:
	check(DreamNarrative.world_ids().size() == 8, "datos narrativos de los ocho mundos")
	for w in WorldRegistry.WORLDS:
		var id := int(w.id)
		var n := DreamNarrative.get_world(id)
		var types := _world_enemy_types(id)
		var rescuable := DreamNarrative.rescuable(id)
		check(rescuable.size() >= 1 and rescuable.size() < types.size(), "Mundo %d: criaturas representativas, no todas (%d de %d)" % [id, rescuable.size(), types.size()])
		for c in rescuable:
			check(c in types and EnemySpawner.SCENES.has(c), "Mundo %d: %s aparece en los datos de ese mundo (numeración 5/6 respetada)" % [id, c])
			check(DreamNarrative.creature_name(c) != c, "Mundo %d: %s tiene nombre visible (EnemyDef)" % [id, c])
		check(not "gomilito_mini" in rescuable, "las gomitas no son rescatables")
		check(String(n.get("reflection", "")) != "" and String(n.get("purified", "")) != "", "Mundo %d: reflexión y forma purificada" % id)
		check(DreamNarrative.memento_texture(id) != null, "Mundo %d: el recuerdo/sticker usa un recurso existente" % id)


func test_narrative_save_compat() -> void:
	SaveManager.reset_progress()
	# guardado de la versión anterior (sin campos narrativos) y con numeración antigua
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "unlockedWorld": 3, "worlds": {"1": {"completed": true, "bestStars": 90, "totalStars": 144, "specialStar": true, "bestTime": 1000}, "2": {"completed": true, "bestStars": 50, "magicCrayons": ["red"]}}, "settings": {"music": false, "sfx": true}}))
	f.close()
	SaveManager.load_state()
	check(SaveManager.is_world_completed(1) and SaveManager.get_world(1).bestStars == 90 and SaveManager.unlocked_world() == 3, "un guardado anterior conserva su progreso")
	check(SaveManager.get_setting("music") == false, "y sus ajustes")
	check(SaveManager.get_rescued(1).is_empty() and SaveManager.journal_seen().is_empty(), "los campos narrativos empiezan vacíos")
	check(int(SaveManager.state.narrativeVersion) == DreamNarrative.VERSION, "versión narrativa por defecto")
	check(SaveManager.add_rescued(1, "scratch") and not SaveManager.add_rescued(1, "scratch"), "una criatura se registra una sola vez")
	SaveManager.add_rescued(3, "rabbit")
	check(not SaveManager.is_world_completed(3) and SaveManager.unlocked_world() == 3, "rescatar no completa ni desbloquea mundos")
	SaveManager.mark_world_completed(1, 10, 144)
	SaveManager.mark_journal_seen(1)
	SaveManager.load_state()
	check(SaveManager.get_rescued(1) == ["scratch"] and SaveManager.get_rescued(3) == ["rabbit"], "los rescates persisten tras recargar y tras completar el mundo")
	check(SaveManager.get_world(1).bestStars == 90, "completar otra vez no pierde la mejor marca")
	check(SaveManager.journal_seen() == [1], "las páginas vistas persisten")
	# datos inválidos en los campos nuevos: se ignoran sin fallar
	f = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"worlds": {"1": {"completed": true, "rescued": ["spit", 7, null, "spit"]}}, "journal": {"seen": ["x", 2, 2.0]}}))
	f.close()
	SaveManager.load_state()
	check(SaveManager.get_rescued(1) == ["spit"] and SaveManager.journal_seen() == [2], "campos narrativos dañados se limpian")
	SaveManager.reset_progress()
	check(SaveManager.get_rescued(1).is_empty() and SaveManager.journal_seen().is_empty(), "borrar progreso borra también la narrativa")


func test_narrative_rescue_once() -> void:
	SaveManager.reset_progress()
	await load_level("World1", _with_weapons)
	await settle()
	_clear_spawner()
	place(60, 20)
	var events: Array = []
	level.rescues.creature_rescued.connect(func(w, c): events.append([w, c]))
	var e := _spawn_enemy("scratch", 66, 20)
	e.def = e.def.duplicate()
	e.def.detect_range = 0
	await frames(3)
	e.take_damage(10, 1)
	check(not e.is_alive() and e.rescue_done, "derrota normal: la criatura queda liberada")
	check(events == [[1, "scratch"]], "creature_rescued(1, scratch) se emite una vez")
	check(RescuedCreatureManager.run_rescues().get("test:scratch") == "scratch", "el rescate se anota en la partida")
	check(SaveManager.get_rescued(1) == ["scratch"], "y en el guardado")
	# señales duplicadas o colisiones posteriores no cuentan otra vez
	check(not level.rescue_creature(e), "el mismo enemigo no se rescata dos veces")
	var twin := _spawn_enemy("scratch", 70, 20)
	twin.take_damage(10, 1)
	check(events.size() == 1 and RescuedCreatureManager.run_rescues().size() == 1, "una aparición ya rescatada no se cuenta otra vez")
	var flea := _spawn_enemy("flea", 62, 20)
	flea.take_damage(10, 1)
	check(not flea.rescue_done and events.size() == 1, "las criaturas no seleccionadas sólo se derrotan, como siempre")
	await frames(50)
	var fx: Array = level.fx_root.get_children().filter(func(n): return n is RescuedCreature)
	check(fx.size() == 1 and fx[0].creature_id == "scratch", "aparece la forma liberada de la criatura")
	check(not level.player.frozen and level.controls.enabled, "el rescate no detiene a Alice")
	await frames(130)
	fx = level.fx_root.get_children().filter(func(n): return n is RescuedCreature)
	check(fx.is_empty(), "y desaparece sola sin bloquear el avance")
	SaveManager.reset_progress()


func test_narrative_rescue_weapons() -> void:
	SaveManager.reset_progress()
	await load_level("World1", _with_weapons)
	await settle()
	_clear_spawner()
	place(60, 20)
	# Lanzaburbujas: atrapa y, al tocarlo, estrella extra + rescate
	var e := _spawn_enemy("scratch", 66, 20)
	e.spawn.id = "test:bubble"
	e.def = e.def.duplicate()
	e.def.detect_range = 0
	await frames(5)
	press("fire")
	await frames(30)
	check(e.is_trapped(), "la burbuja atrapa a la criatura")
	level.player.position.x = e.position.x
	await frames(5)
	check(level.bonus_root.get_child_count() == 1, "la estrella extra sigue apareciendo (sin duplicarse)")
	check(RescuedCreatureManager.run_rescues().has("test:bubble"), "Lanzaburbujas: la criatura queda liberada")
	# Lanzapintura y Tirachinas: daño normal hasta la derrota
	for w in ["paint", "sling"]:
		var s := _spawn_enemy("spit", 66, 20)
		s.spawn.id = "test:%s" % w
		while s.is_alive():
			s.hit_by(_w8_shot(w))
		check(RescuedCreatureManager.run_rescues().has("test:%s" % w), "%s: la criatura queda liberada" % w)
	check(RescuedCreatureManager.run_rescues().size() == 3 and SaveManager.get_rescued(1).size() == 2, "tres rescates en la partida, dos tipos en el guardado")
	SaveManager.reset_progress()


func test_narrative_boss_purification() -> void:
	SaveManager.reset_progress()
	await load_level("Boss", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle()
	place(12, 14)
	await frames(120)
	var boss: Nubarron = level.boss
	level.player.hp = 99
	level.player.max_hp = 99
	boss.invulnerable = false
	boss.hp = 1
	boss.hit_by(_w8_shot("sling"))
	check(boss.is_defeated(), "el jefe cae con su lógica original")
	var found: BossPurification = null
	for i in 400:
		await frames(1)
		var list: Array = level.fx_root.get_children().filter(func(n): return n is BossPurification)
		if not list.is_empty():
			found = list[0]
			break
	check(found != null and found.world_id == 1, "tras su animación de derrota empieza la purificación")
	check(GameState.get_v("bossPurified") == true, "el jefe queda purificado")
	check(not level.player.frozen, "la purificación no congela a Alice")
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(star.size() == 1, "la estrella dorada especial sigue saliendo")
	await frames(200)
	check(level.fx_root.get_children().filter(func(n): return n is BossPurification).is_empty(), "la purificación termina sola")
	SaveManager.reset_progress()


## Jefes de los Mundos 2-7: su derrota original termina en la purificación común (el 1 y el 8
## tienen pruebas propias).
func test_narrative_all_bosses_purify() -> void:
	for key in ["Boss2", "Boss3", "Boss4", "Boss6", "Boss5", "Boss7"]:
		SaveManager.reset_progress()
		await load_level(key, _with_weapons)
		await settle()
		place(12, 14)
		await frames(150)
		var boss: Node2D = level.boss
		var wid := WorldRegistry.id_for_scene(key)
		level.player.max_hp = 99
		level.player.hp = 99
		level.player.invulnerable_until = level.now + 1000000
		boss.invulnerable = false
		boss.hp = 1
		boss.hit_by(_w8_shot("sling"))
		var found: BossPurification = null
		for i in 420:
			await frames(1)
			var list: Array = level.fx_root.get_children().filter(func(n): return n is BossPurification)
			if not list.is_empty():
				found = list[0]
				break
		check(boss.is_defeated() and found != null and found.world_id == wid, "%s (Mundo %d): derrota original y purificación" % [key, wid])
		var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
		check(star.size() == 1 and not level.player.frozen, "%s: estrella especial y Alice libre" % key)
	SaveManager.reset_progress()


func test_narrative_journal() -> void:
	SaveManager.reset_progress()
	check(DreamJournalManager.unlocked_count() == 0 and not DreamJournalManager.has_new_pages(), "diario vacío al empezar")
	SaveManager.add_rescued(1, "scratch")
	var e := DreamJournalManager.entry(1)
	check(not e.unlocked, "visitar o rescatar no desbloquea la página")
	SaveManager.mark_world_completed(1, 97, 144, true)
	e = DreamJournalManager.entry(1)
	check(e.unlocked and e.is_new and DreamJournalManager.has_new_pages(), "completar el mundo desbloquea su página (nueva)")
	check(e.name == WorldRegistry.get_world(1).name and e.boss_name == "Nubarrón", "nombre del mundo y del jefe desde sus fuentes")
	check(e.rescued == ["scratch"] and e.rescuable.size() == 2, "criaturas rescatadas 1 de 2")
	check(e.best_stars == 97 and e.secrets_total == 0 and e.sticker_unlocked(), "estrellas y sticker (el Mundo 1 no tiene secretos)")
	SaveManager.mark_world_completed(2, 50, 160, true, 0.0, ["red"])
	var e2 := DreamJournalManager.entry(2)
	check(e2.secrets_found == 1 and e2.secrets_total == 3 and not e2.sticker_unlocked(), "Mundo 2: secretos 1 de 3, sticker pendiente")
	check(DreamJournalManager.entry(5).name == "El Reino del Tren de Juguete", "la página 5 es el Tren de Juguete (numeración del registro)")
	# interfaz: se abre en la página del mundo, se navega y se cierra
	var holder := Node.new()
	add_child(holder)
	var j := DreamJournal.open(holder, 1)
	await frames(2)
	check(j.page == 1 and j.current_world() == 1, "abre en la página del Mundo 1")
	check(not DreamJournalManager.is_new_page(1), "verla la marca como vista")
	var pages: Array = j.page_root.get_children().filter(func(n): return n is DreamJournalPage)
	check(pages.size() == 1 and pages[0].entry.world_id == 1, "dibuja la página del Mundo 1")
	await _action("move_right")
	await frames(30)
	check(j.page == 2, "derecha pasa a la página siguiente")
	await _action("move_left")
	await frames(30)
	await _action("move_left")
	await frames(30)
	check(j.page == 0, "la portada está antes de la primera página")
	var j3 := DreamJournal.open(holder, 3)
	await frames(2)
	check(j3.page == 0, "una página bloqueada abre en la portada")
	j3.close()
	await _action("pause")
	await frames(2)
	check(not is_instance_valid(j) or not j.is_open, "Esc cierra el diario")
	holder.queue_free()
	# acceso desde el menú principal (y el carrusel) y desde la victoria
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	check(menu.journal_btn != null and menu.journal_btn in menu.list.buttons, "el menú principal tiene el botón del diario")
	menu.journal_btn.activate()
	await frames(2)
	var open_j: Array = menu.get_children().filter(func(n): return n is DreamJournal)
	var sel: int = menu.carousel.worlds[menu.carousel.index].id
	check(open_j.size() == 1 and (open_j[0].current_world() == sel if SaveManager.is_world_completed(sel) else open_j[0].page == 0), "abre el diario en el mundo del carrusel (portada si está bloqueado)")
	var idx_before: int = menu.carousel.index
	await _action("ui_right")
	check(menu.carousel.index == idx_before, "con el diario abierto el carrusel no recibe teclas")
	menu.queue_free()
	await get_tree().process_frame
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 2, "stars": 1, "total": 2, "rescued": ["crayon", "brush", "crayon"], "newPage": true}
	add_child(v)
	await frames(2)
	check(v.celebration != null and v.celebration.creatures.size() == 3, "la victoria celebra las criaturas liberadas (3)")
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(list.buttons[0].label.text == "Ir al Mundo 3" and v.journal_btn in list.buttons, "victoria: botón del diario sin cambiar el primer botón")
	await frames(24)
	await _action("menu_accept")
	check(is_instance_valid(v.celebration) and v.celebration.done, "Enter salta la celebración sin activar el menú")
	await frames(30)
	check(v.journal_btn.label.text == "¡Página nueva!", "aviso de página nueva tras la celebración")
	v.queue_free()
	var v2: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 1, "stars": 1, "total": 2}
	add_child(v2)
	await frames(2)
	check(v2.celebration == null, "sin rescates no hay celebración")
	v2.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


func test_narrative_celebration_pick() -> void:
	check(RescueCelebration.make([]) == null, "sin criaturas no se crea")
	var one := RescueCelebration.make(["pompa"])
	check(one.creatures == ["pompa"], "una sola criatura")
	var many := RescueCelebration.make(["a", "a", "a", "b", "b", "b", "b"])
	check(many.creatures.size() == 5 and "a" in many.creatures and "b" in many.creatures, "como mucho cinco, variadas")
	one.free()
	many.free()


## Completa los ocho mundos con todos sus secretos y criaturas (diario completo).
func _complete_journal() -> void:
	for w in WorldRegistry.WORLDS:
		var id := int(w.id)
		var data: Dictionary = C.load_json(w.data)
		var magic: Array = data.get("magicCrayons", []).map(func(m): return m.color)
		var dream: Array = data.get("dreamCollectibles", []).map(func(d): return str(d.id))
		SaveManager.mark_world_completed(id, 10, 10, true, 1000, magic, dream)
		for c in DreamNarrative.rescuable(id):
			SaveManager.add_rescued(id, c)


func test_narrative_ending() -> void:
	SaveManager.reset_progress()
	var aw: Node2D = load(Router.SCENES.Awakening).instantiate()
	add_child(aw)
	await frames(4)
	check(aw.memories.size() == 7, "siete recuerdos en la habitación (el octavo es el gato)")
	var inside := true
	for id in aw.memories:
		var p: Vector2 = aw.memories[id].position
		inside = inside and p.x > 0 and p.x < C.GAME_W and p.y > 0 and p.y < C.GAME_H and aw.memories[id].texture != null
	check(inside, "todos visibles dentro de la habitación")
	check(aw.cat.sprite_frames == Assets.sprite_frames("gato_morado"), "el gato morado es el recuerdo del Mundo 8")
	check(not aw.diary_bonus, "sin el diario completo no hay detalle extra (el final es el mismo)")
	check(aw.light.modulate.a < 0.2, "empieza con poca luz: amanece")
	aw.set_process(false)
	aw.queue_free()
	_complete_journal()
	check(DreamJournalManager.is_complete(), "diario completo con los ocho mundos, secretos y criaturas")
	var aw2: Node2D = load(Router.SCENES.Awakening).instantiate()
	add_child(aw2)
	await frames(4)
	aw2.t = 11.5
	await frames(4)
	check(aw2.diary_bonus and aw2.diary != null, "con el diario completo, el diario brilla en la mesilla")
	aw2.set_process(false)
	aw2.queue_free()
	var cr: Control = load(Router.SCENES.Credits).instantiate()
	add_child(cr)
	await frames(4)
	check(cr.parade != null and cr.parade.get_child_count() == 6, "las criaturas liberadas desfilan en los créditos (hasta 6)")
	cr.set_process(false)
	cr.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()
