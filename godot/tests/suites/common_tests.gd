extends "res://tests/test_base.gd"
## Pruebas automáticas — Común: datos, protagonista, Mundo 1, jefes, menús y controles. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_data_parity", "test_resources", "test_save_manager", "test_player_rests_on_ground",
	"test_walk_and_run_speeds", "test_jump_height_and_variable_jump", "test_coyote_time", "test_jump_buffer",
	"test_one_way_cloud", "test_moving_platform_carries", "test_crumble_platform", "test_bounce_pad",
	"test_bouncy_cloud", "test_wind_zone", "test_hazard_damage", "test_fall_respawn_checkpoint",
	"test_playtest_log", "test_star_and_pickup", "test_weapons", "test_bubble_traps_and_star",
	"test_paint_and_sling_damage", "test_stomp", "test_scratch_ai", "test_spit_ai",
	"test_flea_ai", "test_enemy_spawner_distance", "test_boss_phases_and_victory", "test_boss_base",
	"test_integer_scaling", "test_menu_keyboard", "test_gamepad", "test_menu_art",
	"test_world_carousel", "test_pause_resume", "test_sign_bubbles_inside", "test_checkpoint_spacing",
]


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


# IMP-034: con "--playtest" los eventos del nivel se añaden a un CSV; sin él no se escribe nada
func test_playtest_log() -> void:
	var file := "user://test_playtest.csv"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	PlaytestLog.path = file
	PlaytestLog.enabled = false
	await load_level()
	await settle()
	check(not FileAccess.file_exists(file), "sin --playtest no se escribe el registro")
	PlaytestLog.enabled = true
	await load_level()
	await settle()
	place(138, 19)
	await frames(10)
	place(161, 21) # hueco 160-162
	await frames(80)
	PlaytestLog.enabled = false
	var lines := FileAccess.get_file_as_string(file).strip_edges().split("\n")
	check(lines.size() >= 4 and lines[0] == PlaytestLog.HEADER, "cabecera y una fila por evento (%d líneas)" % lines.size())
	var kinds := Array(lines).slice(1).map(func(l): return l.split(",")[5])
	check(kinds.has("inicio") and kinds.has("checkpoint") and kinds.has("caida"), "inicio, checkpoint y caída registrados (%s)" % str(kinds))
	var fall: PackedStringArray = Array(lines).filter(func(l): return l.split(",")[5] == "caida")[0].split(",")
	check(fall[2] == "1" and fall[4] == "B" and int(fall[6]) >= 158 and int(fall[6]) <= 164 and fall[8] == "2", "la caída lleva mundo, sección, tesela y vida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	PlaytestLog.path = "user://playtest.csv"


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


func _joy(ev: InputEvent) -> void:
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _joy_button(index: int, pressed: bool) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = index as JoyButton
	ev.pressed = pressed
	return ev


func _joy_axis(axis: int, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	return ev


# IMP-017: mando XInput en el Input Map, en los menús (cruceta/stick + A) y en el juego
func test_gamepad() -> void:
	var missing := []
	for a in ["move_left", "move_right", "aim_up", "jump", "fire", "switch_weapon", "run", "pause", "menu_up", "menu_down", "menu_accept"]:
		if not InputMap.action_get_events(a).any(func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion):
			missing.append(a)
	check(missing.is_empty(), "todas las acciones tienen un evento de mando (faltan %s)" % str(missing))
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	var list: MenuList = menu.get_children().filter(func(n): return n is MenuList)[0]
	var carousel: WorldCarousel = menu.carousel
	var world_before := carousel.index
	# el stick envía muchos eventos al inclinarse: cuenta como una sola pulsación
	for v in [0.3, 0.6, 0.8, 1.0, 0.9, 1.0]:
		await _joy(_joy_axis(JOY_AXIS_LEFT_X, v))
	await _joy(_joy_axis(JOY_AXIS_LEFT_X, 0.0))
	check(carousel.index == (world_before + 1) % 8, "inclinar el stick a la derecha cambia un solo mundo")
	await frames(32)
	await _joy(_joy_button(JOY_BUTTON_DPAD_DOWN, true))
	await _joy(_joy_button(JOY_BUTTON_DPAD_DOWN, false))
	check(list.index == 1 and not carousel.focused, "la cruceta abajo pasa a Música")
	var music_before := AudioManager.music_on
	await _joy(_joy_button(JOY_BUTTON_A, true))
	await _joy(_joy_button(JOY_BUTTON_A, false))
	check(AudioManager.music_on != music_before, "A activa la opción (música)")
	await _joy(_joy_button(JOY_BUTTON_A, true))
	await _joy(_joy_button(JOY_BUTTON_A, false))
	for v in [0.4, 0.9, 1.0]:
		await _joy(_joy_axis(JOY_AXIS_LEFT_Y, -v))
	await _joy(_joy_axis(JOY_AXIS_LEFT_Y, 0.0))
	check(list.index == 0 and carousel.focused and AudioManager.music_on == music_before, "el stick arriba vuelve al carrusel (un solo paso)")
	menu.queue_free()
	await get_tree().process_frame
	# en el nivel: los controles reales (no programados) leen el mando
	await load_level()
	level.controls.scripted = false
	await settle()
	place(6, 19)
	await settle()
	var x0 := level.player.position.x
	await _joy(_joy_axis(JOY_AXIS_LEFT_X, 1.0))
	await frames(30)
	check(level.player.position.x > x0 + 20, "el stick mueve a Alice")
	near(level.player.velocity.x, 95, 8, "andando con el stick")
	await _joy(_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	await frames(20)
	near(level.player.velocity.x, 150, 8, "el gatillo derecho corre")
	await _joy(_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	await _joy(_joy_axis(JOY_AXIS_LEFT_X, 0.0))
	await settle()
	await _joy(_joy_button(JOY_BUTTON_A, true))
	await frames(6)
	check(level.player.velocity.y < 0 and not level.player.grounded, "A salta")
	await _joy(_joy_button(JOY_BUTTON_A, false))
	await settle()
	await _joy(_joy_button(JOY_BUTTON_START, true))
	await frames(2)
	await _joy(_joy_button(JOY_BUTTON_START, false))
	await frames(2)
	check(get_tree().paused, "Start pausa el juego")
	await _joy(_joy_button(JOY_BUTTON_START, true))
	await frames(2)
	await _joy(_joy_button(JOY_BUTTON_START, false))
	await frames(2)
	check(not get_tree().paused, "y Start lo reanuda")
	level.controls.reset()


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


# IMP-003: los ocho jefes heredan de BossBase; el daño y los umbrales de fase viven sólo en la base
func test_boss_base() -> void:
	var bosses := ["Nubarron", "Garabato", "ReySieston", "ReyPatoburbuja", "LunaEstelar", "Locomostro", "DonChupeton", "ReyPesadelo"]
	var hp := {"Nubarron": 40, "Garabato": 48, "ReySieston": 50, "ReyPatoburbuja": 50, "LunaEstelar": 50, "Locomostro": 60, "DonChupeton": 65, "ReyPesadelo": 80}
	var wrong := []
	for name in bosses:
		var boss: Node = load("res://scenes/bosses/%s.tscn" % name).instantiate()
		var script: GDScript = boss.get_script()
		if not boss is BossBase or script.source_code.contains("func hit_by") or script.source_code.contains("func take_damage") or boss.max_hp != hp[name] or boss.hp != hp[name] or boss.phase_data().is_empty():
			wrong.append(name)
		boss.free()
	check(wrong.is_empty(), "los 8 jefes heredan de BossBase con su vida y sus fases (fallan %s)" % str(wrong))
	# IMP-033: las muescas de la barra del jefe están en los umbrales reales de cambio de fase
	await load_level()
	var notches: Array = level.hud.boss_notches.map(func(n): return (n.position.x + 100) / 200.0)
	check(notches.size() == 2 and BossBase.PHASE_THRESHOLDS.size() == 2 and notches.all(func(x): return BossBase.PHASE_THRESHOLDS.any(func(t): return absf(t - x) < 0.01)), "muescas de la barra del jefe en %s" % str(notches))


# IMP-002: escalado entero (píxeles iguales, con bandas si la pantalla no es múltiplo de 480x270)
func test_integer_scaling() -> void:
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "viewport" and ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer", "ventana a 480x270 escalada por un factor entero")
	check(get_window().content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER, "la ventana aplica el escalado entero")


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
