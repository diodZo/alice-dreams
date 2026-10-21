class_name DreamJournalEntry
extends RefCounted
## Una página del Diario de Sueños (datos ya calculados; la dibuja DreamJournalPage).
## La construye DreamJournalManager a partir de WorldRegistry, DreamNarrative, los datos del
## mundo y SaveManager. No guarda nada por sí misma.

var world_id := 1
var name := ""
var short_name := ""
## La página se desbloquea sólo cuando el mundo está completado en el guardado.
var unlocked := false
var is_new := false
var boss_name := ""
## Forma restaurada (texto) y fotograma oficial del jefe vencido (WorldRegistry).
var purified_form := ""
var boss_frames := ""
var boss_anim := ""
var boss_frame := 0
var boss_purified := false
var reflection := ""
## Criaturas rescatables del mundo y las ya rescatadas (tipos estables).
var rescuable: Array = []
var rescued: Array = []
## Secretos = coleccionables persistentes del mundo (crayones mágicos, tesoros del sueño).
var secrets_found := 0
var secrets_total := 0
var best_stars := 0
var total_stars := 0
var special_star := false


## Sticker especial: el mundo completado con todos sus secretos.
func sticker_unlocked() -> bool:
	return unlocked and secrets_found >= secrets_total


func all_rescued() -> bool:
	for c in rescuable:
		if not c in rescued:
			return false
	return true


## Página completa: desbloqueada, todas las criaturas rescatadas y el sticker conseguido.
func is_complete() -> bool:
	return unlocked and all_rescued() and sticker_unlocked()
