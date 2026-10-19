class_name TrainLine
extends Node2D
## Tren de juguete del Mundo 6: una locomotora y sus vagones recorren una vía configurable.
##  - La vía es un Path2D (Curve2D poligonal): un tramo común y, opcionalmente, dos ramales que
##    salen del final del tramo común (desvío). Admite pendientes: los vagones siguen la altura
##    de la vía sin girar (la franja pisable queda siempre horizontal y estable).
##  - Cada vagón es un TrainCar (AnimatableBody2D con sync_to_physics): Godot traslada a Alice
##    cuando va encima, puede andar y saltar desde él y no la atraviesa (colisión unidireccional).
##  - Movimiento determinista sobre el reloj del nivel: acelera y frena con suavidad (frenada
##    calculada para parar justo en cada estación), espera en las estaciones y en los topes del
##    final da la vuelta (ida y vuelta).
##  - Desvío: la palanca pide un ramal (pending_branch); el tren sólo lo toma en un punto seguro,
##    cuando toda la composición está en el tramo común (nunca a mitad del ramal o de una curva).
##  - Con bell_wait el tren espera en las estaciones hasta que suena una campana.

signal arrived(stop_s: float)
signal branch_changed(branch: int)

const CAR_GAP := 3.0
const MIN_SPEED := 6.0
## Tiempo para subir después de tocar la campana.
const BOARD_MS := 1600.0

var level: Node
var atlas := ""
var path: Path2D
var common := PackedVector2Array()
var branches: Array = []
var branch := 0
var pending_branch := 0
## Longitud del tramo común (punto de decisión del desvío).
var decision_s := 0.0
var cars: Array = []
## Distancia (a lo largo de la vía) de cada vagón por detrás de la locomotora.
var offsets: Array[float] = []
var train_len := 0.0
var s := 0.0
var v := 0.0
var dir := 1
var max_speed := 60.0
var accel := 50.0
var wait_ms := 1600.0
var wait_left := 0.0
var bell_wait := false
var called := false
var stop_xs: Array = []
var rails: Array[Line2D] = []
var _tick_frame := -1
var _stops_cache: Array = []
var _last_x := 0.0
## Velocidad horizontal de la composición en el último paso (px/s, con signo).
var velocity_x := 0.0


## def: { points: [[x, y]...] (teselas: altura del carril), branches: [[[x, y]...], [[x, y]...]],
##        branch, cars: ["train_loco", "train_red"...], speed, accel (px/s, px/s²), wait (ms),
##        stops: [x...] (teselas: dónde para la locomotora), start ("begin" | "end"), bellWait }
func setup(owner_level: Node, def: Dictionary, atlas_name: String) -> TrainLine:
	level = owner_level
	atlas = atlas_name
	z_index = C.Z_PLATFORM
	for p in def.points:
		common.append(Vector2(float(p[0]), float(p[1])) * C.TILE)
	for b in def.get("branches", []):
		var pts := PackedVector2Array()
		for p in b:
			pts.append(Vector2(float(p[0]), float(p[1])) * C.TILE)
		branches.append(pts)
	branch = int(def.get("branch", 0))
	pending_branch = branch
	max_speed = float(def.get("speed", 60))
	accel = float(def.get("accel", 50))
	wait_ms = float(def.get("wait", 1600))
	bell_wait = bool(def.get("bellWait", false))
	stop_xs = def.get("stops", [])
	path = Path2D.new()
	path.name = "Route"
	add_child(path)
	_draw_rails()
	_rebuild_curve()
	# composición: la primera pieza (locomotora) va delante en el sentido de ida
	var acc := 0.0
	var prev_half := 0.0
	var names: Array = def.get("cars", ["train_loco", "train_red"])
	for i in names.size():
		var car := TrainCar.new().setup_car(self, names[i], i)
		var half: float = car.width / 2.0
		if i > 0:
			acc += prev_half + CAR_GAP + half
		offsets.append(acc)
		prev_half = half
		cars.append(car)
	train_len = acc
	s = s_max() if str(def.get("start", "begin")) == "end" else s_min()
	dir = -1 if str(def.get("start", "begin")) == "end" else 1
	wait_left = float(def.get("delay", 600))
	_place_cars()
	_last_x = cars[0].position.x if not cars.is_empty() else 0.0
	return self


func _route() -> PackedVector2Array:
	var pts := common.duplicate()
	if not branches.is_empty():
		var b: PackedVector2Array = branches[branch]
		for i in b.size():
			if i == 0 and b[0].is_equal_approx(pts[pts.size() - 1]):
				continue
			pts.append(b[i])
	return pts


func _rebuild_curve() -> void:
	var curve := Curve2D.new()
	curve.bake_interval = 2.0
	var pts := _route()
	for i in pts.size():
		if i == 0 or i == pts.size() - 1:
			curve.add_point(pts[i])
			continue
		# esquina redondeada (arranque y final de cada pendiente): los tramos rectos siguen
		# rectos y la esquina se sustituye por una curva corta por dentro del ángulo
		var a := (pts[i] - pts[i - 1])
		var b := (pts[i + 1] - pts[i])
		if absf(a.angle_to(b)) < 0.01:
			curve.add_point(pts[i])
			continue
		var r := minf(minf(a.length(), b.length()) * 0.3, 24.0)
		var an := a.normalized()
		var bn := b.normalized()
		curve.add_point(pts[i] - an * r, Vector2.ZERO, an * r * 0.55)
		curve.add_point(pts[i] + bn * r, -bn * r * 0.55, Vector2.ZERO)
	path.curve = curve
	var cc := Curve2D.new()
	cc.bake_interval = 2.0
	for p in common:
		cc.add_point(p)
	decision_s = cc.get_baked_length() if not branches.is_empty() else INF
	_stops_cache = []
	_update_rail_tint()


func length() -> float:
	return path.curve.get_baked_length()


func s_min() -> float:
	return train_len


func s_max() -> float:
	return length()


## Punto del carril a una distancia de la vía (fuera de la vía se prolonga en horizontal).
func rail_point(d: float) -> Vector2:
	return path.curve.sample_baked(clampf(d, 0.0, length()))


## Paradas en coordenadas de la vía (distancia de la locomotora). Los topes siempre lo son.
func stops() -> Array:
	if not _stops_cache.is_empty():
		return _stops_cache
	var out: Array = [s_min(), s_max()]
	var curve := path.curve
	for x in stop_xs:
		var target := float(x) * C.TILE
		# punto de la vía más cercano a esa x
		var best := 0.0
		var best_d := INF
		var d := 0.0
		while d <= length():
			var dx := absf(curve.sample_baked(d).x - target)
			if dx < best_d:
				best_d = dx
				best = d
			d += 2.0
		if best_d < C.TILE and best > s_min() + 1 and best < s_max() - 1:
			out.append(best)
	out.sort()
	_stops_cache = out
	return out


## Un paso de simulación (idempotente por fotograma de física: lo llama cada vagón).
func tick(delta_ms: float) -> void:
	var f := Engine.get_physics_frames()
	if f == _tick_frame:
		return
	_tick_frame = f
	var dt := delta_ms / 1000.0
	_try_switch()
	if wait_left > 0:
		# con bell_wait sólo espera a la campana en su estación de salida (nunca se queda al otro lado)
		if bell_wait and not called and s <= s_min() + 0.5 and wait_left <= delta_ms:
			wait_left = delta_ms + 1  # sigue esperando a la campana
		else:
			wait_left -= delta_ms
		v = 0.0
		velocity_x = 0.0
		return
	var target := _next_stop()
	var dist := absf(target - s)
	var brake := sqrt(2.0 * accel * dist)
	var want := minf(max_speed, brake)
	v = move_toward(v, want, accel * dt)
	var step := maxf(v, MIN_SPEED) * dt
	if step >= dist:
		s = target
		_arrive(target)
	else:
		s += dir * step
	_place_cars()
	velocity_x = (cars[0].position.x - _last_x) / maxf(dt, 0.0001)
	_last_x = cars[0].position.x


func _next_stop() -> float:
	var list := stops()
	if dir > 0:
		for x in list:
			if x > s + 0.01:
				return x
		return s_max()
	for i in range(list.size() - 1, -1, -1):
		if list[i] < s - 0.01:
			return list[i]
	return s_min()


func _arrive(stop_s: float) -> void:
	v = 0.0
	wait_left = wait_ms
	called = false
	if stop_s >= s_max() - 0.5:
		dir = -1
	elif stop_s <= s_min() + 0.5:
		dir = 1
	arrived.emit(stop_s)
	if absf(level.player.position.x - cars[0].position.x) < C.GAME_W:
		AudioManager.play("train_bell")


func _place_cars() -> void:
	for i in cars.size():
		cars[i].place(rail_point(s - offsets[i]))


## ¿Está toda la composición en el tramo común? (punto seguro para cambiar de ramal)
func on_common() -> bool:
	return s <= decision_s + 0.5


func _try_switch() -> void:
	if pending_branch == branch or not on_common():
		return
	branch = pending_branch
	_rebuild_curve()
	branch_changed.emit(branch)


## La palanca pide el otro ramal. Devuelve el ramal pedido.
func request_branch(b: int) -> int:
	if branches.size() < 2:
		return branch
	pending_branch = clampi(b, 0, branches.size() - 1)
	return pending_branch


## La campana de la estación llama al tren (sólo cuenta con bell_wait).
## Sale al cabo de BOARD_MS para que dé tiempo a subir ("¡Pasajeros al tren!").
func call_train() -> void:
	if called or not is_waiting():
		return
	called = true
	wait_left = maxf(wait_left, BOARD_MS)
	GameState.show_toast("¡Pasajeros al tren!")


func is_waiting() -> bool:
	return wait_left > 0


# ------------------------------------------------------------------ dibujo
func _draw_rails() -> void:
	var tex := ImageTexture.create_from_image(Assets.frame(atlas, "rail_strip").get_image())
	var lists: Array = [common]
	for b in branches:
		var pts := PackedVector2Array([common[common.size() - 1]])
		pts.append_array(b)
		lists.append(pts)
	for pts in lists:
		var line := Line2D.new()
		line.texture = tex
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		line.width = tex.get_height()
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		var off := Vector2(0, tex.get_height() / 2.0 - 3.0)
		var shifted := PackedVector2Array()
		for p in pts:
			shifted.append(p + off)
		line.points = shifted
		line.z_index = -1
		add_child(line)
		rails.append(line)
	# topes al final de cada extremo
	var ends: Array = [common[0]]
	if branches.is_empty():
		ends.append(common[common.size() - 1])
	else:
		for b in branches:
			ends.append(b[b.size() - 1])
		var cross := Sprite2D.new()
		cross.texture = Assets.frame(atlas, "rail_cross")
		Anim.set_origin(cross, cross.texture.get_size(), 0.5, 1.0)
		cross.position = common[common.size() - 1] + Vector2(0, 8)
		cross.z_index = -1
		add_child(cross)
	for i in ends.size():
		var stop := Sprite2D.new()
		stop.texture = Assets.frame(atlas, "rail_stop")
		Anim.set_origin(stop, stop.texture.get_size(), 0.5, 1.0)
		var p: Vector2 = ends[i]
		var away := -1.0 if i == 0 else 1.0
		if i > 0 and branches.size() > 0:
			var b: PackedVector2Array = branches[i - 1]
			away = signf(b[b.size() - 1].x - b[0].x) if b.size() > 1 else 1.0
		elif i > 0:
			away = signf(common[common.size() - 1].x - common[0].x)
		stop.position = p + Vector2(away * 6, 4)
		add_child(stop)


## El ramal activo se ve brillante; el otro, apagado (estado del desvío).
func _update_rail_tint() -> void:
	for i in rails.size():
		var on := i == 0 or i - 1 == branch
		rails[i].modulate = Color(1, 1, 1, 1.0 if on else 0.4)
