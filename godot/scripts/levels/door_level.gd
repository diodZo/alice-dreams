class_name DoorLevel
extends Level
## Nivel que termina en una puerta hacia la arena del jefe (castillo de Nubarrón en el Mundo 1,
## entrada al Gran Lienzo en el Mundo 2). La puerta se describe en data.door.

var door: CastleDoor


func on_create() -> void:
	door = CastleDoor.new().setup(data.door, data.backgroundAtlas)
	level_objects.objects.add_child(door)


func on_custom_overlap(kind: String, _entity: Object) -> void:
	if kind == "door":
		enter_door()
