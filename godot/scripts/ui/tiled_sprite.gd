class_name TiledSprite
extends Node2D
## Textura repetida en un rectángulo (equivale a TileSprite de Phaser). Admite AtlasTexture
## (p. ej. el tramo central del puente arcoíris) y un desplazamiento de mosaico (tile_offset)
## para las capas de nubes que se desplazan.

var texture: Texture2D
var size := Vector2.ZERO
var tile_offset := Vector2.ZERO:
	set(v):
		tile_offset = v
		queue_redraw()
var tint := Color.WHITE


func setup(tex: Texture2D, area: Vector2) -> TiledSprite:
	texture = tex
	size = area
	queue_redraw()
	return self


func _draw() -> void:
	if texture == null:
		return
	var base: Texture2D = texture
	var src := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		base = (texture as AtlasTexture).atlas
		src = (texture as AtlasTexture).region
	var tw := src.size.x
	var th := src.size.y
	var ox := fposmod(tile_offset.x, tw)
	var oy := fposmod(tile_offset.y, th)
	var y := -oy
	while y < size.y:
		var x := -ox
		while x < size.x:
			# recorta el mosaico a los límites del rectángulo
			var dx0 := maxf(x, 0.0)
			var dy0 := maxf(y, 0.0)
			var dx1 := minf(x + tw, size.x)
			var dy1 := minf(y + th, size.y)
			if dx1 > dx0 and dy1 > dy0:
				var s := Rect2(src.position + Vector2(dx0 - x, dy0 - y), Vector2(dx1 - dx0, dy1 - dy0))
				draw_texture_rect_region(base, Rect2(dx0, dy0, dx1 - dx0, dy1 - dy0), s, tint)
			x += tw
		y += th
