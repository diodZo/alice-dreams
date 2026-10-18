class_name HotspotButton
extends CloudButton
## Zona interactiva sobre una ilustración (islas del menú y del mapa, recuadros de audio).
## No dibuja fondo propio: seleccionada, un marco dorado late alrededor de `frame_rect` (el
## rótulo pintado en la ilustración) con una flecha encima; bloqueada, el rótulo se oscurece
## y muestra un candado. Funciona con MenuList como cualquier CloudButton.

## Rótulo de la ilustración, en coordenadas locales de la zona.
var frame_rect := Rect2()
var locked := false
## Posición local del texto (si lo hay); por defecto, el centro del rótulo.
var label_pos := Vector2(-1, -1)
var badge: PixelText
var _t := 0.0


## zone y frame en coordenadas de pantalla (480x270).
static func make_zone(zone: Rect2, frame: Rect2, text := "") -> HotspotButton:
	var b := HotspotButton.new()
	b.position = zone.position
	b.custom_minimum_size = zone.size
	b.size = zone.size
	b.focus_mode = Control.FOCUS_NONE
	b.frame_rect = Rect2(frame.position - zone.position, frame.size)
	if text != "":
		b.label = PixelText.make(text, {"origin": Vector2(0.5, 0.5), "tint": C.BLUE})
		b.add_child(b.label)
	return b


func _on_resized() -> void:
	pivot_offset = frame_rect.get_center()
	if label:
		label.position = (label_pos if label_pos.x >= 0 else frame_rect.get_center()).floor()
	if badge:
		badge.position = Vector2(frame_rect.end.x - 2, frame_rect.position.y - 3).floor()


## Etiqueta pequeña sobre la esquina del rótulo (p. ej. estrellas conseguidas).
func set_badge(text: String) -> HotspotButton:
	if badge == null:
		badge = PixelText.make(text, {"origin": Vector2(1, 0.5), "tint": C.YELLOW})
		badge.z_index = 1
		add_child(badge)
	badge.text = text
	_on_resized()
	queue_redraw()
	return self


func set_locked(on: bool) -> HotspotButton:
	locked = on
	queue_redraw()
	return self


func set_selected(sel: bool) -> CloudButton:
	selected = sel
	if label:
		label.tint = C.rgb(0xb04a8a) if sel else C.BLUE
	queue_redraw()
	return self


func _process(delta: float) -> void:
	if selected:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var r := frame_rect
	if locked:
		var shade := StyleBoxFlat.new()
		shade.bg_color = Color(0.13, 0.08, 0.3, 0.6)
		shade.set_corner_radius_all(6)
		draw_style_box(shade, r)
		# a la derecha del rótulo: el nombre pintado sigue legible
		_padlock(Vector2(r.end.x - 9, r.get_center().y))
	if badge:
		var w := badge.get_size().x
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(C.INK, 0.8)
		bg.set_corner_radius_all(3)
		draw_style_box(bg, Rect2(badge.position + Vector2(-w - 3, -6), Vector2(w + 6, 12)))
	if selected:
		var a := 0.65 + 0.35 * sin(_t * 6.0)
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Color(C.YELLOW, a)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(7)
		sb.anti_aliasing = false
		draw_style_box(sb, r.grow(2))
		# flecha que señala el rótulo
		var c := Vector2(r.get_center().x, r.position.y - 6 - 2.0 * absf(sin(_t * 4.0)))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -5), c + Vector2(5, -5), c + Vector2(0, 1)]), C.YELLOW)
		draw_polyline(PackedVector2Array([c + Vector2(-5, -5), c + Vector2(5, -5), c + Vector2(0, 1), c + Vector2(-5, -5)]), C.INK, 1.0)


func _padlock(c: Vector2) -> void:
	draw_arc(c + Vector2(0, -3), 3.5, PI, TAU, 8, C.CREAM, 2.0)
	draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 8)), C.YELLOW)
	draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 8)), C.INK, false, 1.0)
	draw_rect(Rect2(c + Vector2(-1, 1), Vector2(2, 3)), C.INK)
