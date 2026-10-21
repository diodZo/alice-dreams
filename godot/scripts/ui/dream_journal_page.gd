class_name DreamJournalPage
extends Node2D
## Contenido de una doble página del Diario de Sueños (o de la portada) dibujado sobre el libro
## abierto de DreamJournal. Coordenadas de pantalla (480x270): página izquierda x 34-232,
## página derecha x 248-446, de y 18 a 248.
##   Izquierda: número y nombre del mundo, ilustración (isla del mapa de mundos), sticker del
##              mundo y el jefe purificado (su fotograma oficial de derrota).
##   Derecha:   recuerdos (criaturas rescatadas, secretos, estrellas), reflexión de Alice y
##              progreso de la página.
## Una página bloqueada sólo muestra el número, el nombre y cómo desbloquearla.
## PROVISIONAL: no hay ilustraciones propias del diario; se reutilizan las islas del mapa de
## mundos, los sprites oficiales y dibujos de código (ver informe narrativo).

const LEFT_X := 133.0
const RIGHT_X := 347.0
const RIGHT_L := 256.0
const PAPER_INK := Color("4a3a6a")
const PAPER_SOFT := Color("8a78b0")

var entry: DreamJournalEntry


## entry == null: portada.
func build(e: DreamJournalEntry) -> DreamJournalPage:
	entry = e
	if e == null:
		_cover()
	elif not e.unlocked:
		_locked()
	else:
		_left()
		_right()
	return self


func _text(txt: String, pos: Vector2, opts: Dictionary = {}) -> PixelText:
	var o := {"origin": Vector2(0.5, 0.5), "tint": PAPER_INK}
	o.merge(opts, true)
	var t := PixelText.make(txt, o)
	t.position = pos
	add_child(t)
	return t


# ------------------------------------------------------------------ portada
func _cover() -> void:
	_text("Diario de Sueños", Vector2(240, 92), {"scale": 2, "tint": C.YELLOW})
	_text("de Alice", Vector2(240, 116), {"tint": C.PINK})
	var moon := Sprite2D.new()
	moon.texture = Assets.frame("world8_objects", "moon_gold")
	moon.position = Vector2(240, 54)
	add_child(moon)
	for p in [Vector2(70, 40), Vector2(410, 46), Vector2(96, 210), Vector2(386, 214), Vector2(150, 160), Vector2(330, 150)]:
		var s := Sprite2D.new()
		s.texture = Assets.frame("fx", "star_gold")
		s.position = p
		s.scale = Vector2(0.8, 0.8)
		add_child(s)
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "modulate:a", 0.4, 0.9 + p.x / 500.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	var count := DreamJournalManager.unlocked_count()
	_text("Páginas: %d de %d" % [count, DreamJournalManager.world_ids().size()], Vector2(240, 150), {"tint": C.CREAM})
	if DreamJournalManager.has_new_pages():
		var badge := _text("¡Nueva página!", Vector2(240, 170), {"tint": C.YELLOW})
		var bt := badge.create_tween().set_loops()
		bt.tween_property(badge, "scale", Vector2(1.15, 1.15), 0.4)
		bt.tween_property(badge, "scale", Vector2.ONE, 0.4)
	if DreamJournalManager.is_complete():
		_text("¡Diario completo!", Vector2(240, 190), {"tint": C.PINK})


# --------------------------------------------------------------- bloqueada
func _locked() -> void:
	_text("Mundo %d" % entry.world_id, Vector2(LEFT_X, 34), {"tint": PAPER_SOFT})
	_text(entry.name, Vector2(LEFT_X, 50), {"max_width": 180.0, "center": true})
	var lock := _text("?", Vector2(LEFT_X, 128), {"scale": 4, "tint": PAPER_SOFT})
	lock.modulate.a = 0.6
	_text("Página sin escribir", Vector2(RIGHT_X, 100), {"tint": PAPER_SOFT})
	_text("Completa el Mundo %d para desbloquearla" % entry.world_id, Vector2(RIGHT_X, 120), {"max_width": 180.0, "center": true})


# ------------------------------------------------------------------ izquierda
func _left() -> void:
	_text("Mundo %d" % entry.world_id, Vector2(LEFT_X, 30), {"tint": PAPER_SOFT})
	_text(entry.name, Vector2(LEFT_X, 46), {"max_width": 180.0, "center": true})
	# ilustración: la isla del mundo con un marco
	var frame := ColorRect.new()
	frame.color = Color("ffffff")
	frame.position = Vector2(LEFT_X - 64, 64)
	frame.size = Vector2(128, 82)
	add_child(frame)
	var worlds := WorldData.catalog()
	if entry.world_id - 1 < worlds.size():
		var tex := worlds[entry.world_id - 1].texture()
		var img := Sprite2D.new()
		img.texture = tex
		img.position = Vector2(LEFT_X, 105)
		var k := minf(120.0 / tex.get_width(), 74.0 / tex.get_height())
		img.scale = Vector2(k, k)
		add_child(img)
	# jefe purificado: su fotograma oficial de derrota (como la pantalla de victoria)
	if entry.boss_frames != "":
		var boss := AnimatedSprite2D.new()
		boss.sprite_frames = Assets.sprite_frames(entry.boss_frames)
		Anim.show_frame(boss, entry.boss_anim, entry.boss_frame)
		var cell := Assets.cell_size(entry.boss_frames)
		Anim.set_origin(boss, cell, 0.5, 0.5)
		var bk := clampf(48.0 / maxf(cell.x, cell.y), 0.2, 1.2)
		boss.scale = Vector2(bk, bk)
		boss.position = Vector2(70, 190)
		add_child(boss)
	_text("Jefe purificado:", Vector2(104, 168), {"origin": Vector2(0, 0.5), "tint": PAPER_SOFT})
	_text("%s, ahora %s" % [entry.boss_name, entry.purified_form], Vector2(104, 182), {"origin": Vector2(0, 0), "max_width": 126.0})
	_sticker(Vector2(214, 34))


## Sticker especial del mundo (su recuerdo); con tono apagado y "?" si aún no se ha ganado.
func _sticker(pos: Vector2) -> void:
	var holder := Node2D.new()
	holder.position = pos
	holder.rotation_degrees = -10
	add_child(holder)
	var bg := Sprite2D.new()
	bg.texture = Assets.generated("glow")
	bg.modulate = Color(1, 1, 1, 0.9) if entry.sticker_unlocked() else Color(0.7, 0.7, 0.8, 0.6)
	bg.scale = Vector2(0.9, 0.9)
	holder.add_child(bg)
	var s := DreamNarrative.memento_sprite(entry.world_id, 22)
	if not entry.sticker_unlocked():
		s.modulate = Color(0.2, 0.15, 0.3, 0.35)
	holder.add_child(s)
	if not entry.sticker_unlocked():
		var q := PixelText.make("?", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
		holder.add_child(q)


# ------------------------------------------------------------------- derecha
func _right() -> void:
	_text("Recuerdos", Vector2(RIGHT_X, 30), {"tint": C.rgb(0xb04a8a)})
	_text("Criaturas liberadas: %d de %d" % [entry.rescued.size(), entry.rescuable.size()], Vector2(RIGHT_L, 46), {"origin": Vector2(0, 0.5)})
	var n := entry.rescuable.size()
	for i in n:
		var id: String = entry.rescuable[i]
		var x := RIGHT_X + (i - (n - 1) / 2.0) * 84.0
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Assets.sprite_frames(id)
		var cell := Assets.cell_size(id)
		Anim.set_origin(spr, cell, 0.5, 1.0)
		var k := 1.0 if cell.y > 22 else 2.0
		spr.scale = Vector2(k, k)
		spr.position = Vector2(x, 92)
		var saved: bool = id in entry.rescued
		if saved:
			Anim.play(spr, "idle")
		else:
			Anim.show_frame(spr, "idle", 0)
			spr.modulate = Color(0.25, 0.2, 0.35, 0.45)
		add_child(spr)
		_text(DreamNarrative.creature_name(id) if saved else "???", Vector2(x, 102), {"max_width": 80.0, "center": true, "tint": PAPER_INK if saved else PAPER_SOFT})
	var secrets := "Este mundo no guarda secretos" if entry.secrets_total == 0 else "Secretos: %d de %d" % [entry.secrets_found, entry.secrets_total]
	_text(secrets, Vector2(RIGHT_L, 126), {"origin": Vector2(0, 0.5)})
	_text("Estrellas: %d de %d" % [entry.best_stars, entry.total_stars], Vector2(RIGHT_L, 140), {"origin": Vector2(0, 0.5)})
	_text("Sticker: %s" % ("conseguido" if entry.sticker_unlocked() else "busca todos los secretos"), Vector2(RIGHT_L, 154), {"origin": Vector2(0, 0.5)})
	# reflexión de Alice en un recuadro rosado
	var box := ColorRect.new()
	box.color = Color(C.PINK, 0.35)
	box.position = Vector2(RIGHT_L - 4, 168)
	box.size = Vector2(190, 46)
	add_child(box)
	_text("Alice piensa:", Vector2(RIGHT_L, 176), {"origin": Vector2(0, 0.5), "tint": C.rgb(0xb04a8a)})
	_text(entry.reflection, Vector2(RIGHT_L, 186), {"origin": Vector2(0, 0), "max_width": 182.0})
	var found := entry.rescued.size() + entry.secrets_found + (1 if entry.boss_purified else 0)
	var total := entry.rescuable.size() + entry.secrets_total + 1
	_text("Descubrimientos: %d de %d" % [found, total], Vector2(RIGHT_X, 232), {"tint": PAPER_SOFT})
