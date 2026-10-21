class_name BossPurification
extends Node2D
## Purificación de un jefe vencido (capa común de las arenas de los Mundos 1-7; el Mundo 8 tiene
## su propia transformación en gato). Empieza cuando el jefe ya terminó su animación de derrota
## oficial y muestra su forma tierna (señal defeated_at): no toca sus fases ni sus tiempos.
##  1 luz cálida que crece sobre el jefe   2 anillo de estrellas que gira
##  3 corazones que suben                   4 reacción de Alice (corazón sobre ella, sin pararla)
##  5 aviso: el sueño se ha restaurado y hay una página nueva en el Diario de Sueños
## La estrella especial y el portal siguen saliendo como siempre (BossArena).

signal finished

const DURATION := 2.6

var target: Node2D
var level: Node
var world_id := 1


func setup(owner_level: Node, boss: Node2D, wid: int) -> BossPurification:
	level = owner_level
	target = boss
	world_id = wid
	position = boss.position + Vector2(0, -30)
	z_index = 1
	return self


func _ready() -> void:
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.modulate = Color(C.rgb(0xfff0c8), 0.0)
	glow.scale = Vector2(2.0, 2.0)
	add_child(glow)
	var gt := glow.create_tween()
	gt.tween_property(glow, "modulate:a", 0.7, 0.6)
	gt.parallel().tween_property(glow, "scale", Vector2(5.0, 4.0), 0.9).set_trans(Tween.TRANS_SINE)
	gt.tween_interval(1.0)
	gt.tween_property(glow, "modulate:a", 0.0, 0.8)

	var ring := Node2D.new()
	add_child(ring)
	for i in 8:
		var s := Sprite2D.new()
		s.texture = Assets.frame("fx", "star_gold")
		s.scale = Vector2(0.5, 0.5)
		s.position = Vector2(cos(TAU * i / 8.0) * 44.0, sin(TAU * i / 8.0) * 22.0)
		ring.add_child(s)
	var rt := ring.create_tween()
	rt.tween_property(ring, "rotation", TAU, DURATION).from(0.0)
	rt.parallel().tween_property(ring, "modulate:a", 0.0, 0.6).set_delay(DURATION - 0.6)

	for i in 5:
		var h := Sprite2D.new()
		h.texture = Assets.frame("fx", "heart_full")
		h.position = Vector2(randf_range(-36, 36), 10)
		h.modulate.a = 0.0
		add_child(h)
		var ht := h.create_tween()
		ht.tween_interval(0.3 + i * 0.25)
		ht.tween_property(h, "modulate:a", 1.0, 0.15)
		ht.parallel().tween_property(h, "position:y", -40.0, 1.0).set_trans(Tween.TRANS_SINE)
		ht.tween_property(h, "modulate:a", 0.0, 0.3)

	_alice_reaction()
	var info := WorldRegistry.get_world(world_id)
	var sub: String = info.get("victorySub", "")
	if sub != "":
		GameState.show_toast(sub)
	AudioManager.play("magic_reveal")
	var t := create_tween()
	t.tween_interval(DURATION)
	t.tween_callback(func():
		finished.emit()
		queue_free())


## Alice se alegra: un corazón sobre su cabeza y chispas (no cambia su control).
func _alice_reaction() -> void:
	if level == null or level.player == null:
		return
	var p: Node2D = level.player
	var h := Sprite2D.new()
	h.texture = Assets.frame("fx", "heart_full")
	h.position = p.position + Vector2(0, -46)
	h.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position:y", h.position.y - 14, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "modulate:a", 0.0, 0.5).set_delay(0.9)
	tw.chain().tween_callback(h.queue_free)
	level.effects.sparkle(p.position.x, p.position.y - 24, 8)
