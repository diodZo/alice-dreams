class_name DreamNarrative
## Datos narrativos de cada mundo (criaturas rescatables, reflexión de Alice, recuerdo/sticker y
## forma purificada del jefe). La clave es el número de mundo que ve el jugador (WorldRegistry):
## el Mundo 5 (Tren de Juguete) usa los archivos world6 y el Mundo 6 (Parque de las Estrellas)
## los archivos world5. Los nombres de los mundos y de los jefes NO están aquí: salen de
## WorldRegistry y de los datos de cada arena.
##
##   rescuable  tipos de enemigo (clave de EnemySpawner/EnemyDef) que se liberan al vencerlos.
##              Son el identificador estable de la criatura en el guardado.
##   reflection frase breve de Alice para su página del diario.
##   purified   forma restaurada del jefe (texto del diario). El dibujo es el fotograma oficial
##              que ya usa la pantalla de victoria (WorldRegistry: bossFrames/bossAnim/bossFrame).
##   memento    recuerdo del mundo: sticker del diario y objeto de la habitación de Alice.
##              {atlas, frame} = fotograma de un atlas; {frames, anim, index} = fotograma de un
##              personaje. `size` = lado mayor en píxeles al dibujarlo como recuerdo.

const VERSION := 1

const WORLDS := {
	1: {
		"rescuable": ["scratch", "spit"],
		"reflection": "Hasta la nube más gris puede volver a sonreír.",
		"purified": "una nubecita feliz",
		"memento": {"atlas": "world1_objects", "frame": "cloud_face_small", "size": 26, "label": "Nubecita"},
	},
	2: {
		"rescuable": ["crayon", "brush"],
		"reflection": "Los colores vuelven cuando dibujamos con cariño.",
		"purified": "un dibujo sonriente de mil colores",
		"memento": {"atlas": "world2_objects", "frame": "magic_crayon_red", "size": 18, "label": "Crayones"},
	},
	3: {
		"rescuable": ["rabbit", "pillow"],
		"reflection": "Descansar también es una forma de ser valiente.",
		"purified": "un peluche dormilón y cariñoso",
		"memento": {"frames": "rabbit", "anim": "idle", "index": 0, "size": 36, "label": "Peluche"},
	},
	4: {
		"rescuable": ["bubble_fish", "pompa"],
		"reflection": "Una burbuja pequeña puede llevar una gran alegría.",
		"purified": "un patito de goma amistoso",
		"memento": {"atlas": "world4_objects", "frame": "duck_a", "size": 20, "label": "Patito"},
	},
	5: {
		"rescuable": ["payasito", "vagoncito"],
		"reflection": "Los viajes son más bonitos cuando se comparten.",
		"purified": "una locomotora de juguete alegre",
		"memento": {"atlas": "world6_objects", "frame": "train_loco", "size": 30, "label": "Tren"},
	},
	6: {
		"rescuable": ["estrellita", "meteorito"],
		"reflection": "En la noche más oscura siempre brilla una estrella.",
		"purified": "una lunita luminosa y tranquila",
		"memento": {"atlas": "world5_objects", "frame": "special_star", "size": 20, "label": "Estrella", "glow": true},
	},
	7: {
		"rescuable": ["cuppy", "gomilito"],
		"reflection": "Lo dulce sabe mejor cuando se comparte.",
		"purified": "un pastelito juguetón",
		"memento": {"atlas": "world7_objects", "frame": "candy_lolli", "size": 20, "label": "Caramelo"},
	},
	8: {
		"rescuable": ["fantasmita", "murcibola"],
		"reflection": "Un abrazo puede vencer a la pesadilla más grande.",
		"purified": "un gatito morado adorable",
		"memento": {"frames": "gato_morado", "anim": "sleep", "index": 0, "size": 30, "label": "Gatito"},
	},
}


static func get_world(world_id: int) -> Dictionary:
	return WORLDS.get(world_id, {})


static func rescuable(world_id: int) -> Array:
	return get_world(world_id).get("rescuable", [])


static func is_rescuable(world_id: int, creature_id: String) -> bool:
	return creature_id in rescuable(world_id)


static func world_ids() -> Array:
	return WORLDS.keys()


## Nombre visible de una criatura (el de su EnemyDef, para no repetir nombres).
static func creature_name(creature_id: String) -> String:
	var def := Assets.enemy_def(creature_id)
	return def.display_name if def != null and def.display_name != "" else creature_id


## Textura de un recuerdo (fotograma de atlas o de personaje).
static func memento_texture(world_id: int) -> Texture2D:
	var m: Dictionary = get_world(world_id).get("memento", {})
	if m.has("atlas"):
		return Assets.frame(m.atlas, m.frame)
	if m.has("frames"):
		var sf := Assets.sprite_frames(m.frames)
		if sf != null and sf.has_animation(m.anim):
			return sf.get_frame_texture(m.anim, clampi(int(m.get("index", 0)), 0, sf.get_frame_count(m.anim) - 1))
	return null


## Sprite de un recuerdo escalado para que su lado mayor mida `size` px (o el valor dado).
static func memento_sprite(world_id: int, size := -1.0) -> Sprite2D:
	var m: Dictionary = get_world(world_id).get("memento", {})
	var tex := memento_texture(world_id)
	var s := Sprite2D.new()
	s.texture = tex
	if tex != null:
		var target := float(m.get("size", 20)) if size <= 0 else size
		var k := target / maxf(1.0, maxf(tex.get_width(), tex.get_height()))
		s.scale = Vector2(k, k)
	return s
