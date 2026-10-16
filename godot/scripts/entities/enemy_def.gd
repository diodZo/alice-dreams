class_name EnemyDef
extends Resource
## Datos de un tipo de monstruo (equivale a entities/enemyDefs.js).
## Tiempos en ms, distancias en píxeles lógicos. La hitbox es independiente del dibujo.

@export var key := ""
@export var display_name := ""
@export var hp := 2
@export var speed := 50.0
@export var body_size := Vector2(16, 20)
@export var detect_range := 130.0
@export var detect_height := 40.0
@export var reaction_time := 450.0
@export var attack_cooldown := 900.0
@export var trap_time := 3500.0
## Arañitas: distancia a la que araña.
@export var attack_range := 0.0
## Escupitín: distancia que intenta mantener [cerca, lejos].
@export var keep_distance := Vector2.ZERO
## Pulgoso: distancia a la que retrocede.
@export var retreat_distance := 0.0
