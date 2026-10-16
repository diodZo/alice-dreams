class_name PaintSurface
extends Area2D
## Pintura sobre el suelo (Mundo 2). Los efectos duran mientras se pisa y se restauran al salir:
##  - blue   (azul, resbaladiza): menos fricción, la protagonista patina
##  - yellow (amarilla, elástica): al aterrizar encima rebota
##  - pink   (rosa, pegajosa): reduce la velocidad
## def: {x, y (superficie), w (teselas), color}. También la crea Garabato durante el combate.

const EFFECTS := {
	"blue": {"speed": 1.0, "friction": 0.22},
	"yellow": {"speed": 1.0, "friction": 1.0, "bounce": -470.0},
	"pink": {"speed": 0.5, "friction": 1.0},
}

var color := "blue"
var strip: TiledSprite


func setup(def: Dictionary, atlas := "world2_objects") -> PaintSurface:
	color = def.get("color", "blue")
	var x0 := float(def.x) * C.TILE
	var w := float(def.w) * C.TILE
	var surface := float(def.y) * C.TILE
	position = Vector2(x0, surface)
	z_index = C.Z_PLATFORM + 1
	var tex := Assets.frame(atlas, "paint_%s_surface" % color)
	strip = TiledSprite.new().setup(tex, Vector2(w, tex.get_height()))
	strip.position = Vector2(0, -3)
	add_child(strip)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 16)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(w / 2.0, -6)
	add_child(cs)
	Trigger.configure(self, "paint")
	return self


func effect() -> Dictionary:
	return EFFECTS.get(color, {})


## Pintura temporal (ataque del jefe): aparece con aviso y se seca al cabo de `ms`.
func make_temporary(level: Node, ms: float) -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	var ref: WeakRef = weakref(self)
	level.after(ms, func():
		var p: PaintSurface = ref.get_ref()
		if p != null:
			p.set_deferred("monitorable", false)
			var t2 := p.create_tween()
			t2.tween_property(p, "modulate:a", 0.0, 0.4)
			t2.tween_callback(p.queue_free))
