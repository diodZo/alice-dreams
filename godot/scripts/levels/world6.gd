extends DoorLevel
## Mundo 6 — El Reino del Tren de Juguete. El motor común construye el mapa desde JSON; los
## trenes (TrainLine/TrainCar), las plataformas con hélice, los puentes arcoíris, los bloques
## que caen, las ruedas, las barreras de estrella, los trenes enemigos, las palancas, las
## campanas y los bloques de estrella son objetos del builder. Aquí sólo se aplican los
## contactos propios del mundo y la cámara al viajar en tren.

## Anticipación horizontal de la cámara mientras Alice va en un vagón (px como máximo).
const TRAIN_LOOK := 54.0
## Ajuste al suelo mientras va en tren (px); fuera del tren se restaura el del jugador.
const RIDE_SNAP := 8.0

var default_snap := 1.0


func on_create() -> void:
	super()
	default_snap = player.floor_snap_length


func on_custom_overlap(kind: String, entity: Object) -> void:
	match kind:
		"lever":
			entity.touch()
		"bell":
			entity.touch()
		"bumper":
			entity.bump(player)
		"shootable":
			pass  # palancas y bloques de estrella sólo reaccionan a los disparos
		_:
			super(kind, entity)


func on_update(_time: float, _delta: float) -> void:
	# en un vagón que baja una pendiente Alice no debe despegarse del techo (perdería el arrastre)
	player.floor_snap_length = RIDE_SNAP if riding_car() != null else default_snap
	# cabezazo desde abajo contra un bloque de estrella
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y > 0.5 and col.get_collider() is StarBlock:
			col.get_collider().bump()


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
