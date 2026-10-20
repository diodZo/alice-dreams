class_name PurpleCat
extends Node2D
## El gato morado en que se transforma el Rey Pesadelo: pequeño, de ojos grandes y tímido.
##  WAKE     parpadea y mira a Alice
##  APPROACH se acerca despacio (con un balanceo: la hoja no trae cuadros de caminar)
##  WAIT     se sienta a esperar cerca de Alice (ella puede acercarse)
##  CUDDLE   al tocarlo: animación de cariño, ronroneo y un corazón -> `hugged`
## Si Alice no se acerca, al cabo de WAIT_MS el gato termina de llegar hasta ella.

signal hugged

const SCALE := 0.95
const SPEED := 22.0
const STOP_DX := 34.0
const TOUCH_DX := 22.0
const WAIT_MS := 8000.0

@onready var sprite: AnimatedSprite2D = $Sprite
var level: Node
var state := ""
var state_at := 0.0
var done := false


func setup(owner_level: Node, flip: bool) -> void:
	level = owner_level
	z_index = C.Z_PLAYER - 1
	sprite.sprite_frames = Assets.sprite_frames("gato_morado")
	Anim.set_origin(sprite, Assets.cell_size("gato_morado"), 0.5, 1.0)
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.flip_h = flip
	_go("WAKE")


func _go(s: String) -> void:
	state = s
	state_at = level.now
	match s:
		"WAKE":
			Anim.show_frame(sprite, "blink", 0)
		"APPROACH":
			Anim.play(sprite, "walk")
		"WAIT":
			Anim.play(sprite, "sit")
		"CUDDLE":
			Anim.play(sprite, "purr")


func _physics_process(delta: float) -> void:
	if level == null or done:
		return
	var p: Player = level.player
	var dx := p.position.x - position.x
	sprite.flip_h = dx < 0
	var t: float = level.now - state_at
	match state:
		"WAKE":
			if t > 900:
				Anim.play(sprite, "idle")
			if t > 1700:
				_go("APPROACH")
		"APPROACH", "WAIT":
			if absf(dx) <= TOUCH_DX and absf(p.position.y - position.y) < 24:
				cuddle()
				return
			var stop := STOP_DX if state == "APPROACH" or t < WAIT_MS else 0.0
			if absf(dx) > stop + 2:
				if state == "WAIT" and t < WAIT_MS:
					_go("APPROACH")
				position.x += signf(dx) * SPEED * delta
				sprite.position.y = -absf(sin(level.now / 120.0)) * 1.5
				sprite.rotation_degrees = sin(level.now / 120.0) * 4.0
			elif state == "APPROACH":
				sprite.position.y = 0
				sprite.rotation_degrees = 0
				_go("WAIT")


## Animación de cariño: ronroneo, un corazón que sube y chispas.
func cuddle() -> void:
	if done:
		return
	done = true
	_go("CUDDLE")
	sprite.position.y = 0
	sprite.rotation_degrees = 0
	AudioManager.play("purr")
	var tw := sprite.create_tween().set_loops(4)
	tw.tween_property(sprite, "scale", Vector2(SCALE * 1.06, SCALE * 0.95), 0.18)
	tw.tween_property(sprite, "scale", Vector2(SCALE, SCALE), 0.18)
	var heart := Sprite2D.new()
	heart.texture = Assets.frame("w8_fx", "cat_heart")
	heart.position = position + Vector2(0, -30)
	heart.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(heart)
	var ht := heart.create_tween().set_parallel()
	ht.tween_property(heart, "position:y", heart.position.y - 26, 1.4).set_trans(Tween.TRANS_SINE)
	ht.tween_property(heart, "scale", Vector2(1.6, 1.6), 1.4)
	ht.chain().tween_property(heart, "modulate:a", 0.0, 0.5)
	ht.chain().tween_callback(heart.queue_free)
	level.effects.sparkle(position.x, position.y - 16, 16)
	hugged.emit()
