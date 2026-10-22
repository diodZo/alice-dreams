extends "res://tests/test_base.gd"
## Pruebas automáticas — Mundo 6. Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_w6_data", "test_w6_sprites", "test_w6_level_loads", "test_w6_layout",
	"test_w6_train_carry", "test_w6_train_slope", "test_w6_train_stations", "test_w6_walk_along_train",
	"test_w6_switch", "test_w6_bell_train", "test_w6_helis", "test_w6_rainbow_arch",
	"test_w6_falling_block", "test_w6_spring_wheel_bumper", "test_w6_hazard_train", "test_w6_collectibles",
	"test_w6_enemies", "test_w6_weapons_vs_enemies", "test_w6_camera", "test_w6_boss",
	"test_w6_boss_victory", "test_w6_progression",
]


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
