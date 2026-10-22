extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 7. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w7_data", "test_w7_sprites", "test_w7_level_loads", "test_w7_jelly_bounce",
	"test_w7_sticky_and_slippery", "test_w7_conveyor", "test_w7_hazards", "test_w7_temp_jelly_and_heart",
	"test_w7_enemies", "test_w7_weapons_vs_enemies", "test_w7_boss", "test_w7_boss_victory",
	"test_w7_progression",
]


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
	# IMP-031: cartel sólo para lo nuevo del mundo
	check(w.signs.size() <= 12, "como mucho 12 carteles (%d)" % w.signs.size())


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
