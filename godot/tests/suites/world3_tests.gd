extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 3. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w3_data", "test_w3_sprites", "test_w3_level_loads", "test_w3_mechanics",
	"test_w3_enemies", "test_w3_boss", "test_w3_progression",
]


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
	# IMP-027: ningún Ovillo (embiste) patrulla a menos de 4 teselas de un foso que se cruza con cuerda
	var ground := {}
	for t in w.terrain:
		for x in range(int(t.x), int(t.x) + int(t.w)):
			ground[x] = true
	var near_rope := []
	for e in w.enemies.filter(func(e): return e.type == "wool"):
		for x in range(int(e.patrol[0]) - 4, int(e.patrol[1]) + 5):
			if not ground.has(x) and w.swings.any(func(s): return absf(float(s.x) - x) <= 6):
				near_rope.append(int(e.x))
				break
	check(near_rope.is_empty(), "ningún Ovillo junto a un foso con cuerda (%s)" % str(near_rope))
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
