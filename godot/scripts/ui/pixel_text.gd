@tool
class_name PixelText
extends Node2D
## Texto pixel art (equivale a pixelText() de PixelFont.js). Funciona tanto en el mundo
## como dentro de CanvasLayer/Control. El tinte multiplica el color, como setTint en Phaser.

@export_multiline var text := "":
	set(v):
		text = v
		_relayout()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()
## Escala entera (Phaser usaba 1 o 2): conserva píxeles nítidos.
@export var text_scale := 1:
	set(v):
		text_scale = maxi(1, v)
		scale = Vector2(text_scale, text_scale)
		_relayout()
## Origen relativo al tamaño del texto (0,0 esquina superior izquierda; 0.5,0.5 centro).
@export var origin := Vector2.ZERO:
	set(v):
		origin = v
		_relayout()
@export var align_center := false:
	set(v):
		align_center = v
		_relayout()
## Ancho máximo en píxeles de pantalla (0 = sin partir líneas).
@export var max_width := 0.0:
	set(v):
		max_width = v
		_relayout()

var _lines: PackedStringArray = []
var _widths: PackedInt32Array = []
var _size := Vector2.ZERO


static func make(txt: String, opts: Dictionary = {}) -> PixelText:
	var t := PixelText.new()
	t.max_width = opts.get("max_width", 0.0)
	t.text_scale = opts.get("scale", 1)
	t.origin = opts.get("origin", Vector2.ZERO)
	t.align_center = opts.get("center", false)
	t.tint = opts.get("tint", Color.WHITE)
	t.text = txt
	return t


func _ready() -> void:
	scale = Vector2(text_scale, text_scale)
	_relayout()


## Tamaño en píxeles de pantalla (incluye la escala).
func get_size() -> Vector2:
	return _size * text_scale


func _relayout() -> void:
	var formatted := PixelFont.format_text(text, max_width, text_scale)
	_lines = formatted.split("\n")
	_widths.resize(_lines.size())
	var w := 0
	for i in _lines.size():
		_widths[i] = PixelFont.line_width(_lines[i])
		w = maxi(w, _widths[i])
	var h := 0 if formatted == "" else (_lines.size() - 1) * PixelFont.LINE_H + PixelFont.CELL_H
	_size = Vector2(w, h)
	queue_redraw()


func _draw() -> void:
	if text == "":
		return
	var tex := PixelFont.texture()
	var base := Vector2(floor(-_size.x * origin.x), floor(-_size.y * origin.y))
	for li in _lines.size():
		var line := _lines[li]
		var x := base.x
		if align_center:
			x += floor((_size.x - _widths[li]) / 2.0)
		var y := base.y + li * PixelFont.LINE_H
		for i in line.length():
			var r := PixelFont.glyph_rect(line[i])
			if r.size == Vector2.ZERO:
				continue
			draw_texture_rect_region(tex, Rect2(x, y, PixelFont.CELL_W, PixelFont.CELL_H), r, tint)
			x += PixelFont.ADVANCE
