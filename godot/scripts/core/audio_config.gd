class_name AudioConfig
## Asociación de eventos de sonido con archivos de audio (equivale a config/audioConfig.js).
##
## Mientras un evento no tenga archivo asignado (cadena vacía), AudioManager usa el sonido
## PROVISIONAL sintetizado (scripts/core/synth.gd). Para sustituirlo: copiar el archivo a
## res://resources/audio/ y escribir aquí su ruta, p. ej. "jump": "res://resources/audio/jump.ogg".
## Si la ruta no existe se vuelve al sonido provisional: la falta de audio nunca bloquea el juego.

const SFX_FILES := {
	"jump": "",
	"shoot_bubble": "",
	"shoot_paint": "",
	"shoot_sling": "",
	"weapon_switch": "",
	"star": "",
	"hurt": "",
	"checkpoint": "",
	"boss_appear": "",
	"victory": "",
	"enemy_hit": "",
	"enemy_defeat": "",
	"bubble_trap": "",
	"bubble_pop": "",
	"bounce": "",
	"pickup": "",
	"wind": "",
	"boss_hit": "",
	"ui_move": "",
	"ui_select": "",
	"pause": "",
	"no_weapon": "",
	"portal": "",
}

const MUSIC_FILES := {
	"menu": "",
	"world1": "",
	"boss": "",
	"world2": "",
	"garabato": "",
	"world2_victory": "",
	"world3": "",
	"sieston": "",
	"world3_victory": "",
}

## Música del Mundo 2: si se copian estos archivos a res://resources/audio/, se usan en lugar de
## la versión sintetizada. Si no existen, no se intenta cargarlos (no hay referencias rotas).
const OPTIONAL_MUSIC := {
	"world2": "res://resources/audio/world2_theme.ogg",
	"garabato": "res://resources/audio/garabato_boss.ogg",
	"world2_victory": "res://resources/audio/world2_victory.ogg",
	"world3": "res://resources/audio/world3_theme.ogg",
	"sieston": "res://resources/audio/rey_sieston_boss.ogg",
	"world3_victory": "res://resources/audio/world3_victory.ogg",
}
