class_name HiddenBridge
extends CloudPlatform
## Puente oculto del Mundo 8: una plataforma que sólo existe cuando la luz la revela. Sin luz
## apenas se insinúa (unas chispas y un contorno muy tenue) y no colisiona.
##  - reveal(0): un farol mágico la enciende para siempre (señal `lit` del farol).
##  - reveal(ms): la luz del farol de un Fantasmita la muestra un rato y vuelve a ocultarse.

signal revealed

var level: Node
var id := ""
var shape: CollisionShape2D
var lit := false
var temp_until := 0.0


func setup_hidden(owner_level: Node, def: Dictionary, atlas: String) -> HiddenBridge:
	level = owner_level
	id = str(def.get("id", ""))
	setup(def, atlas)
	for c in get_children():
		if c is CollisionShape2D:
			shape = c
	shape.disabled = true
	sprite.modulate = Color(C.rgb(0xc8a5ff), 0.12)
	return self


func is_solid() -> bool:
	return not shape.disabled


func reveal(ms := 0.0) -> void:
	if lit:
		return
	if ms <= 0:
		lit = true
	else:
		temp_until = maxf(temp_until, level.now + ms)
	if shape.disabled:
		shape.set_deferred("disabled", false)
		AudioManager.play("magic_reveal")
		level.effects.sparkle(position.x, position.y + 6, 12)
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.35)
		revealed.emit()


func _physics_process(_delta: float) -> void:
	if level == null or lit or temp_until <= 0:
		return
	var left: float = temp_until - level.now
	if left <= 0:
		temp_until = 0
		shape.set_deferred("disabled", true)
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "modulate", Color(C.rgb(0xc8a5ff), 0.12), 0.3)
	elif left < 700:
		# aviso: va a apagarse
		sprite.modulate.a = 0.5 if int(left / 90.0) % 2 else 1.0
