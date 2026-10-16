class_name CloudPlatform
extends StaticBody2D
## Nube estática con colisión unidireccional (port de createCloud/setupCloudBody de
## entities/Platforms.js). Sólo la franja superior colisiona y únicamente desde arriba.
## Con `bouncy` != 0 es la nube elástica: lanza a la protagonista al pisarla.
## Origen del nodo: borde superior central del dibujo (origin 0.5, 0 en Phaser).

var bouncy := 0.0
var sprite: Sprite2D


## def: { x (teselas, centro), y (teselas, superficie), frame, bouncy }
func setup(def: Dictionary, atlas: String) -> CloudPlatform:
	var tex := Assets.frame(atlas, def.frame)
	sprite = Sprite2D.new()
	sprite.texture = tex
	add_child(sprite)
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	position.x = float(def.x) * C.TILE
	add_cloud_shape(self, sprite, tex.get_size(), float(def.y) * C.TILE)
	bouncy = float(def.get("bouncy", 0))
	if bouncy != 0:
		sprite.modulate = C.rgb(0xffe6f6)
	return self


## Configura el dibujo y la franja de colisión: la superficie visual de la nube está 3 px
## por debajo del borde superior; el cuerpo mide (ancho - 2*margen) x 10.
static func add_cloud_shape(body: CollisionObject2D, spr: Sprite2D, size: Vector2, surface_y: float) -> CollisionShape2D:
	var w := size.x
	var inset := minf(6.0, floorf(w * 0.12))
	var top := 3.0
	body.position.y = surface_y - top
	spr.centered = false
	spr.offset = Vector2(-round(w / 2.0), 0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w - inset * 2.0, 10)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(-round(w / 2.0) + inset + shape.size.x / 2.0, top + 5.0)
	cs.one_way_collision = true
	cs.one_way_collision_margin = 5.0
	body.add_child(cs)
	return cs


func on_player_contact() -> void:
	pass


## Pequeño aplastamiento al rebotar (escala alrededor del borde superior, como en Phaser).
func squash() -> void:
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.1, 0.8), 0.08)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.08)
