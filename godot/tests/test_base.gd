extends Node
## Base de los grupos de pruebas (tests/suites/*.gd) y del lanzador run_tests.gd: utilidades
## compartidas y el recuento común (variables estáticas: lo suman todos los grupos).

static var passed := 0
static var failed := 0
static var current := ""
static var level: Level


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


func _with_weapons() -> void:
	GameState.set_v("weaponsOwned", ["bubble", "paint", "sling"])
	GameState.set_v("weapon", "bubble")


func _spawn_enemy(type: String, tx: float, ty: float) -> Enemy:
	var e: Enemy = EnemySpawner.SCENES[type].instantiate()
	e.setup(level, {"id": "test:%s" % type, "type": type, "x": tx * C.TILE + 8, "y": ty * C.TILE, "patrol": [(tx - 3) * C.TILE, (tx + 3) * C.TILE]})
	level.enemies_root.add_child(e)
	return e


func _clear_spawner() -> void:
	level.spawner.pending = []
	level.spawner.reset_active()


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


func _w5_shots(kind: String) -> int:
	return level.enemy_projectiles.get_children().filter(func(n): return n is Projectile and n.active and n.kind == kind).size()


func _w6_spawn(type: String, dx: float, dy := 0.0, extra := {}) -> Enemy:
	var e: Enemy = EnemySpawner.SCENES[type].instantiate()
	var p := level.player.position
	var s := {"id": "test_" + type + str(randi()), "x": p.x + dx, "y": p.y + dy, "patrol": [p.x + dx - 40, p.x + dx + 40]}
	s.merge(extra, true)
	e.setup(level, s)
	level.enemies_root.add_child(e)
	return e


func _w7_run_speed(tx: float, ty: float) -> float:
	place(tx, ty); await frames(4)
	hold(["move_right", "run"])
	await frames(40)
	var v := level.player.velocity.x
	hold([])
	return v


func _w8_shot(w := "sling") -> Projectile:
	var p: Projectile = level.spawn_projectile("player", {"x": 0, "y": 0, "vx": 0, "vy": 0, "kind": w, "frame": "pellet", "lifespan": 100})
	p.weapon = Assets.weapon(w)
	p.active = false
	return p
