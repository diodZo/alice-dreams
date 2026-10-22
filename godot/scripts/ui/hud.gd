extends CanvasLayer
## Interfaz superpuesta (port de ui/GameHUD.js). Lee el estado de GameState y escucha avisos:
##  - corazones, arma seleccionada, estrellas, progreso del nivel, vida de Nubarrón
##  - banner (título grande) y toast (aviso corto)

const PROGRESS_W := 160.0

var hearts: Array[TextureRect] = []
var weapon_icon: TextureRect
var weapon_name: PixelText
var weapon_dots: Control
var star_text: PixelText
var progress_x := 0.0
var progress_marks: Control
var progress_marker: Control
var section_text: PixelText
var boss_group: Control
var boss_bar: ColorRect
var boss_ghost: ColorRect
var _ghost_tween: Tween
var boss_notches: Array[ColorRect] = []
var boss_label: PixelText
## Mundo 2: casillas de los crayones mágicos (rojo, azul, amarillo).
var magic_icons: Array[TextureRect] = []
var moon_icons: Array[TextureRect] = []
var banner: PixelText
var toast: PixelText
var _banner_tween: Tween
var _toast_tween: Tween
var _hearts_tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(C.GAME_W, C.GAME_H)
	add_child(root)
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)

	# --- corazones ---
	for i in 5:
		var h := TextureRect.new()
		h.texture = Assets.frame("fx", "heart_full")
		h.position = Vector2(10 + i * 11, 10)
		h.visible = false
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(h)
		hearts.append(h)

	# --- arma seleccionada ---
	root.add_child(_panel(Rect2(8, 22, 26, 22), Color(C.INK, 0.55), 4, Color(C.CREAM, 0.8)))
	weapon_icon = TextureRect.new()
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_icon.visible = false
	root.add_child(weapon_icon)
	weapon_name = PixelText.make("", {"tint": C.CREAM})
	weapon_name.position = Vector2(38, 28)
	root.add_child(weapon_name)
	weapon_dots = Control.new()
	weapon_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_dots.draw.connect(_draw_weapon_dots)
	root.add_child(weapon_dots)

	# --- estrellas ---
	var star_icon := TextureRect.new()
	star_icon.texture = Assets.frame("fx", "star_gold")
	star_icon.scale = Vector2(0.7, 0.7)
	star_icon.position = Vector2(W - 52, 12) - star_icon.texture.get_size() * 0.7 / 2.0
	star_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(star_icon)
	star_text = PixelText.make("0", {"tint": C.YELLOW})
	star_text.position = Vector2(W - 42, 7)
	root.add_child(star_text)
	for i in 3:
		var m := TextureRect.new()
		var c: String = ["red", "blue", "yellow"][i]
		m.texture = Assets.frame("world2_objects", "magic_crayon_" + c) if Assets.has_frame("world2_objects", "magic_crayon_" + c) else null
		m.scale = Vector2(0.5, 0.5)
		m.position = Vector2(W - 58 + i * 12, 20)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.visible = false
		root.add_child(m)
		magic_icons.append(m)
	# Mundos 3 y 4: los tres coleccionables principales (lunas, conchas); el resto sólo cuenta
	# en la victoria. El icono sale de los datos del mundo (GameState "dreamHud").
	var dream_hud: Array = GameState.get_v("dreamHud", ["world3_objects", "moon_w3", "moon_"])
	for i in 3:
		var m := TextureRect.new()
		m.texture = Assets.frame(dream_hud[0], dream_hud[1]) if Assets.has_frame(dream_hud[0], dream_hud[1]) else null
		m.scale = Vector2(0.5, 0.5)
		m.position = Vector2(W - 58 + i * 12, 20)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.visible = false
		root.add_child(m)
		moon_icons.append(m)

	# --- progreso del nivel ---
	progress_x = W / 2.0 - 80
	var px := progress_x
	root.add_child(_panel(Rect2(px - 3, 6, 166, 10), Color(C.INK, 0.55), 4))
	var line := ColorRect.new()
	line.color = Color(C.CREAM, 0.9)
	line.position = Vector2(px, 10)
	line.size = Vector2(PROGRESS_W, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)
	progress_marks = Control.new()
	progress_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_marks.draw.connect(_draw_progress_marks)
	root.add_child(progress_marks)
	var flag := TextureRect.new()
	flag.texture = Assets.frame("fx", "star_gold")
	flag.scale = Vector2(0.45, 0.45)
	flag.position = Vector2(px + PROGRESS_W, 11) - flag.texture.get_size() * 0.45 / 2.0
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flag)
	progress_marker = Control.new()
	progress_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_marker.draw.connect(func():
		progress_marker.draw_circle(Vector2.ZERO, 3.0, C.PINK, true, -1.0, false)
		progress_marker.draw_arc(Vector2.ZERO, 3.0, 0, TAU, 16, C.INK, 1.0, false))
	progress_marker.position = Vector2(px, 11)
	root.add_child(progress_marker)
	section_text = PixelText.make("", {"origin": Vector2(0.5, 0), "tint": C.CREAM})
	section_text.position = Vector2(W / 2.0, 19)
	root.add_child(section_text)

	# --- barra del jefe ---
	boss_group = Control.new()
	boss_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_group.position = Vector2(W / 2.0, H - 16)
	root.add_child(boss_group)
	boss_group.add_child(_panel(Rect2(-102, -6, 204, 12), Color(C.INK, 0.75), 5))
	# tramo "fantasma" (IMP-020): muestra el daño reciente y se vacía con retraso
	boss_ghost = ColorRect.new()
	boss_ghost.color = Color(C.CREAM, 0.85)
	boss_ghost.position = Vector2(-100, -3)
	boss_ghost.size = Vector2(200, 6)
	boss_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_group.add_child(boss_ghost)
	boss_bar = ColorRect.new()
	boss_bar.color = C.LAVENDER
	boss_bar.position = Vector2(-100, -3)
	boss_bar.size = Vector2(200, 6)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_group.add_child(boss_bar)
	# muescas donde el jefe cambia de fase (IMP-033)
	for t in C.BOSS_PHASE_THRESHOLDS:
		var notch := ColorRect.new()
		notch.color = C.CREAM
		notch.position = Vector2(-100 + roundf(200 * t), -5)
		notch.size = Vector2(1, 10)
		notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boss_group.add_child(notch)
		boss_notches.append(notch)
	boss_label = PixelText.make("Nubarrón", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW})
	boss_label.position = Vector2(0, -16)
	boss_group.add_child(boss_label)
	boss_group.visible = false

	# --- avisos ---
	banner = PixelText.make("", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.CREAM, "center": true, "max_width": 440.0})
	banner.position = Vector2(W / 2.0, 70)
	banner.modulate.a = 0
	root.add_child(banner)
	toast = PixelText.make("", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "center": true, "max_width": 400.0})
	toast.position = Vector2(W / 2.0, 96)
	toast.modulate.a = 0
	root.add_child(toast)

	# --- controles táctiles ---
	if GameState.touch_mode:
		root.add_child(TouchControls.new())

	GameState.changed.connect(refresh)
	GameState.banner.connect(show_banner)
	GameState.toast.connect(show_toast)
	refresh("")


func _panel(rect: Rect2, fill: Color, radius: int, border := Color(0, 0, 0, 0)) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = false
	if border.a > 0:
		sb.border_color = border
		sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func refresh(key: String) -> void:
	var all := key == ""
	if all or key == "hp" or key == "maxHp":
		var hp := int(GameState.get_v("hp", 3))
		var mx := int(GameState.get_v("maxHp", 3))
		for i in hearts.size():
			hearts[i].visible = i < mx
			hearts[i].texture = Assets.frame("fx", "heart_full" if i < hp else "heart_empty")
		if key == "hp":
			if _hearts_tween:
				_hearts_tween.kill()
			_hearts_tween = create_tween().set_parallel()
			for h in hearts:
				h.scale = Vector2.ONE
				_hearts_tween.tween_property(h, "scale", Vector2(1.25, 1.25), 0.08)
			_hearts_tween.chain()
			for h in hearts:
				_hearts_tween.parallel().tween_property(h, "scale", Vector2.ONE, 0.08)
	if all or key == "weapon" or key == "weaponsOwned":
		var id: Variant = GameState.get_v("weapon")
		var w: WeaponDef = Assets.weapon(id) if id is String and id != "" else null
		if w:
			weapon_icon.texture = Assets.frame("fx", w.icon)
			weapon_icon.size = weapon_icon.texture.get_size()
			weapon_icon.position = Vector2(21, 33) - weapon_icon.size / 2.0
			weapon_icon.visible = true
			weapon_name.text = w.display_name
		else:
			weapon_icon.visible = false
			weapon_name.text = "Sin arma"
		weapon_dots.queue_redraw()
	if all or key == "stars":
		star_text.text = str(int(GameState.get_v("stars", 0)))
	if all or key == "progress":
		progress_marker.position.x = progress_x + float(GameState.get_v("progress", 0.0)) * PROGRESS_W
	if all or key == "progressMarks":
		progress_marks.queue_redraw()
	if all or key == "section":
		var s: Variant = GameState.get_v("section")
		section_text.text = "Sección %s" % s if s is String and s != "" else ""
	if all or key == "bossName":
		boss_label.text = str(GameState.get_v("bossName", "Nubarrón"))
	if all or key in ["magicCrayons", "magicTotal"]:
		var have: Array = GameState.get_v("magicCrayons", [])
		var shown := int(GameState.get_v("magicTotal", 0)) > 0
		for i in magic_icons.size():
			var c: String = ["red", "blue", "yellow"][i]
			magic_icons[i].visible = shown
			magic_icons[i].modulate = Color.WHITE if c in have else Color(0.25, 0.22, 0.4, 0.7)
	if all or key in ["dreamCollectibles", "dreamTotal"]:
		var dream: Array = GameState.get_v("dreamCollectibles", [])
		var shown_moons := int(GameState.get_v("dreamTotal", 0)) > 0
		for i in moon_icons.size():
			moon_icons[i].visible = shown_moons
			var prefix: String = GameState.get_v("dreamHud", ["", "", "moon_"])[2]
			moon_icons[i].modulate = Color.WHITE if "%s%d" % [prefix, i + 1] in dream else Color(0.25, 0.22, 0.4, 0.7)
	if all or key in ["bossVisible", "bossHp", "bossMaxHp"]:
		boss_group.visible = bool(GameState.get_v("bossVisible", false))
		var mx := float(GameState.get_v("bossMaxHp", 1))
		var ratio := clampf(float(GameState.get_v("bossHp", mx)) / maxf(mx, 1.0), 0, 1)
		boss_bar.size.x = 200 * ratio
		if boss_bar.size.x >= boss_ghost.size.x:
			boss_ghost.size.x = boss_bar.size.x
		else:
			if _ghost_tween:
				_ghost_tween.kill()
			_ghost_tween = boss_ghost.create_tween()
			_ghost_tween.tween_interval(0.35)
			_ghost_tween.tween_property(boss_ghost, "size:x", boss_bar.size.x, 0.4)
		var th: Array = C.BOSS_PHASE_THRESHOLDS
		boss_bar.color = C.LAVENDER if ratio > th[0] else (C.PINK if ratio > th[1] else C.rgb(0xff7a9a))


func _draw_weapon_dots() -> void:
	var id: Variant = GameState.get_v("weapon")
	var owned: Array = GameState.get_v("weaponsOwned", [])
	for i in owned.size():
		var sel: bool = owned[i] == id
		weapon_dots.draw_rect(Rect2(38 + i * 6, 38, 4, 3), C.YELLOW if sel else Color(C.CREAM, 0.5))


func _draw_progress_marks() -> void:
	for m in GameState.get_v("progressMarks", []):
		progress_marks.draw_rect(Rect2(progress_x + float(m) * PROGRESS_W, 8, 1, 6), C.LAVENDER)


func show_banner(text: String) -> void:
	if _banner_tween:
		_banner_tween.kill()
	banner.text = text
	banner.modulate.a = 0
	banner.position.y = 64
	_banner_tween = create_tween().set_parallel()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(banner, "position:y", 70.0, 0.25)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4).set_delay(2.2)


func show_toast(text: String) -> void:
	if _toast_tween:
		_toast_tween.kill()
	toast.text = text
	toast.modulate.a = 1
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4).set_delay(1.8)
