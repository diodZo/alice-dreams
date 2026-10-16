class_name WeaponDef
extends Resource
## Definición de un arma (equivale a una entrada de weapons/weaponDefs.js).
## Todo lo que diferencia un arma de otra es dato: WeaponManager y Projectile son comunes.
## Los .tres de resources/weapons/ se generan con tools/build_resources.gd desde
## data/weapons/weapons.json (exportado del código Phaser), pero se pueden editar en el inspector.

@export var id := ""
@export var display_name := ""
## Fotograma del atlas fx usado como icono en el HUD y en el objeto recogible.
@export var icon := ""
## Evento de sonido al disparar.
@export var sound := ""
## Tiempo mínimo entre disparos (ms).
@export var cooldown := 300.0
## Daño a enemigos normales.
@export var damage := 1
## Daño a Nubarrón (las tres armas pueden derrotarlo).
@export var boss_damage := 1
## "trap" (la burbuja atrapa), "paint" (marca de pintura y ralentiza) o "impact".
@export_enum("trap", "paint", "impact") var effect := "impact"
## Retroceso horizontal que sufre la protagonista al disparar (px/s).
@export var recoil := 0.0

@export_group("Proyectil")
## Atlas del proyectil ("fx") o textura generada ("paint_blob").
@export var proj_texture := "fx"
@export var proj_frame := ""
@export var proj_speed := 200.0
@export var proj_vy := 0.0
@export var proj_gravity := 0.0
## Vida del proyectil (ms): determina el alcance.
@export var proj_lifespan := 1000.0
@export var proj_alpha := 1.0
@export var proj_wobble := 0.0
## Lado del cuerpo cuadrado de colisión (px).
@export var proj_body := 8.0
@export var proj_scale := 1.0
## "", "paint" o "foam": el color cambia en cada disparo.
@export var proj_tint_cycle := ""
@export var proj_trail := false
## Giro en grados por segundo.
@export var proj_spin := 0.0
