class_name Timers
extends RefCounted
## Acciones diferidas sobre el reloj del nivel (equivale a scene.time.delayedCall de Phaser).
## Se procesan en el bucle de física del dueño, por lo que respetan la pausa y se pueden
## cancelar todas a la vez (clear), como hacía Enemy.clearTimers().

var _items: Array = []
var _next_id := 0
## Cambia en cada clear(): las acciones de una generación anterior ya no se ejecutan.
var _generation := 0


## Programa `fn` para dentro de `ms` milisegundos (respecto a `now`). Devuelve un id.
func add(now: float, ms: float, fn: Callable) -> int:
	_next_id += 1
	_items.append({"id": _next_id, "at": now + ms, "fn": fn, "gen": _generation})
	return _next_id


func cancel(id: int) -> void:
	_items = _items.filter(func(t): return t.id != id)


func clear() -> void:
	_items.clear()
	_generation += 1


func is_empty() -> bool:
	return _items.is_empty()


func process(now: float) -> void:
	if _items.is_empty():
		return
	var due: Array = []
	var rest: Array = []
	for t in _items:
		if now >= t.at:
			due.append(t)
		else:
			rest.append(t)
	if due.is_empty():
		return
	_items = rest
	due.sort_custom(func(a, b): return a.at < b.at)
	for t in due:
		# una acción anterior de este mismo fotograma puede haber cancelado el resto
		if t.gen != _generation:
			continue
		var fn: Callable = t.fn
		if fn.is_valid():
			fn.call()
