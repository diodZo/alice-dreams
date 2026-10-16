extends Node
## Piloto automático para comprobar que el Mundo 1 se puede recorrer de principio a fin con
## la física migrada (sin teletransportes). Sólo usa los mismos controles que un jugador:
## correr, saltar (manteniendo el botón), disparar y apuntar.
##   godot --headless --path godot --fixed-fps 60 res://tests/Autopilot.tscn [-- max_frames=40000]
## Imprime el avance y termina con código 0 si llega a la puerta del castillo.

var level: Level
var frame := 0
var max_frames := 40000
var best_x := 0.0
var deaths := 0
var last_hp := 3
var wait_frames := 0
var jump_hold := 0
var stuck_frames := 0
var last_x := 0.0
var reached := false
var start_tile := -1.0
## Sin daño de enemigos ni peligros (las caídas al vacío sí cuentan): comprueba sólo que el
## recorrido es físicamente posible con los saltos y plataformas migrados.
var godmode := false
var mover_prev := {}
## Nube móvil hacia la que se ha saltado (para orientarse en el aire).
var target_mover: MovingPlatform = null
## Punto de aterrizaje elegido al saltar un hueco (NAN = ninguno).
var target_x := NAN


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("max_frames="):
			max_frames = int(a.substr(11))
		if a == "godmode":
			godmode = true
		if a.begins_with("start="):
			start_tile = float(a.substr(6))
	AudioManager.sfx_on = false # sin persistir: no toca el guardado del usuario
	SaveManager.save_path = "user://tools_save.json"
	SaveManager.load_state()
	var world := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("world="):
			world = int(a.substr(6))
	var scene_key := WorldRegistry.start_run(world)
	level = load(Router.SCENES[scene_key]).instantiate()
	add_child(level)
	level.controls.scripted = true
	if start_tile >= 0:
		# empieza en otra tesela (sobre el suelo de esa columna): para probar un tramo concreto
		var x := start_tile * C.TILE + 8
		var y := 0.0
		while not level.terrain_solid_at(Vector2(x, y + 8)) and y < level.world_h:
			y += C.TILE
		level.player.position = Vector2(x, y)
		level.camera.snap_to_target()
	level.tree_exiting.connect(func(): reached = level.leaving)


func _physics_process(_delta: float) -> void:
	frame += 1
	if not is_instance_valid(level) or level.leaving:
		_finish(true)
		return
	if frame > max_frames:
		_finish(false)
		return
	var p := level.player
	var c := level.controls
	c.script_held.clear()
	if p.hp < last_hp or (p.dead and last_hp > 0):
		deaths += 1
	last_hp = p.hp
	best_x = maxf(best_x, p.position.x)
	if frame % 600 == 0:
		print("[autopilot] f=%d x=%.0f (tesela %d) mejor=%d hp=%d golpes=%d estrellas=%d" % [frame, p.position.x, int(p.position.x / 16), int(best_x / 16), p.hp, deaths, int(GameState.get_v("stars", 0))])
	if "trace" in OS.get_cmdline_user_args() and frame % 5 == 0:
		var m: MovingPlatform = level.level_objects.movers[0]
		print("  f=%d p=(%.1f,%.1f) v=(%.0f,%.0f) g=%s mover=(%.1f,%.1f) ride=%s wait=%d hold=%s" % [frame, p.position.x, p.position.y, p.velocity.x, p.velocity.y, p.grounded, m.position.x, m.position.y, _riding_mover(p) != null, wait_frames, str(c.script_held.keys())])
	if p.dead or level.respawning:
		return
	if godmode:
		p.invulnerable_until = level.now + 1000
	# siempre dispara al frente (el lanzaburbujas admite mantener pulsado)
	c.script_held["fire"] = true
	if wait_frames > 0:
		wait_frames -= 1
		return
	c.script_held["move_right"] = true
	c.script_held["run"] = true
	if jump_hold > 0:
		jump_hold -= 1
		c.script_held["jump"] = true
	# atascado contra algo: salta
	if absf(p.position.x - last_x) < 0.2:
		stuck_frames += 1
	else:
		stuck_frames = 0
	last_x = p.position.x
	if not p.grounded:
		# en el aire: si hay una nube móvil debajo, se orienta hacia su centro
		if p.velocity.y < -400:
			target_x = NAN # rebote (nube elástica, cojín): sigue hacia delante
		if not is_nan(target_x) and target_mover == null:
			c.script_held.erase("move_right")
			c.script_held.erase("run")
			if p.position.x < target_x - 3:
				c.script_held["move_right"] = true
				c.script_held["run"] = target_x - p.position.x > 40
			elif p.position.x > target_x + 3:
				c.script_held["move_left"] = true
		var m := target_mover
		if m != null and absf(m.position.x - p.position.x) < 90 and m.position.y > p.position.y - 8:
			if true:
				c.script_held.erase("move_right")
				c.script_held.erase("run")
				if p.position.x < m.position.x - 4:
					c.script_held["move_right"] = true
				elif p.position.x > m.position.x + 4:
					c.script_held["move_left"] = true
		return
	target_mover = null
	target_x = NAN
	var riding := _riding_mover(p)
	if riding != null:
		# se deja llevar por la nube móvil y salta cuando el suelo queda cerca
		c.script_held.erase("move_right")
		c.script_held.erase("run")
		for d in [20, 36, 52, 68, 84, 100]:
			if level.terrain_solid_at(p.position + Vector2(d, 4)):
				c.script_held["move_right"] = true
				c.script_held["run"] = true
				c.script_pressed["jump"] = true
				c.script_held["jump"] = true
				jump_hold = 40
				break
		return
	var gap := not _support_ahead(p.position + Vector2(18, 4))
	var wall := level.terrain_solid_at(p.position + Vector2(14, -10))
	var enemy := _enemy_ahead(p)
	if gap:
		var mover := _mover_in_gap(p)
		if mover != null:
			# espera a que la nube móvil esté cerca antes de saltar
			# salta cuando la nube está cerca y viene hacia la protagonista o se aleja despacio
			var dx := mover.position.x - p.position.x
			var mv: float = mover.position.x - float(mover_prev.get(mover, mover.position.x))
			if dx < 30 or dx > 60 or mv > 1.2:
				wait_frames = 4
				c.script_held.erase("move_right")
				return
			target_mover = mover
	if gap and target_mover == null:
		target_x = _find_landing(p)
	if gap or wall or enemy or stuck_frames > 20:
		c.script_pressed["jump"] = true
		c.script_held["jump"] = true
		jump_hold = 40
		stuck_frames = 0


## ¿Hay algo que pisar delante? (terreno o plataformas unidireccionales, incluida la móvil)
func _support_ahead(pos: Vector2) -> bool:
	for dy in [4, 20, 36, 52]:
		if level.terrain_solid_at(Vector2(pos.x, pos.y - 4 + dy)):
			return true
	var space := level.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -6), pos + Vector2(0, 40), C.L_ONE_WAY)
	q.hit_from_inside = true
	return not space.intersect_ray(q).is_empty() and _mover_in_gap(level.player) == null


func _process(_delta: float) -> void:
	if is_instance_valid(level) and level.level_objects:
		for m in level.level_objects.movers:
			mover_prev[m] = m.position.x


## Primer apoyo por delante (terreno o plataforma unidireccional) alcanzable con un salto.
func _find_landing(p: Player) -> float:
	var space := level.get_world_2d().direct_space_state
	for d in range(24, 126, 6):
		var x := p.position.x + d
		var y := p.position.y - 64.0
		while y < p.position.y + 40:
			if level.terrain_solid_at(Vector2(x, y + 2)) and not level.terrain_solid_at(Vector2(x, y - 14)):
				return x + 14
			y += 8
		var q := PhysicsRayQueryParameters2D.create(Vector2(x, p.position.y - 80), Vector2(x, p.position.y + 48), C.L_ONE_WAY)
		q.hit_from_inside = true
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return x + 12
	return NAN


func _riding_mover(p: Player) -> MovingPlatform:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		if col.get_collider() is MovingPlatform:
			return col.get_collider()
	return null


func _mover_in_gap(p: Player) -> MovingPlatform:
	for m in level.level_objects.movers:
		var span_l: float = m.start.x - 40
		var span_r: float = m.start.x + m.delta_px.x + 40
		if p.position.x > span_l - 60 and p.position.x < span_r and absf(m.position.y - p.position.y) < 40:
			if not level.terrain_solid_at(p.position + Vector2(18, 4)):
				return m
	return null


func _enemy_ahead(p: Player) -> bool:
	for e in level.enemies_root.get_children():
		if is_instance_valid(e) and not e.finished and e.is_alive() and not e.is_trapped():
			var dx: float = e.position.x - p.position.x
			if dx > 0 and dx < 34 and absf(e.position.y - p.position.y) < 24:
				return true
	return false


func _finish(ok: bool) -> void:
	set_physics_process(false)
	print("[autopilot] %s en %d fotogramas (%.0f s de juego): mejor tesela %d, golpes/caídas %d, estrellas %d" % [
		"LLEGA A LA PUERTA DEL JEFE" if ok else "NO llega", frame, frame / 60.0, int(best_x / 16), deaths, int(GameState.get_v("stars", 0))])
	get_tree().quit(0 if ok else 1)
