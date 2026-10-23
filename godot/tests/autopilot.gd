extends Node
## Piloto automático para comprobar que un mundo (1-8) se puede recorrer de principio a fin con
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
var was_dead := false
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
## Fotogramas seguidos sobre la misma plataforma móvil.
var ride_frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("max_frames="):
			max_frames = int(a.substr(11))
		if a == "godmode":
			godmode = true
		if a.begins_with("start="):
			start_tile = float(a.substr(6))
	AudioManager.sfx_on = false # sin persistir: no toca el guardado del usuario
	# sin música (tampoco se guarda): una reproducción viva al salir hace que el motor avise a
	# veces de objetos sin liberar y la regresión daría un falso fallo
	AudioManager.music_on = false
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
	# una caída cuenta una vez (mientras dura el fundido Alice sigue muerta con la misma vida)
	if p.hp < last_hp or (p.dead and not was_dead):
		deaths += 1
		if "hits" in OS.get_cmdline_user_args():
			print("[autopilot] golpe/caída en x=%.0f (tesela %d) y=%.0f" % [p.position.x, int(p.position.x / 16), p.position.y])
	last_hp = p.hp
	was_dead = p.dead
	best_x = maxf(best_x, p.position.x)
	if frame % 600 == 0:
		print("[autopilot] f=%d x=%.0f (tesela %d) mejor=%d hp=%d golpes=%d estrellas=%d" % [frame, p.position.x, int(p.position.x / 16), int(best_x / 16), p.hp, deaths, int(GameState.get_v("stars", 0))])
	if "trace_train" in OS.get_cmdline_user_args() and frame % 5 == 0 and not level.level_objects.get("trains", []).is_empty():
		var tl: TrainLine = level.level_objects.trains[0]
		for cand in level.level_objects.trains:
			if absf(cand.cars[0].position.x - p.position.x) < absf(tl.cars[0].position.x - p.position.x):
				tl = cand
		print("  f=%d p=(%.1f,%.1f) v=(%.0f,%.0f) g=%s ride=%s train s=%.1f v=%.0f car0=(%.1f,%.1f) hold=%s press=%s" % [frame, p.position.x, p.position.y, p.velocity.x, p.velocity.y, p.grounded, _riding_mover(p) != null, tl.s, tl.v, tl.cars[0].position.x, tl.cars[0].position.y, str(c.script_held.keys()), str(c.script_pressed.keys())])
	if "trace" in OS.get_cmdline_user_args() and frame % 5 == 0:
		var m: MovingPlatform = level.level_objects.movers[0]
		print("  f=%d p=(%.1f,%.1f) v=(%.0f,%.0f) g=%s mover=(%.1f,%.1f) ride=%s wait=%d hold=%s" % [frame, p.position.x, p.position.y, p.velocity.x, p.velocity.y, p.grounded, m.position.x, m.position.y, _riding_mover(p) != null, wait_frames, str(c.script_held.keys())])
	if "trace_swing" in OS.get_cmdline_user_args() and frame % 5 == 0:
		var sw: Array = level.level_objects.movers.filter(func(m): return m is SwingPlatform).map(func(m): return "(%.0f,%.0f)" % [m.position.x, _surface_y(m)])
		print("  f=%d p=(%.1f,%.1f) v=(%.0f,%.0f) g=%s ride=%s swings=%s hold=%s" % [frame, p.position.x, p.position.y, p.velocity.x, p.velocity.y, p.grounded, _riding_mover(p) != null, " ".join(sw), str(c.script_held.keys())])
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
	if p.in_water():
		# nadando (Mundo 4): brazadas a ritmo constante con los mismos controles que un jugador
		if frame % 14 == 0:
			c.script_pressed["jump"] = true
		return
	if not p.grounded:
		# en el aire: si hay una nube móvil debajo, se orienta hacia su centro
		if p.velocity.y < -400:
			target_x = NAN # rebote (nube elástica, cojín): sigue hacia delante
		if target_mover == null and is_nan(target_x) and p.velocity.y > 0:
			# cayendo sin destino (p. ej. tras rebotar en un monstruo junto a un hueco): se orienta
			# hacia la plataforma con hélice del hueco si queda debajo (Mundo 5)
			var below := _mover_in_gap(p)
			if below is HeliPlatform and absf(below.position.x - p.position.x) < 60 and _surface_y(below) > p.position.y:
				target_mover = below
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
					# una plataforma colgante se aleja deprisa: corre para alcanzarla
					c.script_held["run"] = m is SwingPlatform and m.position.x - p.position.x > 24
				elif p.position.x > m.position.x + 4:
					c.script_held["move_left"] = true
		return
	target_mover = null
	target_x = NAN
	var riding := _riding_mover(p)
	ride_frames = ride_frames + 1 if riding != null else 0
	if riding is TrainCar:
		# tren del Mundo 6: lo conduce hacia delante (ARRIBA + derecha: las flechas eligen el
		# sentido y no mueven a Alice) hasta el tope del final; allí se baja hacia delante
		var line: TrainLine = riding.line
		c.script_held.erase("move_right")
		c.script_held.erase("run")
		if line.can_move(1):
			c.script_held["aim_up"] = true
			c.script_held["move_right"] = true
			return
		if line.is_stopped():
			c.script_held["move_right"] = true
			c.script_held["run"] = true
			if not _support_ahead(p.position + Vector2(18, 4)) or level.terrain_solid_at(p.position + Vector2(14, -10)):
				c.script_pressed["jump"] = true
				c.script_held["jump"] = true
				jump_hold = 40
		return
	var next := _next_mover(p, riding) if riding != null else null
	if next != null:
		# cadena de plataformas colgantes (Mundo 8): salta a la siguiente cuando queda al alcance
		target_mover = next
		c.script_pressed["jump"] = true
		c.script_held["jump"] = true
		jump_hold = 6 # salto corto: menos tiempo en el aire mientras la siguiente se mueve
		return
	if riding != null and ride_frames > 240:
		# plataforma opcional sin suelo cerca (secretos del Mundo 3): se baja andando
		return
	if riding != null:
		# se deja llevar por la nube móvil y salta cuando el suelo queda cerca
		c.script_held.erase("move_right")
		c.script_held.erase("run")
		# también suelo más bajo (asientos de las cuerdas del Mundo 3, por encima del borde) o un
		# saliente hasta dos teselas más alto (cohetes del Mundo 5)
		for d in [20, 36, 52, 68, 84, 100]:
			# sólo una superficie pisable (con hueco encima), no la cara de un muro
			if [-28, -12, 4, 20, 36, 52, 68].any(func(dy): return level.terrain_solid_at(p.position + Vector2(d, dy)) and not level.terrain_solid_at(p.position + Vector2(d, dy - 20))):
				c.script_held["move_right"] = true
				c.script_held["run"] = true
				c.script_pressed["jump"] = true
				c.script_held["jump"] = true
				jump_hold = 40
				break
		return
	var board := _train_to_board(p)
	if board != null:
		# sube al vagón de un tren parado en su estación
		target_mover = board
		c.script_pressed["jump"] = true
		c.script_held["jump"] = true
		jump_hold = 20
		return
	var gap := not _support_ahead(p.position + Vector2(18, 4))
	var wall := level.terrain_solid_at(p.position + Vector2(14, -10))
	var enemy := _enemy_ahead(p)
	if gap:
		var mover := _mover_in_gap(p)
		if mover is TrainCar or (mover == null and _track_over_gap(p)):
			# a un tren se sube cuando está parado en su estación (si no, vuelve solo a buscarla)
			wait_frames = 4
			c.script_held.erase("move_right")
			return
		if mover != null:
			# espera a que la nube móvil esté cerca antes de saltar
			# salta cuando la nube está cerca y viene hacia la protagonista o se aleja despacio
			var dx := mover.position.x - p.position.x
			var mv: float = mover.position.x - float(mover_prev.get(mover, mover.position.x))
			# una plataforma vertical se espera hasta que queda al alcance de un salto
			var sy := _surface_y(mover)
			var far_y: bool = _is_lift(mover) and (sy < p.position.y - 40 or sy > p.position.y + 12)
			if dx < 30 or dx > 60 or mv > 1.2 or far_y:
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
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	# plataforma fantasma del Mundo 8: desaparece con su ciclo, no es un apoyo seguro (se salta)
	if hit.collider is GhostPlatform:
		return false
	# una plataforma fija es apoyo; una móvil en el hueco no (hay que esperarla)
	return not (hit.collider is MovingPlatform and not _is_static(hit.collider)) or _mover_in_gap(level.player) == null


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
		# sólo apoyos al alcance de un salto (las rutas altas opcionales no sirven de aterrizaje)
		if not hit.is_empty() and hit.position.y >= p.position.y - 56 and not hit.collider is GhostPlatform:
			return x + 12
	return NAN


func _riding_mover(p: Player) -> MovingPlatform:
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		if col.get_collider() is MovingPlatform and not _is_static(col.get_collider()):
			return col.get_collider()
	return null


## Plataforma que no se mueve (hélice fija del Mundo 6): cuenta como suelo.
func _is_static(m: Object) -> bool:
	return m.has_method("is_static") and m.is_static()


## Plataforma con recorrido vertical largo (ascensor), no un simple vaivén.
func _is_lift(m: MovingPlatform) -> bool:
	return absf(m.delta_px.y) > 2 * C.TILE


## Altura de la superficie pisable de una plataforma (borde superior de su franja de colisión).
func _surface_y(m: MovingPlatform) -> float:
	for child in m.get_children():
		if child is CollisionShape2D:
			return m.position.y + child.position.y - 5.0
	return m.position.y


func _mover_in_gap(p: Player) -> MovingPlatform:
	for m in level.level_objects.movers:
		if _is_static(m):
			continue
		var span_l: float = m.start.x - 40
		var span_r: float = m.start.x + m.delta_px.x + 40
		# plataformas verticales (cohete ascensor del Mundo 5): cuentan en todo su recorrido
		var lo: float = minf(m.start.y, m.start.y + m.delta_px.y) - 40
		var hi: float = maxf(m.start.y, m.start.y + m.delta_px.y) + 40
		var near_y: bool = absf(m.position.y - p.position.y) < 40 or (_is_lift(m) and p.position.y > lo and p.position.y < hi)
		if p.position.x > span_l - 60 and p.position.x < span_r and near_y:
			if not level.terrain_solid_at(p.position + Vector2(18, 4)):
				return m
	return null


## Plataforma colgante por delante, a la altura de la que se monta y a distancia de salto
## (cadena de columpios sobre un foso del Mundo 8; con suelo cerca se salta al suelo).
func _next_mover(p: Player, riding: MovingPlatform) -> MovingPlatform:
	if not riding is SwingPlatform:
		return null
	for m in level.level_objects.movers:
		if m == riding or not m is SwingPlatform:
			continue
		var dx: float = m.position.x - p.position.x
		if dx > 56 and dx < 96 and absf(_surface_y(m) - _surface_y(riding)) < 12:
			# salta en el extremo derecho del vaivén: mientras vuela, la siguiente viene hacia Alice
			var mv: float = riding.position.x - float(mover_prev.get(riding, riding.position.x))
			var right_half: bool = riding.position.x > riding.start.x + riding.delta_px.x * 0.5
			return m if right_half and absf(mv) < 0.5 else null
	return null


## ¿Cruza el hueco de delante la vía de un tren del Mundo 6? (aunque el tren esté lejos)
func _track_over_gap(p: Player) -> bool:
	for line in level.level_objects.get("trains", []):
		var pts: PackedVector2Array = line.common
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q in pts:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		var x := p.position.x + 24
		if x > lo.x - 8 and x < hi.x and p.position.y > lo.y - 80 and p.position.y < hi.y + 60:
			return true
	return false


## Vagón al que subir: un tren del Mundo 6 parado justo delante (en su estación de salida o donde
## Alice lo dejó: si no está a su alcance, vuelve solo a buscarla).
func _train_to_board(p: Player) -> TrainCar:
	for line in level.level_objects.get("trains", []):
		if not line.is_stopped():
			continue
		# fuera de su estación sólo un tren por delante (al bajarse en el final queda detrás)
		var lo := -64.0 if line.s <= line.s_min() + 1 else 8.0
		var best: TrainCar = null
		for car in line.cars:
			var dx: float = car.position.x - p.position.x
			if dx > lo and dx < 70 and absf(car.position.y - p.position.y) < 40 and (best == null or absf(dx) < absf(best.position.x - p.position.x)):
				best = car
		if best != null:
			return best
	return null


func _enemy_ahead(p: Player) -> bool:
	# barreras de estrella del Mundo 6: se saltan como un monstruo
	for o in level.level_objects.objects.get_children():
		if o is StarBumper and o.position.x - p.position.x > 0 and o.position.x - p.position.x < 40 and absf(o.position.y - p.position.y) < 24:
			return true
		# ruedas rodantes que vienen hacia Alice: también se saltan
		if o is RollingWheel and o.visible and o.position.x - p.position.x > 0 and o.position.x - p.position.x < 46 and absf(o.position.y - p.position.y) < 30:
			return true
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
	# libera el nivel (y lo que tenga pendiente: fundido, cambio de escena) antes de salir; si no,
	# el motor avisa a veces de objetos sin liberar al cerrar
	if is_instance_valid(level):
		level.queue_free()
	Fader.clear()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
