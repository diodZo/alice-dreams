extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 8 (final). Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w8_data", "test_w8_sprites", "test_w8_level_loads", "test_w8_ghost_platforms",
	"test_w8_shadow_damage", "test_w8_hooks_swings_and_stars", "test_w8_lantern_bridges", "test_w8_chest_and_memories",
	"test_w8_enemies", "test_w8_weapons_vs_enemies", "test_w8_slow_effect", "test_w8_boss_states",
	"test_w8_boss_attacks", "test_w8_boss_defeat_cancels", "test_w8_boss_retry_phase", "test_w8_boss_victory_and_ending", "test_w8_awakening_and_credits",
	"test_w8_progression",
]


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
	# IMP-031: cartel sólo para lo nuevo del mundo
	check(w.signs.size() <= 12, "como mucho 12 carteles (%d)" % w.signs.size())


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
				if e.def.hp >= Enemy.TOUGH_BUBBLE_HP:
					e.hit_by(p)
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


# IMP-032: desmayarse en la fase 2 o 3 reinicia el combate en esa fase, con el jefe en su umbral
# y sin la intro ni el salón (la recarga de la escena se simula cargando la arena con la fase)
func test_w8_boss_retry_phase() -> void:
	await _w8_boss_ready()
	var boss: ReyPesadelo = level.boss
	boss.invulnerable = false
	boss.phase = 2
	boss.hp = 25
	boss.take_damage(2)
	await frames(10)
	check(boss.phase == 3, "el jefe pasa a la fase 3")
	level.remember_retry_phase()
	check(GameState.get_v("bossRetryPhase") == 3, "al desmayarse se guarda la fase en curso")
	for p in [3, 2]:
		await load_level("Boss8", func(): GameState.set_v("weapon", "sling"); GameState.set_v("bossRetryPhase", p))
		await frames(3)
		boss = level.boss
		check(not GameState.data.has("bossRetryPhase"), "fase %d: la arena consume la fase guardada" % p)
		check(level.fight_started and level.player.position.x > float(level.data.triggerX) * C.TILE, "fase %d: el combate empieza sin recorrer el salón" % p)
		var hp_at := int(floor(boss.max_hp * C.BOSS_PHASE_THRESHOLDS[p - 2]))
		check(boss.phase == p and boss.hp == hp_at and int(GameState.get_v("bossHp")) == hp_at, "fase %d: el jefe empieza con %d PV" % [p, hp_at])
		check(not boss.fsm.is_state("INTRO") and boss.invulnerable, "fase %d: sin intro y con un respiro" % p)
		check(level.phase_stars.size() == level.data.phaseStars.size(), "fase %d: el escenario de la fase 2 (estrellas que caen)" % p)
		await frames(110)
		check(not boss.invulnerable and not boss.fsm.is_state(""), "fase %d: tras el respiro ataca y se le puede golpear" % p)
	await load_level("Boss8")
	await settle()
	place(70, 14)
	await frames(5)
	check(level.boss.phase == 1 and level.boss.fsm.is_state("INTRO"), "sin fase guardada: el combate empieza desde el principio")


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
