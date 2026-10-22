extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 4. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w4_data", "test_w4_sprites", "test_w4_level_loads", "test_w4_layout",
	"test_w4_slopes", "test_w4_water", "test_w4_geyser_and_column", "test_w4_obstacles",
	"test_w4_enemies", "test_w4_weapons_vs_enemies", "test_w4_boss", "test_w4_boss_victory",
	"test_w4_progression",
]


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
