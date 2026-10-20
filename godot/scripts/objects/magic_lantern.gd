class_name MagicLantern
extends Area2D
## Farol mágico del Mundo 8. Apagado se ve tenue; al tocarlo o dispararle se enciende para
## siempre y emite `lit`, que el nivel conecta a los puentes ocultos con su id (señales, sin
## referencias directas entre objetos).

signal lit(lantern: MagicLantern)

var level: Node
var id := ""
var bridges: Array = []
var on := false
var sprite: Sprite2D
var glow: Sprite2D


## def: { id, x, y (superficie) en teselas, bridges: [ids de puente], frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> MagicLantern:
	level = owner_level
	id = str(def.get("id", ""))
	bridges = def.get("bridges", [])
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	z_index = C.Z_PICKUP
	glow = Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.position = Vector2(0, -26)
	glow.scale = Vector2(1.6, 1.6)
	glow.modulate = Color(C.rgb(0xffa657), 0.25)
	add_child(glow)
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "lamp_post"))
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	sprite.modulate = C.rgb(0x8a7aa8)
	add_child(sprite)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 40)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(0, -20)
	add_child(cs)
	Trigger.configure(self, "lantern")
	# los disparos de Alice también lo encienden
	var target := Area2D.new()
	target.collision_layer = C.L_ENEMY_HITBOX
	target.collision_mask = 0
	target.monitoring = false
	target.set_meta("kind", "shootable")
	target.set_meta("entity", self)
	var cs2 := CollisionShape2D.new()
	cs2.shape = rect
	cs2.position = Vector2(0, -20)
	target.add_child(cs2)
	add_child(target)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.12, 0.9)
	tw.tween_property(glow, "modulate:a", 0.3, 0.9)
	return self


func light() -> void:
	if on:
		return
	on = true
	sprite.modulate = Color.WHITE
	glow.modulate = Color(C.rgb(0xffe18c), 0.9)
	glow.scale = Vector2(2.6, 2.6)
	level.effects.sparkle(position.x, position.y - 30, 16)
	level.effects.glow_flash(position + Vector2(0, -28), C.rgb(0xffe18c), 1.0, 3.0, 500, 0.8, 1)
	AudioManager.play("magic_reveal")
	lit.emit(self)


## Disparo de Alice (área "shootable").
func hit_by(_projectile: Projectile) -> bool:
	light()
	return true
