class_name WorldData
extends Resource
## Datos de un mundo del carrusel del menú principal (WorldCarousel / WorldCard).
## El progreso no se guarda aquí: el estado se calcula siempre desde SaveManager y
## WorldRegistry (el mismo sistema que usan el menú, el mapa y la pantalla de victoria).
##
## Ilustración de cada isla:
##   - Definitiva: una isla separada con transparencia en `island_path`
##     (res://resources/menu/islands/world_N.png). Todavía no existe ninguna.
##   - Provisional: mientras falte, se recorta `fallback_region` de world_map_bg.png
##     (mapa de mundos a 480x270) y WorldCard le aplica una máscara ovalada suave.

enum State { LOCKED, UNLOCKED, COMPLETED }

const ISLANDS_DIR := "res://resources/menu/islands/"
const MAP_ART := preload("res://resources/menu/world_map_bg.png")
## Orden fijo del carrusel: [id en WorldRegistry, nombre, recorte provisional en world_map_bg.png].
const CATALOG := [
	[1, "Nubes de Algodón", Rect2(8, 22, 115, 94)],
	[2, "Crayones", Rect2(125, 56, 110, 64)],
	[3, "Peluches", Rect2(243, 48, 115, 71)],
	[4, "Océano de Burbujas", Rect2(365, 42, 110, 74)],
	[5, "Juguetes", Rect2(128, 148, 112, 68)],
	[6, "Parque de las Estrellas", Rect2(8, 143, 118, 76)],
	[7, "Bosque de Caramelos", Rect2(243, 152, 115, 74)],
	[8, "Castillo de los Sueños", Rect2(358, 137, 117, 88)],
]

@export var id := 1
@export var title := ""
@export_file("*.png") var island_path := ""
@export var fallback_region := Rect2()

var _texture: Texture2D


static func catalog() -> Array[WorldData]:
	var list: Array[WorldData] = []
	for row in CATALOG:
		var d := WorldData.new()
		d.id = row[0]
		d.title = row[1]
		d.fallback_region = row[2]
		d.island_path = ISLANDS_DIR + "world_%d.png" % d.id
		list.append(d)
	return list


## ¿Existe la isla separada definitiva?
func has_island() -> bool:
	return island_path != "" and ResourceLoader.exists(island_path)


func texture() -> Texture2D:
	if _texture == null:
		if has_island():
			_texture = load(island_path)
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = MAP_ART
			atlas.region = fallback_region
			_texture = atlas
	return _texture


func state() -> State:
	if SaveManager.is_world_completed(id):
		return State.COMPLETED
	return State.UNLOCKED if can_enter() or is_pending() else State.LOCKED


## Implementado y desbloqueado en el guardado.
func can_enter() -> bool:
	return WorldRegistry.is_playable(id)


## Desbloqueado en el guardado pero todavía sin escena (Mundo 8 al completar el 7): se muestra
## sin candado, pero no se intenta abrir ninguna escena.
func is_pending() -> bool:
	var w := WorldRegistry.get_world(id)
	return not w.is_empty() and not w.get("implemented", false) and id <= SaveManager.unlocked_world()


## Texto bajo el carrusel para el mundo seleccionado.
func describe() -> String:
	var head := "Mundo %d: %s" % [id, title]
	match state():
		State.COMPLETED:
			return head + " - %d estrellas" % int(SaveManager.get_world(id).get("bestStars", 0))
		State.UNLOCKED:
			return head + (" - Desbloqueado: próximamente" if is_pending() else " - ¡A jugar!")
	if not WorldRegistry.get_world(id).get("implemented", false):
		return head + " - Próximamente"
	return head + " - Completa el Mundo %d" % (id - 1)
