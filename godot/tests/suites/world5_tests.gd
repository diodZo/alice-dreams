extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 5. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w5_data", "test_w5_sprites", "test_w5_level_loads", "test_w5_layout",
	"test_w5_slopes", "test_w5_platforms", "test_w5_slide", "test_w5_light_fall",
	"test_w5_falling_star", "test_w5_explosive_cloud", "test_w5_enemies", "test_w5_weapons_vs_enemies",
	"test_w5_boss", "test_w5_boss_victory", "test_w5_progression",
]


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
