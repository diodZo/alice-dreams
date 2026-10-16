class_name Trigger
## Configuración común de las áreas que detecta el sensor de la protagonista
## (estrellas, armas, checkpoints, cojines, obstáculos, corrientes, puerta, portal).


static func configure(area: Area2D, kind: String, entity: Object = null) -> void:
	area.collision_layer = C.L_TRIGGER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("kind", kind)
	area.set_meta("entity", entity if entity != null else area)
