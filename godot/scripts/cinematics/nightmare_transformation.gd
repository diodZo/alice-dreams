class_name NightmareTransformation
extends Node2D
## Transformación del Rey Pesadelo en el gato morado (no es un cambio instantáneo de sprite).
## Una Animation construida en código para el AnimationPlayer de la escena encadena:
##   0.0 s  agotamiento (cuadro "defeated" 0) y partículas moradas
##   0.0-1.1 s  sus ojos dejan de brillar amenazadoramente
##   1.2 s  encoge entre humo morado (cuadro 1); 1.6 y 2.0 s las garras desaparecen entre nubes
##   2.4 s  el gato asoma entre el humo (cuadro 2); el monstruo sigue encogiendo
##   3.2-3.9 s  fundido: el monstruo se desvanece y aparece el gato morado dormido
##   4.6 s  el gato abre los ojos; 5.4 s fin (`finished`)
## Todo con los cuadros oficiales de jefemundo8.png (filas "Derrotado / Transformación" y
## "Gato morado tierno").

signal finished

const LENGTH := 5.4
const CAT_SCALE := 0.95

@onready var monster: AnimatedSprite2D = $Monster
@onready var cat: AnimatedSprite2D = $Cat
@onready var smoke: Node2D = $Smoke
@onready var front: Node2D = $Front
@onready var player: AnimationPlayer = $AnimationPlayer
var flip := false
var eyes: Array[Sprite2D] = []
var particles: ParticleBurst
var started := false


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	monster.sprite_frames = Assets.sprite_frames("rey_pesadelo")
	Anim.set_origin(monster, Assets.cell_size("rey_pesadelo"), 0.5, 1.0)
	monster.flip_h = flip
	Anim.show_frame(monster, "defeated", 0)
	cat.sprite_frames = Assets.sprite_frames("gato_morado")
	Anim.set_origin(cat, Assets.cell_size("gato_morado"), 0.5, 1.0)
	cat.flip_h = flip
	Anim.show_frame(cat, "sleep", 0)
	cat.modulate.a = 0.0
	cat.scale = Vector2(CAT_SCALE * 0.7, CAT_SCALE * 0.7)
	for i in 2:
		var e := Sprite2D.new()
		e.texture = Assets.generated("glow")
		e.modulate = Color(C.rgb(0xffd23c), 0.7)
		e.scale = Vector2(0.4, 0.4)
		e.position = Vector2((-1 if flip else 1) * (24 + i * 9), -40)
		front.add_child(e)
		eyes.append(e)
	particles = ParticleBurst.new().setup({
		"speed": [15, 55], "angle": [200, 340], "life": [700, 1300], "scale": [1.8, 0], "alpha": [0.9, 0],
		"gravity": -30, "colors": Effects.colors([0x713ca8, 0xd85cd5, 0xc8a5ff, 0xf6b4e9]),
	})
	particles.auto_free = false
	front.add_child(particles)
	player.add_animation_library("", _library())
	player.animation_finished.connect(func(_n): finished.emit())


func play() -> void:
	if started:
		return
	started = true
	if not is_node_ready():
		await ready
	player.play("transform")
	AudioManager.play_music("transformation")


func _library() -> AnimationLibrary:
	var a := Animation.new()
	a.length = LENGTH
	# cuadros del monstruo (pista de métodos)
	var m := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(m, ".")
	for k in [[0.0, "_monster_frame", [0]], [1.2, "_monster_frame", [1]], [2.4, "_monster_frame", [2]], [4.6, "_cat_wake", []],
			[0.15, "_burst", [10]], [1.0, "_burst", [14]], [2.0, "_burst", [18]], [3.0, "_burst", [22]],
			[1.6, "_claw_puff", [-1]], [2.0, "_claw_puff", [1]], [1.4, "_smoke", [0]], [1.9, "_smoke", [1]], [2.5, "_smoke", [2]],
			[3.6, "_sparkles", []], [3.3, "_sound", ["magic_reveal"]], [4.7, "_sound", ["meow"]]]:
		a.track_insert_key(m, k[0], {"method": k[1], "args": k[2]})
	# el monstruo encoge y se desvanece
	_value(a, "Monster:scale", [[0.0, Vector2.ONE], [1.2, Vector2(0.94, 0.94)], [2.4, Vector2(0.8, 0.8)], [3.4, Vector2(0.55, 0.55)]])
	_value(a, "Monster:modulate", [[0.0, Color.WHITE], [2.4, Color(0.85, 0.7, 1.0, 1.0)], [3.2, Color(0.85, 0.7, 1.0, 1.0)], [3.9, Color(0.85, 0.7, 1.0, 0.0)]])
	# sus ojos dejan de brillar
	_value(a, "Front:modulate", [[0.0, Color.WHITE], [1.1, Color(1, 1, 1, 0)]])
	# el gato morado aparece entre el humo
	_value(a, "Cat:modulate", [[0.0, Color(1, 1, 1, 0)], [3.2, Color(1, 1, 1, 0)], [3.9, Color.WHITE]])
	_value(a, "Cat:scale", [[0.0, Vector2(CAT_SCALE * 0.7, CAT_SCALE * 0.7)], [3.2, Vector2(CAT_SCALE * 0.7, CAT_SCALE * 0.7)], [4.0, Vector2(CAT_SCALE, CAT_SCALE)]])
	_value(a, "Smoke:modulate", [[0.0, Color(1, 1, 1, 0)], [1.4, Color(1, 1, 1, 0.85)], [3.4, Color(1, 1, 1, 0.85)], [4.4, Color(1, 1, 1, 0)]])
	var lib := AnimationLibrary.new()
	lib.add_animation("transform", a)
	return lib


func _value(a: Animation, path: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
	for k in keys:
		a.track_insert_key(t, k[0], k[1])


func _monster_frame(i: int) -> void:
	Anim.show_frame(monster, "defeated", i)


func _burst(n: int) -> void:
	particles.explode(n, Vector2(randf_range(-20, 20), -30))


## Las garras desaparecen entre nubes mágicas.
func _claw_puff(side: int) -> void:
	var s := Sprite2D.new()
	s.texture = Assets.frame("w8_fx", "gas_puff")
	s.modulate = C.rgb(0xd8b8ff)
	s.position = Vector2(side * 34, -10)
	front.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2(1.6, 1.6), 0.6)
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(s.queue_free)
	AudioManager.play("bubble_pop")


## Humo morado mágico alrededor (nubes del efecto de la hoja, teñidas sin calaveras visibles).
func _smoke(i: int) -> void:
	var s := Sprite2D.new()
	s.texture = Assets.frame("w8_fx", "gas_puff")
	s.modulate = Color(C.rgb(0x9b6ad8), 0.8)
	s.scale = Vector2(2.2, 2.0)
	s.position = Vector2((i - 1) * 26, -24 - (i % 2) * 10)
	smoke.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", s.position.y - 3, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", s.position.y, 0.5).set_trans(Tween.TRANS_SINE)


func _sparkles() -> void:
	var lv: Node = get_parent()
	while lv != null and not lv is Level:
		lv = lv.get_parent()
	if lv != null:
		lv.effects.sparkle(global_position.x, global_position.y - 16, 20)


func _cat_wake() -> void:
	Anim.show_frame(cat, "blink", 0)


func _sound(ev: String) -> void:
	AudioManager.play(ev)
