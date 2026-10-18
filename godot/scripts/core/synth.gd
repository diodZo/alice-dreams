class_name Synth
## SONIDOS PROVISIONALES sintetizados (port de systems/SynthSounds.js).
## El proyecto Phaser no tiene archivos de audio: genera efectos y música chiptune con
## WebAudio. Aquí se reproducen los mismos parámetros (onda, frecuencias, envolventes
## exponenciales, ruido filtrado y partituras) renderizándolos a AudioStreamWAV.
## Se sustituyen asignando archivos reales en scripts/core/audio_config.gd.

const RATE := 22050
const MASTER := 0.9
const FLOOR := 0.0001
const NOTE_INDEX := {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

## Efectos: lista de componentes. tone: [tipo, desde, hasta, inicio, duración, volumen, ataque]
## noise: [inicio, duración, volumen, frecuencia del filtro, q]; arp: [notas, paso, tipo, volumen, duración]
const SFX := {
	"jump": [["tone", "square", 280, 620, 0, 0.13, 0.09]],
	"shoot_bubble": [["tone", "sine", 700, 1300, 0, 0.1, 0.12], ["tone", "sine", 1300, 1700, 0.04, 0.06, 0.06]],
	"shoot_paint": [["noise", 0, 0.12, 0.12, 1800, 2], ["tone", "triangle", 520, 260, 0, 0.1, 0.12]],
	"shoot_sling": [["tone", "square", 180, 90, 0, 0.12, 0.1], ["noise", 0.02, 0.08, 0.07, 3000, 1]],
	"weapon_switch": [["arp", ["E5", "B5"], 0.05, "square", 0.07, 0.06]],
	"star": [["arp", ["C6", "E6", "G6"], 0.045, "square", 0.07, 0.08]],
	"pickup": [["arp", ["C5", "E5", "G5", "C6", "E6"], 0.06, "square", 0.08, 0.1]],
	"hurt": [["tone", "square", 440, 140, 0, 0.25, 0.12], ["noise", 0, 0.1, 0.08, 800, 1]],
	"checkpoint": [["arp", ["G4", "C5", "E5", "G5", "C6"], 0.07, "triangle", 0.16, 0.16]],
	"boss_appear": [["tone", "sawtooth", 110, 55, 0, 0.9, 0.12, 0.1], ["noise", 0, 0.9, 0.1, 300, 1], ["arp", ["A4", "F4", "D4", "A3"], 0.12, "square", 0.08, 0.14]],
	"victory": [["arp", ["C5", "E5", "G5", "C6", "G5", "C6", "E6"], 0.11, "square", 0.09, 0.14], ["arp", ["C4", "G4", "C5"], 0.25, "triangle", 0.14, 0.3]],
	"enemy_hit": [["tone", "square", 600, 300, 0, 0.07, 0.08]],
	"enemy_defeat": [["noise", 0, 0.2, 0.1, 1500, 1], ["arp", ["G5", "E5", "C5"], 0.05, "triangle", 0.1, 0.08]],
	"bubble_trap": [["tone", "sine", 400, 900, 0, 0.25, 0.12]],
	"bubble_pop": [["tone", "sine", 1200, 300, 0, 0.06, 0.14], ["noise", 0, 0.05, 0.06, 4000, 1]],
	"bounce": [["tone", "sine", 160, 640, 0, 0.22, 0.16]],
	"wind": [["noise", 0, 0.6, 0.08, 600, 0.7]],
	"boss_hit": [["tone", "square", 300, 180, 0, 0.06, 0.07]],
	"ui_move": [["tone", "square", 660, 660, 0, 0.04, 0.05]],
	"ui_select": [["arp", ["C5", "G5"], 0.05, "square", 0.08, 0.07]],
	"pause": [["arp", ["G5", "C5"], 0.06, "square", 0.06, 0.07]],
	"no_weapon": [["tone", "square", 200, 180, 0, 0.08, 0.06]],
	"portal": [["tone", "sine", 300, 1200, 0, 0.7, 0.12, 0.05], ["arp", ["C6", "G6", "E6", "C7"], 0.09, "triangle", 0.06, 0.12]],
	# Mundo 4: brazada bajo el agua y chapuzón
	"swim": [["tone", "sine", 300, 520, 0, 0.12, 0.09], ["tone", "sine", 900, 1400, 0.03, 0.05, 0.05]],
	"splash": [["noise", 0, 0.25, 0.1, 2200, 0.8], ["tone", "sine", 600, 200, 0, 0.15, 0.08]],
	# Mundo 5: tintineo de estrella que cae, motor de cohete y nube que estalla en luz
	"twinkle": [["arp", ["E6", "B6", "G6"], 0.05, "triangle", 0.07, 0.07]],
	"rocket": [["noise", 0, 0.35, 0.07, 1200, 0.9], ["tone", "square", 120, 260, 0, 0.3, 0.05]],
	"cloud_boom": [["noise", 0, 0.3, 0.1, 900, 0.8], ["arp", ["C6", "G5", "E6"], 0.04, "sine", 0.08, 0.06]],
}

## Pistas de música (8 corcheas por compás). Token = nota, "-" = mantener, "." = silencio.
const MUSIC := {
	"menu": {
		"bpm": 96, "lead": ["triangle", 0.07], "bass": ["sine", 0.08],
		"melody": "E5 - G5 - C6 - B5 - | A5 - G5 - E5 - - - | F5 - A5 - G5 - E5 - | D5 - - - . . . . | E5 - G5 - C6 - D6 - | E6 - D6 - C6 - A5 - | B5 - G5 - A5 - B5 - | C6 - - - . . . .",
		"bassline": "C3 . G3 . E3 . G3 . | A2 . E3 . C3 . E3 . | F2 . C3 . A2 . C3 . | G2 . D3 . B2 . D3 . | C3 . G3 . E3 . G3 . | A2 . E3 . C3 . E3 . | G2 . D3 . B2 . D3 . | C3 . G3 . C3 . . .",
	},
	"world1": {
		"bpm": 126, "lead": ["square", 0.045], "bass": ["triangle", 0.1],
		"melody": "C5 . E5 . G5 - E5 . | A5 . G5 . E5 - C5 . | D5 . F5 . A5 - G5 . | E5 - - . D5 - - . | C5 . E5 . G5 - C6 . | B5 . A5 . G5 - E5 . | F5 . A5 . G5 . D5 . | C5 - - - . . . . | E5 . E5 . F5 . G5 . | G5 . F5 . E5 . D5 . | C5 . C5 . D5 . E5 . | E5 - D5 . D5 - - . | E5 . E5 . F5 . G5 . | G5 . F5 . E5 . D5 . | C5 . C5 . D5 . E5 . | D5 - C5 . C5 - - .",
		"bassline": "C3 . G2 . C3 . G2 . | F2 . C3 . F2 . C3 . | D3 . A2 . D3 . A2 . | G2 . D3 . G2 . B2 . | C3 . G2 . C3 . G2 . | A2 . E3 . A2 . E3 . | F2 . C3 . G2 . D3 . | C3 . G2 . C3 . . . | C3 . G2 . C3 . G2 . | G2 . D3 . G2 . D3 . | A2 . E3 . A2 . E3 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . G2 . | G2 . D3 . G2 . D3 . | A2 . E3 . F2 . C3 . | G2 . D3 . C3 . . .",
	},
	"boss": {
		"bpm": 150, "lead": ["square", 0.05], "bass": ["sawtooth", 0.05],
		"melody": "A4 . C5 . E5 . A5 . | G5 . E5 . C5 . E5 . | F5 . A5 . C6 . A5 . | G5 - - . E5 - - . | A4 . C5 . E5 . A5 . | B5 . A5 . G5 . E5 . | F5 . E5 . D5 . B4 . | A4 - - - . . . .",
		"bassline": "A2 A2 . A2 E3 . A2 . | C3 C3 . C3 G3 . C3 . | F2 F2 . F2 C3 . F2 . | G2 G2 . G2 D3 . G2 . | A2 A2 . A2 E3 . A2 . | E2 E2 . E2 B2 . E2 . | D3 D3 . D3 A2 . D3 . | E2 E2 . E2 G#2 . E2 .",
	},
	# --- Mundo 2 (provisionales, estilo chiptune NES: pulso + triángulo) ---
	"world2": {
		"bpm": 138, "lead": ["square", 0.045], "bass": ["triangle", 0.1],
		"melody": "G5 . E5 G5 C6 - B5 . | A5 . F5 A5 C6 - A5 . | G5 . E5 G5 C6 - E6 . | D6 - C6 . B5 - - . | A5 . C6 A5 G5 . E5 . | F5 . A5 F5 E5 . C5 . | D5 . E5 F5 G5 - B5 . | C6 - - - . . G5 . | E5 E5 . G5 C6 . E5 . | F5 F5 . A5 C6 . F5 . | G5 G5 . B5 D6 . G5 . | E6 - D6 - C6 - . . | A5 . G5 . F5 . E5 . | D5 . E5 . F5 . A5 . | G5 . F5 . E5 . D5 . | C5 - - - . . . .",
		"bassline": "C3 . G3 . C3 . G3 . | F2 . C3 . F2 . C3 . | C3 . G3 . C3 . G3 . | G2 . D3 . G2 . D3 . | A2 . E3 . A2 . E3 . | F2 . C3 . F2 . C3 . | G2 . D3 . G2 . B2 . | C3 . G2 . C3 . . . | C3 . E3 . G3 . E3 . | F2 . A2 . C3 . A2 . | G2 . B2 . D3 . B2 . | C3 . G2 . C3 . G2 . | F2 . C3 . F2 . C3 . | D3 . A2 . D3 . A2 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . . .",
	},
	"garabato": {
		"bpm": 160, "lead": ["square", 0.05], "bass": ["sawtooth", 0.045],
		"melody": "E5 . G5 . B5 . E5 . | D5 . F#5 . A5 . D5 . | C5 . E5 . G5 . C6 . | B5 - A5 - G5 - F#5 - | E5 . G5 . B5 . E6 . | D6 . B5 . G5 . E5 . | F#5 . A5 . B5 . D6 . | E6 - - - B5 - - - | G5 G5 . G5 A5 . B5 . | A5 A5 . A5 G5 . F#5 . | E5 E5 . E5 F#5 . G5 . | F#5 - E5 - D#5 - B4 - | E5 . E5 . G5 . B5 . | C6 . B5 . A5 . G5 . | F#5 . G5 . A5 . F#5 . | E5 - - - . . . .",
		"bassline": "E2 E2 . E2 B2 . E2 . | D2 D2 . D2 A2 . D2 . | C2 C2 . C2 G2 . C2 . | B1 B1 . B1 F#2 . B1 . | E2 E2 . E2 B2 . E2 . | G2 G2 . G2 D3 . G2 . | D2 D2 . D2 A2 . D2 . | B1 B1 . B1 F#2 . B1 . | E2 E2 . E2 B2 . E2 . | A2 A2 . A2 E3 . A2 . | C2 C2 . C2 G2 . C2 . | B1 B1 . B1 D#2 . B1 . | E2 E2 . E2 B2 . E2 . | A2 A2 . A2 E3 . A2 . | B1 B1 . B1 F#2 . B1 . | E2 E2 . E2 B2 . E2 .",
	},
	"world2_victory": {
		"bpm": 120, "lead": ["square", 0.05], "bass": ["triangle", 0.1],
		"melody": "C5 . E5 . G5 . C6 - | - - B5 . C6 . D6 . | E6 - - - D6 - C6 - | B5 - G5 - - - . . | A5 . C6 . F6 - E6 . | D6 . C6 . B5 . A5 . | G5 . C6 . E6 - D6 . | C6 - - - . . . .",
		"bassline": "C3 . G3 . C3 . G3 . | G2 . D3 . G2 . D3 . | A2 . E3 . A2 . E3 . | E2 . B2 . E2 . B2 . | F2 . C3 . F2 . C3 . | D3 . A2 . D3 . A2 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . . .",
	},
	# Mundo 3: caja de música nocturna; el jefe acelera el motivo sin abandonar el tono infantil.
	"world3": {
		"bpm": 112, "lead": ["triangle", 0.065], "bass": ["square", 0.045],
		"melody": "C5 . E5 . G5 - E5 . | D5 . F5 . A5 - F5 . | E5 . G5 . C6 - B5 . | A5 - G5 - E5 - - . | F5 . A5 . C6 . A5 . | G5 . E5 . D5 . G5 . | C5 . E5 . G5 . B5 . | C6 - - - . . . .",
		"bassline": "C3 . G3 . C3 . G3 . | F2 . C3 . F2 . C3 . | A2 . E3 . A2 . E3 . | G2 . D3 . G2 . D3 . | F2 . C3 . F2 . C3 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . G2 . | C3 . G2 . C3 . . .",
	},
	"sieston": {
		"bpm": 154, "lead": ["square", 0.05], "bass": ["triangle", 0.09],
		"melody": "C5 C5 . E5 G5 . C6 . | B5 . G5 . E5 . D5 . | F5 F5 . A5 C6 . A5 . | G5 - F5 - E5 - D5 - | C5 . E5 . G5 . C6 . | A5 . C6 . E6 . C6 . | D6 . B5 . G5 . D5 . | C5 - - - . . . .",
		"bassline": "C3 C3 . C3 G2 . C3 . | G2 G2 . G2 D3 . G2 . | F2 F2 . F2 C3 . F2 . | G2 G2 . G2 D3 . G2 . | C3 C3 . C3 G2 . C3 . | A2 A2 . A2 E3 . A2 . | G2 G2 . G2 D3 . G2 . | C3 C3 . C3 G2 . C3 .",
	},
	# Mundo 4: melodía saltarina y acuática (pulso + triángulo, arpegios como burbujas).
	"world4": {
		"bpm": 132, "lead": ["square", 0.045], "bass": ["triangle", 0.1],
		"melody": "G5 . C6 . E6 . C6 . | D6 . B5 . G5 - . . | A5 . C6 . F6 . E6 . | D6 - C6 - B5 - . . | G5 . C6 . E6 . G6 . | F6 . D6 . B5 . G5 . | A5 . B5 . C6 . D6 . | C6 - - - . . G5 . | E5 G5 C6 . E5 G5 C6 . | F5 A5 C6 . F5 A5 D6 . | G5 B5 D6 . G5 B5 E6 . | C6 - - . G5 - - . | A5 . G5 . F5 . E5 . | D5 . F5 . A5 . C6 . | B5 . A5 . G5 . F5 . | E5 - D5 - C5 - . .",
		"bassline": "C3 . G3 . C3 . G3 . | G2 . D3 . G2 . D3 . | F2 . C3 . F2 . C3 . | G2 . D3 . G2 . B2 . | C3 . G3 . C3 . G3 . | G2 . D3 . G2 . D3 . | F2 . C3 . G2 . D3 . | C3 . G2 . C3 . . . | C3 . E3 . G3 . E3 . | F2 . A2 . C3 . A2 . | G2 . B2 . D3 . B2 . | C3 . G2 . C3 . G2 . | F2 . C3 . F2 . C3 . | D3 . A2 . D3 . A2 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . . .",
	},
	"patoburbuja": {
		"bpm": 156, "lead": ["square", 0.05], "bass": ["triangle", 0.09],
		"melody": "E5 . G5 . C6 . G5 . | E5 . G5 C6 E6 - D6 . | F5 . A5 . D6 . A5 . | F5 . A5 D6 F6 - E6 . | G5 . B5 . D6 . G6 . | F6 . D6 . B5 . G5 . | C6 . E6 . D6 . B5 . | C6 - - - . . . .",
		"bassline": "C3 C3 . C3 G2 . C3 . | C3 C3 . C3 G2 . E3 . | D3 D3 . D3 A2 . D3 . | D3 D3 . D3 A2 . F3 . | G2 G2 . G2 D3 . G2 . | G2 G2 . G2 D3 . B2 . | A2 A2 . F2 F2 . G2 . | C3 C3 . C3 G2 . C3 .",
	},
	"world4_victory": {
		"bpm": 116, "lead": ["square", 0.05], "bass": ["triangle", 0.1],
		"melody": "C6 . G5 . E5 . G5 . | C6 . E6 . G6 - - . | F6 . E6 . D6 . C6 . | D6 - - - G5 . . . | C6 . G5 . E5 . G5 . | A5 . C6 . F6 - E6 . | D6 . B5 . G5 . B5 . | C6 - - - . . . .",
		"bassline": "C3 . G3 . C3 . G3 . | A2 . E3 . A2 . E3 . | F2 . C3 . F2 . C3 . | G2 . D3 . G2 . D3 . | C3 . G3 . C3 . G3 . | F2 . C3 . F2 . C3 . | G2 . D3 . G2 . D3 . | C3 . G2 . C3 . . .",
	},
	"world3_victory": {
		"bpm": 104, "lead": ["triangle", 0.075], "bass": ["sine", 0.09],
		"melody": "C5 . E5 . G5 . C6 - | E6 - D6 . C6 . G5 . | A5 . C6 . E6 - D6 . | C6 - - - . . . .",
		"bassline": "C3 . G3 . C3 . G3 . | A2 . E3 . A2 . E3 . | F2 . C3 . G2 . D3 . | C3 . G2 . C3 . . .",
	},
	# Mundo 5: cielo nocturno; arpegios brillantes como estrellas sobre un bajo suave.
	"world5": {
		"bpm": 124, "lead": ["square", 0.045], "bass": ["triangle", 0.1],
		"melody": "E5 . G5 . B5 . E6 . | D6 - B5 . G5 . A5 . | C6 . E6 . G6 - E6 . | D6 - - - B5 . . . | A5 . C6 . E6 . A6 . | G6 . E6 . C6 . E6 . | F#6 . D6 . A5 . D6 . | B5 - - - . . E5 . | G5 B5 E6 . G5 B5 E6 . | A5 C6 E6 . A5 C6 F6 . | B5 D6 G6 . B5 D6 F#6 . | E6 - - . B5 - - . | C6 . B5 . A5 . G5 . | F#5 . A5 . C6 . E6 . | D6 . C6 . B5 . A5 . | G5 - F#5 - E5 - . .",
		"bassline": "E3 . B3 . E3 . B3 . | G2 . D3 . G2 . D3 . | C3 . G3 . C3 . G3 . | G2 . D3 . G2 . B2 . | A2 . E3 . A2 . E3 . | C3 . G3 . C3 . G3 . | D3 . A3 . D3 . A3 . | G2 . D3 . G2 . . . | E3 . G3 . B3 . G3 . | A2 . C3 . E3 . C3 . | G2 . B2 . D3 . B2 . | E3 . B2 . E3 . B2 . | C3 . G3 . C3 . G3 . | D3 . A2 . D3 . A2 . | G2 . D3 . G2 . D3 . | E3 . B2 . E3 . . .",
	},
	"luna_estelar": {
		"bpm": 150, "lead": ["square", 0.05], "bass": ["triangle", 0.09],
		"melody": "A5 . C6 . E6 . C6 . | A5 . E6 A6 G6 - E6 . | F5 . A5 . C6 . A5 . | F5 . C6 F6 E6 - C6 . | G5 . B5 . D6 . G6 . | F6 . D6 . B5 . G5 . | E6 . G#6 . B6 . G#6 . | A6 - - - . . . .",
		"bassline": "A2 A2 . A2 E3 . A2 . | A2 A2 . A2 E3 . G2 . | F2 F2 . F2 C3 . F2 . | F2 F2 . F2 C3 . E2 . | G2 G2 . G2 D3 . G2 . | G2 G2 . G2 D3 . B2 . | E2 E2 . E2 B2 . E2 . | A2 A2 . A2 E3 . A2 .",
	},
	"world5_victory": {
		"bpm": 112, "lead": ["triangle", 0.075], "bass": ["sine", 0.09],
		"melody": "G5 . B5 . D6 . G6 - | F#6 . D6 . B5 . D6 . | E6 . G6 . B6 - A6 . | G6 - - - . . . . | C6 . E6 . G6 . E6 . | D6 . F#6 . A6 . F#6 . | G6 . D6 . B5 . D6 . | G6 - - - . . . .",
		"bassline": "G2 . D3 . G2 . D3 . | D3 . A2 . D3 . A2 . | E3 . B2 . E3 . B2 . | G2 . D3 . G2 . . . | C3 . G3 . C3 . G3 . | D3 . A3 . D3 . A3 . | G2 . D3 . G2 . D3 . | G2 . D3 . G2 . . .",
	},
}

static var _noise: PackedFloat32Array
## Interrumpe la generación de música (al cerrar el juego).
static var abort := false


static func note_to_freq(note: String) -> float:
	var re := RegEx.create_from_string("^([A-G]#?)(\\d)$")
	var m := re.search(note)
	if m == null:
		return 0.0
	var midi := 12 * (int(m.get_string(2)) + 1) + int(NOTE_INDEX[m.get_string(1)])
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _wave(type: String, phase: float) -> float:
	match type:
		"sine":
			return sin(TAU * phase)
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"sawtooth":
			return 2.0 * phase - 1.0
		"triangle":
			return 1.0 - 4.0 * absf(phase - 0.5)
	return 0.0


## tone(): oscilador con rampa exponencial de frecuencia y envolvente exponencial.
static func _tone(buf: PackedFloat32Array, type: String, from: float, to: float, start: float, dur: float, vol: float, attack := 0.005) -> void:
	var s0 := int(start * RATE)
	var n := int((dur + 0.02) * RATE)
	var phase := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var t := float(i) / RATE
		var f := from
		if to != from:
			f = from * pow(to / from, minf(t, dur) / dur)
		var g: float
		if t < attack:
			g = FLOOR * pow(vol / FLOOR, t / attack)
		elif t < dur:
			g = vol * pow(FLOOR / vol, (t - attack) / (dur - attack))
		else:
			g = FLOOR
		buf[idx] += _wave(type, phase) * g
		phase = fmod(phase + f / RATE, 1.0)


static func _noise_buffer() -> PackedFloat32Array:
	if _noise.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		_noise.resize(int(RATE * 0.5))
		for i in _noise.size():
			_noise[i] = rng.randf() * 2.0 - 1.0
	return _noise


## noise(): ruido blanco (búfer de 0,5 s, sin bucle) por un filtro pasa-banda.
static func _add_noise(buf: PackedFloat32Array, start: float, dur: float, vol: float, freq: float, q: float) -> void:
	var src := _noise_buffer()
	var w0 := TAU * freq / RATE
	var alpha := sin(w0) / (2.0 * q)
	var a0 := 1.0 + alpha
	var b0 := alpha / a0
	var b2 := -alpha / a0
	var a1 := -2.0 * cos(w0) / a0
	var a2 := (1.0 - alpha) / a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var s0 := int(start * RATE)
	var n := mini(int((dur + 0.02) * RATE), src.size())
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var x := src[i]
		var y := b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var t := float(i) / RATE
		var g := vol * pow(FLOOR / vol, minf(t, dur) / dur)
		buf[idx] += y * g


static func _sfx_length(parts: Array) -> float:
	var length := 0.0
	for p in parts:
		match p[0]:
			"tone":
				length = maxf(length, p[3] + p[5])
			"noise":
				length = maxf(length, p[1] + p[2])
			"arp":
				length = maxf(length, (p[1].size() - 1) * p[2] + p[5])
	return length + 0.05


static func render_sfx(event: String) -> AudioStreamWAV:
	if not SFX.has(event):
		return null
	var parts: Array = SFX[event]
	var buf := PackedFloat32Array()
	buf.resize(int(_sfx_length(parts) * RATE))
	for p in parts:
		match p[0]:
			"tone":
				_tone(buf, p[1], p[2], p[3], p[4], p[5], p[6], p[7] if p.size() > 7 else 0.005)
			"noise":
				_add_noise(buf, p[1], p[2], p[3], p[4], p[5])
			"arp":
				var notes: Array = p[1]
				for i in notes.size():
					var f := note_to_freq(notes[i])
					_tone(buf, p[3], f, f, i * p[2], p[5], p[4])
	return _to_stream(buf, false)


static func _parse_track(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	for tok in s.replace("|", " ").split(" ", false):
		out.append(tok)
	return out


static func _duration_of(arr: PackedStringArray, i: int, step: float) -> float:
	var n := 1
	while arr[(i + n) % arr.size()] == "-" and n < 16:
		n += 1
	return n * step


## scheduleNote(): ataque de 10 ms, sostenido y caída exponencial final de 40 ms.
static func _note(buf: PackedFloat32Array, type: String, vol: float, freq: float, start: int, dur: float) -> void:
	var hold := maxf(0.02, dur - 0.04)
	var n := int((dur + 0.02) * RATE)
	var size := buf.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var g: float
		if t < 0.01:
			g = FLOOR * pow(vol / FLOOR, t / 0.01)
		elif t < hold:
			g = vol
		elif t < dur:
			g = vol * pow(FLOOR / vol, (t - hold) / (dur - hold))
		else:
			g = FLOOR
		buf[(start + i) % size] += _wave(type, phase) * g
		phase = fmod(phase + freq / RATE, 1.0)


## Renderiza una pista completa como bucle continuo (las notas que cruzan el final se
## pliegan al principio, igual que el secuenciador en bucle de Phaser).
static func render_music(track: String) -> AudioStreamWAV:
	if not MUSIC.has(track):
		return null
	var song: Dictionary = MUSIC[track]
	var melody := _parse_track(song.melody)
	var bass := _parse_track(song.bassline)
	var step: float = 60.0 / song.bpm / 2.0
	var steps := maxi(melody.size(), bass.size())
	var buf := PackedFloat32Array()
	buf.resize(int(steps * step * RATE))
	for i in steps:
		if abort:
			return null
		var start := int(i * step * RATE)
		var m := melody[i % melody.size()]
		var b := bass[i % bass.size()]
		if m != "-" and m != ".":
			_note(buf, song.lead[0], song.lead[1], note_to_freq(m), start, _duration_of(melody, i % melody.size(), step) * 0.92)
		if b != "-" and b != ".":
			_note(buf, song.bass[0], song.bass[1], note_to_freq(b), start, _duration_of(bass, i % bass.size(), step) * 0.9)
	return _to_stream(buf, true)


static func _to_stream(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * MASTER, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s
