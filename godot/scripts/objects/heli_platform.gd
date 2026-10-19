class_name HeliPlatform
extends MovingPlatform
## Plataforma con hélice del Mundo 6 ("plataformas con hélice" de tilesets_world_6.png): la
## hélice gira encima (se estrecha en horizontal y cambia de lado, como un giro visto de lado)
## y la plataforma de alas se pisa desde arriba. Tres tipos según dx/dy:
##  fija (dx = dy = 0), horizontal o vertical, con el vaivén suavizado de MovingPlatform.
## Las hélices visuales nunca hacen daño (las hélices peligrosas son Hazard con "spin").

const VARIANTS := {"a": ["heli_plat", "heli_prop"], "b": ["heli_plat_b", "heli_prop_b"], "c": ["heli_plat_c", "heli_prop_c"]}

var prop: Sprite2D
var spin := 0.0


## def: { x, y (teselas: superficie), variant ("a" | "b" | "c"), dx, dy (teselas), duration, delay (ms) }
func setup(def: Dictionary, atlas: String) -> MovingPlatform:
	var v: Array = VARIANTS.get(str(def.get("variant", "a")), VARIANTS.a)
	var d := def.duplicate()
	d.frame = v[0]
	d.top = def.get("top", 5)
	super(d, atlas)
	prop = Sprite2D.new()
	prop.texture = Assets.frame(atlas, v[1])
	prop.centered = true
	prop.position = Vector2(0, -prop.texture.get_height() / 2.0 + 2)
	prop.z_index = -1
	add_child(prop)
	spin = randf() * TAU
	return self


func step(delta_ms: float) -> void:
	super(delta_ms)
	spin += delta_ms / 1000.0 * 14.0
	var c := cos(spin)
	prop.scale.x = maxf(0.2, absf(c))
	prop.flip_h = c < 0


## Una plataforma fija no tiene recorrido: no cuenta como móvil para nadie.
func is_static() -> bool:
	return delta_px == Vector2.ZERO
