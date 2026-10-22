extends DoorLevel
## Mundo 8 — El Castillo de las Pesadillas. El motor común construye el mapa desde JSON; las
## plataformas fantasma, los puentes ocultos y sus faroles mágicos, los charcos y la bruma de
## sombras, los ganchos en cadena, las estrellas que caen, las plataformas colgantes, las setas
## elásticas y el cofre son objetos del builder. Aquí sólo se aplican los contactos propios del
## mundo, los tres recuerdos mágicos y la apertura de la gran puerta del salón del trono.

## Motivos de los mundos anteriores que muestra cada recuerdo: [personaje, animación, cuadro].
const MEMORIES := {
	"courage": {"title": "Recuerdo del valor", "sprites": [["nubarron", "idle", 1], ["locomostro", "defeated", 2], ["luna_estelar", "defeated", 1]]},
	"imagination": {"title": "Recuerdo de la imaginación", "sprites": [["garabato", "idle", 1], ["patoburbuja", "defeated", 0], ["don_chupeton", "defeated", 1]]},
	"friendship": {"title": "Recuerdo de la amistad", "sprites": [["sieston", "defeated", 2], ["player", "victory", 1], ["gato_morado", "purr", 0]]},
}

## Próximo instante en que una sombra puede volver a hacer daño (intervalo, no cada fotograma).
var shadow_next := 0.0
var door_opening := false
var vision: Node2D


func on_custom_overlap(kind: String, entity: Object) -> void:
	match kind:
		"heart":
			if entity.collect(player):
				GameState.show_toast("¡Corazón de sueño!")
		"shadow":
			if now >= shadow_next and not player.is_invulnerable():
				shadow_next = now + ShadowZone.DAMAGE_INTERVAL
				player.hurt(entity.position.x + entity.width / 2.0)
		"slow_cloud":
			entity.apply(player)
		"chest":
			if entity.touch("key_1" in GameState.get_v("dreamCollectibles", []), player):
				GameState.show_banner("¡El tesoro del castillo!")
				var list: Array = GameState.get_v("dreamCollectibles", []).duplicate()
				if not "chest_1" in list:
					list.append("chest_1")
				GameState.set_v("dreamCollectibles", list)
		"shootable":
			pass  # los faroles reaccionan a los disparos (y al tocarlos, con su propio kind)
		"door":
			open_giant_door()
		_:
			super(kind, entity)


## La puerta gigantesca se abre hacia el salón del trono: brilla, se abre y Alice entra.
func open_giant_door() -> void:
	if door_opening or leaving or player.dead:
		return
	door_opening = true
	player.frozen = true
	player.velocity.x = 0
	AudioManager.play("magic_reveal")
	camera.shake(260, 0.003)
	effects.glow_flash(door.position + Vector2(0, -30), C.rgb(0xd85cd5), 1.0, 6.0, 900, 0.9, 1)
	effects.sparkle(door.position.x, door.position.y - 30, 24)
	var tw := door.create_tween()
	tw.tween_property(door, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_BACK)
	GameState.show_banner("¡La gran puerta se abre!")
	after(900, func():
		player.frozen = false
		enter_door())


## Coleccionables: además de contarlos, cada recuerdo mágico muestra un instante breve de la
## aventura (motivos de los mundos anteriores). No es una cinemática: Alice sigue al mando.
func on_dream_collectible(item: DreamCollectible) -> void:
	var memory := ""
	for d in data.get("dreamCollectibles", []):
		if str(d.id) == item.id:
			memory = str(d.get("memory", ""))
	super(item)
	if memory != "" and not item.active:
		show_memory(memory)


func show_memory(memory: String) -> void:
	var m: Dictionary = MEMORIES.get(memory, {})
	if m.is_empty():
		return
	AudioManager.play("memory")
	GameState.show_banner(m.title)
	if vision != null and is_instance_valid(vision):
		vision.queue_free()
	vision = Node2D.new()
	vision.z_index = C.Z_UI_WORLD
	vision.position = player.position + Vector2(0, -78)
	fx_root.add_child(vision)
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.modulate = Color(C.rgb(0xc8a5ff), 0.55)
	glow.scale = Vector2(5.5, 2.4)
	vision.add_child(glow)
	var sprites: Array = m.sprites
	for i in sprites.size():
		var s: Array = sprites[i]
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = Assets.sprite_frames(s[0])
		Anim.show_frame(spr, s[1], int(s[2]))
		Anim.set_origin(spr, Assets.cell_size(s[0]), 0.5, 0.5)
		var cell := Assets.cell_size(s[0])
		var k := clampf(30.0 / maxf(cell.x, cell.y), 0.18, 1.0)
		spr.scale = Vector2(k, k)
		spr.position = Vector2((i - 1) * 34, 0)
		vision.add_child(spr)
	vision.modulate.a = 0.0
	vision.scale = Vector2(0.6, 0.6)
	var tw := vision.create_tween()
	tw.set_parallel()
	tw.tween_property(vision, "modulate:a", 1.0, 0.3)
	tw.tween_property(vision, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(vision, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(vision.queue_free)
	effects.sparkle(player.position.x, player.position.y - 40, 14)


func on_update(_time: float, _delta: float) -> void:
	if vision != null and is_instance_valid(vision):
		vision.position = vision.position.lerp(player.position + Vector2(0, -78), 0.15)


func on_respawn() -> void:
	shadow_next = 0.0
