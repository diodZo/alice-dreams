class_name DreamCollectible
extends Area2D
## Coleccionable opcional (Mundo 3: lunas mágicas y botones dorados; Mundo 4: conchas token,
## estrella marina mágica, burbuja arcoíris y patito real; Mundo 5: fichas de luna, estrella
## especial, fragmento de constelación y mini cohete dorado).

const FRAMES := {"moon": "moon_w3", "button": "button_gold", "shell": "shell_token", "starfish": "starfish_pink", "rainbow": "bubble_float_l", "duck": "duck_king",
	"moon_token": "moon_token", "special": "special_star", "constellation": "star_w5_b", "rocket": "mini_rocket"}

var level: Node
var id := ""
var kind := "moon"
var active := true

## def: { id, kind ("moon" | "button"), x, y (teselas, centro), frame }
func setup(owner_level: Node, def: Dictionary, atlas := "world3_objects") -> DreamCollectible:
	level = owner_level
	kind = str(def.get("kind", "moon"))
	id = str(def.get("id", "%s_%s" % [kind, def.x]))
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE + 8)
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", FRAMES.get(kind, "moon_w3")))
	add_child(spr)
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.modulate = Color(C.YELLOW, 0.45)
	glow.scale = Vector2(1.6, 1.6)
	glow.show_behind_parent = true
	add_child(glow)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10
	cs.shape = shape
	add_child(cs)
	Trigger.configure(self, "dream_collectible")
	z_index = C.Z_PICKUP
	if def.has("tint"):
		spr.modulate = Color(def.tint)
	if kind == "rainbow":
		# la burbuja arcoíris cambia de color sin parar
		var rt := spr.create_tween().set_loops()
		for c in [0xffb3e6, 0xb3f0ff, 0xfff0a0, 0xd4b8ff]:
			rt.tween_property(spr, "modulate", C.rgb(c), 0.35)
	var y := position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", y - 4, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE)
	return self

func collect() -> bool:
	if not active:
		return false
	active = false
	level.effects.sparkle(position.x, position.y, 18)
	queue_free()
	return true
