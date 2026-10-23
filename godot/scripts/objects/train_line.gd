class_name TrainLine
extends Node2D
## Tren de juguete del Mundo 6: una locomotora y sus vagones recorren una vía configurable.
##  - La vía es un Path2D (Curve2D poligonal): un tramo común y, opcionalmente, dos ramales que
##    salen del final del tramo común (desvío). Admite pendientes: los vagones siguen la altura
##    de la vía sin girar (la franja pisable queda siempre horizontal y estable).
##  - Cada vagón es un TrainCar (AnimatableBody2D con sync_to_physics): Godot traslada a Alice
##    cuando va encima, puede andar y saltar desde él y no la atraviesa (colisión unidireccional).
##  - Lo conduce Alice (IMP-029/IMP-035): espera en su estación de salida hasta que sube; con
##    ARRIBA mantenido avanza hacia donde mira Alice (las flechas eligen el sentido) y al
##    soltarlo frena hasta pararse. Acelera y frena con suavidad y nunca pasa de los topes.
##  - Saltando desde el vagón el mando queda fijado hasta que Alice vuelve a pisar algo: el tren
##    no cambia de velocidad bajo ella mientras está en el aire (y ella conserva su velocidad).
##  - Tren abandonado: cuando Alice lleva un rato fuera (sobre otro apoyo) y está a menos de una
##    pantalla de la vía, el tren vuelve solo hasta ponerle un vagón al alcance, sin salirse de la
##    vía; al reaparecer tras una caída el nivel lo coloca directamente junto a ella (reset_near).
##    Así nunca se queda sin tren. Los trenes de vías lejanas no se mueven.
##  - Desvío: la palanca pide un ramal (pending_branch); el tren sólo lo toma en un punto seguro,
##    cuando toda la composición está en el tramo común (nunca a mitad del ramal o de una curva).

signal arrived(stop_s: float)
signal branch_changed(branch: int)

const CAR_GAP := 3.0
const MIN_SPEED := 6.0
## Frenada respecto a la aceleración (soltar ARRIBA, cambio de sentido y topes).
const BRAKE := 1.6
## Tiempo que el tren espera a Alice antes de volver solo a buscarla (ms).
const RETURN_MS := 1200.0
## Margen (px) entre Alice y el vagón más cercano para considerarlo a su alcance.
const REACH := 12.0

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
## Velocidad a lo largo de la vía (px/s, con signo: + hacia el final de la vía).
var v := 0.0
## Sentido del último movimiento (+1 / -1).
var dir := 1
var max_speed := 60.0
var accel := 50.0
## Mando actual: -1, 0 (frenar) o +1. Queda fijado mientras Alice salta desde el tren.
var command := 0
## Vuelve solo a buscar a Alice si lo deja (las pruebas lo apagan para colocar el tren a mano).
var auto_return := true
## Último instante (reloj del nivel) en que Alice iba en este tren o saltaba desde él.
var with_alice_at := -INF
var rails: Array[Line2D] = []
var hint: PixelText
var _tick_frame := -1
var _last_x := 0.0
## Velocidad horizontal de la composición en el último paso (px/s, con signo).
var velocity_x := 0.0


## def: { points: [[x, y]...] (teselas: altura del carril), branches: [[[x, y]...], [[x, y]...]],
##        branch, cars: ["train_loco", "train_red"...], speed, accel (px/s, px/s²) }
## El tren empieza parado en su estación de salida (el principio de la vía).
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
	s = s_min()
	_place_cars()
	_last_x = cars[0].position.x if not cars.is_empty() else 0.0
	# aviso de conducción: una flecha ARRIBA sobre Alice mientras va en el tren parado
	hint = PixelText.make("^", {"origin": Vector2(0.5, 1.0), "tint": C.YELLOW})
	hint.z_index = C.Z_PLAYER + 1 - C.Z_PLATFORM
	hint.visible = false
	add_child(hint)
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


## Distancia de la vía cuyo punto queda más cerca (en horizontal) de x.
func s_at_x(x: float) -> float:
	var best := 0.0
	var best_d := INF
	var d := 0.0
	while d <= length():
		var dx := absf(rail_point(d).x - x)
		if dx < best_d:
			best_d = dx
			best = d
		d += 2.0
	return best


## Un paso de simulación (idempotente por fotograma de física: lo llama cada vagón).
func tick(delta_ms: float) -> void:
	var f := Engine.get_physics_frames()
	if f == _tick_frame:
		return
	_tick_frame = f
	var dt := delta_ms / 1000.0
	_try_switch()
	var want := _wanted_speed()
	# nunca pasa de los topes: la velocidad se limita para frenar justo en el final de la vía
	var brake := accel * BRAKE
	want = clampf(want, -sqrt(2.0 * brake * maxf(s - s_min(), 0.0)), sqrt(2.0 * brake * maxf(s_max() - s, 0.0)))
	if want != 0.0 and absf(want) < MIN_SPEED:
		want = signf(want) * MIN_SPEED
	var speeding_up := want != 0.0 and (v == 0.0 or signf(want) == signf(v)) and absf(want) > absf(v)
	v = move_toward(v, want, (accel if speeding_up else brake) * dt)
	var moving := absf(v) > 0.01
	s += v * dt
	if s >= s_max() or s <= s_min():
		s = clampf(s, s_min(), s_max())
		if moving:
			_arrive(s)
		v = 0.0
	if absf(v) > 0.01:
		dir = 1 if v > 0 else -1
	_place_cars()
	velocity_x = (cars[0].position.x - _last_x) / maxf(dt, 0.0001)
	_last_x = cars[0].position.x
	_update_hint()


## Velocidad que pide el mando (o el regreso automático) en este paso, antes de los topes.
func _wanted_speed() -> float:
	var player: Player = level.player
	if level.get("drive_line") == self and not player.dead:
		with_alice_at = level.now
		if carries_alice():
			command = drive_dir() if level.controls.up else 0
		# en el aire tras saltar del tren: el mando queda como estaba al despegar
		return command * max_speed
	command = 0
	if not auto_return or player.dead or not player.grounded or level.get("respawning"):
		return 0.0
	if level.now - with_alice_at < RETURN_MS or not is_near(player.position.x):
		return 0.0
	# tren abandonado: vuelve hasta ponerle a Alice un vagón al alcance
	var dist := pickup_s(player.position.x) - s
	if absf(dist) < 1.0:
		return 0.0
	return signf(dist) * minf(max_speed, sqrt(2.0 * accel * BRAKE * absf(dist)))


## Sentido en el que conduce Alice: el de las flechas o, sin ellas, hacia donde mira.
func drive_dir() -> int:
	var axis: int = level.controls.axis
	return axis if axis != 0 else int(level.player.facing)


## ¿Puede el tren avanzar en ese sentido? (en un tope no: Alice baja andando)
func can_move(d: int) -> bool:
	return s < s_max() - 0.5 if d > 0 else s > s_min() + 0.5


## ¿Está Alice de pie sobre uno de los vagones en este fotograma?
func carries_alice() -> bool:
	var player: Player = level.player
	if not player.grounded:
		return false
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y < -0.5 and col.get_collider() in cars:
			return true
	return false


## Posición del tren (s) que deja un vagón al alcance de Alice en x (la actual si ya lo está).
## Fuera de la vía se queda en el tope más cercano.
func pickup_s(x: float) -> float:
	var best := 0
	for i in cars.size():
		if absf(cars[i].position.x - x) < absf(cars[best].position.x - x):
			best = i
	var car: TrainCar = cars[best]
	if absf(car.position.x - x) <= car.width / 2.0 + REACH:
		return s
	return clampf(s_at_x(x) + offsets[best], s_min(), s_max())


## ¿Queda x a menos de `dist` px (una pantalla por defecto) del tramo que cubre la vía?
func is_near(x: float, dist := float(C.GAME_W)) -> bool:
	var lo := INF
	var hi := -INF
	for pts in [common] + branches:
		for p in pts:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return x > lo - dist and x < hi + dist


## Coloca el tren parado junto a Alice (al reaparecer tras una caída o un desmayo).
func reset_near(x: float) -> void:
	command = 0
	v = 0.0
	with_alice_at = -INF
	s = pickup_s(x)
	_place_cars()
	_last_x = cars[0].position.x
	velocity_x = 0.0
	hint.visible = false


func _arrive(stop_s: float) -> void:
	arrived.emit(stop_s)
	if absf(level.player.position.x - cars[0].position.x) < C.GAME_W:
		AudioManager.play("train_bell")


func _place_cars() -> void:
	for i in cars.size():
		cars[i].place(rail_point(s - offsets[i]))


## Flecha ARRIBA que bota sobre Alice mientras va en el tren parado (cómo se conduce).
func _update_hint() -> void:
	var show: bool = level.get("drive_line") == self and carries_alice() and is_stopped() and not level.controls.up \
		and (can_move(1) or can_move(-1))
	hint.visible = show
	if show:
		var p: Vector2 = level.player.position
		hint.position = Vector2(round(p.x), round(p.y - 36 - absf(sin(level.now / 180.0)) * 4))


func is_stopped() -> bool:
	return absf(v) < 0.01


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


## La campana de su estación llama al tren: vuelve a buscar a Alice sin esperar.
func call_train() -> void:
	if level.get("drive_line") == self:
		return
	with_alice_at = -INF
	GameState.show_toast("¡Pasajeros al tren!")


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
