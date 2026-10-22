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
	"swim": "",
	"splash": "",
}

const MUSIC_FILES := {
	"menu": "res://resources/audio/menu_principal.mp3",
	"world1": "res://resources/audio/mundo_1.mp3",
	"boss": "res://resources/audio/jefe_mundo_1.mp3",
	"world2": "res://resources/audio/mundo_2.mp3",
	"garabato": "res://resources/audio/jefe_mundo_2.mp3",
	"world2_victory": "",
	"world3": "",
	"sieston": "",
	"world3_victory": "",
	"world4": "",
	"patoburbuja": "",
	"world4_victory": "",
	"world5": "",
	"luna_estelar": "",
	"world5_victory": "",
	"world6": "",
	"locomostro": "",
	"world6_victory": "",
	"world7": "",
	"don_chupeton": "",
	"world7_victory": "",
	"world8": "",
	"rey_pesadelo": "",
	"rey_pesadelo_fury": "",
	"transformation": "",
	"alice_awakening": "",
	"alice_credits": "",
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
	"world4": "res://resources/audio/world4_theme.ogg",
	"patoburbuja": "res://resources/audio/rey_patoburbuja_boss.ogg",
	"world4_victory": "res://resources/audio/world4_victory.ogg",
	"world5": "res://resources/audio/world5_theme.ogg",
	"luna_estelar": "res://resources/audio/luna_estelar_boss.ogg",
	"world5_victory": "res://resources/audio/world5_victory.ogg",
	"world6": "res://resources/audio/world6_theme.ogg",
	"locomostro": "res://resources/audio/locomostro_boss.ogg",
	"world6_victory": "res://resources/audio/world6_victory.ogg",
	"world7": "res://resources/audio/world7_theme.ogg",
	"don_chupeton": "res://resources/audio/don_chupeton_boss.ogg",
	"world7_victory": "res://resources/audio/world7_victory.ogg",
	# Mundo 8 y final de la aventura
	"world8": "res://resources/audio/world8_theme.ogg",
	"rey_pesadelo": "res://resources/audio/rey_pesadelo_boss.ogg",
	"rey_pesadelo_fury": "res://resources/audio/rey_pesadelo_fury.ogg",
	"transformation": "res://resources/audio/transformation_theme.ogg",
	"alice_awakening": "res://resources/audio/alice_awakening.ogg",
	"alice_credits": "res://resources/audio/alice_credits.ogg",
}
