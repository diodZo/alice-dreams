class_name ShadowZone
extends Area2D
## Charco de sombra (kind "pool") o bruma de sombras (kind "mist") del Mundo 8. Hace un daño
## moderado mientras Alice lo toca, pero con intervalo: el nivel aplica como mucho un golpe
## cada DAMAGE_INTERVAL ms y respeta la invulnerabilidad tras cada golpe (nunca resta vida en
## cada fotograma). La colisión es una franja baja sobre la superficie: se puede saltar.

const DAMAGE_INTERVAL := 1100.0

var kind := "pool"
var width := 0.0


## def: { x (borde izquierdo), y (superficie), w (teselas), kind ("pool" | "mist"), frame }
func setup(def: Dictionary, atlas: String) -> ShadowZone:
	kind = def.get("kind", "pool")
	width = float(def.w) * C.TILE
	position = Vector2(float(def.x) * C.TILE, float(def.y) * C.TILE)
	z_index = C.Z_PLATFORM + 1
	var frame: String = def.get("frame", "shadow_pool" if kind == "pool" else "shadow_mist")
	var tex := Assets.frame(atlas, frame)
	# dibujos repetidos a lo ancho (cada uno algo solapado) con un leve vaivén
	var n := maxi(1, int(ceil(width / (tex.get_width() * 0.8))))
	for i in n:
		var s := Sprite2D.new()
		s.texture = tex if kind == "pool" or i % 2 == 0 else Assets.frame(atlas, "shadow_mist_b") if Assets.has_frame(atlas, "shadow_mist_b") else tex
		Anim.set_origin(s, s.texture.get_size(), 0.5, 1.0)
		s.position = Vector2(width * (i + 0.5) / n, 3)
		s.scale.x = minf(1.0, width / n / (s.texture.get_width() * 0.8))
		s.modulate.a = 0.92
		add_child(s)
		var tw := s.create_tween().set_loops()
		var d := 0.9 + 0.2 * i
		tw.tween_property(s, "scale:y", 1.08, d).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "scale:y", 0.94, d).set_trans(Tween.TRANS_SINE)
	var h := 8.0 if kind == "pool" else 18.0
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 4, h)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(width / 2.0, -h / 2.0)
	add_child(cs)
	Trigger.configure(self, "shadow")
	var wisps := ParticleBurst.new().setup({
		"x_range": [0, width],
		"speed_y": [-26, -10],
		"speed_x": [-6, 6],
		"life": [900, 900],
		"scale": [1.4, 0],
		"alpha": [0.7, 0],
		"frequency": 140.0,
		"colors": Effects.colors([0x713ca8, 0xd85cd5, 0x35205f]),
	})
	wisps.position = Vector2(0, -4)
	wisps.emitting = true
	wisps.auto_free = false
	add_child(wisps)
	return self
