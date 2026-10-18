extends DoorLevel
## Mundo 5 — Sueños Cósmicos, Islas en el Cielo. El motor común construye el mapa desde JSON;
## los toboganes arcoíris, los cohetes, las lunas en órbita, las cascadas de luz, las estrellas
## que caen y las nubes explosivas son objetos del builder. Aquí sólo se aplican los dos
## solapamientos propios del mundo: el deslizamiento del tobogán y el contacto con las nubes.

## Velocidad del tobogán que se pisa en este fotograma (0 = ninguno).
var _slide := 0.0


func on_custom_overlap(kind: String, entity: Object) -> void:
	match kind:
		"slide":
			if player.grounded:
				_slide = entity.slide_velocity()
		"shootable":
			if entity is ExplosiveCloud:
				entity.touch(player)
		_:
			super(kind, entity)


func on_update(_time: float, _delta: float) -> void:
	# el deslizamiento sólo dura mientras se pisa el tobogán (como la pintura del Mundo 2)
	player.slide_speed = _slide
	_slide = 0.0


func on_respawn() -> void:
	player.slide_speed = 0.0
