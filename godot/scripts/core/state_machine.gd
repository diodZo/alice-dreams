class_name StateMachine
extends RefCounted
## Máquina de estados mínima usada por enemigos y jefe (port de systems/StateMachine.js).
## Cada estado NOMBRE se implementa en el dueño con métodos opcionales:
##   _enter_NOMBRE(prev: String, data)   _update_NOMBRE(time_ms, delta_ms)   _exit_NOMBRE(next: String)

var target: Object
var current := ""
## Milisegundos transcurridos en el estado actual.
var elapsed := 0.0


func _init(owner_object: Object, initial := "") -> void:
	target = owner_object
	if initial != "":
		set_state(initial)


func set_state(state: String, data: Variant = null) -> void:
	assert(target.has_method("_enter_" + state) or target.has_method("_update_" + state), "Estado desconocido: " + state)
	var prev := current
	if prev != "" and target.has_method("_exit_" + prev):
		target.call("_exit_" + prev, state)
	current = state
	elapsed = 0.0
	if target.has_method("_enter_" + state):
		target.call("_enter_" + state, prev, data)


func is_state(state: String) -> bool:
	return current == state


func update(time: float, delta: float) -> void:
	elapsed += delta
	if current != "" and target.has_method("_update_" + current):
		target.call("_update_" + current, time, delta)
