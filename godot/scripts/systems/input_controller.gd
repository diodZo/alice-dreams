class_name InputController
extends RefCounted
## Traduce teclado y botones táctiles (TouchScreenButton -> mismas acciones) a acciones de
## juego. Se actualiza una vez por fotograma de física; las entidades sólo consultan acciones,
## nunca teclas (port de systems/InputController.js).
##   A/←  D/→  izquierda/derecha · W/↑ apuntar arriba · Espacio saltar
##   J disparar · K cambiar arma · Shift correr · Esc/P pausa
## Mando (XInput, Input Map de project.godot): cruceta/stick moverse y apuntar arriba · A saltar
##   X disparar · Y cambiar arma · gatillos correr · Start pausa
##
## Para pruebas automáticas se puede activar `scripted` y escribir en `script_held`
## (acciones mantenidas) y `script_pressed` (pulsaciones de un fotograma).

var enabled := true
## Mundo 8: durante la transformación del jefe y el final Alice puede moverse pero no disparar
## ni cambiar de arma.
var combat_enabled := true
var left := false
var right := false
var up := false
var run := false
var jump_held := false
var jump_pressed := false
var fire_held := false
var fire_pressed := false
var switch_pressed := false
var pause_pressed := false

var scripted := false
var script_held := {}
var script_pressed := {}


func update() -> void:
	# Las pulsaciones se consumen siempre, aunque el control esté desactivado, para que no
	# se acumulen durante una animación o una pausa.
	var jp := _pressed("jump")
	var fp := _pressed("fire")
	var sp := _pressed("switch_weapon")
	pause_pressed = _pressed("pause")
	script_pressed.clear()
	_blank_held()
	if enabled:
		left = _held("move_left")
		right = _held("move_right")
		up = _held("aim_up")
		run = _held("run")
		jump_held = _held("jump")
		fire_held = _held("fire")
		jump_pressed = jp
		fire_pressed = fp
		switch_pressed = sp
		if not combat_enabled:
			fire_held = false
			fire_pressed = false
			switch_pressed = false


func _held(action: String) -> bool:
	if scripted:
		return bool(script_held.get(action, false))
	return Input.is_action_pressed(action)


func _pressed(action: String) -> bool:
	if scripted:
		return bool(script_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


func _blank_held() -> void:
	left = false
	right = false
	up = false
	run = false
	jump_held = false
	fire_held = false
	jump_pressed = false
	fire_pressed = false
	switch_pressed = false


var axis: int:
	get:
		return (1 if right else 0) - (1 if left else 0)


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_blank_held()


## Suelta todas las acciones (al pausar o cambiar de escena) para evitar teclas "pegadas".
func reset() -> void:
	for a in ["move_left", "move_right", "aim_up", "jump", "fire", "switch_weapon", "run", "pause"]:
		Input.action_release(a)
	_blank_held()
	pause_pressed = false
