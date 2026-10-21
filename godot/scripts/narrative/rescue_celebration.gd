class_name RescueCelebration
extends CanvasLayer
## Celebración breve de las criaturas liberadas en el nivel (pantalla de victoria y créditos):
## entre una y cinco criaturas, según las que se hayan rescatado de verdad, saltan de alegría,
## saludan y sueltan corazones. Termina sola a los DURATION segundos; Saltar, Disparar, Enter,
## Esc o un clic la terminan antes (después de SKIP_AFTER). Mientras se ve, el menú de debajo no
## recibe pulsaciones.

signal finished

const DURATION := 4.2
const SKIP_AFTER := 0.3
const MAX_SHOWN := 5
## Altura objetivo de cada criatura en pantalla (px lógicos; escala entera 1 o 2).
const TARGET_H := 40.0

var creatures: Array = []
var shown: Array[AnimatedSprite2D] = []
var t := 0.0
var done := false
var _heart_acc := 0.0


## creature_ids: un tipo por criatura rescatada (puede repetirse). Devuelve null si no hay ninguna.
static func make(creature_ids: Array) -> RescueCelebration:
	if creature_ids.is_empty():
		return null
	var c: RescueCelebration = load("res://scenes/narrative/RescueCelebration.tscn").instantiate()
	c.creatures = _pick(creature_ids)
	return c


## Hasta MAX_SHOWN criaturas, alternando tipos para que se vean variadas.
static func _pick(ids: Array) -> Array:
	var by_type := {}
	for id in ids:
		by_type[id] = int(by_type.get(id, 0)) + 1
	var out: Array = []
	while out.size() < MAX_SHOWN and out.size() < ids.size():
		for k in by_type.keys():
			if by_type[k] > 0 and out.size() < MAX_SHOWN:
				out.append(k)
				by_type[k] -= 1
	return out


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var shade := ColorRect.new()
	shade.color = Color(C.INK, 0.94)
	shade.size = Vector2(W, H)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			skip())
	add_child(shade)
	var title := PixelText.make("¡Criaturas liberadas!", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 46)
	add_child(title)
	var names: Array = []
	for c in creatures:
		var n := DreamNarrative.creature_name(c)
		if not n in names:
			names.append(n)
	var sub := PixelText.make("Ya no tienen pesadillas: ¡gracias, Alice!", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	sub.position = Vector2(W / 2, 72)
	add_child(sub)
	var who := PixelText.make(", ".join(names), {"origin": Vector2(0.5, 0.5), "tint": C.PINK, "max_width": W - 40, "center": true})
	who.position = Vector2(W / 2, 220)
	add_child(who)
	var hint := PixelText.make("SALTAR o ENTER: continuar", {"origin": Vector2(0.5, 0.5), "tint": C.LAVENDER})
	hint.position = Vector2(W / 2, H - 14)
	add_child(hint)

	var gap := minf(80.0, (W - 60.0) / maxf(1.0, creatures.size()))
	var x0 := W / 2 - gap * (creatures.size() - 1) / 2.0
	for i in creatures.size():
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Assets.sprite_frames(creatures[i])
		Anim.set_origin(spr, Assets.cell_size(creatures[i]), 0.5, 1.0)
		var k := 2.0 if Assets.cell_size(creatures[i]).y * 2 <= TARGET_H + 8 else 1.0
		spr.scale = Vector2(k, k)
		spr.position = Vector2(x0 + i * gap, 170)
		spr.flip_h = i % 2 == 1
		Anim.play(spr, "idle")
		spr.modulate.a = 0.0
		add_child(spr)
		shown.append(spr)
		# aparecen una tras otra y saltan de alegría (cada una con su ritmo)
		var tw := spr.create_tween()
		tw.tween_interval(0.15 * i)
		tw.tween_property(spr, "modulate:a", 1.0, 0.2)
		var hop := spr.create_tween().set_loops()
		hop.tween_interval(0.1 * i)
		hop.tween_property(spr, "position:y", 156.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hop.tween_property(spr, "position:y", 170.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		hop.tween_interval(0.35)
	AudioManager.play("checkpoint")


func _process(delta: float) -> void:
	if done:
		return
	t += delta
	_heart_acc += delta
	if _heart_acc >= 0.45 and not shown.is_empty():
		_heart_acc = 0.0
		_heart(shown[randi() % shown.size()].position + Vector2(0, -36))
	if t >= DURATION:
		skip()


func _input(event: InputEvent) -> void:
	if done:
		return
	var pressed := event.is_pressed() and not event.is_echo()
	if pressed and (event.is_action("jump") or event.is_action("fire") or event.is_action("menu_accept") or event.is_action("pause") or event.is_action("ui_accept")):
		get_viewport().set_input_as_handled()
		if t >= SKIP_AFTER:
			skip()
	elif event is InputEventKey or event is InputEventAction:
		get_viewport().set_input_as_handled()


func _heart(pos: Vector2) -> void:
	var h := Sprite2D.new()
	h.texture = Assets.frame("fx", "heart_full")
	h.position = pos + Vector2(randf_range(-8, 8), 0)
	add_child(h)
	var tw := h.create_tween().set_parallel()
	tw.tween_property(h, "position:y", pos.y - 30, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(h.queue_free)


## Termina la celebración (sola, con una tecla o con un clic).
func skip() -> void:
	if done:
		return
	done = true
	var tw := create_tween()
	for c in get_children():
		if c is CanvasItem:
			tw.parallel().tween_property(c, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		finished.emit()
		queue_free())
