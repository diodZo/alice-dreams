extends DoorLevel
## Mundo 6 — El Reino del Tren de Juguete. El motor común construye el mapa desde JSON; los
## trenes (TrainLine/TrainCar), las plataformas con hélice, los puentes arcoíris, los bloques
## que caen, las ruedas, las barreras de estrella, los trenes enemigos, las palancas, las
## campanas y los bloques de estrella son objetos del builder. Aquí sólo se aplican los
## contactos propios del mundo, quién conduce cada tren y la cámara al viajar en tren.
##
## Conducir (IMP-029/IMP-035): de pie en un vagón, mantener ARRIBA (W, flecha arriba, cruceta o
## stick arriba, botón ^ táctil) mueve el tren hacia donde mira Alice; las flechas eligen el
## sentido sin que ella ande. Al soltar ARRIBA el tren frena y Alice vuelve a andar por los
## vagones. Saltar, recoger estrellas y golpear bloques funciona igual con el tren en marcha.

## Anticipación horizontal de la cámara mientras Alice va en un vagón (px como máximo).
const TRAIN_LOOK := 54.0
## Ajuste al suelo mientras va en tren (px); fuera del tren se restaura el del jugador.
const RIDE_SNAP := 8.0

var default_snap := 1.0
## Tren que conduce Alice: en el que va de pie o desde el que acaba de saltar (null si ninguno).
var drive_line: TrainLine = null
## Instante en que Alice pisó por última vez un vagón de drive_line.
var _aboard_at := -INF
## Saltando desde un vagón, el mando sigue fijado como máximo este tiempo (ms).
const AIR_DRIVE_MS := 2500.0
var _drive_toast_shown := false


func on_create() -> void:
	super()
	default_snap = player.floor_snap_length


func on_custom_overlap(kind: String, entity: Object) -> void:
	match kind:
		"shootable":
			pass  # palancas y bloques de estrella sólo reaccionan a los disparos
		_:
			super(kind, entity)


func on_update(_time: float, _delta: float) -> void:
	# en un vagón que baja una pendiente Alice no debe despegarse del techo (perdería el arrastre)
	var car := riding_car()
	player.floor_snap_length = RIDE_SNAP if car != null else default_snap
	_update_driver(car)
	# cabezazo desde abajo contra un bloque de estrella
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y > 0.5 and col.get_collider() is StarBlock:
			col.get_collider().bump()


## Decide qué tren conduce Alice (lo leen los trenes en el fotograma siguiente) y si las flechas
## la mueven a ella o sólo eligen el sentido del tren (player.driving).
func _update_driver(car: TrainCar) -> void:
	if car != null:
		drive_line = car.line
		_aboard_at = now
		if not _drive_toast_shown:
			_drive_toast_shown = true
			GameState.show_toast("Mantén ^ (arriba) para conducir el tren. Suelta y frena")
	elif player.grounded or player.dead or player.in_water() or now - _aboard_at > AIR_DRIVE_MS:
		drive_line = null
	var d: int = controls.axis if controls.axis != 0 else player.facing
	# en un tope el tren no puede seguir: ARRIBA no bloquea las flechas y Alice baja andando
	player.driving = drive_line != null and controls.up and drive_line.can_move(d)


## Vagón sobre el que va Alice (null si no va en tren).
func riding_car() -> TrainCar:
	if not player.grounded:
		return null
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y < -0.5 and col.get_collider() is TrainCar:
			return col.get_collider()
	return null


## Cámara: al viajar en tren la anticipación sigue al tren (moderada y suavizada) en lugar de
## a hacia dónde mira Alice; así la cámara no da saltos con los movimientos del vagón.
func update_camera(delta_ms: float) -> void:
	var car := riding_car()
	if car == null:
		super(delta_ms)
		return
	var vx: float = car.line.velocity_x
	var target := clampf(vx / maxf(car.line.max_speed, 1.0), -1.0, 1.0) * TRAIN_LOOK
	look_ahead += (target - look_ahead) * minf(1.0, delta_ms / 700.0)
	camera.follow_offset = Vector2(-look_ahead, 16)
	camera.update_follow(delta_ms)


func on_respawn() -> void:
	player.floor_snap_length = default_snap
	# tras una caída o un desmayo los trenes de las vías cercanas (hasta dos pantallas) esperan
	# parados junto a Alice: nunca queda sin tren (uno lejano vuelve solo cuando ella se acerca)
	drive_line = null
	player.driving = false
	for line in level_objects.trains:
		if line.is_near(player.position.x, 2.0 * C.GAME_W):
			line.reset_near(player.position.x)
