extends DoorLevel
## Mundo 7 — El Valle de Caramelo. El motor común construye el mapa desde JSON; las gelatinas
## elásticas (nubes con rebote), el caramelo resbaladizo y el chocolate pegajoso (superficies),
## las correas de chocolate, las piruletas giratorias, los lanzadores de caramelos, los chorros de
## chocolate, las gelatinas que desaparecen y los bloques de premio son objetos del builder. Aquí
## sólo se aplican los contactos propios del mundo.


func on_custom_overlap(kind: String, entity: Object) -> void:
	match kind:
		"heart":
			if entity.collect(player):
				GameState.show_toast("¡Corazón dulce!")
		"shootable":
			pass  # los bloques de premio sólo reaccionan a cabezazos y disparos
		_:
			super(kind, entity)


func on_update(_time: float, _delta: float) -> void:
	# cabezazo desde abajo contra un bloque de premio
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y > 0.5 and col.get_collider() is StarBlock:
			col.get_collider().bump()


## Velocidad de la correa de chocolate sobre la que está Alice (0 si no pisa ninguna).
func belt_under_player() -> float:
	if not player.grounded:
		return 0.0
	for i in player.get_slide_collision_count():
		var col := player.get_slide_collision(i)
		if col.get_normal().y < -0.5 and col.get_collider() is ConveyorBelt:
			return col.get_collider().belt_speed()
	return 0.0
