extends Node
## Verificación de carga: compila todos los scripts y carga/instancia todas las escenas
## con los autoloads activos. Uso:
##   godot --headless --path godot res://tests/CheckAll.tscn

var failures := 0


func _ready() -> void:
	for path in _files("res://scripts", ".gd") + _files("res://tools", ".gd") + _files("res://tests", ".gd"):
		var s := load(path)
		if s == null or (s is GDScript and not s.can_instantiate() and not _is_static_only(s)):
			_fail("script", path)
	for path in _files("res://scenes", ".tscn"):
		var ps := load(path) as PackedScene
		if ps == null:
			_fail("scene", path)
			continue
		var inst := ps.instantiate()
		if inst == null:
			_fail("instantiate", path)
		else:
			inst.free()
	for path in _files("res://resources", ".tres"):
		if load(path) == null:
			_fail("resource", path)
	print("[check_all] fallos: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _is_static_only(s: GDScript) -> bool:
	# clases sólo con funciones estáticas (C, Anim...) o que extienden SceneTree
	return s.get_instance_base_type() in ["RefCounted", "Object", "SceneTree"]


func _fail(kind: String, path: String) -> void:
	failures += 1
	printerr("[check_all] FALLO %s: %s" % [kind, path])


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out += _files(dir.path_join(sub), ext)
	return out
