class_name CloudButton
extends BaseButton
## Botón con forma de nube y texto pixel art (port de ui/CloudButton.js). Funciona con
## ratón y táctil (BaseButton) y con teclado a través de MenuList.

signal activated(button: CloudButton)
signal hovered(button: CloudButton)

var label: PixelText
var selected := false
var _bg_tint := Color.WHITE
var _tween: Tween


static func make(text: String, width := 140.0, height := 22.0) -> CloudButton:
	var b := CloudButton.new()
	b.custom_minimum_size = Vector2(width, height)
	b.size = Vector2(width, height)
	b.focus_mode = Control.FOCUS_NONE
	b.label = PixelText.make(text, {"origin": Vector2(0.5, 0.5), "tint": C.BLUE})
	b.add_child(b.label)
	return b


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_on_resized)
	mouse_entered.connect(func(): hovered.emit(self))
	pressed.connect(activate)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size / 2.0
	if label:
		label.position = (size / 2.0).floor()


func set_label(text: String) -> CloudButton:
	label.text = text
	return self


func set_selected(sel: bool) -> CloudButton:
	selected = sel
	_bg_tint = C.YELLOW if sel else Color.WHITE
	label.tint = C.rgb(0xb04a8a) if sel else C.BLUE
	scale = Vector2(1.06, 1.06) if sel else Vector2.ONE
	queue_redraw()
	return self


func activate() -> void:
	if not visible or disabled:
		return
	if _tween:
		_tween.kill()
	var base := scale
	_tween = create_tween()
	_tween.tween_property(self, "scale", base * 0.94, 0.06)
	_tween.tween_property(self, "scale", base, 0.06)
	activated.emit(self)


func _draw() -> void:
	var w := size.x
	var h := size.y
	_cloud(C.BLUE * _bg_tint, 0, w, h)
	_cloud(C.CREAM * _bg_tint, 1, w, h)
	draw_rect(Rect2(4, h - 6, w - 8, 2), C.PINK * _bg_tint)


func _cloud(color: Color, inset: float, w: float, h: float) -> void:
	var r := (h - inset * 2.0) / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(maxf(2.0, r - 2.0)))
	sb.anti_aliasing = false
	draw_style_box(sb, Rect2(inset + 2, inset + 2, w - inset * 2 - 4, h - inset * 2 - 4))
	var bumps := maxi(2, floori(w / 18.0))
	for i in bumps:
		var cx := 8.0 + (w - 16.0) * (i + 0.5) / bumps
		draw_circle(Vector2(cx, inset + 5), maxf(2.0, 6.0 - inset), color, true, -1.0, false)
