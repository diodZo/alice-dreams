class_name BossBase
extends Area2D
## Base común de los ocho jefes (IMP-003): estado compartido, interfaz que usa la arena
## (setup, intro, hit_by, is_defeated, set_body_enabled, invulnerable, señal defeated_at) y las
## reglas de daño: destello, umbrales de fase y paso a DEFEATED. Cada jefe define sus constantes
## MAX_HP y PHASES y sus estados de ataque (_enter_X / _update_X / _exit_X en su StateMachine).
## La escena del jefe tiene los nodos Sprite (AnimatedSprite2D) y Shape (CollisionShape2D).

signal defeated_at(x: float, y: float)

## Vida restante (fracción) a la que se pasa a la fase 2 y a la 3.
const PHASE_THRESHOLDS := C.BOSS_PHASE_THRESHOLDS

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape

var level: Node
var cfg := {}
var fsm: StateMachine
var timers := Timers.new()
var velocity := Vector2.ZERO
var max_hp := 1
var hp := 1
var phase := 1
var pattern_index := 0
var min_x := 0.0
var max_x := 0.0
var floor_y := 0.0
var dir := -1
var invulnerable := true
var body_enabled := false
## Material del destello blanco al recibir un golpe (resources/effects/flash.gdshader).
var flash: ShaderMaterial
## Estado al que se pasa al cruzar un umbral de fase.
var phase_change_state := "PHASE_CHANGE"
## Chispa o mancha de pintura donde impacta el proyectil (Nubarrón y Garabato).
var impact_effects := false
var _phases := {}


func _init() -> void:
	var constants: Dictionary = get_script().get_script_constant_map()
	max_hp = int(constants.get("MAX_HP", max_hp))
	hp = max_hp
	_phases = constants.get("PHASES", {})


var player: Player:
	get:
		return level.player


var now: float:
	get:
		return level.now


func is_defeated() -> bool:
	return fsm.is_state("DEFEATED")


func phase_data() -> Dictionary:
	return _phases[phase]


func set_body_enabled(on: bool) -> void:
	body_enabled = on
	shape.set_deferred("disabled", not on)


## Entrada en escena (la llama la arena al cerrar la puerta).
func intro() -> void:
	fsm.set_state("INTRO")


func facing() -> int:
	return -1 if sprite.flip_h else 1


## Ejecuta fn dentro de ms milisegundos del nivel, salvo que el jefe ya haya sido derrotado.
func after(ms: float, fn: Callable) -> void:
	timers.add(now, ms, func():
		if not is_defeated():
			fn.call())


## Impacto de un arma de la protagonista. Siempre consume el proyectil.
func hit_by(projectile: Projectile) -> bool:
	if is_defeated():
		return true
	if invulnerable:
		level.effects.sparkle(projectile.position.x, projectile.position.y, 3)
		return true
	if impact_effects:
		if projectile.weapon and projectile.weapon.effect == "paint":
			level.effects.paint_splat(projectile.position.x, projectile.position.y, projectile.paint_color)
		else:
			level.effects.impact(projectile.position.x, projectile.position.y, Color.WHITE)
	take_damage(projectile.weapon.boss_damage if projectile.weapon else 1)
	return true


## Resta vida, destella y decide el cambio de fase o la derrota.
func take_damage(dmg: int) -> void:
	if is_defeated() or invulnerable:
		return
	hp = maxi(0, hp - dmg)
	GameState.set_v("bossHp", hp)
	AudioManager.play("boss_hit")
	# destello blanco (setTintFill) durante 60 ms
	flash.set_shader_parameter("flash", 1.0)
	var ref: WeakRef = weakref(self)
	level.after(60, func():
		var b: BossBase = ref.get_ref()
		if b != null:
			b.flash.set_shader_parameter("flash", 0.0))
	var ratio := float(hp) / max_hp
	if hp <= 0:
		fsm.set_state("DEFEATED")
	elif phase <= PHASE_THRESHOLDS.size() and ratio <= PHASE_THRESHOLDS[phase - 1]:
		phase += 1
		fsm.set_state(phase_change_state)
	else:
		on_hurt()


## Golpe que no cambia de fase ni derrota (p. ej. fotograma de dolor durante el descanso).
func on_hurt() -> void:
	pass
