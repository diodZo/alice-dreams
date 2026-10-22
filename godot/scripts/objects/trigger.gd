class_name Trigger
## Configuración común de las áreas que detecta el sensor de la protagonista
## (estrellas, armas, checkpoints, cojines, obstáculos, corrientes, puerta, portal).
## Si `entity` tiene on_player_overlap(level, player, delta), el nivel lo llama mientras la
## protagonista toca el área (salvo en las áreas "shootable", que sólo reciben disparos); si no,
## el nivel lo gestiona por su `kind` (Level._process_overlaps / on_custom_overlap).


static func configure(area: Area2D, kind: String, entity: Object = null) -> void:
	area.collision_layer = C.L_TRIGGER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.set_meta("kind", kind)
	area.set_meta("entity", entity if entity != null else area)
