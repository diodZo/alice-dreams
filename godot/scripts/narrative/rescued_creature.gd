class_name RescuedCreature
extends Node2D
## Forma liberada de una criatura: chispas mágicas, un destello y la criatura tierna que salta
## de alegría, suelta un corazón y se eleva desvaneciéndose (≈1,6 s). Sólo es un efecto visual:
## no tiene colisiones ni detiene a Alice.
##
## PROVISIONAL (arte pendiente): no existen sprites de "versión liberada" de los monstruos; se
## usa su propio fotograma `idle` con colores suaves y un halo. Ver
## docs/narrative/NARRATIVE_IMPLEMENTATION_REPORT.md (recursos pendientes).

const DURATION := 1.6
const SOFT_TINT := Color(1.0, 0.93, 1.0)

var creature_id := ""
var sprite: AnimatedSprite2D
var halo: Sprite2D


func setup(type: String, pos: Vector2, flip := false) -> RescuedCreature:
	creature_id = type
	position = pos
	z_index = 1  # relativo a fx_root (que ya está en Z_FX)
	halo = Sprite2D.new()
	halo.texture = Assets.generated("glow")
	halo.modulate = Color(C.rgb(0xffe6fb), 0.0)
	halo.scale = Vector2(1.6, 1.6)
	halo.position = Vector2(0, -12)
	add_child(halo)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.sprite_frames(type)
	Anim.set_origin(sprite, Assets.cell_size(type), 0.5, 1.0)
	Anim.play(sprite, "idle")
	sprite.flip_h = flip
	sprite.modulate = Color(3.0, 3.0, 3.0, 0.0)
	add_child(sprite)
	return self


func _ready() -> void:
	# 1 partículas  2 destello (transformación)  3 forma tierna que salta  4 corazón  5 se eleva
	var level_fx := _effects()
	if level_fx != null:
		level_fx.sparkle(position.x, position.y - 10, 10)
	var tw := create_tween()
	tw.set_parallel()
	tw.tween_property(halo, "modulate:a", 0.8, 0.25)
	tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.2)
	tw.chain().tween_property(sprite, "modulate", Color(SOFT_TINT, 1.0), 0.3)
	tw.chain().tween_property(sprite, "position:y", -10.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(sprite, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_heart)
	tw.chain().set_parallel()
	tw.tween_property(self, "position:y", position.y - 26, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tw.chain().tween_callback(queue_free)
	AudioManager.play("pickup")


func _heart() -> void:
	var h := Sprite2D.new()
	h.texture = Assets.frame("fx", "heart_full")
	h.position = Vector2(0, -30)
	h.scale = Vector2(0.7, 0.7)
	add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position:y", -44.0, 0.6)
	tw.tween_property(h, "scale", Vector2(1.0, 1.0), 0.6)


func _effects() -> Effects:
	var lv: Node = get_parent()
	while lv != null and not lv is Level:
		lv = lv.get_parent()
	return lv.effects if lv != null else null
