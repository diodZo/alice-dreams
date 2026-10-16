class_name SignPost
extends Node2D
## Cartel con instrucción contextual: muestra un bocadillo al acercarse (port de Sign.js).

var bubble: Node2D
var visible_bubble := false
var _tween: Tween


## def: { x, y (teselas), text, touch? }
func setup(def: Dictionary, atlas: String, touch_mode: bool, post_frame := "signpost") -> SignPost:
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE + 2)
	z_index = C.Z_DECOR_BACK + 1
	var post := Sprite2D.new()
	post.texture = Assets.frame(atlas, def.get("frame", post_frame))
	Anim.set_origin(post, post.texture.get_size(), 0.5, 1.0)
	add_child(post)
	var text: String = def.touch if touch_mode and def.has("touch") else def.text
	var label := PixelText.make(text, {"origin": Vector2(0.5, 0.5), "tint": C.BLUE, "max_width": 170.0})
	var ls := label.get_size()
	var w := ceilf(ls.x) + 12
	var h := ceilf(ls.y) + 10
	bubble = SpeechBubble.new()
	bubble.box = Vector2(w, h)
	bubble.add_child(label)
	bubble.position = Vector2(0, -post.texture.get_height() - h / 2.0 - 8)
	# que el bocadillo no se salga por arriba
	if position.y + bubble.position.y - h / 2.0 < 4:
		bubble.position.y = h / 2.0 + 4 - position.y
	bubble.z_as_relative = false
	bubble.z_index = C.Z_PLAYER - 1
	bubble.modulate.a = 0.0
	add_child(bubble)
	return self


func distance_to_player(player: Node2D) -> float:
	return absf(player.position.x - position.x) if absf(player.position.y - position.y) < 64 else INF


## Muestra el bocadillo sólo si este es el cartel activo (el más cercano).
func update_proximity(active: bool) -> void:
	if active == visible_bubble:
		return
	visible_bubble = active
	if _tween:
		_tween.kill()
	_tween = bubble.create_tween()
	_tween.tween_property(bubble, "modulate:a", 1.0 if active else 0.0, 0.18)


## Fondo del bocadillo: borde oscuro, relleno crema y pico hacia abajo.
class SpeechBubble:
	extends Node2D
	var box := Vector2(40, 20)

	func _draw() -> void:
		var w := box.x
		var h := box.y
		var outer := StyleBoxFlat.new()
		outer.bg_color = C.INK
		outer.set_corner_radius_all(5)
		outer.anti_aliasing = false
		draw_style_box(outer, Rect2(-w / 2.0 - 1, -h / 2.0 - 1, w + 2, h + 2))
		var inner := StyleBoxFlat.new()
		inner.bg_color = C.CREAM
		inner.set_corner_radius_all(4)
		inner.anti_aliasing = false
		draw_style_box(inner, Rect2(-w / 2.0, -h / 2.0, w, h))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, h / 2.0 - 1), Vector2(4, h / 2.0 - 1), Vector2(0, h / 2.0 + 5)]), C.CREAM)
