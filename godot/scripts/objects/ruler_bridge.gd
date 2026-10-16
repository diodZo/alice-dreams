class_name RulerBridge
extends StaticBody2D
## Puente de reglas escolares (Mundo 2), unidireccional como las nubes y los puentes arcoíris.
## Variantes (todas con el mismo código, según los datos):
##  - recto:       {x, y, w}                      (teselas; y = superficie)
##  - inclinado:   {x, y, to: [x2, y2]}
##  - articulado:  {x, y, points: [[x2, y2], ...]} (bisagras en cada unión)
##  - dibujado:    "drawn": true  -> el Borrador saltarín puede borrarlo un rato
##  - temporal:    "cycle": [ms visible, ms oculto, desfase]
##  - activable:   "switch": [x, y] -> aparece al tocar el molinillo interruptor
## Gráficos de tilesets_world_2.png: tramo de regla repetido, postes y bisagras.

var level: Node
var atlas := "world2_objects"
var points: Array[Vector2] = []
var drawn := false
var solid := true
var cycle: Array = []
var segments: Array[Node2D] = []
var shapes: Array[CollisionShape2D] = []
var _visual: Node2D
var _restore_id := -1


func setup(owner_level: Node, def: Dictionary, atlas_key := "world2_objects") -> RulerBridge:
	level = owner_level
	atlas = atlas_key
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	var p0 := Vector2(float(def.x), float(def.y)) * C.TILE
	points = [p0]
	if def.has("points"):
		for p in def.points:
			points.append(Vector2(float(p[0]), float(p[1])) * C.TILE)
	elif def.has("to"):
		points.append(Vector2(float(def.to[0]), float(def.to[1])) * C.TILE)
	else:
		points.append(p0 + Vector2(float(def.w) * C.TILE, 0))
	drawn = def.get("drawn", false)
	cycle = def.get("cycle", [])
	_visual = Node2D.new()
	add_child(_visual)
	_build()
	if def.has("switch"):
		set_solid(false, false)
	if drawn:
		_visual.modulate = Color(1, 1, 1, 0.92)
	return self


func _build() -> void:
	var mid := Assets.frame(atlas, "ruler_mid")
	var h := mid.get_height()
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var d := b - a
		var ang := d.angle()
		var seg := Node2D.new()
		seg.position = a
		seg.rotation = ang
		var strip := TiledSprite.new().setup(mid, Vector2(d.length(), h))
		strip.position = Vector2(0, -2)
		seg.add_child(strip)
		_visual.add_child(seg)
		segments.append(seg)
		# cuerpo unidireccional de 8 px bajo la superficie del tramo (gira con él)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(d.length(), 8)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.rotation = ang
		cs.position = a + d / 2.0 + Vector2(0, 4).rotated(ang)
		cs.one_way_collision = true
		cs.one_way_collision_margin = 5.0
		add_child(cs)
		shapes.append(cs)
	# postes en los extremos y bisagras en las uniones
	for i in points.size():
		var p := points[i]
		var spr := Sprite2D.new()
		if i == 0 or i == points.size() - 1:
			spr.texture = Assets.frame(atlas, "ruler_post")
			Anim.set_origin(spr, spr.texture.get_size(), 0.5, 0.0)
			spr.position = p + Vector2(0, -6)
		else:
			spr.texture = Assets.frame(atlas, "ruler_hinge")
			spr.position = p + Vector2(0, 2)
		spr.z_index = 1
		_visual.add_child(spr)


## Longitud total y altura de la superficie en una x (para pruebas y enemigos).
func surface_y_at(x: float) -> float:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(1.0, b.x - a.x))
	return INF


func covers_x(x: float) -> bool:
	return x >= points[0].x and x <= points[-1].x


func set_solid(on: bool, animate := true) -> void:
	solid = on
	for cs in shapes:
		cs.set_deferred("disabled", not on)
	var target_alpha := (0.92 if drawn else 1.0) if on else 0.0
	if animate:
		var tw := _visual.create_tween()
		tw.tween_property(_visual, "modulate:a", target_alpha, 0.25)
	else:
		_visual.modulate.a = target_alpha


## Lo borra el Borrador saltarín: desaparece y vuelve a dibujarse al rato.
func erase_temporarily(ms: float) -> void:
	if not drawn or not solid:
		return
	set_solid(false)
	level.effects.poof(points[0].lerp(points[-1], 0.5).x, points[0].y, 12)
	var ref: WeakRef = weakref(self)
	_restore_id = level.after(ms, func():
		var b: RulerBridge = ref.get_ref()
		if b != null:
			b._redraw())


func _redraw() -> void:
	set_solid(true)
	level.effects.sparkle(points[0].lerp(points[-1], 0.5).x, points[0].y - 6, 10)


## Interruptor: el puente se dibuja tramo a tramo de izquierda a derecha.
func activate() -> void:
	if solid:
		return
	solid = true
	_visual.modulate.a = 0.92 if drawn else 1.0
	for i in segments.size():
		var seg := segments[i]
		seg.scale = Vector2(0, 1)
		var tw := seg.create_tween()
		tw.tween_interval(i * 0.18)
		tw.tween_property(seg, "scale", Vector2.ONE, 0.3)
	for cs in shapes:
		cs.set_deferred("disabled", false)
	AudioManager.play("checkpoint")


## Puentes temporales: aparecen y desaparecen con un ritmo fijo y avisan antes de irse.
func _physics_process(_delta: float) -> void:
	if cycle.is_empty() or level == null:
		return
	var on_ms: float = cycle[0]
	var off_ms: float = cycle[1]
	var t := fposmod(level.now + float(cycle[2] if cycle.size() > 2 else 0), on_ms + off_ms)
	var should := t < on_ms
	if should != solid:
		set_solid(should)
	elif should and on_ms - t < 700:
		_visual.modulate.a = 0.35 if int(t / 90.0) % 2 else (0.92 if drawn else 1.0)


func on_player_contact() -> void:
	pass
