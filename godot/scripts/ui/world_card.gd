class_name WorldCard
extends Control
## Isla de un mundo dentro de WorldCarousel. El carrusel anima la raíz (posición, escala y
## opacidad); la flotación sólo mueve la ilustración interior, así que nunca compite con el
## Tween de navegación. Bloqueada: ilustración atenuada y candado; completada: estrella.

signal clicked(card: WorldCard)
signal hovered(card: WorldCard)

const LOCKED_TINT := Color(0.62, 0.6, 0.78)
const FLOAT_AMPLITUDE := 2.0
const FLOAT_SPEED := 2.4
## Máscara ovalada para los recortes provisionales del mapa (rectángulos con fondo).
const MASK_SHADER := """
shader_type canvas_item;
uniform vec4 region;
uniform float feather = 0.22;
void fragment() {
	vec2 region_uv = (UV - region.xy) / region.zw;
	vec2 p = region_uv * 2.0 - 1.0;
	float d = length(p * vec2(1.0, 1.08));
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(1.0 - feather, 1.0, d);
}
"""

static var _mask_shader: Shader

var data: WorldData
var island: TextureRect
var overlay: Control
## Sólo la isla central flota.
var floating := false
var _t := 0.0
var _float := 0.0


static func make(d: WorldData) -> WorldCard:
	var c := WorldCard.new()
	c.data = d
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tex := data.texture()
	size = tex.get_size()
	pivot_offset = (size / 2.0).floor()
	island = TextureRect.new()
	island.texture = tex
	island.size = size
	island.stretch_mode = TextureRect.STRETCH_KEEP
	island.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	island.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not data.has_island():
		island.material = _provisional_mask(tex as AtlasTexture)
	add_child(island)
	overlay = Control.new()
	overlay.size = size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	mouse_entered.connect(func(): hovered.emit(self))
	refresh()


## Vuelve a leer el estado del progreso.
func refresh() -> void:
	if island == null:
		return
	island.self_modulate = LOCKED_TINT if data.state() == WorldData.State.LOCKED else Color.WHITE
	overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(self)


func _process(delta: float) -> void:
	if floating:
		_t += delta
		_float = sin(_t * FLOAT_SPEED) * FLOAT_AMPLITUDE
	else:
		_t = 0.0
		_float = move_toward(_float, 0.0, delta * 8.0)
	# píxel entero: la ilustración no tiembla
	island.position.y = roundf(_float)
	overlay.position.y = island.position.y


func _draw_overlay() -> void:
	match data.state():
		WorldData.State.LOCKED:
			_padlock(Vector2(size.x / 2.0, size.y * 0.55).floor())
		WorldData.State.COMPLETED:
			_star(Vector2(size.x - 14, 14), 7.0)


func _padlock(c: Vector2) -> void:
	overlay.draw_arc(c + Vector2(0, -6), 6.0, PI, TAU, 10, C.INK, 5.0)
	overlay.draw_arc(c + Vector2(0, -6), 6.0, PI, TAU, 10, C.CREAM, 3.0)
	var body := Rect2(c + Vector2(-9, -5), Vector2(18, 14))
	overlay.draw_rect(body.grow(1), C.INK)
	overlay.draw_rect(body, C.YELLOW)
	overlay.draw_rect(Rect2(c + Vector2(-1, -1), Vector2(2, 6)), C.INK)


func _star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	overlay.draw_colored_polygon(pts, C.YELLOW)
	pts.append(pts[0])
	overlay.draw_polyline(pts, C.INK, 1.0)


static func _provisional_mask(atlas: AtlasTexture) -> ShaderMaterial:
	if _mask_shader == null:
		_mask_shader = Shader.new()
		_mask_shader.code = MASK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _mask_shader
	var full := atlas.atlas.get_size()
	var r := atlas.region
	m.set_shader_parameter("region", Vector4(r.position.x / full.x, r.position.y / full.y, r.size.x / full.x, r.size.y / full.y))
	return m
