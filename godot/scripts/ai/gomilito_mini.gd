class_name GomilitoMini
extends GomilitoMonster
## Gomita pequeña que sale de un Gomilito Saltarín al dividirse: mismo comportamiento a
## saltitos, menos vida (gomilito_mini.tres) y no vuelve a dividirse. Cada gomita es de un
## color de la hoja (rosa, azul, amarilla o verde): todas sus animaciones usan ese dibujo y el
## movimiento se expresa con estiramientos (la hoja sólo tiene un cuadro por color).
## Opciones: color, speed (px/s; 0 = la de su ficha), kick (salen despedidas hacia ese lado).

var color := "pink"


func _ready() -> void:
	super()
	color = str(spawn.get("color", "pink"))
	if float(spawn.get("speed", 0)) > 0:
		def = def.duplicate()
		def.speed = float(spawn.speed)
	split_done = true
	anim("idle")
	var kick := float(spawn.get("kick", 0))
	if kick != 0:
		velocity = Vector2(kick * 70.0, -170.0)
		hopping = true


func can_split() -> bool:
	return false


## Todas las animaciones son el dibujo de su color.
func anim(_anim_name: String, _ignore_if_playing := true) -> void:
	Anim.play(sprite, color, true)


func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.5, 0.4), 0.2)
